# Geração de Currículo — Mini-curso Personalizado
**Etapa 1 do fluxo:** usuário fornece tema → IA gera estrutura das 7 aulas

---

## Temas sugeridos (exibir como chips/cards no app)

Lista inicial sugerida — pode expandir conforme o app cresce:

```typescript
export const SUGGESTED_THEMES = [
  { icon: "🙏", label: "Oração e Espiritualidade", theme: "O poder e o sentido da oração na vida espiritual" },
  { icon: "⚖️", label: "Lei de Causa e Efeito", theme: "Como a lei de causa e efeito explica os acontecimentos da vida" },
  { icon: "💔", label: "Luto e Saudade", theme: "Como o Espiritismo explica a morte e ajuda a lidar com o luto" },
  { icon: "🔮", label: "Mediunidade", theme: "O que é a mediunidade e como ela se manifesta na vida cotidiana" },
  { icon: "✨", label: "Caridade", theme: "A caridade como prática transformadora segundo o Evangelho" },
  { icon: "🌙", label: "Sonhos e Desdobramento", theme: "O que acontece com o espírito durante o sono, segundo o Espiritismo" },
  { icon: "👶", label: "Crianças e Reencarnação", theme: "Reencarnação infantil, escolha de família e missão espiritual" },
  { icon: "😔", label: "Obsessão Espiritual", theme: "O que é obsessão espiritual e como ela é tratada pela doutrina" },
  { icon: "🕊️", label: "Perdão", theme: "O perdão como lei moral e caminho de libertação espiritual" },
  { icon: "🌍", label: "Pluralidade dos Mundos", theme: "A vida em outros mundos segundo a doutrina espírita" },
];
```

---

## Prompt de geração do currículo

```typescript
function buildCurriculumPrompt(theme: string, format: string): string {
  const fmt = FORMAT_MAP[format]; // { label, tone_add, intensity }

  return `Você é especialista em doutrina espírita (base FEB — Guillon Ribeiro — 3ª edição) e em design instrucional para apps mobile.

TAREFA: Criar o CURRÍCULO de um mini-curso de 7 aulas sobre o tema abaixo.

TEMA SOLICITADO PELO USUÁRIO:
"${theme}"

FORMATO PREFERIDO: ${fmt.label} (${fmt.tone_add})

INSTRUÇÕES:
- Decomponha o tema em 7 aulas progressivas, cada uma abordando um aspecto/ângulo diferente
- Siga o fluxo narrativo: angústia → questionamento → curiosidade → expansão → consolação racional ao longo do mini-curso como um todo
- Cada aula deve ter um conflito central (pergunta/tensão) e uma transformação esperada (o que o aluno passa a compreender)
- Identifique a obra-base espírita mais adequada ao tema (LE, LM, ESE, AG, CI, RE)
- Sugira um ícone (emoji) e uma cor de acento (hex) que representem visualmente o tema
- Títulos de aula devem evitar "Introdução"/"Conclusão" — preferir tensão filosófica, metáforas, curiosidade existencial
- Evite expressões como "isso muda tudo", "Kardec revela", "jornada transformadora"

Retorne APENAS o JSON abaixo, sem texto antes ou depois, sem markdown:

{
  "title": "Título do mini-curso (até 50 chars)",
  "subtitle": "Subtítulo curto (até 80 chars)",
  "obra": "Obra-base principal, ex: O Livro dos Espíritos (LE)",
  "icon": "emoji único",
  "color": "#HEXCOLOR",
  "lessons": [
    {
      "lessonNumber": 1,
      "title": "Título da aula 1",
      "desc": "Subtema central em 1-2 frases",
      "conflict": "Conflito central — pergunta ou tensão filosófica/emocional",
      "transform": "Transformação esperada no aluno após esta aula",
      "tone": "tom emocional predominante desta aula (ex: contemplativo, filosófico e sereno)"
    }
    // ... repetir para lessonNumber 2 a 7
  ]
}`;
}
```

---

## Modelo recomendado para esta etapa

Use um modelo mais leve (ex: `claude-haiku-4-5`) com `max_tokens: 2500`. A saída é compacta (7 objetos pequenos) e não precisa do poder de um modelo maior — economiza custo na etapa que o usuário pode repetir várias vezes até ficar satisfeito (ex: "gerar outro currículo para este tema").

```typescript
const response = await fetch("https://api.anthropic.com/v1/messages", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 2500,
    messages: [{ role: "user", content: buildCurriculumPrompt(theme, format) }],
  }),
});
```

---

## Após gerar: salvar no Firestore

```typescript
async function saveCurriculum(userId: string, theme: string, themeSource: "suggested" | "custom", format: string, curriculumData: any) {
  const courseId = `ugc_${userId}_${Date.now()}`;

  // Documento principal
  await setDoc(doc(db, "userGeneratedCourses", courseId), {
    id: courseId,
    userId,
    title: curriculumData.title,
    subtitle: curriculumData.subtitle,
    theme,
    themeSource,
    format,
    obra: curriculumData.obra,
    icon: curriculumData.icon,
    color: curriculumData.color,
    status: "draft_curriculum",
    lessonCount: 7,
    lessonsGeneratedCount: 0,
    visibility: "private",
    isOfficial: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    stats: {
      totalDurationMinutes: 22 * 7,
      enrolledStudents: 0,
      completionRate: 0,
    },
  });

  // Subcoleção de currículo (1 doc por aula)
  for (const lesson of curriculumData.lessons) {
    await setDoc(
      doc(db, "userGeneratedCourses", courseId, "curriculum", String(lesson.lessonNumber)),
      {
        ...lesson,
        edited: false,
        contentGenerated: false,
      }
    );
  }

  return courseId;
}
```

---

## Tela de revisão (próxima etapa, fora deste escopo)

Após salvar, o app deve:
1. Buscar `userGeneratedCourses/{courseId}/curriculum/*` ordenado por `lessonNumber`
2. Exibir cards editáveis: título, subtema (`desc`), e opcionalmente conflito/transformação/tom em modo avançado
3. Botão **"Gerar outro currículo"** → repete a chamada com o mesmo tema (criativo é não-determinístico, pode gerar variações)
4. Botão **"Aprovar e continuar"** → muda `status` para `curriculum_approved` e segue para geração de conteúdo (ver arquivo `02-prompt-geracao-conteudo.md`)
