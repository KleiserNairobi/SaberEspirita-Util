# Remoção de Functions Legadas (Monitoramento v1) + Ajuste deepseekProxy

## Status Geral

| Item | Status |
|---|---|
| Functions v1 legadas removidas do código e do servidor | ✅ Concluído em 19/06/2026 |
| `deepseekProxy` — ajuste de `minInstances: 1 → 0` | ✅ Concluído em 20/06/2026 |
| Secret cacheado via `process.env` (injeção Firebase) | ✅ Já correto (sem re-leitura por chamada) |

---

## Parte 1: Limpeza de Functions Legadas (Monitoramento v1)

### Objetivo

Desativar e excluir definitivamente as Cloud Functions antigas (v1) do sistema de monitoramento, que tinham falhas de contagem em duplicidade e foram substituídas por um modelo v2 orientado a eventos (gatilhos `*LogCreated` / `*LogDeleted`).

### Functions removidas

As seguintes funções legadas foram superadas pelo modelo v2 e removidas por completo:

1. **`onAmbientPlayerUsage`** → substituída por `onAmbientPlayerLogCreated`
2. **`onGlossaryUsage`** → substituída por `onGlossaryLogCreated`
3. **`onMeditationUsage`** → substituída por `onMeditationLogCreated`
4. **`onPrayerUsage`** → substituída por `onPrayerLogCreated`
5. **`onEmotionalChatUsage`** → substituída por `onEmotionalChatLogCreated`
6. **`onScientificChatUsage`** → substituída por `onScientificChatLogCreated`
7. **`onDailyChallengeCompletion`** → substituída por `onChallengeLogCreated`
8. **`onTruthOrFalseAnswer`** → substituída por `onTruthOrFalseLogCreated`
9. **`onLessonCompleted`** → substituída por `onLessonLogCreated`

### Como foi executado

1. Arquivos `.ts` das functions v1 apagados de `functions/src/triggers/`.
2. Linhas de importação e exportação removidas do `functions/src/index.ts`.
3. Deploy executado (`firebase deploy --only functions`).
4. CLI do Firebase detectou a divergência e apagou as triggers do servidor após confirmação com `Y`.

### Confirmação pós-deploy

Busca realizada em 20/06/2026 no código-fonte confirma que nenhuma das 9 functions v1 existe mais na pasta `src/triggers/` nem no `index.ts`. A migração para o monitoramento v2 está encerrada sem risco de duplicidade de contagem.

---

## Parte 2: Ajuste de Custo — `deepseekProxy`

### Causa raiz do custo extra

A `deepseekProxy` estava configurada com `minInstances: 1`, mantendo uma instância ativa 24h/dia, cobrada continuamente em GB-segundos/vCPU-segundos — independente do volume de chamadas (~15/mês no período analisado).

### Ajuste aplicado em 20/06/2026

**Arquivo:** `functions/src/triggers/deepseekProxy.ts`

```diff
- // Mantém uma instância sempre aquecida para eliminar cold start
- minInstances: 1,
+ // minInstances: 0 — com ~15 chamadas/mês, o cold start ocasional é aceitável
+ // e o custo de manter 1 instância sempre ativa (GB-s/vCPU-s) não se justifica.
+ minInstances: 0,
```

### Sobre o Secret Manager

O acesso ao secret já estava correto: o Firebase injeta `DEEPSEEK_API_KEY` em `process.env` via declaração `secrets: ['DEEPSEEK_API_KEY']` na configuração da function. Esse valor é cacheado automaticamente na instância entre invocações — não há re-leitura a cada chamada. O custo de R$ 0,53 no período é de armazenamento da versão do secret (fixo), não de acesso por requisição.

### Próximos passos

- [ ] **Deploy:** executar `firebase deploy --only functions` para aplicar a mudança em produção.
- [ ] **Validar no Console:** `Cloud Functions → deepseekProxy` → coluna de instâncias deve passar de `1 / 20` para `0 / 20`.
- [ ] **Confirmar no billing:** acompanhar o ciclo de faturamento seguinte (julho/2026) para confirmar queda no custo de Cloud Run Functions.
- [ ] **(Recomendado)** Configurar budget alert no Cloud Billing (ex: limite de R$ 10–15/mês).
