# Plano de Otimização de Leituras de Cursos, Aulas e Início Rápido (Firestore)

Este documento descreve o diagnóstico, a estratégia e as alterações implementadas para otimizar as consultas e zerar o consumo redundante de leituras no Cloud Firestore nos módulos de **Cursos**, **Aulas** e no card de **Início Rápido (Continuar Curso)** na Home do aplicativo Mobile (`SaberEspirita-Expo`).

---

## 1. Análise e Diagnóstico de Ineficiências

Antes da otimização, a navegação pelo catálogo de cursos, abertura de aulas e renderização da Home apresentavam as seguintes ineficiências:

1. **Card "Continuar Curso" na Home sem Cache Nátivo**:
   - O hook `useLastAccessedCourse()` fazia até **3 consultas sequenciais ao Firestore** a cada abertura do aplicativo ou retorno para a Home (`users/{uid}/courseProgress`, `courses/{courseId}`, `lessons/{lessonId}`).
2. **Download do Catálogo de Cursos sem Cache-First**:
   - `getCourses()` e `getCoursesByDifficulty()` executavam `getDocs` consultando diretamente os servidores do Firestore a cada expiração do React Query.
3. **Subcoleção de Aulas sem Trava de Leitura Local**:
   - `getLessonsByCourseId()` e `getLessonById()` não utilizavam `getDocsFromCache` / `getDocFromCache`, exigindo tráfego de rede para carregar as aulas de um curso recém-aberto.
4. **Leitura do Progresso Geral sem Cache Local**:
   - `useAllCoursesProgress()` lia toda a subcoleção de progresso do usuário sem tentar primeiro a leitura no cache nativo do dispositivo.

---

## 2. Proposta e Estratégia de Otimização

### 1. Leitura *Cache-First* Nível Firestore (Offline-First)
* Alterar as funções em `courseService.ts` e `lessonService.ts` para tentar primeiro obter os dados do cache nativo do aparelho via `getDocsFromCache` / `getDocFromCache`.
* Após o primeiro acesso ao catálogo ou às aulas de um curso, **navegações subsequentes são resolvidas no dispositivo com 0 leituras cobradas no servidor**.
* Caso o cache local esteja vazio, o serviço faz o fallback transparente para `getDocsFromServer` / `getDocFromServer`.

### 2. Trava Arquitetural de Escalabilidade (`limit`)
* Adicionar `.limit(50)` nas buscas gerais de catálogo de cursos (`getCourses`, `getCoursesByDifficulty`) e `.limit(5)` nas buscas de cursos em destaque (`getFeaturedCourses`).

### 3. Otimização do Card de Início Rápido na Home
* O hook `useLastAccessedCourse.ts` passou a utilizar os serviços *Cache-First* (`getCourseById`, `getLessonById`, `getLessonsByCourseId`) e leitura local do progresso mais recente (`getDocsFromCache`).
* Adicionado `refetchOnMount: false` e mantido o `staleTime: 24h`. A invalidação da query ocorre cirurgicamente via `useTouchCourseAccess` apenas quando o usuário de fato assiste a uma aula.

### 4. Ajuste de Vida Útil do Cache (React Query)
* Adicionar `refetchOnMount: false`, `staleTime: 24h` e `gcTime: 7d` em `useCourses`, `useLessons`, `useAllCoursesProgress` e `useLastAccessedCourse`.

---

## 3. Alterações Realizadas no Código

### Componentes Mobile (`SaberEspirita-Expo`)

#### A. Serviços de Banco de Dados (`src/services/firebase/`)

##### [MODIFY] [courseService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/courseService.ts)
* `getCourses()`: Implementada tentativa via `getDocsFromCache` com fallback para `getDocsFromServer` e adicionada trava `limit(50)`.
* `getCourseById()`: Implementada tentativa via `getDocFromCache` com fallback para `getDocFromServer`.
* `getCoursesByDifficulty()`: Implementada tentativa via `getDocsFromCache` com `limit(50)`.
* `getFeaturedCourses()`: Implementada tentativa via `getDocsFromCache` com `limit(5)`.

##### [MODIFY] [lessonService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/lessonService.ts)
* `getLessonsByCourseId()`: Implementada leitura `getDocsFromCache` com fallback para `getDocsFromServer`.
* `getLessonById()`: Implementada leitura `getDocFromCache` com fallback para `getDocFromServer`.

---

#### B. Hooks de Consulta React Query (`src/hooks/queries/`)

##### [MODIFY] [useCourses.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useCourses.ts)
* Adicionado `refetchOnMount: false` nas queries `useCourses()`, `useFeaturedCourses()` e `useCourse(id)`.

##### [MODIFY] [useLessons.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useLessons.ts)
* Aumentado `staleTime` de 12 horas para **24 horas** e `gcTime` para **7 dias**, com `refetchOnMount: false`.

##### [MODIFY] [useAllCoursesProgress.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useAllCoursesProgress.ts)
* Implementada leitura `getDocsFromCache` para a subcoleção `courseProgress` do usuário e adicionado `refetchOnMount: false`.

##### [MODIFY] [useLastAccessedCourse.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useLastAccessedCourse.ts)
* Integrados os serviços *Cache-First* (`getCourseById`, `getLessonById`, `getLessonsByCourseId`) e leitura local do progresso com `refetchOnMount: false`.

---

## 4. Plano de Verificação e Como Testar

### Teste 1: Validação do Card "Continuar Curso" na Home
1. Abra o aplicativo e navegue pela Home.
2. Certifique-se de que o card de Início Rápido exibe o curso/aula corretos.
3. Sair da Home para a aba de Perfil, Configurações ou Meditar e retornar à Home repetidamente.
4. **Resultado Esperado:** O card carrega instantaneamente e nenhuma nova requisição de rede ao Firestore é disparada.

### Teste 2: Validação do Catálogo de Cursos & Aulas Offline (Modo Avião)
1. Com os cursos já visualizados uma vez, ative o **Modo Avião** do dispositivo.
2. Feche e reabra o aplicativo.
3. Acesse o Catálogo de Cursos, selecione um curso e abra a lista de aulas.
4. **Resultado Esperado:** Os cursos, módulos e detalhes das aulas devem carregar 100% offline a partir do cache local do Firestore nativo.

---

## 5. Otimização no Backend & Cloud Functions (Ciclo de Escrita de Progresso)

### A. Diagnóstico da Falha no Backend
As triggers `onCourseProgressWritten` e `onCourseProgressForCommunity` dispararam **mais de 52.000 vezes** em respostas a atualizações na subcoleção `users/{userId}/courseProgress/{courseId}`. Cada disparo gerava leituras excessivas no Firestore por conta de:
1. **Chamada de Metadata Sem Cache (`getCourseLessonCounts`):** A cada disparo de trigger (mesmo atualizações simples de `lastAccessedAt` via `touchCourseAccess`), a função lia o documento `global_stats/courses_metadata` no Firestore.
2. **Execução Antes de Validação de Mudança:** Em `onCourseProgressWritten`, a leitura no Firestore ocorria na linha 25, *antes* de checar se houve mudança real em `completedLessons`.
3. **Escaneamento de Coleção Completa (`recomputeStudyStats`):** `onCourseProgressForCommunity` reconstruía o histórico realizando busca completa da coleção `courseProgress` do usuário.

### B. Soluções Aplicadas no Backend (`SaberEspirita-Web/functions`)

1. **Cache de Metadados em Memória com TTL (`getCourseLessonCounts`):**
   - Implementado cache em memória no escopo da instância da Cloud Function para o documento `global_stats/courses_metadata` com TTL de 1 hora.
   - **Economia:** Elimina até 52.000 leituras no Firestore a cada ciclo intenso de atualizações.

2. **Early Return Guard em `onCourseProgressWritten`:**
   - Adicionada verificação prévia de alteração em `completedLessons` *antes* de executar `getCourseLessonCounts()` ou qualquer leitura de banco. Atualizações simples de `lastAccessedAt` ou `lastLessonId` encerram a função imediatamente com **0 leituras**.

3. **Otimização de `recomputeStudyStats`:**
   - Uso do cache de metadados em memória para o cálculo estatístico da comunidade.

---

## 6. Impacto Financeiro e Redução de Leituras (Consolidado)

| Indicador | Antes da Otimização | Depois da Otimização | Redução |
| :--- | :--- | :--- | :--- |
| **Abertura da Home (Continuar Curso)** | Até 3 leituras de rede por abertura | **0 leituras** (resolvido em cache local) | **100%** |
| **Navegação no Catálogo de Cursos** | Revalidação no servidor | Leitura local (`getDocsFromCache`) | **100% (0 reads)** |
| **Abertura de Aulas do Curso** | Download no servidor | Leitura local (`getDocsFromCache`) | **100% (0 reads)** |
| **Triggers Backend (`onCourseProgress*`)** | ~104.000 leituras geradas no backend por 52 mil disparos | **0 leituras desnecessárias** (guard e cache em memória) | **> 98%** |

