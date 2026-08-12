# Plano de Implementação — Push para Curso Abandonado (Saber Espírita)

Contexto: o app já inicializa OneSignal e sincroniza tags de preferências (ex.: `course_reminders`) no boot.
Referência: `/Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/App.tsx#L142-178`.

## Objetivo

Enviar push notification para usuários que:

- iniciaram um curso (fizeram 1+ aulas / progresso > 0),
- não concluíram (progresso < 100),
- ficaram inativos naquele curso por um período configurável,
- e aceitaram receber notificações de curso.

O foco é reduzir abandono e aumentar retorno ao estudo.

---

## Padrões e Restrições

- Evitar spam: aplicar janelas, estágios e cooldown.
- Respeitar preferência do usuário (opt-in/opt-out).
- Rodar como rotina agendada (Cloud Functions v2 Scheduler).
- Rastrear o que foi enviado (idempotência por curso/usuário/estágio).

---

## Definição de “Curso abandonado”

Um curso é candidato a abandono quando:

- existe `users/{uid}/courseProgress/{courseId}` (ou legado `users/{uid}/progress/{courseId}` se ainda existir),
- `completedLessons.length > 0`,
- `completionPercent < 100`,
- `lastAccessedAt < now - N dias`.

Observação: `completionPercent` não existe como campo no doc; deve ser calculado em runtime com base em:

- `completedLessons.length`
- total de aulas do curso (`global_stats/courses_metadata[courseId]`)

---

## Fonte de verdade da preferência do usuário

Hoje o app envia tag OneSignal:

- `course_reminders: "true" | "false"`

Tags por si só não impedem envio (a menos que o backend use filtro/segmentação baseada nelas). Para garantir respeito à preferência sem depender de OneSignal, criar também persistência no Firestore:

### Proposta de campo no perfil

`users/{uid}`:

```json
{
  "notificationPrefs": {
    "course_reminders": true
  }
}
```

### Ajuste necessário no mobile

Sempre que o usuário alterar a preferência (e também no boot), espelhar o valor em `users/{uid}.notificationPrefs.course_reminders`.

---

## Estratégia de envio (anti-spam)

Usar estágios com cooldown por curso:

- Estágio 1: 7 dias sem acessar o curso
- Estágio 2: 21 dias sem acessar o curso
- Estágio 3: 45 dias sem acessar o curso

Persistir controle por curso no próprio `courseProgress`:

`users/{uid}/courseProgress/{courseId}`:

```json
{
  "reminders": {
    "abandonedCourse": {
      "stage7dSentAt": "Timestamp | null",
      "stage21dSentAt": "Timestamp | null",
      "stage45dSentAt": "Timestamp | null",
      "lastSentAt": "Timestamp | null"
    }
  }
}
```

Regras:

- Não enviar se `lastSentAt` < 7 dias (cooldown geral).
- Enviar somente o próximo estágio não enviado e compatível com `lastAccessedAt`.

---

## Conteúdo do push

Título + mensagem + payload para deep link:

Sugestões:

- Stage 1:
  - Título: “Seu estudo está te esperando”
  - Msg: “Que tal retomar de onde parou? Um pequeno passo hoje já conta.”
- Stage 2:
  - Título: “Vamos continuar juntos?”
  - Msg: “Você avançou no curso. Retome a próxima aula quando puder.”
- Stage 3:
  - Título: “Uma semente precisa de constância”
  - Msg: “Volte ao curso e siga no seu ritmo. A comunidade está com você.”

Payload sugerido:

```json
{
  "type": "course_reminder",
  "courseId": "CURSO-XXX",
  "screen": "CourseCurriculum"
}
```

---

## Cloud Function (Scheduler)

Criar function agendada, por exemplo:

- `notifyAbandonedCourses`
- schedule: `every day 10:00` (America/Sao_Paulo) ou UTC (desde que consistente)

Fluxo:

1. Buscar `courses_metadata` para total de aulas por curso.
2. Query em `collectionGroup('courseProgress')` filtrando por `lastAccessedAt < cutoffStage7d` (reduz varredura).
3. Para cada doc:
   - obter `uid` via `doc.ref.parent.parent?.id`
   - ignorar guest (uid ausente ou `guest`)
   - calcular completionPercent
   - ignorar `completionPercent === 0` e `completionPercent >= 100`
   - checar `users/{uid}.notificationPrefs.course_reminders` (default true se ausente, ou default false — definir política)
   - checar marcadores de estágio no doc `reminders.abandonedCourse.*`
   - enviar push via `NotificationService.sendPushToUser(uid, title, msg, data)`
   - atualizar o doc `courseProgress` com `stageXdSentAt` e `lastSentAt`

Batching:

- Processar em lotes (ex.: 200 por execução) para evitar timeouts e rate limit.

Logs:

- Logar métricas de execução (quantos candidatos, quantos enviados, quantos ignorados por opt-out, etc.)

---

## Índices / Performance

A query principal sugere:

- `collectionGroup('courseProgress')` com `where('lastAccessedAt', '<', cutoff)` e `orderBy('lastAccessedAt')` + `limit`.
  Se o Firestore exigir índice composto, criar o índice indicado pelo erro do console.

---

## Testes (checklist)

- Usuário com progresso 1/8 e lastAccessedAt antigo → recebe stage 1.
- Usuário já notificado stage 1 e ainda inativo → recebe stage 2 após 21 dias.
- Usuário com progresso 0/8 → não recebe.
- Usuário com 100% → não recebe.
- Usuário com opt-out (`notificationPrefs.course_reminders=false`) → não recebe.
- Cooldown ativo → não recebe duplicado.
- Payload chega no app e abre a tela do curso (ajustar roteamento se necessário).

---

## Entregáveis

- Cloud Function `notifyAbandonedCourses` (Scheduler)
- Atualização do modelo `courseProgress` (campo `reminders.abandonedCourse`)
- Persistência de preferência no Firestore (`users/{uid}.notificationPrefs.course_reminders`)
- Ajuste no mobile para espelhar preferência no Firestore
- Ajuste no handler de push/deep link no mobile (se ainda não existir)
