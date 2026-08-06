# Schema Firestore — Cursos Gerados pelo Usuário
**App:** Saber Espírita
**Feature:** Geração de mini-curso personalizado (currículo → revisão → conteúdo)

---

## Visão geral do fluxo

```
1. Usuário escolhe tema (sugerido ou livre) + formato (expositivo/reflexivo/dialógico/prático)
2. App chama IA → gera CURRÍCULO (7 aulas: título + subtema + campos do prompt mestre)
3. Currículo é salvo em /userGeneratedCourses/{courseId} com status "draft_curriculum"
4. Usuário revisa/edita títulos e subtemas no app
5. Usuário confirma → status muda para "generating_content"
6. App gera conteúdo aula por aula (2 chamadas por aula: slides 1-5 e 6-9)
7. Cada aula gerada é salva em /userGeneratedCourses/{courseId}/lessons/{lessonId}
8. Quando todas as aulas estão prontas → status "published"
```

---

## Coleção: `userGeneratedCourses/{courseId}`

```typescript
interface IUserGeneratedCourse {
  id: string;                    // courseId gerado (ex: "ugc_<uid>_<timestamp>")
  userId: string;                // uid do Firebase Auth do criador
  title: string;                 // título do mini-curso (vem do currículo gerado)
  subtitle: string;              // subtítulo curto
  theme: string;                 // tema original digitado/selecionado pelo usuário
  themeSource: "suggested" | "custom"; // se veio de lista sugerida ou digitado
  format: "expositivo" | "reflexivo" | "dialogico" | "pratico";
  obra: string;                  // obra-base principal (ex: "O Livro dos Espíritos (LE)")
  icon: string;                  // emoji sugerido pela IA para o curso
  color: string;                 // cor de acento hex sugerida pela IA

  status:
    | "draft_curriculum"   // currículo gerado, aguardando revisão do usuário
    | "curriculum_approved" // usuário aprovou, ainda sem conteúdo
    | "generating_content"  // geração de aulas em progresso
    | "published"           // todas as aulas geradas
    | "error";

  lessonCount: number;           // sempre 7 para mini-curso completo
  lessonsGeneratedCount: number; // quantas aulas já têm conteúdo (0 a 7)

  visibility: "private" | "public"; // usuário pode tornar público depois
  isOfficial: false;              // sempre false — diferencia de cursos oficiais do app

  createdAt: string;             // ISO timestamp
  updatedAt: string;

  // Estatísticas básicas (mesmo padrão do ICourse oficial)
  stats: {
    totalDurationMinutes: number; // 22 * lessonCount estimado
    enrolledStudents: number;     // sempre 0 ou 1 (o próprio criador), exceto se público
    completionRate: number;
  };
}
```

---

## Subcoleção: `userGeneratedCourses/{courseId}/curriculum/{lessonNumber}`

Armazena o **currículo de cada aula** (gerado na primeira chamada de IA, editável pelo usuário antes da geração de conteúdo).

```typescript
interface ILessonCurriculum {
  lessonNumber: number;          // 1 a 7
  title: string;                 // título da aula
  desc: string;                  // subtema/descrição curta

  // Campos do prompt mestre — preenchidos pela IA, editáveis pelo usuário
  conflict: string;              // conflito central
  transform: string;             // transformação esperada
  tone: string;                  // tom emocional predominante

  edited: boolean;                // true se o usuário alterou algo manualmente
  contentGenerated: boolean;      // true quando o conteúdo (9 slides) já foi gerado
}
```

> **Por que separar currículo de conteúdo?**
> Permite que o usuário revise/edite título, subtema, conflito etc. ANTES de gastar tokens gerando os 9 slides completos de cada aula. Evita retrabalho e gera economia.

---

## Subcoleção: `userGeneratedCourses/{courseId}/lessons/{lessonNumber}`

Armazena o **conteúdo completo da aula** (gerado depois que o currículo é aprovado), seguindo exatamente o formato JSON do prompt mestre.

```typescript
interface IGeneratedLesson {
  id: string;                    // "LESSON-<courseId>-01" etc
  courseId: string;
  lessonNumber: number;          // 1 a 7
  title: string;
  source: string;                // obra-base
  durationMinutes: number;       // 22

  slides: ISlide[];               // 9 slides
  reflectionQuestions: IReflectionQuestion[]; // 3 perguntas

  generatedAt: string;
}

interface ISlide {
  slideType: string;
  title: string;
  content: string;               // 250-400 chars, com **negrito**
  emotion: string;
  learningGoal: string;
  commonMisunderstanding: string;
  highlights: IHighlight[];
  references: {
    kardeciana: string;
    biblica: string;
  };
  glossary: IGlossaryEntry[];
}

interface IHighlight {
  title: string;                 // ≤45 chars
  content: string;               // 140-220 chars
}

interface IGlossaryEntry {
  id: string;
  term: string;
  definition: string;            // 140-200 chars
  category: string;
  references: string[];
  synonyms: string[];
}

interface IReflectionQuestion {
  question: string;
  focus: "Autoconhecimento" | "Aplicação prática" | "Transformação moral";
}
```

---

## Regras de segurança Firestore (rascunho)

```
match /userGeneratedCourses/{courseId} {
  allow read: if resource.data.visibility == "public"
               || resource.data.userId == request.auth.uid;
  allow create: if request.auth != null
                 && request.resource.data.userId == request.auth.uid;
  allow update, delete: if resource.data.userId == request.auth.uid;

  match /curriculum/{lessonNumber} {
    allow read: if get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.visibility == "public"
                 || get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.userId == request.auth.uid;
    allow write: if get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.userId == request.auth.uid;
  }

  match /lessons/{lessonNumber} {
    allow read: if get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.visibility == "public"
                 || get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.userId == request.auth.uid;
    allow write: if get(/databases/$(database)/documents/userGeneratedCourses/$(courseId)).data.userId == request.auth.uid;
  }
}
```

---

## Considerações de custo/limite (importante)

- Geração de **currículo**: 1 chamada de IA (~1500-2000 tokens de saída) — barata
- Geração de **conteúdo por aula**: 2 chamadas de IA (~6000-8000 tokens cada) — a parte cara
- Mini-curso completo (7 aulas) = 1 (currículo) + 14 (conteúdo) = **15 chamadas de IA**

**Recomendações:**
1. Gerar conteúdo **sob demanda** — só gerar a aula quando o usuário for abri-la (lazy generation), não tudo de uma vez
2. Definir um **limite de cursos personalizados por usuário** (ex: 3 por mês para usuários free)
3. Mostrar `lessonsGeneratedCount` na UI como progresso ("3 de 7 aulas geradas")
4. Considerar usar `max_tokens` menores ou modelo mais barato (Haiku) para o currículo, já que é mais simples
