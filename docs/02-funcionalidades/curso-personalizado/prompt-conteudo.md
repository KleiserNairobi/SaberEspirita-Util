# Geração de Conteúdo — Mini-curso Personalizado
**Etapa 2 do fluxo:** currículo aprovado → gerar os 9 slides de cada aula (lazy, sob demanda)

Esta etapa reaproveita exatamente a lógica de **split em 2 chamadas** (slides 1-5 / slides 6-9 + reflexão) já validada no gerador da série Origem & Criação — apenas trocando os dados fixos dos cursos pelos dados do `ILessonCurriculum` salvo no Firestore.

---

## Schema reaproveitado

```typescript
const SLIDE_SCHEMA = `{
  "slideType": "string",
  "title": "string — titulo com tensao filosofica ou metafora",
  "content": "string — 250 a 400 chars com **negritos** em termos doutrinarios",
  "emotion": "string",
  "learningGoal": "string",
  "commonMisunderstanding": "string",
  "highlights": [
    { "title": "string max 45 chars", "content": "string 140 a 220 chars: definicao + contexto + aplicacao" }
  ],
  "references": { "kardeciana": "string", "biblica": "string" },
  "glossary": [
    {
      "id": "slug",
      "term": "string",
      "definition": "string 140 a 200 chars",
      "category": "Doutrina Basica",
      "references": ["string"],
      "synonyms": ["string"]
    }
  ]
}`;
```

---

## Contexto dinâmico (substitui o `buildContext` fixo)

Antes, o contexto vinha de objetos `course`/`lesson` hardcoded. Agora vem do Firestore:

```typescript
interface CourseContext {
  title: string;   // curriculumDoc course title
  obra: string;
}

interface LessonContext {
  n: number;
  title: string;
  desc: string;
  conflict: string;
  transform: string;
  tone: string;
}

function buildContext(course: CourseContext, lesson: LessonContext, fmt: FormatConfig): string {
  return [
    "Mini-curso: " + course.title,
    "Aula " + lesson.n + "/7: " + lesson.title,
    "Subtema: " + lesson.desc,
    "Obra-base: " + course.obra,
    "Conflito central: " + lesson.conflict,
    "Transformacao esperada: " + lesson.transform,
    "Tom: " + lesson.tone + ", " + fmt.tone_add,
    "Intensidade: " + fmt.intensity,
    "Fluxo: angustia > questionamento > curiosidade > expansao > consolacao racional",
    "Regras: linguagem humana e natural; minimo 3 microcenas cotidianas; nunca culpar o leitor; sem pregacao; base FEB Guillon Ribeiro 3a ed.",
  ].join("\n");
}
```

---

## Prompt A — Slides 1 a 5 (idêntico ao gerador anterior)

```typescript
function buildPromptA(course: CourseContext, lesson: LessonContext, format: string): string {
  const fmt = FORMAT_MAP[format];
  const ctx = buildContext(course, lesson, fmt);
  return `Voce e especialista em doutrina espirita e educacao mobile.

CONTEXTO:
${ctx}

TAREFA: Gere exatamente os slides 1 a 5 desta aula.
Retorne APENAS um array JSON valido com 5 objetos. Sem texto antes ou depois. Sem markdown.

SLIDES:
1 - O Misterio Inicial: paradoxo ou pergunta provocativa
2 - Contexto Biblico Vivo: cena dramatizada com microcena humana
3 - Primeira Luz Espirita: primeira explicacao doutrinaria
4 - Segunda Luz Espirita: contraste entre interpretacao comum e visao espirita
5 - Ponto Crucial: reviravolta doutrinaria central

SCHEMA DE CADA SLIDE:
${SLIDE_SCHEMA}

Retorne: [ {slide1}, {slide2}, {slide3}, {slide4}, {slide5} ]`;
}
```

---

## Prompt B — Slides 6 a 9 + Reflexão (idêntico ao gerador anterior)

```typescript
function buildPromptB(course: CourseContext, lesson: LessonContext, format: string): string {
  const fmt = FORMAT_MAP[format];
  const ctx = buildContext(course, lesson, fmt);
  return `Voce e especialista em doutrina espirita e educacao mobile.

CONTEXTO:
${ctx}

TAREFA: Gere exatamente os slides 6 a 9 desta aula mais as 3 perguntas reflexivas.
Retorne APENAS JSON valido no formato abaixo. Sem texto antes ou depois. Sem markdown.

SLIDES:
6 - Raiz Doutrinaria: conexao com outras Obras Basicas
7 - Quebra de Paradigma: consequencia transformadora com microcena cotidiana
8 - Vida Pratica Hoje: aplicacao imediata
9 - Sintese Final: sintese emocional e consolacao racional

SCHEMA DE CADA SLIDE:
${SLIDE_SCHEMA}

Retorne:
{
  "slides": [ {slide6}, {slide7}, {slide8}, {slide9} ],
  "reflectionQuestions": [
    { "question": "pergunta pessoal de autoconhecimento em 2a pessoa", "focus": "Autoconhecimento" },
    { "question": "pergunta de aplicacao pratica", "focus": "Aplicacao pratica" },
    { "question": "pergunta de transformacao moral", "focus": "Transformacao moral" }
  ]
}`;
}
```

---

## Função orquestradora (lazy generation de uma aula)

```typescript
async function generateLessonContent(
  courseId: string,
  lessonNumber: number
): Promise<IGeneratedLesson> {
  // 1. Buscar dados do curso e currículo da aula no Firestore
  const courseSnap = await getDoc(doc(db, "userGeneratedCourses", courseId));
  const courseData = courseSnap.data();

  const lessonSnap = await getDoc(
    doc(db, "userGeneratedCourses", courseId, "curriculum", String(lessonNumber))
  );
  const lessonData = lessonSnap.data() as LessonContext;

  const course: CourseContext = { title: courseData.title, obra: courseData.obra };
  const format = courseData.format;

  // 2. Chamada A — slides 1-5
  const rawA = await callAPI(buildPromptA(course, lessonData, format));
  const slidesA = extractJSON(rawA);
  if (!Array.isArray(slidesA) || slidesA.length === 0) {
    throw new Error("Slides 1-5 não gerados.");
  }

  // 3. Chamada B — slides 6-9 + reflexão
  const rawB = await callAPI(buildPromptB(course, lessonData, format));
  const partB = extractJSON(rawB);
  if (!partB.slides || partB.slides.length === 0) {
    throw new Error("Slides 6-9 não gerados.");
  }

  // 4. Montar objeto final
  const finalLesson: IGeneratedLesson = {
    id: `LESSON-${courseId}-${String(lessonNumber).padStart(2, "0")}`,
    courseId,
    lessonNumber,
    title: lessonData.title,
    source: course.obra,
    durationMinutes: 22,
    slides: [...slidesA, ...partB.slides],
    reflectionQuestions: partB.reflectionQuestions || [],
    generatedAt: new Date().toISOString(),
  };

  // 5. Salvar no Firestore
  await setDoc(
    doc(db, "userGeneratedCourses", courseId, "lessons", String(lessonNumber)),
    finalLesson
  );

  // 6. Atualizar currículo (marcar como gerado) e contador do curso
  await updateDoc(
    doc(db, "userGeneratedCourses", courseId, "curriculum", String(lessonNumber)),
    { contentGenerated: true }
  );

  const newCount = (courseData.lessonsGeneratedCount || 0) + 1;
  await updateDoc(doc(db, "userGeneratedCourses", courseId), {
    lessonsGeneratedCount: newCount,
    status: newCount === 7 ? "published" : "generating_content",
    updatedAt: new Date().toISOString(),
  });

  return finalLesson;
}
```

---

## Helpers reaproveitados (idênticos ao gerador anterior)

```typescript
const FORMAT_MAP = {
  expositivo: { label: "Expositivo",  tone_add: "claro e didático",               intensity: "Média" },
  reflexivo:  { label: "Reflexivo",   tone_add: "contemplativo e introspectivo",   intensity: "Média" },
  dialogico:  { label: "Dialógico",   tone_add: "dialogal e investigativo",         intensity: "Baixa" },
  pratico:    { label: "Prático",     tone_add: "aplicado e transformador",         intensity: "Alta"  },
};

async function callAPI(prompt: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514", // modelo maior para conteúdo denso
      max_tokens: 8000,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  const data = await res.json();
  if (data.error) throw new Error("API: " + data.error.message);
  const raw = data.content?.map((b: any) => b.text || "").join("") || "";
  if (!raw) throw new Error("Resposta vazia da API.");
  return raw;
}

function extractJSON(raw: string): any {
  const match = raw.match(/[\[\{][\s\S]*[\]\}]/);
  if (!match) throw new Error("JSON não encontrado na resposta.");
  return JSON.parse(match[0]);
}
```

---

## Fluxo de UI sugerido para a tela de "minhas aulas"

```
Aula 1  ✅ Pronta        → toca para abrir os 9 slides
Aula 2  ✅ Pronta        → toca para abrir
Aula 3  ⏳ Gerar         → toca → chama generateLessonContent(courseId, 3) → loading → abre
Aula 4  ⏳ Gerar
Aula 5  ⏳ Gerar
Aula 6  ⏳ Gerar
Aula 7  ⏳ Gerar
```

Isso evita gerar as 7 aulas de uma vez (14 chamadas) caso o usuário desista no meio, e distribui o custo de IA ao longo do consumo real.
