# Checklist de Execução — Redução de Custo Firestore
> Criado em 22/07/2026. Atualizado em 22/07/2026.
> Legenda: ✅ Concluído | ⏳ Aguardando | 🔜 Próximo

---

## ✅ ETAPA 1 — Deploy do TTL (active_days)
> **CONCLUÍDA em 22/07/2026.**

- [x] Deploy executado: `firebase deploy --only firestore:indexes,functions`
- [x] `firestore.indexes.json` aplicado com TTL policy para `active_days`
- [x] Functions `onForumCommentCreated` e `onForumReactionWritten` atualizadas com `expiresAt`

> ⏳ **Aguardar até 48h** para a TTL policy do Firestore ativar (verificar em Firestore → Indexes → TTL).

---

## ⏳ ETAPA 2 — Backfill dos 301 documentos históricos
> Executar **somente após a TTL policy estar ativa**.

- [ ] Executar o script uma única vez:
  ```bash
  node functions/scripts/backfill_active_days_ttl.js
  ```
- [ ] Verificar a saída: deve mostrar ~301 documentos marcados
- [ ] Aguardar até 24h — o Firestore deletará automaticamente (deleção por TTL é gratuita)
- [ ] Confirmar no console que a coleção `active_days` está vazia ou próxima disso

> ✅ A partir daqui, `active_days` não vai mais causar custo excessivo ao abrir o console.

---

## ✅ ETAPA 3 — Corrigir os hooks do app (Fase 1)
> **Código concluído em 22/07/2026.** OTA pendente (publicar junto com demais queries).

**3a — `useCommunityProgress`** (`src/hooks/queries/useLessonForum.ts`)
- [x] `refetchOnMount: "always"` → `refetchOnMount: false`
- [x] `staleTime: 1000 * 60 * 30` (30 minutos) adicionado

**3b — `useForumHasNewComments`** (`src/hooks/queries/useLessonForum.ts`)
- [x] `staleTime` de 1min → 10min
- [x] `refetchOnMount: false` adicionado

**3c — `useLessonForumComments`** (`src/hooks/queries/useLessonForum.ts`)
- [x] `staleTime` de 2min → 10min
- [x] `refetchOnMount: false` adicionado

**3d — `useCourseProgress`** (`src/hooks/queries/useCourseProgress.ts`)
- [x] `refetchOnMount: false` adicionado
- [x] `gcTime: 1000 * 60 * 60 * 24 * 7` (7 dias) adicionado
- [x] `getDoc` substituído por Cache-First (`getDocFromCache` → fallback `getDocFromServer`)

- [ ] Trabalhar nas demais queries (ver análise-consultas.md)
- [ ] Publicar via OTA após todas as queries estarem prontas

---

## ⏳ ETAPA 4 — Monitorar por 3–5 dias
> Iniciar após publicar o OTA.

- [ ] **Dia 1 após OTA:** confirmar que leituras diárias caíram abaixo de 50 mil
- [ ] **Dia 2–3:** verificar tendência — deve estabilizar entre 5–15 mil leituras/dia com < 100 DAU
- [ ] Anotar o número médio diário como nova baseline

> Se os números ainda estiverem altos, investigar antes de continuar.

---

## ⏳ ETAPA 5 — Verificar backlog de logs não processados
> Antes de reativar os triggers, saber o tamanho do problema histórico.

- [ ] No console do Firestore ou via script, verificar o volume de docs não processados:
  ```
  Coleção lesson_logs → filtrar: processed != true → contar
  ```
- [ ] **Se backlog pequeno (< 500 docs):** aceitar o gap histórico e reativar normalmente
- [ ] **Se backlog grande (> 500 docs):** decidir:
  - Opção A: aceitar o gap — marcar todos como `processed: true` sem processar
  - Opção B: processar manualmente com script (recupera dados, mas gera writes)

---

## ⏳ ETAPA 6 — Reativar triggers em fases
> Projeto: `SaberEspirita-Web`. Descomentar em `functions/src/index.ts` e fazer deploy entre cada fase.

**Fase A — Triggers simples (sem impacto em community_progress)**
- [ ] Descomentar no `index.ts`:
  ```ts
  export * from './triggers/onCertificateLog';
  export * from './triggers/onMeditationLog';
  export * from './triggers/onPrayerLog';
  export * from './triggers/onPodcastLog';
  export * from './triggers/onAmbientPlayerLog';
  export * from './triggers/onEmotionalChatLog';
  export * from './triggers/onScientificChatLog';
  ```
- [ ] `firebase deploy --only functions`
- [ ] Monitorar por 1 dia — confirmar custo aceitável

**Fase B — Triggers de métricas gerais**
- [ ] Descomentar no `index.ts`:
  ```ts
  export * from './triggers/onChallengeLog';
  export * from './triggers/onQuizLog';
  export * from './triggers/onTruthOrFalseLog';
  export * from './triggers/onGlossaryLog';
  export * from './triggers/onVisitLog';
  ```
- [ ] `firebase deploy --only functions`
- [ ] Monitorar por 1 dia — confirmar custo aceitável

**Fase C — `onLessonLog` (toca active_days + community_progress)**
- [ ] Resolver backlog conforme decisão da Etapa 5
- [ ] Descomentar no `index.ts`:
  ```ts
  export * from './triggers/onLessonLog';
  ```
- [ ] `firebase deploy --only functions`
- [ ] Monitorar por 2 dias — verificar `activeDays` e `lessonsCompleted` sendo incrementados

---

## ✅ ETAPA 7 — Fix Cloud Function `getTopCoursesData` (Fase 0)
> **CONCLUÍDO em 22/07/2026.**

- [x] Em `getTopCoursesData.ts`: garantido que `global_stats/top_courses` seja válido ou retorne `[]` para não-admins
- [x] Adicionada verificação de custom claim e no banco para permissões de admin no fallback
- [x] O fallback atualizado agora salva o resultado recalculado de volta no Firestore consolidado
- [x] Deploy bem-sucedido das functions alteradas em 22/07/2026

---

## ✅ ETAPA 8 — Desnormalização de Reações do Fórum (N+1 reads)
> **CONCLUÍDO em 22/07/2026.**

- [x] Modificado trigger `onForumReactionWritten` no backend para salvar no campo `userReactions` do comentário.
- [x] Modificado helper `getForumCommentsPage` no frontend para ler do campo desnormalizado e remover a query síncrona.
- [x] Executado o script de migração das reações legadas em produção (56 comentários históricos atualizados em 22/07/2026)

---

## ✅ ETAPA 9 — Desnormalização de Cursos no Progresso (cold start da StudyScreen)
> **CONCLUÍDO em 22/07/2026.**

- [x] Modificado trigger `onCourseProgressWritten` no backend para desnormalizar `courseTitle`, `courseLessonCount`, `lastLessonTitle` e `lastLessonOrder`.
- [x] Modificado hook `useLastAccessedCourse` no frontend para ler do progresso desnormalizado com fallback seguro.
- [x] Adicionados novos campos opcionais à interface `IUserCourseProgress` no Expo.
- [x] Executado o script de backfill do progresso legado em produção (566 progressos históricos migrados e desnormalizados em 22/07/2026)

---

## 📊 Resumo visual da sequência

```
[22/07] ✅ Etapa 1: Deploy TTL (active_days)
             ↓ aguardar ≤ 48h (a partir de 22/07)
        ⏳ Etapa 2: Backfill active_days (criar CF temporária quando TTL estiver ativa)
             ↓
[22/07] ✅ Etapa 3: OTA Publicado no Expo (Build 2.0.19-ota.5 ativo)
             ↓ aguardar 3-5 dias
        ⏳ Etapa 4: Monitorar baseline de leituras (acompanhar redução na nuvem)
             ↓
[22/07] ✅ Etapa 5: Verificar backlog de logs (2.675 docs no total - decidido aceitar gap histórico)
             ↓
        ⏳ Etapa 6: Reativar triggers em fases (Agendado para Virada do Mês - 01/08)
             ↓
[22/07] ✅ Etapa 7: Fix CF getTopCoursesData (deploy realizado e ativo)
             ↓
[22/07] ✅ Etapa 8: Desnormalização de Reações (deploy, migração e OTA concluídos)
             ↓
[22/07] ✅ Etapa 9: Desnormalização de Cursos no Progresso (deploy, migração e OTA concluídos)
             ↓
        ⏳ Recalibração de Estatísticas (rodar syncAllStats na Virada do Mês - 01/08)
```
