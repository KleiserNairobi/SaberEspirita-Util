# Otimização de Cotas de Leitura do Firestore

Este plano visa resolver os picos de consumo de leituras no Cloud Firestore descritos no diagnóstico. A solução consiste em denormalizar os contadores de coleções para evitar múltiplas execuções de `count()` em tempo real (substituindo-as por gatilhos do Cloud Functions e uma leitura única no frontend) e em implementar cache local com TTL na listagem do Leaderboard do aplicativo mobile.

## User Review Required

> [!IMPORTANT]
> **Necessidade de Deploy das Cloud Functions:** As alterações propostas no backend requerem o deploy das Cloud Functions atualizadas para o Firebase para que os contadores sejam atualizados dinamicamente a cada criação/deleção nas coleções vigiadas.
>
> **Execução Única de Sincronização:** Após o deploy das funções e a publicação do frontend, precisaremos executar a nova Cloud Function `syncCounters` uma única vez (via chamada HTTPS autenticada ou ferramenta administrativa) para inicializar e calibrar o documento `/global_stats/counters` com a contagem atual das coleções do banco de dados.

## Open Questions

Neste momento, não temos dúvidas técnicas impeditivas. O design e os pontos de atuação no código estão claros. Caso você queira alterar o tempo de expiração (TTL) do cache do Leaderboard no app (proposto em 5 minutos), por favor nos informe.

## Proposed Changes

---

### [SaberEspirita-Web - Cloud Functions]

Criaremos e modificaremos funções no diretório de Cloud Functions para rastrear a criação e remoção de documentos e manter a contagem atualizada no documento `/global_stats/counters`.

#### [NEW] [updateCounters.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions/src/triggers/updateCounters.ts)
Gatilhos do Firestore v2 escutando criação/deleção nas coleções: `courses`, `lessons` (subcoleção), `quizes`, `lesson_quizzes`, `prayers`, `reflections`, `glossary`, `meditations`, `podcasts` e `users`. Toda ação incrementará ou decrementará o respectivo contador no documento central `/global_stats/counters`.

#### [NEW] [syncCounters.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions/src/maintenance/syncCounters.ts)
Uma Cloud Function HTTPS `syncCounters` para calibrar/sincronizar os contadores agregados a partir de queries `.count()` rápidas no lado do servidor. Essa função será chamada via API administrativa (usando o token `ADMIN_SECRET_TOKEN`) para fazer o setup inicial e garantir resiliência caso os contadores saiam de sincronia.

#### [MODIFY] [index.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/functions/src/index.ts)
Exportação dos novos gatilhos e da função de sincronização de contadores.

---

### [SaberEspirita-Web - Admin Frontend]

Alterar as consultas de integridade do dashboard administrativo para ler a estatística consolidada a partir do documento `/global_stats/counters`.

#### [MODIFY] [analytics.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/services/analytics.ts)
- Alterar `getKeyMetrics()` para obter a contagem de usuários ativos através de `/global_stats/counters` ao invés de executar um `getCountFromServer` na coleção `users`.
- Alterar `checkIntegrity()` para realizar apenas uma única leitura em `/global_stats/counters` ao invés de disparar múltiplas chamadas `getCountFromServer` individuais em paralelo (incluindo o loop que conta lições de cada curso).

---

### [SaberEspirita-Expo - Mobile App]

Implementar cache em memória no Leaderboard para evitar consultas repetitivas de 300 documentos a cada abertura da aba de rankings.

#### [MODIFY] [leaderboardService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/leaderboardService.ts)
Implementar cache de curta duração em memória (TTL de 5 minutos) indexado por período (`WEEK`, `MONTH`, `ALL`) na função `getLeaderboard`.

---

## Verification Plan

### Automated Tests
- Executaremos um build local do painel administrativo (`SaberEspirita-Web`) e do backend das funções (`SaberEspirita-Web/functions`) para garantir que as alterações não introduzem erros de tipagem TypeScript ou quebras de build.
  - Comando: `pnpm run build` na pasta `SaberEspirita-Web/functions`.
  - Comando: `npm run build` (ou gerenciador equivalente do painel) em `SaberEspirita-Web` para validar o frontend.

### Manual Verification
- Validaremos a lógica do cache no Leaderboard simulando chamadas repetidas e verificando se os dados do cache são reutilizados dentro do intervalo do TTL.
- Mostraremos as mudanças de código correspondentes ao usuário e detalharemos as instruções para a execução do endpoint de sincronização inicial.
