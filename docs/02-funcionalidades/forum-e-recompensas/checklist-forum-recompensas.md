# Saber Espírita — Plano Técnico (Expo + Web + Firebase) + Checklist

Baseado em: [EspecificacaoForumRecompensas_v2.md](file:///Users/nairobi/Documents/Desenv/2026/docs/novos/EspecificacaoForumRecompensas_v2.md)

## Padrão a reutilizar (já existe no projeto)

- Eventos imutáveis em `*_logs` + agregação via Cloud Functions.
- Campos esperados por log: `processed`, `yearMonth`, `createdAt`.
- Limpeza de logs via job agendado (apagar somente `processed === true`).

Referências no código:

- Trigger de agregação (exemplo): [onLessonLog.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions/src/triggers/onLessonLog.ts#L14-L105)
- Retenção/limpeza (exemplo): [logRetentionCleanup.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions/src/maintenance/logRetentionCleanup.ts#L7-L118)

## Estratégia de entrega (fases)

- Fase 1: Fórum por aula (sem reações)
- Fase 2: Reações
- Fase 3: Recompensas simbólicas

---

## 1) Modelagem (Firestore)

### Comentários (domínio)

Recomendação prática de path:

- `lesson_forums/{lessonId}/comments/{commentId}`

Campos (alinhados à spec):

- `courseId`, `lessonId`, `userId`, `userName`, `userAvatar`, `isAnonymous`, `userCommunityLevel`
- `content` (<= 600)
- `createdAt` (serverTimestamp), `updatedAt` (opcional)
- `isDeleted`, `deletedAt`
- `reactions.{me_tocou, aprendi_algo, quero_refletir, gratidao, luz}`

### Reações (garantir 1 por usuário por comentário)

Recomendação:

- `lesson_forums/{lessonId}/comments/{commentId}/reactions/{userId}`

Campos:

- `type`, `createdAt`

### Progresso comunitário (snapshot por usuário)

- `community_progress/{userId}` com `communityLevelId`, `stats.*` e `levelHistory[]`

### Dia ativo idempotente (UTC)

Recomendação:

- `active_days/{userId}_{dayKeyUTC}`

---

## 2) Logs (fonte de verdade para KPIs + recomputes)

- `forum_comment_logs/{logId}`
  - `userId`, `courseId`, `lessonId`, `commentId`, `createdAt`, `yearMonth`, `processed:false`
- `forum_reaction_logs/{logId}`
  - `userId`, `lessonId`, `commentId`, `type`, `createdAt`, `yearMonth`, `processed:false`
- `active_day_logs/{logId}` (opcional se usar somente `active_days`)
  - `userId`, `dayKeyUTC`, `createdAt`, `yearMonth`, `processed:false`

---

## 3) Cloud Functions (agregação + nível)

Triggers no create dos logs, no mesmo estilo do que já existe:

- `onForumCommentLogCreated`
  - Incrementa stats do autor (`forumComments`)
  - Atualiza `community_progress/{userId}`
  - Recalcula `communityLevelId` se necessário
- `onForumReactionLogCreated`
  - Resolve autor do comentário
  - Incrementa `reactionsReceived.*` do autor do comentário
  - Atualiza `community_progress` e recalcula nível
- `onActiveDayCreated` (se usar `active_days`)
  - Incrementa `activeDays` apenas no primeiro doc do dia

Retenção:

- Incluir `forum_*_logs` (e `active_day_logs` se existir) na política de limpeza existente, apagando apenas quando `processed === true`.

---

## 4) Regras/ACL (diretriz)

- Guest: bloquear leitura e escrita do fórum (conforme spec).
- Auth + “matriculado”: considerar matriculado quando existir `users/{uid}/courseProgress/{courseId}`.
- Cliente:
  - Pode criar comentários/reactions e criar logs.
  - Não pode escrever em agregados (`global_stats`, `item_stats`, `community_progress`) — somente backend/admin.

---

## 5) App (SaberEspirita-Expo)

Entrada:

- Hoje já existe FAB de IA: [DoubtFAB.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/lesson-player/components/DoubtFAB.tsx)
- Evoluir para FAB com 2 ações (IA + Fórum) conforme a spec.

Tela Fórum (MVP):

- Topo fixo com `reflectionQuestions[0]` e `focus`
- Lista paginada (20) + “Ver mais”
- Composer: contador, validação vazio/600, toggle anonimato
- Delete do autor: soft delete e placeholder “Comentário removido pelo autor”
- Ordenação: mais recentes primeiro

Badge “novos desde última visita”:

- Guardar `lastSeenAt` por `lessonId` em doc do usuário e comparar com `createdAt` para indicar novos.

---

## 6) Web (SaberEspirita-Web)

Painel de moderação:

- Página/rota para listar comentários por `courseId`/`lessonId`, filtrar por `isDeleted`, ordenar por `createdAt`
- Ação “Remover (admin)”

Backend para remoção admin:

- Callable/HTTP Function protegida por custom claim de admin
- Remover comentário e, idealmente, reações associadas

---

## Checklist (MVP por fases)

### Fase 1 — Fórum por Aula

- [ ] Bloquear guest (sem leitura/sem escrita) e mostrar CTA de cadastro ao tocar em “Fórum”
- [ ] Ler `reflectionQuestions[0]` do JSON e exibir como pergunta âncora no topo
- [ ] Implementar coleção `lesson_forums/{lessonId}/comments` com `createdAt` (serverTimestamp)
- [ ] Listar comentários por `lessonId` com paginação (20) e ordenação desc
- [ ] Publicar comentário com validação: não vazio, <= 600, contador visível
- [ ] Toggle “anônimo”: grava `isAnonymous`, exibe “Estudante Anônimo” e oculta avatar
- [ ] Delete do autor: soft delete e placeholder “Comentário removido pelo autor”
- [ ] Criar `forum_comment_logs` e trigger `onForumCommentLogCreated` (processed/yearMonth)
- [ ] Registrar/atualizar “última visita” do usuário por aula para habilitar badge de novos

### Fase 2 — Reações

- [ ] Implementar subcoleção `reactions/{userId}` por comentário (garante 1 por usuário)
- [ ] Bloquear auto-reação (regra + UI)
- [ ] Trocar reação e remover reação (toque na ativa remove)
- [ ] Exibir contagens por tipo no comentário
- [ ] Criar `forum_reaction_logs` e trigger `onForumReactionLogCreated` para atualizar:
- [ ] Contadores agregados no comentário (`reactions.{type}`)
- [ ] `community_progress` do autor do comentário (`reactionsReceived.*` e `total`)
- [ ] Resolver `myReaction` na UI (via leitura do doc `reactions/{userId}`) para cada comentário da página

### Fase 3 — Recompensas simbólicas

- [ ] Criar/atualizar `community_progress/{userId}` (somente backend)
- [ ] Implementar cálculo de nível com os thresholds da spec (nível 2 e 3)
- [ ] Persistir `levelHistory` quando subir nível
- [ ] App: exibir nível no perfil e nos comentários (tag discreta)
- [ ] App: modal de avanço de nível com as frases da spec
- [ ] App: “Sua jornada” (progresso rumo ao próximo nível) na tela do curso
- [ ] Contabilizar “dia ativo” com doc idempotente UTC + incremento no agregado

### Web — Moderação

- [ ] Criar página/rota no painel para listar comentários por aula/curso
- [ ] Implementar ação “remover comentário” com Function protegida por admin claim
- [ ] Garantir que comentário removido por admin não apareça no app (sem placeholder)
- [ ] Hard delete: ao remover comentário, deletar também as reações associadas (subcoleção) para não deixar lixo órfão
- [ ] (Opcional) Registrar log de ação admin (audit) com `commentId`, `lessonId`, `courseId`, `adminId`, `createdAt`

---

## Perguntas em aberto (para fechar ACL e paths sem suposições)

- Matrícula: confirmado que é a existência de `users/{uid}/courseProgress/{courseId}`.
- Moderação: confirmado hard delete do comentário removido por admin (por custo).
