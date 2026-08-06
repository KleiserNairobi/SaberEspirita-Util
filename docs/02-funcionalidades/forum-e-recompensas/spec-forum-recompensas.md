# Saber Espírita — Especificação de Produto

## Funcionalidades: Fórum por Aula, Reações e Sistema de Recompensas Simbólicas

---

## CONTEXTO DO PRODUTO

**App:** Saber Espírita — plataforma mobile de estudo doutrinário espírita  
**Lançamento:** Fevereiro de 2026  
**Operação:** Solo (desenvolvedor e gestor são a mesma pessoa)  
**Público:** Estudantes da Doutrina Espírita de todos os níveis — perfil leitor, reflexivo, com cultura de debate doutrinário (grupos de estudo, reuniões, debates pós-palestra)  
**Stack de aulas:** JSON estruturado com `slides`, `highlights`, `glossary`, `reflectionQuestions`  
**Plataforma de desenvolvimento:** TRAE

### Cursos ativos no app

| Nome                                           | Aulas | Duração     | Obra base |
| ---------------------------------------------- | ----- | ----------- | --------- |
| Iniciação à Doutrina                           | 8     | 3h 36min    | Múltiplas |
| O Evangelho Segundo o Espiritismo              | 94    | 42h 18min   | ESE       |
| Luz no Lar: Culto do Evangelho                 | 6     | 2h 42min    | Prático   |
| Mediunidade: Conceitos Fundamentais            | 14    | 6h 18min    | LM        |
| As Leis Morais                                 | 12    | 5h 24min    | LE        |
| O Que Há Depois da Morte?                      | 10    | 4h 30min    | CI        |
| Transição Planetária — O Que Kardec Nos Ensina | 9     | em produção | Múltiplas |

### Problema que estas funcionalidades resolvem

O app tem avaliações altas (4.5–5.0) mas baixa taxa de conclusão. Um dos fatores identificados é o isolamento do estudo individual. O público espírita tem cultura de debate e comunidade — o app precisa digitalizar esse comportamento. Adicionalmente, dúvidas pontuais (ex: "o culto deve ser feito em voz alta?") que hoje chegam via mensagem direta ao desenvolvedor precisam virar patrimônio coletivo visível a todos os alunos.

---

## PARTE 1 — FÓRUM POR AULA

### 1.1 Visão Geral

Cada aula terá um espaço de discussão vinculado exclusivamente àquele conteúdo. O fórum é ancorado na **pergunta reflexiva** (`reflectionQuestions`) já existente no JSON da aula, eliminando a necessidade de criação manual de perguntas pelo admin.

### 1.2 Regras de Acesso

- **Quem pode ver:** Todos os alunos autenticados e matriculados no curso, independentemente do progresso
- **Quem pode comentar:** Todos os alunos autenticados e matriculados no curso
- **Modo Visitante (guest):** Não tem acesso ao fórum (nem leitura, nem escrita). Ao tocar em "Fórum", exibir o mesmo convite de cadastro já usado no final da aula: "Crie uma conta para participar do fórum e salvar seu progresso."
- **Justificativa:** Atende a exigência de experiência sem fornecimento de dados e evita abertura de regras públicas de leitura no Firestore. Mantém a implementação simples e segura. Caso a conversão exija, uma fase futura pode liberar visualização read-only para guest com arquitetura específica (sem regras abertas).
- **Moderação:** Publicação direta, sem aprovação prévia. Admin pode remover comentários a qualquer momento via painel.

### 1.3 Âncora do Fórum — reflectionQuestions

O fórum de cada aula é iniciado automaticamente pela pergunta reflexiva extraída do campo `reflectionQuestions` do JSON da aula.

**Estrutura das perguntas — igual em todas as aulas:**

Todas as aulas contêm exatamente 3 `reflectionQuestions`, exibidas no último slide como um **card com 3 seções temáticas**, sempre nesta ordem fixa:

| Posição | Foco                | Papel                                     |
| ------- | ------------------- | ----------------------------------------- |
| 1ª      | Autoconhecimento    | **Âncora do fórum** + exibida no card     |
| 2ª      | Aplicação prática   | Apenas exibida no card — reflexão passiva |
| 3ª      | Transformação moral | Apenas exibida no card — reflexão passiva |

> Esta estrutura é garantida pelo gerador de aulas: `SaberEspirita-Web/prompts/aulas/PromptAulaGlossario_v3.md`.

> **Como o aluno acessa o fórum:** No último slide da aula, há um FAB único com duas ações — **IA** (para tirar dúvidas sobre o conteúdo) e **Fórum** (para debater com outros alunos). Ao tocar em Fórum, o aluno é levado à tela de discussão daquela aula, onde a 1ª `reflectionQuestion` aparece fixada no topo como pergunta âncora.

**Estrutura do JSON — todas as aulas:**

```json
"reflectionQuestions": [
  {
    "question": "Pergunta de Autoconhecimento — âncora do fórum",
    "focus": "Autoconhecimento"
  },
  {
    "question": "Pergunta de Aplicação Prática",
    "focus": "Aplicação prática"
  },
  {
    "question": "Pergunta de Transformação Moral",
    "focus": "Transformação moral"
  }
]
```

**Exemplo real (curso Transição Planetária):**

```json
"reflectionQuestions": [
  {
    "question": "Diante das crises ao redor, você sente desespero ou percebe um convite à transformação?",
    "focus": "Autoconhecimento"
  },
  {
    "question": "O que você tem feito na sua vida cotidiana que contribui para o mundo que está nascendo?",
    "focus": "Aplicação prática"
  },
  {
    "question": "Que aspecto de você mesmo precisa mudar para estar alinhado com o novo tempo?",
    "focus": "Transformação moral"
  }
]
```

**Comportamento esperado:**

- Exibir apenas a 1ª `reflectionQuestion` (Autoconhecimento) como pergunta fixada no topo do fórum
- As perguntas 2ª e 3ª pertencem exclusivamente ao card do último slide — não aparecem no fórum
- O campo `focus` exibido como tag visual discreta abaixo da pergunta âncora (ex: `🔍 Autoconhecimento`)

### 1.4 Estrutura de Dados — Comentário

```json
{
  "id": "uuid",
  "lessonId": "LESSON-TRANS-PLAN-001-01",
  "courseId": "CURSO-TRANS-PLAN-001",
  "userId": "uuid-do-usuario",
  "userName": "Nome exibido no momento da publicação",
  "userAvatar": "url-ou-null",
  "isAnonymous": false,
  "userCommunityLevel": "sementeiro | cultivador | arvore_frondosa",
  "content": "Texto do comentário (máx 600 caracteres)",
  "createdAt": "ISO 8601",
  "updatedAt": "ISO 8601 | null",
  "reactions": {
    "me_tocou": 0,
    "aprendi_algo": 0,
    "quero_refletir": 0,
    "gratidao": 0,
    "luz": 0
  },
  "myReaction": "me_tocou | null",
  "isDeleted": false,
  "deletedAt": "ISO 8601 | null"
}
```

### 1.5 Interface — Tela do Fórum

**Ponto de entrada — FAB único com 2 ações (IA/Fórum) no último slide da aula:**

O acesso ao fórum parte do FAB já existente (hoje usado para IA) e evolui para um FAB único que, ao ser tocado, abre um menu com duas ações:

```
┌─────────────────┐
│  🤖 IA  💬 Fórum │  ← FAB expandido com duas opções
└─────────────────┘
```

- **IA** → comportamento atual: abre o assistente para tirar dúvidas sobre o conteúdo
- **Fórum** → novo: abre a tela de discussão daquela aula (somente para usuários autenticados). Em modo visitante (guest), o toque abre o convite de cadastro.

O FAB fica disponível no último slide da aula — onde o card de reflexão já está visível e o aluno está no momento certo para debater.

**Layout da tela do fórum:**

```
┌─────────────────────────────────────┐
│  💬 Fórum — [Título da Aula]        │
│  [tag do curso]  •  N comentários   │
├─────────────────────────────────────┤
│  📌 PERGUNTA PARA REFLEXÃO          │
│  "Diante das crises ao redor, você  │
│   sente desespero ou percebe um     │
│   convite à transformação?"         │
│  🔍 Autoconhecimento                │
├─────────────────────────────────────┤
│  [Campo: Compartilhe sua reflexão…] │
│                        [Publicar]   │
├─────────────────────────────────────┤
│  Mais recentes ▼                    │
│                                     │
│  [Avatar] Nome do Aluno  •  há 2h   │
│  🌱 Sementeiro                      │
│  "Texto do comentário aqui..."      │
│  🕊️ 3  💡 1  🤔 0  🙏 2  ✨ 0     │
│                          [Reagir ▾] │
│                                     │
│  [Avatar] Nome do Aluno  •  há 5h   │
│  🌳 Árvore Frondosa                 │
│  "Outro comentário aqui..."         │
│  🕊️ 7  💡 3  🤔 2  🙏 5  ✨ 1     │
│                          [Reagir ▾] │
└─────────────────────────────────────┘
```

### 1.6 Comportamentos Obrigatórios

- Comentário vazio não pode ser publicado
- Limite de 600 caracteres por comentário (contador visível)
- Edição não permitida após publicação (simplifica moderação)
- Exclusão pelo próprio usuário permitida (soft delete — exibe "Comentário removido pelo autor")
- Exclusão pelo admin disponível no painel web
- Ordenação padrão: mais recentes primeiro
- Paginação: carregar 20 comentários por vez, botão "Ver mais" ao final
- Indicador de comentários novos desde a última visita do usuário (badge numérico na aba do fórum)

### 1.7 Notificações (fase futura, documentar agora)

- Notificar o aluno quando alguém reagir ao seu comentário
- Notificar quando um novo comentário for publicado no fórum de uma aula que o aluno comentou
- Configurável nas preferências do usuário (ativar/desativar)

---

## PARTE 2 — REAÇÕES

### 2.1 As Cinco Reações

| Emoji | Identificador interno | Label exibido       |
| ----- | --------------------- | ------------------- |
| 🕊️    | `me_tocou`            | Me tocou            |
| 💡    | `aprendi_algo`        | Aprendi algo novo   |
| 🤔    | `quero_refletir`      | Quero refletir mais |
| 🙏    | `gratidao`            | Gratidão            |
| ✨    | `luz`                 | Luz                 |

> **Nota:** A reação `luz` (✨) foi adicionada como quinta opção por estar em sintonia com o vocabulário espírita e complementar o conjunto emocional das demais.

### 2.2 Regras de Negócio

- Cada usuário pode reagir a cada comentário com **apenas uma reação**
- Trocar de reação é permitido (remove a anterior, adiciona a nova)
- Remover reação é permitido (toque na reação ativa a remove)
- Reagir ao próprio comentário **não é permitido**
- Contagem de reações é pública e visível a todos

### 2.3 Estrutura de Dados — Reação

```json
{
  "id": "uuid",
  "commentId": "uuid-do-comentario",
  "userId": "uuid-do-usuario",
  "type": "me_tocou | aprendi_algo | quero_refletir | gratidao | luz",
  "createdAt": "ISO 8601"
}
```

### 2.4 Interface — Picker de Reações

Ao tocar em "Reagir", exibir um picker horizontal com os 5 emojis + label.  
Ao tocar em uma reação já ativa do usuário, a reação é removida.  
Contagens exibidas inline abaixo do comentário, agrupadas por tipo.

```
┌──────────────────────────────────────────────┐
│  🕊️ Me tocou  💡 Aprendi  🤔 Refletir  🙏 Gratidão  ✨ Luz │
└──────────────────────────────────────────────┘
```

---

## PARTE 3 — SISTEMA DE RECOMPENSAS SIMBÓLICAS

### 3.1 Filosofia do Sistema

O sistema **não é gamificação competitiva**. Não há pontos, não há rankings de quem mais comentou. É um sistema de **reconhecimento simbólico de jornada** — inspirado na linguagem da natureza e do crescimento espiritual, coerente com o tom do app.

O aluno não "ganha" um nível — ele "se torna" algo. A progressão deve parecer natural, não forçada.

### 3.2 Os Três Níveis

| Nível | Identificador     | Emoji | Nome            | Descrição exibida no perfil                                         |
| ----- | ----------------- | ----- | --------------- | ------------------------------------------------------------------- |
| 1     | `sementeiro`      | 🌱    | Sementeiro      | "Deu os primeiros passos na jornada do conhecimento"                |
| 2     | `cultivador`      | 🌿    | Cultivador      | "Cultiva o estudo com constância e partilha sua reflexão"           |
| 3     | `arvore_frondosa` | 🌳    | Árvore Frondosa | "Referência de presença, profundidade e fraternidade na comunidade" |

### 3.3 Lógica de Progressão

A progressão combina **estudo** e **participação comunitária**. Nenhum nível é atingido apenas por consumir conteúdo ou apenas por comentar — os dois precisam andar juntos.

**Definições operacionais (fonte de verdade):**

- **Aula concluída:** Aula marcada como concluída pelo app ao finalizar a aula (último slide).
- **Curso concluído:** Curso considerado concluído quando o aluno concluiu **todas as aulas** do curso. Exercícios não são obrigatórios para concluir o curso.
- **Certificado (quando o curso oferece):** Certificado é uma camada extra e só fica disponível quando `certification.enabled = true` e o aluno cumpre os requisitos exibidos no app: percentual mínimo de aulas concluídas + percentual mínimo de exercícios com nota ≥ `minimumGrade`.
- **Dia ativo (para recompensas simbólicas):** Um dia é contado como ativo quando o aluno realiza pelo menos 1 interação rastreável no dia (ex.: concluir uma aula, publicar comentário no fórum, reagir a um comentário). A fonte de verdade é um documento idempotente por `userId` + `dayKey` (UTC) para evitar duplicidade no mesmo dia e alinhar com o padrão de métricas do app.

#### Nível 1 — 🌱 Sementeiro

Atribuído automaticamente ao criar a conta. Todos começam aqui.

> Não há critério de conquista — é o ponto de partida.

#### Nível 2 — 🌿 Cultivador

Atingido quando o aluno cumprir **todos** os critérios abaixo:

| Critério                               | Valor |
| -------------------------------------- | ----- |
| Aulas concluídas                       | ≥ 10  |
| Comentários publicados no fórum        | ≥ 5   |
| Reações recebidas (total)              | ≥ 10  |
| Pelo menos 1 curso com progresso > 50% | ✅    |

#### Nível 3 — 🌳 Árvore Frondosa

Atingido quando o aluno cumprir **todos** os critérios abaixo:

| Critério                                        | Valor |
| ----------------------------------------------- | ----- |
| Aulas concluídas                                | ≥ 40  |
| Cursos concluídos                               | ≥ 2   |
| Comentários publicados no fórum                 | ≥ 20  |
| Reações recebidas (total)                       | ≥ 50  |
| Reações do tipo 🕊️ ou 🙏 recebidas              | ≥ 15  |
| Dias ativos no app (com pelo menos 1 interação) | ≥ 30  |

> **Nota sobre reações qualitativas:** O nível 3 exige especificamente reações de "Me tocou" e "Gratidão" porque sinalizam impacto emocional e espiritual — não apenas volume de participação. Um aluno que acumula essas reações genuinamente contribui para a experiência dos outros.

### 3.4 Estrutura de Dados — Progresso do Usuário

```json
{
  "userId": "uuid",
  "communityLevelId": "sementeiro | cultivador | arvore_frondosa",
  "stats": {
    "lessonsCompleted": 0,
    "coursesCompleted": 0,
    "forumComments": 0,
    "reactionsReceived": {
      "me_tocou": 0,
      "aprendi_algo": 0,
      "quero_refletir": 0,
      "gratidao": 0,
      "luz": 0,
      "total": 0
    },
    "activeDays": 0,
    "lastActiveAt": "ISO 8601"
  },
  "levelHistory": [
    {
      "communityLevelId": "sementeiro",
      "achievedAt": "ISO 8601"
    }
  ]
}
```

### 3.5 Momento da Notificação de Avanço de Nível

Ao atingir um novo nível, exibir uma tela/modal comemorativo com:

- Emoji grande do novo nível
- Nome do nível
- Frase inspiradora (ver abaixo)
- Botão "Continuar minha jornada"

**Frases por nível:**

🌿 Cultivador:

> _"Sua constância no estudo e na partilha começa a florescer. A semente que você plantou está se tornando raiz."_

🌳 Árvore Frondosa:

> _"Você se tornou presença viva nesta comunidade. Como a árvore que oferece sombra, sua jornada ilumina a de outros."_

### 3.6 Onde o Nível é Exibido

- **Perfil do usuário:** destaque, com emoji, nome e descrição
- **Comentários no fórum:** tag discreta abaixo do nome (ex: `🌳 Árvore Frondosa`)
- **Tela de progresso do curso:** seção "Sua jornada" com barra de progresso rumo ao próximo nível
- **Não exibir** em rankings públicos ou comparações entre usuários — o reconhecimento é individual, não competitivo

### 3.7 Transparência — "Como funciono?"

Na tela de perfil, link "Como funciona meu nível?" exibe os critérios de progressão de forma clara e motivacional, sem tom de desafio ou pressão.

---

## PARTE 4 — CONSIDERAÇÕES DE IMPLEMENTAÇÃO

### 4.1 Ordem de Implementação Recomendada

Dado que o desenvolvedor opera sozinho, a ordem abaixo minimiza retrabalho e entrega valor incremental:

1. **Fórum por aula** (sem reações ainda) — valida a funcionalidade core
2. **Reações nos comentários** — adiciona sobre a estrutura de comentários já criada
3. **Sistema de recompensas** — depende de dados de fórum acumulados para ser significativo

### 4.1.1 Padrão Visual (Mobile)

- Implementação mobile deve seguir o padrão temático já existente no app, usando `useAppTheme()` e tokens (`theme.colors`, `theme.spacing`, `theme.radius`, `theme.text`) em todos os componentes do fórum (telas, cards, botões, badges, estados vazios e loading).
- Evitar cores hardcoded e estilos inline para elementos fixos; respeitar safe-area e padrões já usados em `lesson-player` e componentes globais.

### 4.2 Dados Necessários do Backend

- **Padrão obrigatório (métricas):** Seguir o padrão já adotado no app para KPIs: eventos/logs imutáveis + agregação via Cloud Functions. Evitar contadores incrementados diretamente pelo cliente como fonte de verdade.
- Operação para listar comentários por `lessonId` (paginado)
- Operação para criar comentário (valida matrícula e bloqueia modo visitante) + registrar log do evento (`processed: false`, `createdAt`, `yearMonth`)
- Operação para deletar comentário (soft delete, verificação de ownership) + registrar log do evento quando aplicável
- Operação para adicionar/remover/trocar reação (1 por usuário, bloquear auto-reação) + registrar log do evento (`processed: false`, `createdAt`, `yearMonth`)
- Operação para registrar dia ativo via documento idempotente (`userId` + `dayKey` UTC) + log opcional de atividade
- Cloud Functions/Jobs para:
  - Agregar métricas globais (ex.: `global_stats`/`item_stats`) a partir dos logs
  - Recalcular `communityProgress` e `communityLevelId` após cada interação relevante
- Operação admin para deletar qualquer comentário (sem depender do cliente)

### 4.3 Campo no JSON da Aula Já Disponível

O campo `reflectionQuestions` já existe no JSON de todas as aulas geradas pelo prompt atual. Todas as aulas contêm exatamente 3 perguntas na ordem fixa: Autoconhecimento → Aplicação prática → Transformação moral. Não é necessário nenhuma alteração no processo de geração de conteúdo para o fórum funcionar.

**Uso no código:**

```javascript
// Buscar a pergunta âncora do fórum de uma aula (sempre a primeira)
const anchorQuestion = lesson.reflectionQuestions[0].question;
const focusTag = lesson.reflectionQuestions[0].focus; // sempre "Autoconhecimento"

// As perguntas [1] e [2] pertencem ao card do último slide — não usar no fórum
```

### 4.4 Privacidade e Moderação

- Nomes de usuários são exibidos publicamente nos comentários
- O app já permite que o usuário altere seu nome/apelido no perfil (hoje usado também em placares do quiz geral). O fórum deve reutilizar o mesmo `userName` como padrão.
- **Opção de anonimato no fórum:** permitir que o usuário publique como "Estudante Anônimo" (por comentário, com toggle no momento de publicar). Quando `isAnonymous: true`, exibir `userName = "Estudante Anônimo"` e ocultar `userAvatar`.
- **Moderação preservada:** mesmo em modo anônimo, `userId` permanece gravado e visível para o admin no painel.
- Comentários deletados pelo usuário mostram "Comentário removido pelo autor" — não somem completamente (preserva o contexto da thread)
- Comentários deletados pelo admin somem completamente, sem aviso

### 4.5 Retenção e Limpeza de Logs (KPI)

Para evitar crescimento desnecessário de dados e manter o padrão de métricas (logs imutáveis + agregação), estabelecer uma política de retenção desde o início:

- Logs de evento devem conter `createdAt`, `yearMonth` e `processed`.
- Limpeza automática só pode ocorrer para logs com `processed === true` e após uma janela de segurança.
- Manter permanentemente apenas os documentos agregados (ex.: `global_stats`/`item_stats`) e os documentos de domínio (comentários, reações, progresso).
- Retenção recomendada:
  - Logs de fórum/reação/atividade: manter por 90–180 dias (para auditoria e reprocessamento recente).
  - Documentos diários idempotentes de dia ativo: manter por 90–180 dias (a contagem histórica permanece no agregado `communityProgress.stats.activeDays`).
- Implementar job agendado (Cloud Function) para remoção em lote por faixa de data.

---

## NOTAS FINAIS

Este documento foi construído a partir de conversas sobre o produto, métricas reais de uso (fev–maio 2026) e o perfil específico do público espírita. As decisões de design — fórum público para todos os matriculados, reações simbólicas, níveis baseados em natureza — não são arbitrárias: decorrem da identidade do app e do comportamento esperado deste público.

Qualquer ajuste nos critérios de progressão de nível pode ser feito sem impacto na estrutura de dados, desde que os campos de `stats` já estejam sendo contabilizados corretamente desde o início.

---

_Documento gerado em maio de 2026 — Saber Espírita v1.x_
