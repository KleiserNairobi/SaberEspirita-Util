# Plano Unificado (v2) — Monitoramento Saber Espírita

_Versão 4.0 — Consolidação final dos docs 00, 01, 02 e 03_

---

## 0. Objetivo e Escopo

Este documento consolida e fecha decisões do sistema de monitoramento (Mobile Expo + Web Dashboard + Cloud Functions + Firestore), eliminando ambiguidades.

O que este plano garante:

- Um único fluxo de verdade para contagens: logs como fatos + back-end como processador.
- Idempotência por log e consistência via transação.
- Decrementos em exclusões de logs para evitar contadores “inflando” artificialmente.
- Reset/Rebuild auditável via `syncAllStats`.
- Estratégia de migração que evita monitoramento híbrido e dupla contagem.

---

## 1. Decisões Finais (Sem Ambiguidade)

1. **Fonte da Verdade**

- A fonte da verdade são os **logs** (`*_logs`) e os dados primários (`Auth`, `users`).
- `global_stats/*` e `item_stats/*` são **derivados**, sempre reconstruíveis.

2. **Sem increment no app**

- O app Expo nunca atualiza `global_stats` nem `item_stats`.
- O app apenas cria documentos em coleções `*_logs`.

3. **Idempotência**

- Idempotência é garantida por:
  - `processed` no log, gravado como `true` pela Cloud Function após contabilizar, dentro da mesma transação.
  - Logs são processados por triggers `onDocumentCreated` e revertidos por `onDocumentDeleted` (apenas se `processed === true` no snapshot deletado).

4. **Exclusões decrementam**

- Para todo KPI baseado em logs, existe trigger de delete que decrementa contadores correspondentes.

5. **Tempo e `yearMonth`**

- `yearMonth` usa **UTC** e formato `"YYYY-MM"`.
- `createdAt` deve ser `serverTimestamp()` no momento da criação do log.

6. **Reset / Rebuild (`syncAllStats`)**

- `syncAllStats` é a referência de auditoria: reconstrói **deterministicamente** `global_stats` e `item_stats` a partir dos logs numa janela `[from, to]`.
- `syncAllStats` **não depende** de `processed` para calcular totais (o log é o fato). `processed` é apenas mecanismo incremental das triggers.
- O “divisor de águas” é a execução do `syncAllStats` para o período escolhido como início do novo ciclo (Dia 1).

7. **Tratamento de erros**

- Logs com schema inválido não incrementam nada.
- A function registra `error` no próprio log e mantém `processed !== true`.

---

## 2. Modelo de Dados (Firestore)

### 2.1. Schema base de logs (`*_logs/{logId}`)

Todo log criado pelo app deve conter:

```json
{
  "userId": "string",
  "createdAt": "Timestamp (server)",
  "yearMonth": "string (UTC, YYYY-MM)",
  "processed": false
}
```

Regras adicionais:

- `processed` inicia como `false`.
- Campos específicos por módulo são obrigatórios conforme seção 3.

### 2.2. Agregados globais (`global_stats/{kpi}`)

Para KPIs baseados em logs:

```json
{
  "totalCount": 0,
  "monthly": {
    "2026-05": 0,
    "2026-06": 0
  }
}
```

Exceções:

- `global_stats/users` usa `totalCredentials` (ver seção 3.A).
- `Usuários Ativos` não tem `global_stats` (count query direta na coleção `users`).

### 2.3. Ranking por item (`item_stats/{module}/items/{itemId}`)

Apenas para módulos com ranking (Reflexões, Meditações Guiadas, Lições, Glossário, Orações):

```json
{
  "title": "string",
  "totalCount": 0,
  "monthly": {
    "2026-05": 0
  }
}
```

Campos extras por módulo:

- Lições: `{ title, courseId, totalCount, monthly }`
- Glossário: `{ term, totalCount, monthly }`
- Orações: `{ title, totalCount, monthly }`

---

## 3. KPIs (Definições Fechadas)

### A) Gestão de Usuários

**1. Credenciais (Cadastros Totais)**
- Fonte: Firebase Auth.
- Trigger: `auth.user().onCreate` e `auth.user().onDelete`.
- Documento: `global_stats/users` → `totalCredentials`.

**2. Usuários Ativos (Perfis Reais)**
- Fonte: Firestore.
- Leitura: count query em `collection('users')`.
- Não usa logs, não usa `global_stats`.

### B) Estude

**3. Aulas Concluídas (Conteúdo)**
- Coleção: `lesson_logs`.
- O quê: conclusão da aula como conteúdo (progresso/consumo). Não depende de quiz.
- Regra: o app cria o log quando o usuário finaliza a aula.
- Campos obrigatórios: `lessonId`, `lessonTitle`, `courseId`.
- Global: `global_stats/lessons`.
- Ranking: `item_stats/lessons/items/{lessonId}`.

**4. Quizzes de Aula (Exercícios)**
- Coleção: `quiz_logs`.
- Discriminador: `quizType: "lesson"`.
- O quê: tentativas/submissões de exercícios de aula (para medir prática de exercícios).
- Campos obrigatórios: `quizType`, `quizId`, `quizTitle`, `lessonId`, `lessonTitle`, `courseId`.
- Campos opcionais (recomendados): `score` (number), `passed` (boolean).
- Global: `global_stats/lesson_quizzes`.
- Ranking (por quiz): `item_stats/lesson_quizzes/items/{quizId}`.

**5. Glossário**
- Coleção: `glossary_logs`.
- O quê: acessos ao glossário (menu e atalhos em aula).
- Campos obrigatórios: `termId`, `termLabel`, `origin` (`"menu"` | `"lesson"`).
- Campo opcional: `lessonId` (quando `origin === "lesson"`).
- Global: `global_stats/glossary`.
- Ranking: `item_stats/glossary/items/{termId}`.

**6. Chat Científico (Sr. Allan)**
- Coleção: `scientific_chat_logs`.
- O quê: mensagens enviadas no chat científico, incluindo atalhos da aula e do glossário.
- Campos obrigatórios: `messageLength` (number), `origin` (`"direct"` | `"lesson"` | `"glossary"`).
- Campo opcional: `lessonId` (quando `origin === "lesson"`).
- Global: `global_stats/scientific_chat`.

**7. Certificados Emitidos (Cursos)**
- Coleção: `certificate_logs`.
- O quê: eventos de emissão de certificado para usuários.
- Regra: só existe para cursos que oferecem certificado; certificado não é obrigatório e depende da política do curso.
- Importante: `certificate_logs` é o log dedicado do monitoramento e é independente da coleção `certificates` (armazenamento/validação).
- Campos obrigatórios: `courseId`, `courseTitle`, `certificateId`.
- Global: `global_stats/certificates`.
- Ranking (por curso): `item_stats/certificates/items/{courseId}`.

### C) Fixe

**8. Quizzes Gerais**
- Coleção: `quiz_logs`.
- Discriminador: `quizType: "general"`.
- Campos obrigatórios: `quizType`, `quizId`, `quizTitle`.
- Global: `global_stats/quizzes`.

**9. Desafio Diário (Quiz)**
- Coleção: `challenge_logs`.
- Discriminador: `quizType: "daily_challenge"`.
- Campos obrigatórios: `quizType`, `challengeId`, `date` (`"YYYY-MM-DD"`).
- Global: `global_stats/daily_challenge`.

**10. Verdade ou Mentira (V ou F)**
- Coleção: `truth_or_false_logs`.
- Campos obrigatórios: `questionId`, `answer` (`"true"` | `"false"`), `correct` (boolean).
- Global: `global_stats/truth_or_false`.

### D) Medite

**11. Reflexões (Textos) — Lidas**
- Coleção: `meditation_logs`.
- Discriminador: `contentType: "reflection"`.
- Campos obrigatórios: `itemId`, `itemTitle`.
- Global: `global_stats/reflections`.
- Ranking: `item_stats/reflections/items/{itemId}`.

**12. Meditações Guiadas (Áudio) — Plays**
- Coleção: `meditation_logs`.
- Discriminador: `contentType: "guided_meditation"`.
- Campos obrigatórios: `itemId`, `itemTitle`.
- Global: `global_stats/guided_meditations`.
- Ranking: `item_stats/guided_meditations/items/{itemId}`.

**13. Chat Emocional (Guia)**
- Coleção: `emotional_chat_logs`.
- O quê: mensagens enviadas no chat emocional (usado em Medite e Ore).
- Campos obrigatórios: `messageLength` (number), `origin` (`"medite"` | `"ore"`).
- Global: `global_stats/emotional_chat`.

### E) Ore

**14. Orações Lidas**
- Coleção: `prayer_logs`.
- Campos obrigatórios: `prayerId`, `prayerTitle`.
- Global: `global_stats/prayer`.
- Ranking: `item_stats/prayer/items/{prayerId}`.

**15. Player (Sintonia) — Plays**
- Coleção: `ambient_player_logs`.
- Campos obrigatórios: `trackId`, `trackTitle`.
- Global: `global_stats/ambient_player`.
- Observação obrigatória: remover todo `increment()` manual do app para este KPI.

---

## 4. Cloud Functions (Implementação v2)

### 4.1. Princípios obrigatórios

- Toda atualização em `global_stats/*` e `item_stats/*` ocorre via `runTransaction`.
- Em triggers de create:
  - Se `processed === true`, retorna.
  - Valida campos obrigatórios.
  - Atualiza contadores.
  - Marca `processed: true` no log no mesmo commit.
- Em triggers de delete:
  - Lê dados do snapshot deletado.
  - Se `processed !== true`, retorna.
  - Decrementa os mesmos contadores do create equivalente.

### 4.2. Template base (create)

Padrão obrigatório (estrutura lógica):

1. Ler log.
2. Se `processed === true`, retornar.
3. Validar schema.
4. Transação:
   - `tx.set(global_stats/{kpi}, increments, { merge:true })`
   - se aplicável, `tx.set(item_stats/... , increments + title, { merge:true })`
   - `tx.update(logRef, { processed:true })`

### 4.3. Funções (mapa completo)

- Auth:
  - `onUserCreated` (incrementa `global_stats/users.totalCredentials`)
  - `onUserDeleted` (decrementa `global_stats/users.totalCredentials`)
- Logs com create + delete:
  - `onMeditationLogCreated` / `onMeditationLogDeleted`
  - `onLessonLogCreated` / `onLessonLogDeleted`
  - `onGlossaryLogCreated` / `onGlossaryLogDeleted`
  - `onPrayerLogCreated` / `onPrayerLogDeleted`
  - `onAmbientPlayerLogCreated` / `onAmbientPlayerLogDeleted`
  - `onQuizLogCreated` / `onQuizLogDeleted`
  - `onChallengeLogCreated` / `onChallengeLogDeleted`
  - `onEmotionalChatLogCreated` / `onEmotionalChatLogDeleted`
  - `onScientificChatLogCreated` / `onScientificChatLogDeleted`
  - `onCertificateLogCreated` / `onCertificateLogDeleted`
  - `onTruthOrFalseLogCreated` / `onTruthOrFalseLogDeleted`

Regra: se um KPI é log-based, ele tem delete handler correspondente.

### 4.4. Erros de schema (contrato)

Quando faltar discriminador ou campo obrigatório:

- Create handler:
  - não incrementa nada
  - grava `error` no log (ex.: `missing_required_fields`, `missing_discriminator`, `invalid_discriminator_value`)
  - mantém `processed !== true`

---

## 5. `syncAllStats` (Função de Manutenção) — Contrato Fechado

### 5.1. Objetivo

Reconstruir `global_stats/*` e `item_stats/*` a partir dos logs existentes dentro de uma janela `[from, to]`.

### 5.2. Entrada

- `from`: Timestamp
- `to`: Timestamp

Regras:

- Janela fechada: só considera logs com `createdAt >= from` e `createdAt <= to`.
- `from` e `to` devem ser interpretados em UTC para coerência do `yearMonth`.

### 5.3. Saída (efeito)

- Zera e reescreve os agregados de todos os KPIs log-based para refletirem exatamente os logs no intervalo.
- Reconstrói rankings (`item_stats/*`) para módulos aplicáveis.
- Não altera fontes primárias:
  - `Usuários Ativos`: permanece via count query.
  - `Credenciais`: permanece via Auth (pode ter sync separado se desejado).

### 5.4. Relação com `processed`

- `syncAllStats` ignora `processed` como filtro de verdade.
- `processed` permanece como mecanismo incremental para operação diária.
- Se for necessário reconciliação de `processed`, isso deve ser uma rotina separada (fora do escopo do v2).

### 5.5. Segurança

- HTTP endpoint protegido (service-to-service), não público.

---

## 6. Responsabilidades do App (Expo)

Obrigatório:

- Criar logs com `processed: false`.
- `createdAt` como `serverTimestamp()`.
- `yearMonth` em UTC `"YYYY-MM"` no momento do log.

Obrigatório por fluxo:

- `meditation_logs`: sempre incluir `contentType` + `itemId` + `itemTitle`.
- `emotional_chat_logs`: sempre incluir `messageLength` + `origin` (`"medite"` | `"ore"`).
- `scientific_chat_logs`: sempre incluir `messageLength` + `origin` (`"direct"` | `"lesson"` | `"glossary"`) (+ `lessonId` quando aplicável).
- `lesson_logs`: sempre incluir `lessonId` + `lessonTitle` + `courseId`.
- `quiz_logs`: sempre incluir `quizType` e os campos do tipo:
  - `quizType: "lesson"`: `quizId`, `quizTitle`, `lessonId`, `lessonTitle`, `courseId`.
  - `quizType: "general"`: `quizId`, `quizTitle`.
- `challenge_logs`: sempre incluir `quizType: "daily_challenge"` + `challengeId` + `date`.
- `truth_or_false_logs`: sempre incluir `questionId` + `answer` + `correct`.
- `certificate_logs`: sempre incluir `courseId`, `courseTitle`, `certificateId`.

Proibido:

- Qualquer escrita em `global_stats/*` e `item_stats/*`.
- Qualquer `increment()` no app (especialmente no fluxo de `ambient_player`).

---

## 7. Responsabilidades do Web (Dashboard)

- KPIs log-based:
  - Ler `global_stats/{kpi}.totalCount`.
  - Para visão mensal, ler `global_stats/{kpi}.monthly.{yearMonth}`.
- Ranking (quando aplicável):
  - Ler `item_stats/{module}/items/*` ordenando por `totalCount desc` e limitar Top 10.
- Usuários Ativos:
  - Count query direta em `users` (não usar `global_stats`).

---

## 8. Segurança (Firestore Rules) — Requisitos

- Logs (`*_logs`):
  - Cliente pode criar apenas com `request.auth.uid == userId`.
  - Cliente não pode gravar `processed: true`.
  - Cliente não pode atualizar logs após criação (create-only), exceto se adotado um modelo de retry controlado (decisão do projeto). Padrão recomendado: create-only.
- Agregados (`global_stats/*` e `item_stats/*`):
  - Nenhuma escrita pelo cliente.
  - Escrita apenas por Admin SDK (Cloud Functions).

---

## 9. Migração (Playbook v2)

Objetivo: sair do híbrido e iniciar ciclo auditável.

### Etapa 1 — Deploy das Cloud Functions v2

- Subir todas as functions v2.
- Garantir que as functions v1 não permaneçam ativas causando dupla contagem.
- Estratégia recomendada para coexistência segura: desativar v1 imediatamente após o deploy v2 (sem excluir ainda).

### Etapa 2 — App sem incrementos

- Remover todos os `increment()` do app.
- Garantir que todos os fluxos criam logs com schema completo.
- Publicar versão do app.

### Etapa 3 — `syncAllStats` (marco de transição)

- Rodar `syncAllStats` com:
  - `from = início do período escolhido como “Dia 1”`
  - `to = momento da execução`
- A partir daqui, os números do painel são considerados auditáveis.

### Etapa 4 — Validação (janela variável)

Validar por um intervalo definido por evidência:

- Contadores crescem sem duplicidade.
- Não há volume relevante de logs com `error`.
- Não há divergência entre amostras de logs e `monthly`.

### Etapa 5 — Remoção definitiva da v1

- Excluir functions antigas apenas após estabilidade confirmada.
- Manter v2 + `syncAllStats`.

---

## 10. Critérios Objetivos de Validação (Checklist)

- Sintonia:
  - `global_stats/ambient_player.totalCount` cresce apenas quando existe novo documento em `ambient_player_logs`.
  - Não há crescimento duplo por uma única ação do usuário.
- Chats:
  - `emotional_chat_logs` e `scientific_chat_logs` crescem conforme envio de mensagens.
  - `global_stats/emotional_chat` e `global_stats/scientific_chat` refletem amostra de logs do período.
- Desafio Diário:
  - `global_stats/daily_challenge.totalCount` cresce apenas quando existe novo documento em `challenge_logs`.
- V ou F:
  - `global_stats/truth_or_false.totalCount` cresce apenas quando existe novo documento em `truth_or_false_logs`.
- Medite:
  - `contentType` sempre presente e válido em `meditation_logs`.
  - `global_stats/reflections` e `global_stats/guided_meditations` batem com amostras.
  - `global_stats/emotional_chat.totalCount` cresce quando existem novos documentos em `emotional_chat_logs` com `origin: "medite"`.
- Glossário:
  - `origin` sempre presente e válido.
  - Rankings em `item_stats/glossary` populam corretamente.
- Lições:
  - `lesson_logs` apenas em conclusão real.
  - `global_stats/lessons` e ranking batem com logs.
- Erros:
  - Percentual de logs com `error` é monitorado e corrigido por release do app.

---

_Documento 04 — Plano Unificado v4.0 — 18/05/2026_
