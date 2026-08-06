# Implementação — Saneamento/Retenção de Logs (Firestore)

**Objetivo:** Implementar saneamento automático das coleções de logs (KPI) para manter custo/volume controlados e evitar acúmulo indefinido.  
**Política:** reter por **6 meses (180 dias)** e deletar apenas logs já processados.

---

## 1. Escopo

### 1.1 O que será limpo

- Coleções de logs de KPI (eventos imutáveis), por exemplo:
  - `lesson_logs`
  - `certificate_logs`
  - `glossary_logs`
  - `prayer_logs`
  - `ambient_player_logs`
  - `quiz_logs`
  - `challenge_logs`
  - `truth_or_false_logs`
  - `chat_logs`
  - `meditation_logs`
  - Logs novos adicionados futuramente (ex.: fórum/reação/atividade)

### 1.2 O que NÃO será limpo

- Documentos agregados de leitura rápida:
  - `global_stats/*`
  - `item_stats/*`
- Documentos de domínio:
  - comentários, reações, progresso do usuário, etc.

---

## 2. Regras de Retenção (obrigatórias)

- **Só deletar logs com `processed === true`.**
- **Só deletar logs com `createdAt` definido** e anterior ao cutoff.
- **Janela:** `cutoff = now - 180 dias`.
- **Segurança:** manter logs não processados (para não “perder” eventos antes da agregação).

Campos mínimos esperados nos logs (já padrão do projeto):

- `createdAt: Timestamp`
- `yearMonth: "YYYY-MM"`
- `processed: boolean`
- `error?: string`

---

## 3. Abordagem Técnica (Cloud Functions)

### 3.1 Trigger

Criar uma Cloud Function agendada (scheduler) para rodar 1x por dia.

- Plataforma: Cloud Functions for Firebase (v2)
- Tipo: `onSchedule`
- Sugestão: rodar de madrugada (ex.: 03:30) para reduzir conflito com picos.
- Timezone: UTC (para consistência com `yearMonth`/`dayKey`).

### 3.2 Algoritmo de limpeza (por coleção)

Para cada coleção de logs:

1. Calcular `cutoffTimestamp` (agora - 180 dias).
2. Consultar Firestore:
   - `where("processed", "==", true)`
   - `where("createdAt", "<", cutoffTimestamp)`
   - `orderBy("createdAt", "asc")`
   - `limit(N)` (N = 300–500 por iteração)
3. Deletar em lote os documentos retornados.
4. Repetir até não haver mais resultados.

### 3.3 Mecanismo de deleção (limites Firestore)

- `WriteBatch` tem limite de 500 operações por commit.
- Preferível usar `BulkWriter` (Admin SDK) para throughput e retry automático.
- Sempre aplicar paginação por `limit` e loop, evitando carregar milhares de docs em memória.

### 3.4 Índices

Cada coleção precisa suportar query composta:

- `processed == true` + `createdAt < cutoff` + `orderBy(createdAt)`

Se o Firestore exigir índice, ele vai apontar o link de criação no log de execução da function.

---

## 4. Observabilidade e Segurança Operacional

### 4.1 Dry-run (recomendado)

Implementar um modo “dry-run” (sem deletar) controlado por config/variável para:

- logar quantos docs seriam deletados por coleção
- validar queries/índices

### 4.2 Limites e timeouts

- A function deve impor um limite de tempo por execução.
- Estratégia: interromper após X minutos e continuar no próximo schedule, para não estourar timeout.

### 4.3 Logs de execução

Para cada execução:

- `runId`, data/hora, cutoff calculado
- total deletado por coleção
- tempo total
- erros por coleção (ex.: missing index)

---

## 5. Checklist de Implementação

- [ ] Criar trigger `onSchedule` “logRetentionCleanup”
- [ ] Declarar lista de coleções alvo em um array central
- [ ] Implementar `cutoffTimestamp` (180 dias)
- [ ] Implementar loop paginado por coleção (`processed == true` e `createdAt < cutoff`)
- [ ] Implementar `dryRun` + métricas de saída
- [ ] Garantir que deletar só ocorra quando `dryRun === false`
- [ ] Rodar em emulador (se aplicável) ou deploy em ambiente de teste
- [ ] Rodar 1 execução manual (callable/admin) opcional para validar índices
- [ ] Deploy e monitorar logs por 48h

---

## 6. Considerações para o Fórum (quando entrar)

Se o fórum seguir o padrão KPI:

- Logs de comentário/reação/atividade devem ter `processed`, `createdAt`, `yearMonth`.
- A limpeza segue as mesmas regras (somente `processed === true`).

Se houver documento diário idempotente de “dia ativo”:

- Pode ser limpo com a mesma janela (90–180 dias) porque o agregado `activeDays` permanece no `communityProgress`.
