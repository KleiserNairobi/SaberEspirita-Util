# Plano de Execução (v2) — Correção Definitiva do Monitoramento

_Baseado no doc 04 e decisões confirmadas — Mobile + Web/Cloud Functions_

---

## 0) Objetivo

Implementar o monitoramento v2 em duas frentes (Mobile e Web/Cloud Functions) para eliminar:

- contagens híbridas (cliente incrementando contadores)
- inconsistências entre painel e Firestore/Auth
- contagens infladas por ausência de decrementos e falta de reconstrução auditável

Resultado esperado:

- Mobile registra apenas fatos (logs) com schema v2
- Back-end consolida estatísticas (`global_stats/*` + `item_stats/*`) via Cloud Functions com idempotência e decrementos
- `syncAllStats` reconstrói números de forma auditável numa janela `[from, to]`
- Dashboard lê apenas agregados consolidados (com fallback temporário se necessário)

---

## 1) Repositórios / Frentes

### Frente A — Mobile (Expo)

Raiz: `/Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo`

Responsabilidade:

- Criar logs v2 (com `userId`, `createdAt`, `yearMonth`, `processed:false`) para todos os KPIs
- Remover qualquer `increment()`/escrita em `global_stats/*` e `item_stats/*`

### Frente B — Web/Back-end (Cloud Functions + Dashboard)

Raiz: `/Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions`

Responsabilidade:

- Triggers v2 (create + delete) com transação e idempotência (`processed`)
- `syncAllStats` HTTP protegido
- Ajustes no dashboard para ler `totalCount`/`monthly`

---

## 2) Dependências e Ordem (para evitar contagem dupla)

Regra operacional:

- Não pode existir, ao mesmo tempo, “cliente incrementando” e “CF v2 incrementando o mesmo KPI”, senão volta o híbrido.

Ordem recomendada (segura):

1. Mobile: parar `increment()` e começar a gravar logs v2 (sem depender das CFs v2 estarem ativas)
2. Web/CF: ativar triggers v2 e desativar gatilhos legados conflitantes
3. Web/CF: executar `syncAllStats` (marco de transição)
4. Dashboard: apontar leitura para `totalCount`/`monthly` (com fallback temporário se necessário)
5. Validação e, por fim, remoção definitiva do legado

---

## 3) Checklist Macro de Entregáveis (por módulo do produto)

### Estude

- `lesson_logs` (aulas concluídas)
- `quiz_logs` com `quizType:"lesson"` (quizzes de aula)
- `glossary_logs` com `origin:"menu"|"lesson"` (+ `lessonId` quando `"lesson"`)
- `scientific_chat_logs` com `origin:"direct"|"lesson"|"glossary"` (+ `lessonId` quando `"lesson"`)
- `certificate_logs` (evento dedicado) independente de `certificates`

### Fixe

- `quiz_logs` com `quizType:"general"` (quizzes gerais)
- `challenge_logs` (desafio diário)
- `truth_or_false_logs` (Verdade ou Mentira)

### Medite

- `meditation_logs` com `contentType:"reflection"|"guided_meditation"`
- `emotional_chat_logs` com `origin:"medite"`

### Ore

- `prayer_logs`
- `ambient_player_logs` (Sintonia)
- `emotional_chat_logs` com `origin:"ore"`

---

## 4) Execução — Frente A (Mobile / Expo)

### 4.1 Remover monitoramento híbrido (obrigatório)

- Remover uso de:
  - `StatsService.incrementQuizCount(...)`
  - `StatsService.incrementAmbientPlayCount(...)`
  - quaisquer outras escritas em `global_stats/*` e `daily_stats/*` para fins de monitoramento

Pontos já identificados:

- `/src/services/firebase/statsService.ts`
- `/src/services/firebase/progressService.ts` (chamada de increment após salvar exercício)
- `/src/services/firebase/quizService.ts` (increment após salvar histórico)
- telas de visitante que incrementam ao finalizar

### 4.2 Padronizar schema v2 em todos os logs

Implementar utilitário único:

- `yearMonth` em UTC (`YYYY-MM`)
- `createdAt: serverTimestamp()`
- `processed: false`
- `userId` sempre preenchido (ou `"guest"` quando aplicável)

Aplicar para:

- `meditation_logs`
- `glossary_logs`
- `prayer_logs`
- `ambient_player_logs`
- `emotional_chat_logs`
- `scientific_chat_logs`
- `lesson_logs`
- `quiz_logs`
- `challenge_logs`
- `truth_or_false_logs`
- `certificate_logs`

### 4.3 Implementar criação de logs ausentes (que hoje não existem)

- `lesson_logs`: criar no “Finalizar” da aula (Estude)
- `quiz_logs` (lesson/general): criar no “Finalizar” dos quizzes correspondentes
- `challenge_logs`: criar no “Finalizar” do desafio diário
- `truth_or_false_logs`: criar ao salvar resposta no V/F
- `certificate_logs`: criar quando o certificado for efetivamente emitido (momento de geração/armazenamento)

### 4.4 Garantir “independência de origem”

- Glossário:
  - origem via menu: `origin:"menu"`
  - origem via aula: `origin:"lesson"` + `lessonId`
- Chat Científico:
  - `origin:"direct"|"lesson"|"glossary"` (+ `lessonId` quando `"lesson"`)

### 4.5 Critérios de aceite (Mobile)

- Não existe mais nenhum caminho que escreva em `global_stats/*` ou `item_stats/*`
- Cada ação do usuário cria exatamente 1 log do tipo correto
- Todos os logs têm os 4 campos base + campos específicos do KPI
- Visitante:
  - ainda pode criar logs (com `userId:"guest"`) se vocês quiserem medir visitantes; caso contrário, bloquear criação de logs para guest de forma consistente

---

## 5) Execução — Frente B (Web / Cloud Functions)

### 5.1 Triggers v2 (create + delete)

Para cada coleção `*_logs` do doc 04, criar:

- `onXLogCreated` (`onDocumentCreated`)
- `onXLogDeleted` (`onDocumentDeleted`)

Contrato:

- create:
  - se `processed === true`, retorna
  - valida campos base (`userId`, `createdAt`, `yearMonth`, `processed`) e específicos
  - transação:
    - incrementa `global_stats/{kpi}.totalCount` e `global_stats/{kpi}.monthly.{yearMonth}`
    - se houver ranking: incrementa também `item_stats/...`
    - marca `processed:true`
- delete:
  - só decrementa se snapshot deletado tiver `processed === true`
  - decrementa os mesmos campos do create

### 5.2 Compatibilidade/legado (evitar contagem dupla)

Inventariar triggers atuais que já contam:

- `onAmbientPlayerUsage` (já conta `ambient_player_logs`)
- `onGlossaryUsage` (já conta `glossary_logs`)
- `onMeditationUsage` (já conta `meditation_logs`)
- `onPrayerUsage` (já conta `prayer_logs`)
- `onEmotionalChatUsage` (já conta `emotional_chat_logs`)
- `onScientificChatUsage` (já conta `scientific_chat_logs`)
- `onDailyChallengeCompletion` (conta via `users_history`)
- `onTruthOrFalseAnswer` (conta via `users/{uid}/truthOrFalseResponses`)

Decisão operacional:

- Desativar os legados que conflitam com os logs v2, ou colocar guard para que eles ignorem logs “v2” (por exemplo, detectar `yearMonth`/`processed` e não contabilizar no legado).

### 5.3 Implementar `syncAllStats` (HTTP protegido)

Requisitos:

- Entrada: `{ from: Timestamp, to: Timestamp }`
- Recalcular:
  - `global_stats/*` log-based (`totalCount` + `monthly`)
  - `item_stats/*` dos módulos com ranking
- Ignorar `processed` como fonte de verdade
- Executar em janela fechada `[from, to]` usando `createdAt`
- Segurança: autenticação service-to-service (não público)

### 5.4 Critérios de aceite (Cloud Functions)

- Cada log v2 incrementa exatamente 1 vez (idempotente)
- Delete decrementa corretamente quando o log foi processado
- `syncAllStats` produz o mesmo resultado ao ser executado repetidas vezes com a mesma janela

---

## 6) Dashboard (Web)

### 6.1 Leitura de KPIs

- Ler `global_stats/{kpi}.totalCount`
- Visão mensal: `global_stats/{kpi}.monthly.{yearMonth}`
- Ranking: `item_stats/{module}/items` Top 10

### 6.2 Fallback temporário (se necessário)

Durante migração, suportar fallback para campos legados (`totalPlays`, `totalViews`, `totalMessages`, etc.) apenas para não quebrar UI enquanto o rebuild não acontece.

---

## 7) Migração Operacional (Dia 1)

1. Publicar Mobile com logs v2 e sem increments
2. Deploy Cloud Functions v2 + desativar/guardar legados conflitantes
3. Executar `syncAllStats` com:
   - `from = início do ciclo (Dia 1 escolhido)`
   - `to = momento da execução`
4. Validar painel e amostras (ver seção 8)
5. Após estabilidade: remover definitivamente CFs legadas

---

## 8) Validação (critérios objetivos)

- Estude:
  - `global_stats/lessons.totalCount` bate com amostra de `lesson_logs`
  - `global_stats/lesson_quizzes.totalCount` bate com amostra de `quiz_logs` (`quizType:"lesson"`)
  - `glossary_logs.origin` sempre presente e válido
  - `scientific_chat_logs.origin` sempre presente e válido
- Fixe:
  - `global_stats/quizzes.totalCount` bate com `quiz_logs` (`quizType:"general"`)
  - `global_stats/daily_challenge.totalCount` cresce apenas com `challenge_logs`
  - `global_stats/truth_or_false.totalCount` cresce apenas com `truth_or_false_logs`
- Medite/Ore:
  - `global_stats/emotional_chat.totalCount` cresce com `emotional_chat_logs` e distingue por `origin`
  - `global_stats/ambient_player.totalCount` cresce apenas com `ambient_player_logs` (sem duplicidade)
- Erros:
  - volume de logs com `error` é baixo e investigável

---

## 9) Próximo passo (após este plano)

Executar primeiro a Frente A (Mobile) nos pontos de maior risco de híbrido:

- remover `StatsService` como produtor de `global_stats`
- criar os logs v2 que ainda não existem (lesson_logs, quiz_logs, challenge_logs, truth_or_false_logs, certificate_logs)
- padronizar schema dos logs existentes (meditation/glossary/prayer/ambient/chat)

Depois partir para Frente B (CFs v2 + guard do legado + `syncAllStats`).
