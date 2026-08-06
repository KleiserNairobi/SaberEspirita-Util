# Especificação — Acesso ao Fórum pelo Currículo (v1)

## Objetivo

Permitir que o usuário acesse o Fórum de uma aula diretamente pela tela de Currículo do curso, sem precisar avançar até o último slide da aula, mantendo coerência com a regra de que o Fórum existe em função da 1ª pergunta (de 3) exibida no último slide.

## Problema Atual

- O Fórum é acessado via FAB no último slide da aula.
- No Currículo, o usuário pode querer ir direto ao Fórum (ou ao exercício) de uma aula.
- Se o Fórum depender do “último slide”, o Currículo não tem uma fonte simples/leve para exibir/abrir o Fórum.

## Princípio de Solução (Fonte Única)

A 1ª pergunta do último slide (a “pergunta âncora” do Fórum) precisa existir como **metadata canônica da aula**, para ser acessível por qualquer tela (Currículo, Player, Fórum), sem precisar carregar todos os slides.

## Modelo de Dados (Lição)

Adicionar (ou garantir) no documento/objeto de cada aula:

- `forumEnabled: boolean`
  - Controla se a aula tem Fórum.
  - Importante para compatibilidade com cursos já existentes.
- `forumPrompt: string | null`
  - Texto da pergunta âncora do Fórum.
  - Deve ser igual à 1ª pergunta exibida no último slide.
- `forumFocusTag: string | null` (opcional)
  - Label/tema (ex.: “Fé”, “Caridade”, etc.) para exibição no Fórum.

Regras:

- Se `forumEnabled === true`, então `forumPrompt` deve estar preenchido.
- Se `forumEnabled === false`, o Currículo pode ocultar o item “Fórum” (ou exibir desativado, conforme decisão de UX).

## Publicação e Bloqueio

Premissa do produto:

- O “bloqueio” do Fórum deve ser condicionado à **existência/disponibilidade da aula**.
- Quando a aula é publicada, o exercício deve existir (se essa for a regra do curso).

Proposta de regra de disponibilidade para ações no Currículo:

- Aula **EM BREVE** (`status === COMING_SOON`):
  - Não permitir abrir Aula/Exercício/Fórum.
  - Mostrar feedback (“Em breve”).
- Aula **BLOQUEADA** (regra de progressão do curso):
  - Não permitir abrir Exercício/Fórum (e, se aplicável, também a Aula).
  - Mostrar feedback (“Conclua aulas anteriores para desbloquear”).
- Aula **DISPONÍVEL/EM ANDAMENTO/CONCLUÍDA**:
  - Aula: pode abrir normalmente.
  - Exercício: pode abrir (com regra adicional de “adiantado” caso a aula não esteja concluída, se vocês quiserem).
  - Fórum: pode abrir se `forumEnabled === true`.

## UX no Currículo (Ação Secundária)

Para cada aula, exibir uma linha secundária abaixo do card (semelhante ao “Exercício”):

- “Fórum: Reflexão” + ícone + chevron
- Condições:
  - Se `forumEnabled === false` → ocultar (recomendado).
  - Se `forumEnabled === true` e aula indisponível/bloqueada → exibir desativado (opacidade) e interceptar clique com mensagem.
  - Se `forumEnabled === true` e aula disponível → navegar para o Fórum.

## Navegação e Contrato da Tela de Fórum

Para evitar inconsistências, a tela `LessonForum` deve ser capaz de operar com `courseId` e `lessonId` como mínimo.

Recomendação:

- `LessonForum` recebe: `courseId`, `lessonId` (e opcionalmente `lessonTitle`).
- Ao montar, busca a aula e resolve:
  - `anchorQuestion = lesson.forumPrompt`
  - `focusTag = lesson.forumFocusTag`
  - Se `forumEnabled === false` → mostrar mensagem e voltar (ou desativar no Currículo para evitar chegar aqui).

Se vocês preferirem manter `anchorQuestion` por parâmetro (curto prazo), ainda assim o ideal é que a origem seja a metadata da aula, não o último slide.

## Consistência com o Último Slide

O último slide continua exibindo as 3 perguntas, porém:

- A 1ª pergunta deve ser **a mesma string** de `forumPrompt`.
- Evitar “duplicação manual” divergente:
  - Ideal: CMS/seed salva `forumPrompt` e também monta o último slide a partir dessas perguntas.
  - Alternativa: pipeline de publicação valida que `forumPrompt` == primeira pergunta do último slide.

## Migração para Cursos Existentes

Para cursos já publicados:

- Default seguro: `forumEnabled = false` (não mostra Fórum no Currículo).
- Para cursos/aulas onde o Fórum deve existir:
  - preencher `forumEnabled = true`
  - preencher `forumPrompt` (e opcional `forumFocusTag`)

## Validações (Recomendado)

No momento de “publicar” uma aula (ou quando `status` muda para disponível):

- Validar que:
  - Se `forumEnabled === true` → `forumPrompt` não é vazio.
  - Exercício existe (se for regra obrigatória).

Implementação possível:

- Validação no admin/CMS (frontend).
- Validação em Cloud Function (ex.: ao atualizar `lessons/{lessonId}`), bloqueando/alertando publicação inválida.

## Checklist de Implementação (Sugestão)

1. Adicionar `forumEnabled/forumPrompt/forumFocusTag` ao tipo de aula e ao storage (Firestore/CMS).
2. Ajustar tela de Currículo:
   - Renderizar linha “Fórum” por aula (condicionada a `forumEnabled`).
   - Bloquear clique se aula “EM BREVE” ou “BLOQUEADA”.
3. Ajustar tela `LessonForum` para ler `forumPrompt` da aula (fonte de verdade).
4. Ajustar pipeline de publicação:
   - Validar “aula publicada ⇒ exercício existe”.
   - Validar “forumEnabled ⇒ forumPrompt existe”.
