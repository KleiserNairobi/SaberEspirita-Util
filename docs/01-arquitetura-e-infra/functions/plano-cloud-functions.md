# Plano de Cloud Functions — Monitoramento Saber Espírita
*Versão 2.0 — Revisada e corrigida*

---

## 1. Princípios de Implementação

- **Sem increment no app:** O app Expo apenas cria documentos de log. Todo `increment()` em `statsService.ts` deve ser removido.
- **Idempotência obrigatória:** Toda função deve verificar `processed === true` no documento antes de agir. Após processar, grava `processed: true` no log dentro da mesma transação.
- **Transações para contadores:** Toda escrita em `global_stats` usa `runTransaction` para evitar race conditions.
- **Discriminador obrigatório:** Funções que consolidam múltiplos tipos (chat, meditation) dependem de um campo discriminador presente no log. Logs sem esse campo são ignorados e marcados com `processed: false` e `error: "missing_discriminator"`.

---

## 2. Padrão de Implementação (Template Base)

Toda Cloud Function de monitoramento deve seguir este padrão:

```typescript
export const onXxxLogCreated = onDocumentCreated("xxx_logs/{logId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();

  // 1. Idempotência: já processado?
  if (data.processed === true) return;

  // 2. Validação dos campos obrigatórios
  if (!data.userId || !data.yearMonth) {
    await snap.ref.update({ processed: false, error: "missing_required_fields" });
    return;
  }

  const statsRef = db.doc("global_stats/xxx");

  // 3. Transação: incrementa global_stats e marca log como processado
  await db.runTransaction(async (tx) => {
    tx.set(statsRef, {
      totalCount: FieldValue.increment(1),
      [`monthly.${data.yearMonth}`]: FieldValue.increment(1),
    }, { merge: true });

    tx.update(snap.ref, { processed: true });
  });
});
```

---

## 3. Mapa Completo de Funções

### `onUserCreated`
- **Trigger:** `auth.user().onCreate`
- **Coleção monitorada:** Firebase Auth
- **Objetivo:** Incrementa `global_stats/users → totalCredentials` quando uma nova conta é criada.
- **Idempotência:** Auth triggers não reenviam eventos; não é necessário campo `processed`.
- **Observação:** Nenhum documento de log é criado para este evento — o Auth é a fonte direta.

---

### `onUserDeleted`
- **Trigger:** `auth.user().onDelete`
- **Coleção monitorada:** Firebase Auth
- **Objetivo:** Decrementa `global_stats/users → totalCredentials` quando uma conta é excluída.
- **Observação:** Complementa `onUserCreated` para manter o contador real de credenciais.

---

### `onMeditationLogCreated`
- **Trigger:** `onDocumentCreated("meditation_logs/{logId}")`
- **Coleção monitorada:** `meditation_logs`
- **Objetivo:** Processa Reflexões Lidas e Meditações Guiadas com base no campo discriminador.
- **Campo discriminador:** `contentType` — valores válidos: `"reflection"` | `"guided_meditation"`.
- **Lógica:**
  - Se `contentType === "reflection"`: incrementa `global_stats/reflections` e `item_stats/reflections/items/{itemId}`.
  - Se `contentType === "guided_meditation"`: incrementa `global_stats/guided_meditations` e `item_stats/guided_meditations/items/{itemId}`.
  - Qualquer outro valor: grava `error: "invalid_contentType"` e encerra.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `contentType`, `itemId`, `itemTitle`, `processed`.

---

### `onMeditationLogDeleted`
- **Trigger:** `onDocumentDeleted("meditation_logs/{logId}")`
- **Coleção monitorada:** `meditation_logs`
- **Objetivo:** Decrementa os contadores correspondentes quando um log é removido (limpeza de banco, exclusão de conta).
- **Lógica:** Lê o snapshot do documento deletado, identifica `contentType` e decrementa os mesmos campos que `onMeditationLogCreated` teria incrementado. Só age se `processed === true` (log que já foi contabilizado).

---

### `onLessonFinished`
- **Trigger:** `onDocumentCreated("lesson_logs/{logId}")`
- **Coleção monitorada:** `lesson_logs`
- **Objetivo:** Registra a conclusão real de uma aula (não tentativas isoladas de quiz).
- **Critério:** O log só deve ser criado pelo app quando o usuário submete com sucesso o quiz final da aula.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `lessonId`, `lessonTitle`, `courseId`, `processed`.
- **Atualiza:** `global_stats/lessons` e `item_stats/lessons/items/{lessonId}`.

---

### `onLessonLogDeleted`
- **Trigger:** `onDocumentDeleted("lesson_logs/{logId}")`
- **Objetivo:** Decrementa `global_stats/lessons` e `item_stats/lessons/items/{lessonId}` quando um log de conclusão é removido.
- **Condição:** Só age se `processed === true`.

---

### `onGlossaryLogCreated`
- **Trigger:** `onDocumentCreated("glossary_logs/{logId}")`
- **Coleção monitorada:** `glossary_logs`
- **Objetivo:** Contabiliza acessos ao glossário via menu principal e via integração nas aulas.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `termId`, `termLabel`, `origin` (`"menu"` | `"lesson"`), `processed`.
- **Campo opcional:** `lessonId` (preenchido apenas quando `origin === "lesson"`).
- **Atualiza:** `global_stats/glossary` e `item_stats/glossary/items/{termId}`.
- **Responsabilidade do app:** O componente de aula deve chamar `glossaryService.logAccess(termId, { origin: "lesson", lessonId })` — não gravar diretamente na coleção.

---

### `onGlossaryLogDeleted`
- **Trigger:** `onDocumentDeleted("glossary_logs/{logId}")`
- **Objetivo:** Decrementa `global_stats/glossary` e `item_stats/glossary/items/{termId}`.
- **Condição:** Só age se `processed === true`.

---

### `onPrayerLogCreated`
- **Trigger:** `onDocumentCreated("prayer_logs/{logId}")`
- **Coleção monitorada:** `prayer_logs`
- **Objetivo:** Alimenta a contagem de orações lidas e o ranking de orações mais acessadas.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `prayerId`, `prayerTitle`, `processed`.
- **Atualiza:** `global_stats/prayer` e `item_stats/prayer/items/{prayerId}`.

---

### `onPrayerLogDeleted`
- **Trigger:** `onDocumentDeleted("prayer_logs/{logId}")`
- **Objetivo:** Decrementa `global_stats/prayer` e `item_stats/prayer/items/{prayerId}`.
- **Condição:** Só age se `processed === true`.

---

### `onAmbientPlayerLogCreated`
- **Trigger:** `onDocumentCreated("ambient_player_logs/{logId}")`
- **Coleção monitorada:** `ambient_player_logs`
- **Objetivo:** Substitui completamente o `increment()` manual que existia no app Expo para Sintonia (Plays).
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `trackId`, `trackTitle`, `processed`.
- **Atualiza:** `global_stats/ambient_player`.
- **Ação imediata no app:** Remover o `increment()` de `statsService.ts` para `ambient_player` antes de ativar esta function.

---

### `onQuizLogCreated`
- **Trigger:** `onDocumentCreated("quiz_logs/{logId}")`
- **Coleção monitorada:** `quiz_logs`
- **Objetivo:** Processa Quizzes Gerais do módulo Fixe.
- **Campo discriminador obrigatório:** `quizType: "general"` — garante que apenas quizzes do módulo Fixe sejam contabilizados aqui. Outros valores são ignorados.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `quizId`, `quizTitle`, `quizType`, `processed`.
- **Atualiza:** `global_stats/quizzes`.

---

### `onChatLogCreated`
- **Trigger:** `onDocumentCreated("chat_logs/{logId}")`
- **Coleção monitorada:** `chat_logs`
- **Objetivo:** Consolida Msgs Guia (Apoio Emocional) e Msgs Sr. Allan (Estudo Doutrinário) em uma única trigger.
- **Campo discriminador obrigatório:** `chatType` — valores válidos: `"guide"` | `"scientific"`.
  - Se `chatType === "guide"`: incrementa `global_stats/emotional_chat`.
  - Se `chatType === "scientific"`: incrementa `global_stats/scientific_chat`.
  - Ausência do campo ou valor inválido: grava `error: "missing_chatType"` e encerra sem incrementar.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `chatType`, `origin`, `processed`.
- **Campo opcional:** `lessonId` (quando `chatType === "scientific"` e `origin === "lesson"`).

---

### `onChatLogDeleted`
- **Trigger:** `onDocumentDeleted("chat_logs/{logId}")`
- **Objetivo:** Decrementa o contador correspondente (`emotional_chat` ou `scientific_chat`) com base em `chatType`.
- **Condição:** Só age se `processed === true`.

---

### `onChallengeLogCreated`
- **Trigger:** `onDocumentCreated("challenge_logs/{logId}")`
- **Coleção monitorada:** `challenge_logs`
- **Objetivo:** Processa o Desafio Diário.
- **Campo discriminador obrigatório:** `quizType: "daily_challenge"` — impede sobreposição com `quiz_logs`.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `challengeId`, `date`, `quizType`, `processed`.
- **Atualiza:** `global_stats/daily_challenge`.

---

### `onTruthOrFalseLogCreated`
- **Trigger:** `onDocumentCreated("truth_or_false_logs/{logId}")`
- **Coleção monitorada:** `truth_or_false_logs`
- **Objetivo:** Monitora participações no jogo V ou F.
- **Campos obrigatórios no log:** `userId`, `yearMonth`, `questionId`, `answer`, `correct`, `processed`.
- **Atualiza:** `global_stats/truth_or_false`.

---

### `syncAllStats` *(Função de Manutenção)*
- **Trigger:** HTTP Request (chamada manual ou agendada)
- **Objetivo:** Reconstruir todos os totais de `global_stats` e `item_stats` a partir dos logs existentes, dentro de uma janela de tempo definida.
- **Parâmetros de entrada:** `{ from: Timestamp, to: Timestamp }`
- **Estratégia de concorrência:** A função processa apenas logs com `createdAt <= to` (janela fechada). Logs gravados após `to` não são afetados. Para o reset do "dia 1", `from` é o início do novo mês e `to` é o momento da execução do reset.
- **Segurança:** Protegida por autenticação de serviço (não exposta publicamente).

---

## 4. Tabela Resumo

| Função | Trigger | Coleção | KPI(s) |
|---|---|---|---|
| `onUserCreated` | `auth.onCreate` | Firebase Auth | Credenciais |
| `onUserDeleted` | `auth.onDelete` | Firebase Auth | Credenciais (decremento) |
| `onMeditationLogCreated` | `onDocumentCreated` | `meditation_logs` | Reflexões / Meditações |
| `onMeditationLogDeleted` | `onDocumentDeleted` | `meditation_logs` | Reflexões / Meditações (decremento) |
| `onLessonFinished` | `onDocumentCreated` | `lesson_logs` | Lições Concluídas |
| `onLessonLogDeleted` | `onDocumentDeleted` | `lesson_logs` | Lições Concluídas (decremento) |
| `onGlossaryLogCreated` | `onDocumentCreated` | `glossary_logs` | Glossário |
| `onGlossaryLogDeleted` | `onDocumentDeleted` | `glossary_logs` | Glossário (decremento) |
| `onPrayerLogCreated` | `onDocumentCreated` | `prayer_logs` | Orações Lidas |
| `onPrayerLogDeleted` | `onDocumentDeleted` | `prayer_logs` | Orações Lidas (decremento) |
| `onAmbientPlayerLogCreated` | `onDocumentCreated` | `ambient_player_logs` | Sintonia (Plays) |
| `onQuizLogCreated` | `onDocumentCreated` | `quiz_logs` | Quizzes Gerais |
| `onChatLogCreated` | `onDocumentCreated` | `chat_logs` | Msgs Guia / Msgs Sr. Allan |
| `onChatLogDeleted` | `onDocumentDeleted` | `chat_logs` | Msgs Guia / Msgs Sr. Allan (decremento) |
| `onChallengeLogCreated` | `onDocumentCreated` | `challenge_logs` | Desafio Diário |
| `onTruthOrFalseLogCreated` | `onDocumentCreated` | `truth_or_false_logs` | V ou F |
| `syncAllStats` | HTTP Request | Todas | Reset / Auditoria |

---

## 5. Checklist Pré-Deploy

Antes de ativar as functions e zerar os contadores:

- [ ] Remover todos os `increment()` de `statsService.ts` no Expo (especialmente `ambient_player`)
- [ ] Confirmar que todos os fluxos do app gravam o campo `processed: false` ao criar logs
- [ ] Confirmar que `chat_logs` sempre incluem `chatType` (`"guide"` ou `"scientific"`)
- [ ] Confirmar que `meditation_logs` sempre incluem `contentType` (`"reflection"` ou `"guided_meditation"`)
- [ ] Confirmar que o componente de aula chama `glossaryService.logAccess()` e não grava diretamente
- [ ] Confirmar que `challenge_logs` incluem `quizType: "daily_challenge"` e que `quiz_logs` do Fixe incluem `quizType: "general"`
- [ ] Executar `syncAllStats` com janela `from = início do novo mês` após o deploy
- [ ] Validar os contadores no painel após 24h de operação

---

## 6. Retenção e Limpeza de Logs

Para controlar custo/volume e manter o Firestore saudável, estabelecer retenção para coleções de log desde o início.

- **Regra:** Só remover logs com `processed === true` e após uma janela de segurança.
- **Retenção padrão:** 6 meses (180 dias) para logs de evento.
- **Agregados permanentes:** `global_stats/*` e `item_stats/*` permanecem como fonte de leitura para dashboard e não devem depender da existência dos logs antigos.
- **Job agendado:** Cloud Function (scheduler) para deletar em lote logs `processed === true` com `createdAt` anterior ao cutoff (hoje - 180 dias).

> Observação: o limite de ~1 MiB por documento impacta principalmente documentos agregados muito “inflados” (muitas chaves/dimensões dentro do mesmo doc). A política de retenção acima é focada em logs, mas é recomendável também limitar granularidade de agregados (ex.: por mês em vez de por dia no mesmo doc).

---

*Plano de Implementação v2.0 — Revisado e corrigido em 16/05/2026*
