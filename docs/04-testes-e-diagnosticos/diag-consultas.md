# Análise de Consultas — Módulo de Cursos (Tela Estude)

> **Contexto:** Em 21/07/2026 o Firestore ultrapassou 109 mil leituras (cota gratuita: 50 mil/dia),
> gerando cobrança. Com menos de 100 DAU, o volume é tecnicamente inaceitável.
> Este documento mapeia **todas** as consultas Firestore — diretas ou indiretas — envolvidas
> com cursos na tela Estude do projeto `SaberEspirita-Expo`, avaliando cache e propondo ações.

---

## Índice

1. [Mapa de Telas e Hooks](#1-mapa-de-telas-e-hooks)
2. [Consultas da Tela Principal (StudyScreen)](#2-consultas-da-tela-principal-studyscreen)
3. [Consultas da Tela CourseDetails](#3-consultas-da-tela-coursedetails)
4. [Consultas da Tela CoursesCatalog](#4-consultas-da-tela-coursescatalog)
5. [Consultas da Tela CourseCurriculum](#5-consultas-da-tela-coursecurriculum)
6. [Consultas da Tela LessonPlayer](#6-consultas-da-tela-lessonplayer)
7. [Consultas da Tela LessonForum](#7-consultas-da-tela-lessonforum)
8. [Consultas da Tela CourseCertificate](#8-consultas-da-tela-coursecertificate)
9. [Problemas Críticos Identificados](#9-problemas-críticos-identificados)
10. [Plano de Ação Prioritário](#10-plano-de-ação-prioritário)

---

## 1. Mapa de Telas e Hooks

\`\`\`
StudyScreen
 ├── useFeaturedCourses          → courseService.getFeaturedCourses()
 ├── useAllCoursesProgress       → Firestore direto (collection courseProgress)
 ├── useLastAccessedCourse       → Firestore direto + courseService + lessonService
 ├── useCommunityProgress        → forumService.getCommunityProgress()
 └── useHasUnreadNotifications   → (fora do escopo de cursos)

CourseDetails
 ├── useCourse                   → courseService.getCourseById()
 ├── useCourseProgress           → Firestore direto (doc courseProgress/courseId)
 └── useLessons                  → lessonService.getLessonsByCourseId()

CoursesCatalog
 ├── useCourses                  → courseService.getCourses()
 └── useAllCoursesProgress       → (mesmo de StudyScreen)

CourseCurriculum
 ├── useCourse                   → courseService.getCourseById()
 ├── useLessons                  → lessonService.getLessonsByCourseId()
 ├── useCourseProgress           → Firestore direto (doc courseProgress/courseId)
 └── useCourseExercises          → exerciseService.getExercisesByCourseId()

LessonPlayer
 ├── useLesson                   → lessonService.getLessonById()
 ├── useLessons                  → lessonService.getLessonsByCourseId() [prefetch]
 ├── useCourseProgress           → Firestore direto (doc courseProgress/courseId)
 ├── useExercises                → exerciseService.getExercisesByLessonId()
 ├── useForumHasNewComments      → forumService.hasNewForumComments() [2 leituras/chamada]
 └── useTouchCourseAccess        → progressService (write com throttle 15 min)

LessonForum
 ├── useLesson                   → lessonService.getLessonById()
 ├── useCommunityProgress        → forumService.getCommunityProgress()
 ├── useLessonForumComments      → forumService.getForumCommentsPage() + N reações [N+1!]
 ├── useForumHasNewComments      → (indiretamente via navegação)
 └── useTouchCourseAccess        → (write)

CourseCertificate
 ├── useCourse                   → courseService.getCourseById()
 └── useCourseProgress           → Firestore direto (doc courseProgress/courseId)
\`\`\`

---

## 2. Consultas da Tela Principal (StudyScreen)

### 2.1 `useFeaturedCourses` — Hook: `useCourses.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useCourses.ts` |
| **Serviço** | `courseService.getFeaturedCourses()` |
| **Coleção** | `courses` (where featured==true, limit 5) |
| **Leituras por chamada** | 1–5 documentos |
| **staleTime atual** | 24 horas |
| **gcTime atual** | 7 dias |
| **refetchOnMount** | `false` ✅ |
| **Estratégia de cache no serviço** | Cache-First (`getDocsFromCache` → fallback servidor) |

**Avaliação:** ✅ Bem configurado. Dificilmente contribui para o pico.  
**Ação necessária:** Nenhuma no momento.

---

### 2.2 `useAllCoursesProgress` — Hook: `useAllCoursesProgress.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useAllCoursesProgress.ts` |
| **Coleção** | `users/{uid}/courseProgress` (collection completa) |
| **Leituras por chamada** | 1 leitura por curso iniciado pelo usuário |
| **staleTime atual** | 24 horas |
| **gcTime atual** | 7 dias |
| **refetchOnMount** | `false` ✅ |
| **Estratégia de cache no hook** | Cache-First (`getDocsFromCache` → fallback servidor) |

**Avaliação:** ⚠️ Consulta feita **tanto na StudyScreen quanto na CoursesCatalog** — são dois pontos de montagem distintos. Se o cache Firestore não retornar resultado (ex: primeira sessão ou cache limpo), **ambas as telas disparam leitura no servidor**.  
**Ação necessária:** Verificar se a invalidação de cache (`invalidateQueries`) não está sendo chamada desnecessariamente em outros pontos. Ver seção 9.

---

### 2.3 `useLastAccessedCourse` — Hook: `useLastAccessedCourse.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useLastAccessedCourse.ts` |
| **Coleção** | `users/{uid}/courseProgress` (query ordenada, limit 1) + `courses/{id}` + `courses/{id}/lessons/{id}` |
| **Leituras por chamada** | **3–4 leituras** por execução (progresso + curso + aula) |
| **staleTime atual** | 24 horas |
| **gcTime atual** | 7 dias |
| **refetchOnMount** | `false` ✅ |
| **Estratégia de cache no hook** | Cache-First para progresso; delega ao `getCourseById` e `getLessonById` (também Cache-First) |

**Avaliação:** ⚠️ **ATENÇÃO — dependência encadeada de 3 leituras.** Quando o cache Firestore está frio (app reiniciado sem dados persistidos), executa:
1. `getDocsFromServer` na subcoleção `courseProgress`
2. `getCourseById` → pode gerar 1 leitura adicional (doc + fallback por campo `id`)
3. `getLessonById` **ou** `getLessonsByCourseId` → mais 1 leitura

**Ação necessária:** Ver seção 9 — candidata à desnormalização (salvar `courseTitle` + `lessonTitle` diretamente no documento de progresso).

---

### 2.4 `useCommunityProgress` — Hook: `useLessonForum.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useLessonForum.ts` |
| **Coleção** | `community_progress/{uid}` |
| **Leituras por chamada** | 1 documento |
| **staleTime atual** | **Indefinido (não configurado!)** ❌ |
| **gcTime atual** | Indefinido (padrão React Query: 5 min) |
| **refetchOnMount** | `"always"` ❌ **CRÍTICO** |

**Avaliação:** 🔴 **PROBLEMA GRAVE.** `refetchOnMount: "always"` força um refetch no servidor **toda vez que a tela monta**, incluindo navegação de volta da tela de fórum ou qualquer remount. Sem `staleTime`, o React Query considera o dado sempre stale e busca novamente.

Este hook é usado em **2 lugares**: `StudyScreen` e `LessonForumScreen`. Cada vez que o usuário abre a tela Estude após sair do fórum, gera 2 leituras desnecessárias.

**Ação necessária:** 🔴 **Urgente.** Adicionar `staleTime: 1000 * 60 * 30` (30 min) e mudar `refetchOnMount` para `false`.

---

## 3. Consultas da Tela CourseDetails

### 3.1 `useCourse` — Hook: `useCourses.ts`

| Atributo | Valor |
|---|---|
| **Coleção** | `courses/{courseId}` |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First no serviço ✅ |

**Avaliação:** ✅ OK.

---

### 3.2 `useCourseProgress` — Hook: `useCourseProgress.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useCourseProgress.ts` |
| **Coleção** | `users/{uid}/courseProgress/{courseId}` |
| **Leituras por chamada** | 1 documento |
| **staleTime atual** | 24 horas |
| **gcTime atual** | **Não configurado** (padrão 5 min) ⚠️ |
| **refetchOnMount** | **Não configurado** (padrão `true`) ⚠️ |
| **Estratégia** | `getDoc` puro — **sem Cache-First** ❌ |

**Avaliação:** 🟠 **PROBLEMA.** Ausência de `refetchOnMount: false` e `gcTime` baixo fazem com que este hook busque do servidor ao montar cada tela que o usa. Este hook é montado em **4 telas**: `CourseDetails`, `CourseCurriculum`, `LessonPlayer` e `CourseCertificate`. Se o usuário navega pelo fluxo completo (Detalhes → Currículo → Player → Certificado), ocorrem **4 leituras do mesmo documento**.

Agravante: o serviço usa `getDoc` padrão (não `getDocFromCache` + fallback), ignorando o cache offline do Firestore.

**Ação necessária:** 🟠 **Alta prioridade.**
1. Adicionar `refetchOnMount: false` e `gcTime: 1000 * 60 * 60 * 24 * 7`
2. Substituir `getDoc` por estratégia Cache-First: `getDocFromCache` → fallback `getDocFromServer`

---

### 3.3 `useLessons` — Hook: `useLessons.ts`

| Atributo | Valor |
|---|---|
| **Coleção** | `courses/{courseId}/lessons` |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First ✅ |
| **refetchOnMount** | `false` ✅ |

**Avaliação:** ✅ OK. Porém é chamada redundantemente em `CourseDetails` E `CourseCurriculum` para o mesmo `courseId`. Como a queryKey é a mesma, o React Query deduplicará — OK.

---

## 4. Consultas da Tela CoursesCatalog

### 4.1 `useCourses` — Hook: `useCourses.ts`

| Atributo | Valor |
|---|---|
| **Coleção** | `courses` (orderBy title, limit 50) |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First ✅ |

**Avaliação:** ✅ OK.

---

### 4.2 `useAllCoursesProgress` (reutilizado)

Mesma análise do item 2.2. A tela CoursesCatalog também monta este hook. Se as duas telas (StudyScreen + CoursesCatalog) estiverem em abas simultâneas, o React Query deduplicará a chamada por ter a mesma queryKey — OK. Porém se o cache já tiver expirado, ambas dispararão.

---

## 5. Consultas da Tela CourseCurriculum

### 5.1 `useCourse`, `useLessons`, `useCourseProgress`

Ver análises 3.1, 3.3 e 3.2 respectivamente. O ponto crítico é o `useCourseProgress` sem Cache-First.

---

### 5.2 `useCourseExercises` — Hook: `useExercises.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useExercises.ts` |
| **Coleção** | `exercises` (where courseId==X) |
| **Leituras por chamada** | N documentos (todos exercícios do curso) |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First ✅ |
| **refetchOnMount** | `false` ✅ |

**Avaliação:** ✅ OK. Cache-First bem implementado.

---

## 6. Consultas da Tela LessonPlayer

### 6.1 `useLesson` — Hook: `useLessons.ts`

| Atributo | Valor |
|---|---|
| **Coleção** | `courses/{courseId}/lessons/{lessonId}` |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First ✅ |

**Avaliação:** ✅ OK.

---

### 6.2 `useLessons` (prefetch da próxima aula)

O `LessonPlayer` carrega `useLessons(courseId)` para descobrir a próxima aula. Como já foi carregado no `CourseCurriculum`, o React Query usa o cache — **sem leitura adicional**.  
**Avaliação:** ✅ OK por deduplicação.

---

### 6.3 `useCourseProgress` (reutilizado)

Ver 3.2 — mesmo problema.

---

### 6.4 `useExercises` (por lessonId) — Hook: `useExercises.ts`

| Atributo | Valor |
|---|---|
| **Coleção** | `exercises` (where lessonId==X) |
| **staleTime atual** | 24 horas |
| **Estratégia** | Cache-First ✅ |

**Avaliação:** ✅ OK.

---

### 6.5 `useForumHasNewComments` — Hook: `useLessonForum.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useLessonForum.ts` |
| **Coleção** | `users/{uid}/forumLastSeen/{lessonId}` + `lesson_forums/{lessonId}/comments` (limit 1) |
| **Leituras por chamada** | **2 leituras** (lastSeen doc + query de comentários) |
| **staleTime atual** | 1 minuto ❌ |
| **gcTime atual** | Indefinido |
| **refetchOnMount** | `true` ❌ |

**Avaliação:** 🔴 **PROBLEMA GRAVE.** Este hook executa 2 leituras no Firestore com `staleTime` de apenas 1 minuto. O `LessonPlayer` monta este hook para cada aula aberta. Se um usuário navegar entre 10 aulas em uma sessão, isso pode gerar até **20 leituras** por sessão apenas neste hook. Com 85 DAU, pode gerar ~1.700 leituras/dia só desta query.

**Ação necessária:** 🔴 **Urgente.**
1. Aumentar `staleTime` para 5–10 minutos: `staleTime: 1000 * 60 * 10`
2. Adicionar `refetchOnMount: false`
3. **Longo prazo:** Considerar consolidar a informação de "tem comentários novos" no documento de progresso da aula para eliminar uma das 2 leituras.

---

### 6.6 `useTouchCourseAccess` (write com throttle)

| Atributo | Valor |
|---|---|
| **Operação** | Write (`updateDoc` / `setDoc`) |
| **Throttle** | 15 minutos por chave `userId_courseId_lessonId` |

**Avaliação:** ✅ Throttle correto. **Porém:** o throttle é **em memória** (Map) e é zerado a cada reinício do app. Se o usuário fechar e reabrir o app dentro de 15 minutos, o throttle não funciona e uma nova escrita é disparada.  
**Ação necessária:** 🟡 Baixa prioridade agora. Avaliar persistir o timestamp no AsyncStorage.

---

## 7. Consultas da Tela LessonForum

### 7.1 `useLesson` (reutilizado)

Ver 6.1 — OK.

---

### 7.2 `useCommunityProgress` (reutilizado)

Ver 2.4 — **mesmo problema crítico de `refetchOnMount: "always"`**.

---

### 7.3 `useLessonForumComments` — Hook: `useLessonForum.ts`

| Atributo | Valor |
|---|---|
| **Arquivo** | `src/hooks/queries/useLessonForum.ts` |
| **Coleção** | `lesson_forums/{lessonId}/comments` + `lesson_forums/{lessonId}/comments/{id}/reactions/{uid}` |
| **Leituras por chamada** | **N + N_comments leituras** (1 query + 1 por comentário para buscar minha reação) |
| **staleTime atual** | 2 minutos ⚠️ |
| **refetchOnMount** | `true` ⚠️ |

**Avaliação:** 🔴 **PROBLEMA GRAVE — N+1 Reads.** A função `getForumCommentsPage` carrega uma página de N comentários e, para cada um, faz um `getDoc` individual para buscar a reação do usuário atual. Com 20 comentários por página, isso resulta em **21 leituras por paginação**. A staleTime de 2 minutos com `refetchOnMount: true` significa que cada vez que o usuário entra no fórum, 21 leituras são disparadas.

O próprio código possui comentário revelador: `// 2 minutos — mitiga N+1 reads enquanto desnormalização não é implementada`.

**Ação necessária:** 🔴 **Urgente — esta é provavelmente a maior fonte de leituras.**
1. **Curto prazo:** Aumentar `staleTime` para no mínimo 10 minutos e `refetchOnMount: false`
2. **Médio prazo (obrigatório):** Desnormalizar — salvar a reação do usuário **dentro do documento de comentário** como subcampo `reactions.{userId}` ou usar Cloud Function para manter `myReaction` atualizado. Elimina completamente os N `getDoc` de reações.

---

### 7.4 Mutations do Fórum

`useSetForumLastSeen`, `useCreateForumComment`, `useSoftDeleteForumComment`, `useSetForumReaction`, `useRemoveForumReaction` são writes. Não geram leituras extras além das invalidações de cache pós-mutation, que estão corretas (invalidam apenas as queries necessárias).

**Avaliação:** ✅ OK — mutations bem controladas.

---

## 8. Consultas da Tela CourseCertificate

### 8.1 `useCourse` e `useCourseProgress`

Ver 3.1 e 3.2. Mesmos dados, já em cache se o usuário veio pelo fluxo normal.  
**Avaliação:** ✅ OK por cache (se gcTime não tiver expirado).

---

## 9. Problemas Críticos Identificados

### 🔴 Crítico 1 — N+1 Reads no Fórum (`getForumCommentsPage`)

**Impacto estimado:** 21 leituras por acesso ao fórum × N usuários × refetch a cada 2 min.  
**Arquivo:** `src/services/firebase/forumService.ts` (L236–L249)  
**Solução:** Desnormalizar `myReaction` no documento do comentário ou usar subcoleção de reações com campo `userId` indexado.

---

### 🔴 Crítico 2 — `useCommunityProgress` com `refetchOnMount: "always"`

**Impacto estimado:** 1 leitura por montagem de `StudyScreen` ou `LessonForumScreen` sem cache.  
**Arquivo:** `src/hooks/queries/useLessonForum.ts` (L42)  
**Solução:** `refetchOnMount: false`, `staleTime: 1000 * 60 * 30`.

---

### 🔴 Crítico 3 — `useForumHasNewComments` com staleTime de 1 minuto (2 leituras/chamada)

**Impacto estimado:** 2 leituras × N aulas visitadas por sessão × 85 DAU.  
**Arquivo:** `src/hooks/queries/useLessonForum.ts` (L59)  
**Solução:** `staleTime: 1000 * 60 * 10`, `refetchOnMount: false`.

---

### 🟠 Alto 4 — `useCourseProgress` sem Cache-First e sem `refetchOnMount: false`

**Impacto estimado:** 1 leitura adicional por tela montada (4 telas no fluxo). 4 leituras/sessão/usuário.  
**Arquivo:** `src/hooks/queries/useCourseProgress.ts` (L19–L42)  
**Solução:** Adicionar `refetchOnMount: false`, `gcTime`, e implementar `getDocFromCache` + fallback no serviço.

---

### 🟠 Alto 5 — `useLastAccessedCourse` com 3–4 leituras encadeadas

**Impacto estimado:** 3–4 leituras no cold start por usuário ativo.  
**Arquivo:** `src/hooks/queries/useLastAccessedCourse.ts`  
**Solução:** Desnormalizar `courseTitle`, `courseImageUrl`, `lessonTitle` no documento de progresso para eliminar as leituras secundárias de `courses/{id}` e `lessons/{id}`.

---

## 10. Plano de Ação Prioritário

### ~~Fase 1 — Correções imediatas (1–2 horas de trabalho)~~ [CONCLUÍDO em 22/07/2026]

| # | Ação | Arquivo | Impacto | Status |
|---|---|---|---|---|
| 1 | ~~`useCommunityProgress`: `refetchOnMount: false`, `staleTime: 30min`~~ | `useLessonForum.ts` | 🔴 Alto | ✅ Concluído |
| 2 | ~~`useForumHasNewComments`: `staleTime: 10min`, `refetchOnMount: false`~~ | `useLessonForum.ts` | 🔴 Alto | ✅ Concluído |
| 3 | ~~`useLessonForumComments`: `staleTime: 10min`, `refetchOnMount: false`~~ | `useLessonForum.ts` | 🔴 Alto | ✅ Concluído |
| 4 | ~~`useCourseProgress`: `refetchOnMount: false`, `gcTime: 7 dias`~~ | `useCourseProgress.ts` | 🟠 Médio | ✅ Concluído |
| 5 | ~~`useCourseProgress` serviço: implementar `getDocFromCache` + fallback~~ | `useCourseProgress.ts` | 🟠 Médio | ✅ Concluído |

### Fase 2 — Desnormalização (1–2 dias de trabalho) [PENDENTE]

| # | Ação | Impacto | Status |
|---|---|---|---|
| 6 | ~~Eliminar N+1 de reações: salvar `myReactions` no doc do comentário via Cloud Function~~ | 🔴 Crítico | ✅ Concluído |
| 7 | ~~Desnormalizar `courseTitle`+`lessonTitle` no doc de progresso (elimina 2 leituras em `useLastAccessedCourse`)~~ | 🟠 Médio | ✅ Concluído |

### Estimativa de Redução

- **Fase 1:** redução estimada de **40–60%** nas leituras diárias (implementada).
- **Fase 2:** redução adicional estimada de **20–30%** (especialmente para usuários ativos no fórum).

---

> **Nota:** As consultas de outros módulos (meditação, orações, notificações, glossário) não foram incluídas
> neste documento por estarem fora do escopo da tela Estude e do módulo de cursos. Devem ser objeto
> de análise separada se os números persistirem após estas correções.

---

## 11. Cruzamento com Dados Reais do Firestore Console (21/07/2026)

> Print das consultas mais custosas extraído do painel do Firestore no dia do estouro.
> Os números abaixo confirmam, ampliam ou corrigem a análise anterior.

### 11.1 Consultas confirmadas e seus números reais

| Consulta | Execuções | Ops Leitura | Docs Verificados | Índices Lidas | Retornados |
|---|---|---|---|---|---|
| `COLLECTION /courses/*/less...` | **12** | 0 | 0 | **16.083** | 1 |
| `COLLECTION /users/*/course...` | **18** | 44 | 2.444 | 2.444 | 2.444 |
| `COLLECTION_GROUP coursePro...` | 1 | **200** | 200 | 201 | 200 |
| `COLLECTION /exercises SELE...` | 1 | **199** | 199 | 199 | 199 |
| `COLLECTION /active_days SE...` | 1 | **301** | 301 | 301 | 300 |
| `COLLECTION * SELECT __coll...` | 1 | **107** | 107 | 107 | 56 |
| `COLLECTION /courses SELECT...` | 1 | 23 | 23 | 23 | 12 |
| `COLLECTION /courses/*/less...` | 3 | 0 | 0 | 0 | 0 (cache) |
| `COLLECTION /courses/*/less...` | 1 | 7 | 7 | 7 | 7 |

---

### 11.2 Descoberta crítica NÃO prevista na análise: `COLLECTION_GROUP courseProgress`

**🔴 ALERTA MÁXIMO.** O print revela uma consulta `COLLECTION_GROUP courseProgress` com **200 operações de leitura e 200 documentos retornados**, ou seja, lê o progresso de **todos os usuários do sistema** em uma única varredura.

Rastreando a origem no código:

- **`getTopCoursesData.ts` (Cloud Function callable)** — linha 91: `db.collectionGroup('courseProgress').get()` **sem nenhum filtro** — varre 100% dos documentos de progresso de todos os usuários.
- **`syncTopCoursesStatsDaily.ts` (Cloud Function agendada às 02h)** — linha 82: mesma varredura total sem filtro.
- **`getCourseManagementData.ts` (Cloud Function callable)** — linha 67: usa `collectionGroup('courseProgress').where('courseId', '==', courseId).limit(100)` — filtrado, porém chamado pelo painel web ao visualizar um curso.

**O print mostra 1 execução com 200 leituras.** Isso é consistente com a Cloud Function `syncTopCoursesStatsDaily` rodando às 02h (atualização diária do ranking) OU com alguém acessando o painel web (`getTopCoursesData` como fallback quando `global_stats/top_courses` não existe ou está desatualizado).

> **Atenção:** A Cloud Function `getTopCoursesData` possui lógica de fallback: se o documento `global_stats/top_courses` existir e for válido, retorna sem fazer o `collectionGroup`. **Porém**, se esse documento estiver ausente ou inválido (logo após deploy, por exemplo), ela faz a varredura completa. O risco é real sempre que o painel web for aberto e o cache não estiver quente.

---

### 11.3 Descoberta crítica: `/courses/*/lessons` com 16.083 entradas de índice (12 execuções)

**Auditoria e Status [RESOLVIDO em 22/07/2026]:**
1. **Estrutura de Consulta:** A query executada no app Expo é em subcoleção de documento único (`courses/{courseId}/lessons` ordenando por `order ASC`). No Firestore, consultas de escopo de subcoleção individual que ordenam por um único campo são atendidas pelo indexador de campo automático padrão, **sem exigir a criação de índices compostos explícitos**.
2. **Custo Financeiro:** O print do console confirmou que o custo financeiro cobrado foi **0 operações de leitura**, vindo direto do cache local dos usuários.
3. **Segurança:** O arquivo local [firestore.indexes.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/firestore.indexes.json) foi verificado e não necessita de novos índices compostos para essa query, visto que ela já opera de forma otimizada.

---

### 11.4 Descoberta: `/users/*/courseProgress` com 18 execuções e 2.444 documentos

A subcoleção `users/*/courseProgress` é consultada **18 vezes**, retornando 2.444 documentos no total (média ~136 por execução). Isso é incompatível com um único usuário — um usuário típico tem no máximo 10 cursos em progresso.

Possíveis causas:
1. O hook `useAllCoursesProgress` ou `useLastAccessedCourse` sendo chamado mais vezes que o esperado (remounts ou invalidações desnecessárias).
2. Alguma Cloud Function que escaneia subcoleções de múltiplos usuários (diferente da query de `collectionGroup` já identificada).
3. O hook `useCourseProgress` (por curso) sendo chamado repetidamente sem cache — confirmando o problema 🟠 Alto 4 da análise.

Com 85 DAU e 18 execuções de leitura de courseProgress, a média é ~0,21 execuções/usuário/dia, mas cada execução lê ~136 documentos — sugerindo que algumas execuções estão varrendo dados de múltiplos usuários (provavelmente as chamadas das Cloud Functions admin-side).

---

### 11.5 Descoberta: `/exercises SELECT...` com 199 documentos

**Auditoria e Status [RESOLVIDO em 22/07/2026]:**
1. **Resultado da Auditoria no Banco:** Criamos e executamos a Cloud Function temporária `tempListExercises` em produção para analisar a coleção `exercises`. A varredura constatou que **não existem dados duplicados** ou registros órfãos por título na mesma lição.
2. **Motivo do Volume:** O volume de 199 exercícios é legítimo e pertence à grade curricular estendida do curso do *Evangelho Segundo o Espiritismo* (que possui muitas lições, cada uma contendo apenas 1 exercício quiz legítimo associado).
3. **Mitigação no App:** O custo é controlado porque o hook no frontend do Expo usa estratégia *Cache-First* (`getDocsFromCache` com fallback de servidor) e tem `staleTime: 24h` com `refetchOnMount: false`. O dado é carregado da rede apenas 1 vez ao dia e depois servido do cache local a custo zero.

---

### 11.6 Descoberta: `COLLECTION /active_days` com 301 leituras

A coleção `active_days` executa **301 operações de leitura**, retornando 300 documentos. Esta coleção **não está no escopo do módulo de cursos**, mas é a **maior fonte individual de leituras cobradas** no print. Merece análise separada urgente.

---

### 11.7 Descoberta: `COLLECTION * SELECT __coll...` com 107 leituras

Esta consulta genérica (`SELECT __collection_path`) com 107 docs verificados e apenas 56 retornados é típica de **consultas de collection group sem filtro** ou de operações administrativas do console do Firebase. Pode ser oriunda da tela `ForumModeration.tsx` (usa `collectionGroup(db, 'comments')`).

---

### 11.8 Resumo: análise original vs. dados reais

| Item da Análise Original | Status após print |
|---|---|
| 🔴 Crítico 1 — N+1 Reads no Fórum | **Não aparece diretamente** no print — provavelmente porque o fórum não foi muito usado nesse dia. O risco permanece. |
| 🔴 Crítico 2 — `useCommunityProgress` com `refetchOnMount: "always"` | **Confirmado indiretamente** — vide `COLLECTION * SELECT __coll...` (56 retornados de 107 verificados). |
| 🔴 Crítico 3 — `useForumHasNewComments` com staleTime 1 min | **Não isolável** no print (mesclado em `/users` queries). Risco mantido. |
| 🟠 Alto 4 — `useCourseProgress` sem Cache-First | **Confirmado** — 18 execuções em `/users/*/courseProgress`. |
| 🟠 Alto 5 — `useLastAccessedCourse` encadeado | **Confirmado** — contribui para as 12+ execuções de `/courses/*/lessons`. |
| ❌ **NÃO PREVISTO** — `COLLECTION_GROUP courseProgress` sem filtro | **DESCOBERTO** — Cloud Function `getTopCoursesData` (fallback) e `syncTopCoursesStatsDaily` varrem TODOS os usuários. **200 leituras/execução**. |
| ❌ **NÃO PREVISTO** — `/active_days` com 301 leituras | **DESCOBERTO** — maior custo isolado do dia. Fora do escopo de cursos, mas crítico. |

---

### 11.9 Atualização do Plano de Ação

#### Adicionado — Fase 0 (correção imediata, máximo impacto):

| # | Ação | Arquivo | Impacto | Status |
|---|---|---|---|---|
| 0a | Garantir que `global_stats/top_courses` seja sempre válido para evitar fallback em `getTopCoursesData` | `getTopCoursesData.ts` | 🔴 200 leituras/acionamento | 🔜 Próximo |
| 0b | Adicionar guarda de autenticação admin (verificar `customClaims.admin`) antes de executar fallback | `getTopCoursesData.ts` | 🔴 Evita acionamentos não autorizados | 🔜 Próximo |
| 0c | ~~Investigar coleção `/active_days` — 301 leituras, maior custo do dia~~ | Fora do escopo de cursos | 🔴 Urgente | ✅ Concluído |

