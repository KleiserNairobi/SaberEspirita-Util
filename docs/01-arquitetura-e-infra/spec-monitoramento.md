# Especificação de Monitoramento — Saber Espírita
*Versão 2.0 — Revisada e corrigida*

---

## 1. Princípios de Ouro do Monitoramento

- **Back-end como Fonte da Verdade:** O aplicativo apenas registra o "fato" (log). O servidor processa e acumula a estatística. Nenhum `increment()` deve existir no código do app Expo.
- **Independência de Origem:** Se um recurso é acessado por dois fluxos diferentes (ex: Sr. Allan via menu ou via lição), ambos gravam na mesma coleção de log. A Cloud Function contabiliza independente da origem.
- **Granularidade Temporal:** Todo documento de log deve conter os campos `createdAt` (Timestamp) e `yearMonth` (string, ex: `"2026-05"`). Isso permite filtros mensais sem queries pesadas.
- **Idempotência Garantida:** Toda Cloud Function deve verificar se o log já foi processado antes de alterar contadores globais. O campo `processed: true` é gravado no próprio documento de log após o processamento. Em caso de reexecução, a função verifica esse campo e encerra sem alterar nada.
- **Consistência via Transação:** Toda atualização de `global_stats` deve ocorrer dentro de uma transação Firestore para evitar race conditions em acessos simultâneos.

---

## 2. Schema Base dos Documentos de Log

Todo documento gravado em qualquer coleção `*_logs` deve conter os campos abaixo. Campos específicos de cada módulo são adicionais.

```
{
  userId:    string,        // UID do usuário (Firebase Auth)
  createdAt: Timestamp,     // Firestore server timestamp
  yearMonth: string,        // Ex: "2026-05" — para filtros mensais
  processed: boolean        // Inicia como false; Cloud Function grava true ao processar
}
```

---

## 3. Definição dos Indicadores (KPIs)

### A. Gestão de Usuários

**1. Credenciais (Cadastros Totais)**
- O quê: Volume total de contas criadas no Firebase Auth.
- Como: Disparado automaticamente pelo evento `auth.user().onCreate`.
- Contador global: `global_stats/users` → campo `totalCredentials`.
- Detalhe: Deve decrementar em `auth.user().onDelete` para refletir exclusões de conta.

**2. Usuários Ativos (Perfis Reais)**
- O quê: Contagem de documentos existentes na coleção `users` do Firestore. Representa a base engajada com perfil criado.
- Como: Count Query direta — não usa log nem contador global.
- Detalhe: Reflete a realidade em tempo real. Não necessita de trigger adicional.

---

### B. Módulo "Medite"

> O nome "Medite" no app é o título do módulo, que agrega dois tipos de conteúdo distintos: textos de reflexão e áudios de meditação guiada. Ambos devem ser monitorados separadamente.

**3. Reflexões Lidas (Inspiração)**
- O quê: Número de acessos a textos de reflexão.
- Coleção de log: `meditation_logs`
- Campo discriminador no log: `contentType: "reflection"`
- Campos adicionais no log: `itemId` (ID do texto), `itemTitle` (título).
- Contador global: `global_stats/reflections` → campos `totalCount` e `monthly.{yearMonth}`.
- Ranking: `item_stats/reflections/items/{itemId}` → `{ title, totalCount, monthly }`.

**4. Meditações Guiadas (Áudio)**
- O quê: Número de plays iniciados em áudios de meditação guiada.
- Coleção de log: `meditation_logs`
- Campo discriminador no log: `contentType: "guided_meditation"`
- Campos adicionais no log: `itemId`, `itemTitle`.
- Contador global: `global_stats/guided_meditations` → campos `totalCount` e `monthly.{yearMonth}`.
- Ranking: `item_stats/guided_meditations/items/{itemId}` → `{ title, totalCount, monthly }`.

---

### C. Educação e Estudo

**5. Lições Concluídas**
- O quê: Número de vezes que um usuário **finalizou** uma aula. Não conta tentativas de quiz isoladas.
- Critério técnico de conclusão: A lição é considerada concluída quando o usuário submete com sucesso o quiz final da aula (evento de submissão com resultado registrado). Esse é o gatilho para criação do log.
- Coleção de log: `lesson_logs`
- Campos adicionais no log: `lessonId`, `lessonTitle`, `courseId`.
- Contador global: `global_stats/lessons` → campos `totalCount` e `monthly.{yearMonth}`.
- Ranking: `item_stats/lessons/items/{lessonId}` → `{ title, courseId, totalCount, monthly }`.

**6. Glossário**
- O quê: Consultas a termos do glossário, independente do fluxo de origem.
- Fluxos cobertos:
  - Acesso direto via menu principal do app.
  - Clique em termo destacado dentro de uma aula (integração aula → glossário).
- Responsabilidade de gravação do log: Em ambos os fluxos, o log deve ser gravado pelo mesmo serviço centralizado (`glossaryService.logAccess(termId)`). O componente da aula deve chamar esse serviço — não gravar diretamente na coleção.
- Coleção de log: `glossary_logs`
- Campos adicionais no log: `termId`, `termLabel`, `origin` (`"menu"` ou `"lesson"`), `lessonId` (opcional, preenchido apenas quando `origin = "lesson"`).
- Contador global: `global_stats/glossary` → campos `totalCount` e `monthly.{yearMonth}`.
- Ranking: `item_stats/glossary/items/{termId}` → `{ term, totalCount, monthly }`.

**7. Quizzes Gerais (Módulo Fixe)**
- O quê: Participações nos quizzes de aprendizado e diversão do módulo "Fixe". Não inclui quiz de lição nem Desafio Diário.
- Coleção de log: `quiz_logs`
- Campo discriminador no log: `quizType: "general"` — garante que essa trigger não confunda com outros tipos de quiz.
- Campos adicionais no log: `quizId`, `quizTitle`.
- Contador global: `global_stats/quizzes` → campos `totalCount` e `monthly.{yearMonth}`.

---

### D. Interação e Apoio

**8. Apoio Emocional (Msgs Guia)**
- O quê: Volume de mensagens trocadas com o Guia, em qualquer contexto.
- Fluxos cobertos:
  - Acesso direto via chat de apoio emocional.
  - Acesso via módulo "Ore" (Apoio para Oração).
- Coleção de log: `chat_logs`
- Campo discriminador no log: `chatType: "guide"` — obrigatório em ambos os fluxos.
- Campos adicionais no log: `origin` (`"direct"` ou `"prayer_module"`).
- Contador global: `global_stats/emotional_chat` → campos `totalCount` e `monthly.{yearMonth}`.

**9. Estudo Doutrinário (Msgs Sr. Allan)**
- O quê: Volume de mensagens trocadas com o Sr. Allan, em qualquer contexto.
- Fluxos cobertos:
  - Acesso direto via chat científico.
  - Acesso via integração nas aulas (Esclarecimento de Dúvidas).
- Coleção de log: `chat_logs`
- Campo discriminador no log: `chatType: "scientific"` — obrigatório em ambos os fluxos.
- Campos adicionais no log: `origin` (`"direct"` ou `"lesson"`), `lessonId` (opcional).
- Contador global: `global_stats/scientific_chat` → campos `totalCount` e `monthly.{yearMonth}`.

**10. Orações Lidas**
- O quê: Acessos a orações do catálogo.
- Coleção de log: `prayer_logs`
- Campos adicionais no log: `prayerId`, `prayerTitle`.
- Contador global: `global_stats/prayer` → campos `totalCount` e `monthly.{yearMonth}`.
- Ranking: `item_stats/prayer/items/{prayerId}` → `{ title, totalCount, monthly }`.

---

### E. Engajamento e Games

**11. Sintonia (Plays)**
- O quê: Uso do player de música ambiente e frequências.
- Coleção de log: `ambient_player_logs`
- Campos adicionais no log: `trackId`, `trackTitle`.
- Contador global: `global_stats/ambient_player` → campos `totalCount` e `monthly.{yearMonth}`.
- Atenção: Remover todo `increment()` manual do `statsService.ts` no Expo para este item. O log já existe — apenas a Cloud Function deve contabilizar.

**12. Desafio Diário**
- O quê: Participações no quiz de desafio diário (gamificação).
- Coleção de log: `challenge_logs`
- Campo discriminador no log: `quizType: "daily_challenge"` — impede sobreposição com `quiz_logs` do módulo Fixe.
- Campos adicionais no log: `challengeId`, `date` (data do desafio, formato `"YYYY-MM-DD"`).
- Contador global: `global_stats/daily_challenge` → campos `totalCount` e `monthly.{yearMonth}`.

**13. V ou F**
- O quê: Participações no jogo Verdadeiro ou Falso.
- Coleção de log: `truth_or_false_logs`
- Campos adicionais no log: `questionId`, `answer` (`"true"` ou `"false"`), `correct` (boolean).
- Contador global: `global_stats/truth_or_false` → campos `totalCount` e `monthly.{yearMonth}`.

---

## 4. Requisitos de Detalhamento

Para os indicadores com ranking (Reflexões, Meditações, Lições, Glossário, Orações), o sistema deve suportar:

- **Top 10 por item:** Ordenação por `totalCount` descendente em `item_stats/{module}/items`.
- **Filtro por mês/ano:** Leitura do campo `monthly.{yearMonth}` em `global_stats` e `item_stats`.

Para todos os indicadores (exceto Usuários Ativos):

- **Visão mensal:** O campo `monthly` em `global_stats` é um mapa `{ "2026-05": N, "2026-06": N, ... }` atualizado pela Cloud Function a cada novo log processado.

---

## 5. Plano de Reset (Dia 1)

O objetivo é zerar contagens incorretas e iniciar com dados auditáveis a partir do primeiro dia do mês seguinte.

1. Todos os campos em `global_stats/*` devem ser zerados manualmente ou via `syncAllStats` com janela de tempo `>= início do novo mês`.
2. Os campos `item_stats/*` de rankings também devem ser zerados.
3. A partir do dia 1, apenas logs com `createdAt >= início do novo mês` serão considerados.
4. A função `syncAllStats` pode ser executada a qualquer momento para reconstruir os totais a partir dos logs existentes dentro de uma janela de tempo definida.

---

*Documento de Especificação v2.0 — Revisado e corrigido em 16/05/2026*
