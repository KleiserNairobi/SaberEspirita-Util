# Análise do Sistema de Monitoramento - Saber Espírita

Esta análise foi realizada para identificar discrepâncias entre os números exibidos no Painel de Controle e a realidade dos dados no Firestore/Auth, além de verificar a maturidade das Cloud Functions.

## Resumo Executivo
Atualmente, o monitoramento é **híbrido**. Alguns números são incrementados diretamente pelo aplicativo (Expo), enquanto outros dependem de Cloud Functions disparadas por logs. Esta abordagem gera inconsistências e contagens duplicadas.

---

## Detalhamento por Item Monitorado

| Item | Origem do Dado (Web) | Mecanismo de Atualização | Status Cloud Function | Maturidade / Observação |
| :--- | :--- | :--- | :--- | :--- |
| **Credenciais** | `global_stats/users` | `onUserCreated.ts` | ✅ Existe | **Média.** Apenas incrementa. Não decrementa em exclusões. Existe script de sync manual. |
| **Usuários Ativos** | `collection('users')` | Direto (Count Query) | ❌ N/A | **Alta.** Reflete a realidade exata dos documentos existentes no Firestore. |
| **Lições Concl.** | `global_stats/lesson_quizzes` | App Expo (Manual) | ❌ Ausente* | **Baixa.** O dashboard usa `totalAttempts`. A function `onLessonCompleted` atualiza `course_stats`, não este campo. |
| **Quizzes Gerais** | `global_stats/quizzes` | App Expo (Manual) | ❌ Ausente | **Baixa.** Atualizado apenas via cliente. Sujeito a falhas de conexão/perda de eventos. |
| **Meditações** | `global_stats/guided_meditations` | `onMeditationUsage.ts` | ✅ Existe | **Média.** Usa `onDocumentCreated`. Não reflete exclusões de logs. |
| **Reflexões Lidas** | `global_stats/meditation` | `onMeditationUsage.ts` | ✅ Existe | **Média.** Mesmo caso das meditações (usa o campo legado `meditation`). |
| **Sintonia (Plays)** | `global_stats/ambient_player` | **Ambos (Conflito)** | ✅ Existe | **Crítico.** Tanto o App Expo quanto a CF `onAmbientPlayerUsage` incrementam o campo. **Contagem Duplicada.** |
| **Orações Lidas** | `global_stats/prayer` | `onPrayerUsage.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |
| **Glossário** | `global_stats/glossary` | `onGlossaryUsage.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |
| **Msgs Sr. Allan** | `global_stats/scientific_chat` | `onScientificChatUsage.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |
| **Msgs Guia** | `global_stats/emotional_chat` | `onEmotionalChatUsage.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |
| **Desafio Diário** | `global_stats/daily_challenge` | `onDailyChallengeCompletion.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |
| **V ou F** | `global_stats/truth_or_false` | `onTruthOrFalseAnswer.ts` | ✅ Existe | **Média.** Apenas incrementa no `onDocumentCreated`. |

---

## Problemas Identificados

1.  **Contagem Duplicada (Sintonia):** O arquivo `statsService.ts` no Expo incrementa `totalPlays` e a Cloud Function `onAmbientPlayerUsage` também o faz ao detectar a criação do log.
2.  **Mismatch de Lições:** O dashboard monitora `lesson_quizzes` (total de tentativas), mas o back-end foca em `course_stats` (conclusões). Não há uma trigger para sincronizar o total global de tentativas de quizzes de lições.
3.  **Maturidade das Functions:** Todas as triggers atuais usam `onDocumentCreated`. Se um documento de log for excluído (por limpeza de banco ou erro), o contador global **não é decrementado**, fazendo com que o número cresça artificialmente ao longo do tempo.
4.  **Dependência do Cliente (Manual):** Quizzes (Gerais e Lições) ainda dependem de chamadas diretas do App para `global_stats`. Se o app falhar ao rodar o `setDoc` após o quiz, o número se perde.

## Recomendações para "Zerar" e Corrigir

1.  **Migração Total para Triggers:** Remover todos os `increment()` manuais do arquivo `src/services/firebase/statsService.ts` no projeto Expo. O App deve apenas criar o documento de log.
2.  **Implementação de Decrementos:** Alterar as triggers para `onDocumentWritten` ou adicionar `onDocumentDeleted` para subtrair do contador global quando logs forem removidos.
3.  **Script de Recount (Reset):** Criar uma Cloud Function de manutenção (similar à `syncUserCount`) que percorra as coleções de logs e recalcule os totais do zero para cada item, garantindo que o "dia 1" comece com números auditáveis.
4.  **Unificar Lições:** Decidir se o Dashboard deve mostrar "Tentativas de Quizzes de Lição" ou "Lições Concluídas" e ajustar a trigger para refletir essa escolha em `global_stats`.

---
*Análise gerada por Antigravity em 16/05/2026.*
