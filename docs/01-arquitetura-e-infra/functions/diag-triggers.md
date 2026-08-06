# Análise de Triggers — Cloud Functions SaberEspirita-Web

> Gerado em 22/07/2026. Fonte: `functions/src/index.ts` + leitura completa de todos os arquivos de trigger.

---

## 1. Mapa Completo: Ativos vs Desativados

### ✅ Triggers ATIVOS (exportados em `index.ts`)

| Trigger | Arquivo | Toca `active_days`? | Observação |
|---|---|---|---|
| `onUserCreated` / `onUserDeleted` | `onUserCreated.ts` | ❌ | Criação/remoção de usuário |
| `beforeUserCreated` | `beforeUserCreated.ts` | ❌ | Validação pré-criação |
| `onCourseProgressWritten` | `onCourseProgressWritten.ts` | ❌ | Atualiza agregados de progresso |
| `onCourseProgressForCommunity` | `onCourseProgressForCommunity.ts` | ❌ | Sinc. progresso → comunidade |
| `updateCourseFeedbackAggregates` | `updateCourseFeedbackAggregates.ts` | ❌ | Agrega avaliações de cursos |
| **`onForumCommentCreated`** | `onForumCommentCreated.ts` | **✅ SIM** | Cria `active_days` + incrementa `activeDays` |
| **`onForumReactionWritten`** | `onForumReactionWritten.ts` | **✅ SIM** | Cria `active_days` + incrementa `activeDays` |
| `getCourseManagementData` | `getCourseManagementData.ts` | ❌ | Callable admin — filtra courseProgress por courseId |
| `getTopCoursesData` | `getTopCoursesData.ts` | ❌ | Callable admin — **⚠️ fallback sem filtro** |
| `sendBulkEmail` / `sendDirectEmail` | — | ❌ | E-mails |
| `adminDelete*`, `sendAdminNotification` | — | ❌ | Funções admin |
| `deleteMyAccount` | — | ❌ | Exclusão de conta |
| `cleanupInactiveUsers` *(scheduled)* | `maintenance/` | ❌ | Diária |
| **`logRetentionCleanup`** *(scheduled 03:30 UTC)* | `logRetentionCleanup.ts` | ❌ | **⚠️ Limpa logs com ≥ 180 dias — NÃO limpa `active_days`** |
| `notifyAbandonedCourses` *(scheduled)* | — | ❌ | Notificação |
| `resetPeriodicScores` *(scheduled)* | — | ❌ | Reset de pontuação |
| `syncCourseRatings` *(scheduled)* | — | ❌ | Avaliações |
| `syncAllStats` *(HTTP manual)* | — | ❌ | Uso pontual |
| `deepseekProxy` | — | ❌ | Proxy IA |

---

### ❌ Triggers DESATIVADOS (comentados em `index.ts`)

| Trigger | Arquivo | Toca `active_days`? | O que faz |
|---|---|---|---|
| `syncUserCountDaily` | `syncUserCount.ts` | ❌ | Contagem diária de usuários |
| **`onLessonLog`** | `onLessonLog.ts` | **✅ SIM** | Era o principal criador de `active_days` — desativado intencionalmente |
| `onChallengeLog` | `onChallengeLog.ts` | ❌ | `global_stats/daily_challenge` + `daily_stats` |
| `onQuizLog` | `onQuizLog.ts` | ❌ | `global_stats/quizzes` ou `lesson_quizzes` + `item_stats` + `daily_stats` |
| `onCertificateLog` | `onCertificateLog.ts` | ❌ | `global_stats/certificates` + `item_stats` |
| `onTruthOrFalseLog` | `onTruthOrFalseLog.ts` | ❌ | `global_stats/truth_or_false` + `daily_stats` |
| `onVisitLog` | `onVisitLog.ts` | ❌ | `daily_stats` (visitas) |
| `onPrayerLog` | `onPrayerLog.ts` | ❌ | `global_stats/prayer` + `item_stats` |
| `onGlossaryLog` | `onGlossaryLog.ts` | ❌ | `global_stats/glossary` + `item_stats` |
| `onMeditationLog` | `onMeditationLog.ts` | ❌ | `global_stats/reflections` ou `guided_meditations` + `item_stats` |
| `onPodcastLog` | `onPodcastLog.ts` | ❌ | `global_stats/podcasts` + `item_stats` + `daily_stats` |
| `onAmbientPlayerLog` | `onAmbientPlayerLog.ts` | ❌ | `global_stats/ambient_player` |
| `onEmotionalChatLog` | `onEmotionalChatLog.ts` | ❌ | `global_stats/emotional_chat` |
| `onScientificChatLog` | `onScientificChatLog.ts` | ❌ | `global_stats/scientific_chat` |
| **`syncTopCoursesStatsDaily`** | `syncTopCoursesStatsDaily.ts` | ❌ | **⚠️ Scheduled às 02h — faz `collectionGroup('courseProgress').get()` sem filtro** |

---

## 2. Quem toca `active_days` — mapa definitivo

```
active_days/{userId}_{dayKey}

CRIADORES:
  ✅ ATIVO   onForumCommentCreated  → cria quando usuário comenta pela primeira vez no dia
  ✅ ATIVO   onForumReactionWritten → cria quando usuário reage pela primeira vez no dia
  ❌ DESATIV  onLessonLog           → criava quando usuário completava aula pela primeira vez no dia

LEITORES (para verificação de idempotência, dentro de transação):
  ✅ ATIVO   onForumCommentCreated  → tx.get(activeDayRef) para checar se já existe
  ✅ ATIVO   onForumReactionWritten → tx.get(activeDayRef) para checar se já existe
  ❌ DESATIV  onLessonLog           → tx.get(activeDayRef) para checar se já existe

LEITORES DE PRODUÇÃO (app mobile): NENHUM
  → firestore.rules: allow read, write: if false
```

**Conclusão:** `active_days` só é consultada por Cloud Functions no servidor, nunca pelo app mobile.

---

## 3. Veredito sobre "lixo" em `active_days`

### O que é lixo?

Um documento `active_days/{userId}_{dayKey}` tem **valor apenas dentro do dia UTC representado por `dayKey`**. Seu único propósito é impedir que `community_progress.stats.activeDays` seja incrementado mais de uma vez no mesmo dia.

**Após a meia-noite UTC do dia representado pelo `dayKey`, o documento não tem mais nenhuma função.**

### Os 301 documentos históricos são lixo?

**Sim, com certeza absoluta.** Raciocínio:

1. **O `dayKey` é sempre uma data no passado** (os docs foram criados enquanto `onLessonLog` estava ativo, antes de ser desativado).
2. **Nenhum trigger consultará uma key de data passada** — a leitura de idempotência usa sempre `getUTCDayKey(now)` (data do dia atual). Jamais há consulta retroativa.
3. **O contador `activeDays` em `community_progress`** já foi incrementado na época. Os docs de active_days não são a fonte de verdade do contador — apenas o token de controle.
4. **Nenhuma query de negócio lê a coleção** — regras do Firestore bloqueiam acesso do cliente.
5. **`logRetentionCleanup` não limpa `active_days`** — a coleção está fora da lista `TARGET_COLLECTIONS`.

> **Portanto:** Todos os 301 documentos existentes são lixo operacional. Podem e devem ser deletados. O TTL é a forma correta de fazê-lo (automático, gratuito, sem impacto no negócio).

### Novos documentos criados pelos triggers de fórum (ativos)

Os docs criados por `onForumCommentCreated` e `onForumReactionWritten` **têm valor apenas no dia UTC corrente**. Com o `expiresAt` (+48h) que foi adicionado, o TTL vai deletá-los automaticamente — correto.

---

## 4. Se `onLessonLog` for reativado — está seguro?

**Sim.** A edição feita em `onLessonLog.ts` (22/07/2026) já adiciona `expiresAt: +48h` ao `tx.create(activeDayRef, ...)`. Se o trigger for reativado, os novos `active_days` já nascem com TTL configurado — nenhum acúmulo histórico.

**Impacto em `active_days` ao reativar `onLessonLog`:**
- Novos docs criados por aula completada → expiram em 48h automaticamente ✅
- Volume estimado: 1 doc/usuário/dia ativo → com 85 DAU, ~85 docs/dia, ~170 docs vivos em qualquer momento ✅

---

## 5. Avaliação dos triggers desativados — devem ser reativados?

### ⚠️ Requer decisão de negócio

Os triggers de log abaixo foram desativados em bloco (sem saber a causa do custo — era a `active_days`). Cada um gera **1 write de trigger por ação do usuário**. Nenhum deles toca `active_days`.

| Trigger | Custo se reativado | Risco de custo excessivo |
|---|---|---|
| `onChallengeLog` | 1 write/completion | Baixo — volume limitado |
| `onQuizLog` | 1 write/tentativa | Médio — depende do volume |
| `onCertificateLog` | 1 write/certificado | Baixo — evento raro |
| `onTruthOrFalseLog` | 1 write/resposta | Médio — pode ser frequente |
| `onVisitLog` | 1 write/sessão | Alto — evento muito frequente |
| `onPrayerLog` | 1 write/oração | Baixo |
| `onGlossaryLog` | 1 write/consulta | Médio |
| `onMeditationLog` | 1 write/meditação | Baixo |
| `onPodcastLog` | 1 write/reprodução | Médio |
| `onAmbientPlayerLog` | 1 write/reprodução | Médio |
| `onEmotionalChatLog` | 1 write/chat | Baixo |
| `onScientificChatLog` | 1 write/chat | Baixo |
| `onLessonLog` | 1 write/aula + active_days | **Médio** — com TTL implementado, OK |

### 🔴 `syncTopCoursesStatsDaily` — NÃO reativar sem fix

Faz `collectionGroup('courseProgress').get()` **sem filtro** diariamente às 02h. São ~200 leituras/execução, ou seja, **~200 leituras/dia** de forma programada. Deve ser reativado junto com o fix da `getTopCoursesData` (Etapa 7 do checklist) para garantir que o cache esteja sempre quente e o fallback nunca execute.

---

## 6. Resumo executivo

| Item | Status |
|---|---|
| Única coleção que toca `active_days` com trigger ATIVO | `onForumCommentCreated` + `onForumReactionWritten` |
| `onLessonLog` (principal criador) | **DESATIVADO** |
| Os 301 docs existentes são lixo? | **✅ Sim, com certeza absoluta** |
| TTL + `expiresAt` implementados corretamente? | **✅ Sim** — todos os 3 pontos de criação atualizados (22/07/2026) |
| Backfill script pronto? | **✅ Sim** — `functions/scripts/backfill_active_days_ttl.js` |
| Deploy realizado? | **✅ Sim** — 22/07/2026 |
| Próximo passo para `active_days` | Aguardar TTL ativar (≤ 48h), depois rodar backfill |
