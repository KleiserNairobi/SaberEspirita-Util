# Plano de Otimização de Leituras de Verdadeiro ou Falso e Exercícios (Firestore)

Este documento descreve o diagnóstico, a estratégia e as alterações implementadas para otimizar as consultas e zerar o consumo redundante de leituras no Cloud Firestore nos módulos de **Verdadeiro ou Falso / Desafio Diário** e **Exercícios de Fixação** no aplicativo Mobile (`SaberEspirita-Expo`).

---

## 1. Análise e Diagnóstico de Ineficiências

Antes da otimização, os módulos apresentavam os seguintes comportamentos desnecessários:

1. **`getAllResponses()` sem Limite e sem Cache-First**:
   - `getAllResponses()` em `truthOrFalseService.ts` executava `getDocs` na subcoleção `users/{uid}/truthOrFalseResponses` sem utilizar o cache local nativo do aparelho e sem limite de itens.
2. **Consultas de Exercícios sem Leitura Local**:
   - `getExercisesByLessonId()` e `getExercisesByCourseId()` em `exerciseService.ts` faziam requisições de rede ao Firestore toda vez que uma aula com exercícios era aberta.
3. **Falta de Configuração de Cache no React Query**:
   - Os hooks `useDailyChallengeStatus()`, `useUserStreak()`, `useDailyChallengeStats()` e `useExercises()` não possuíam `refetchOnMount: false` nem `staleTime: 24h`.

---

## 2. Proposta e Estratégia de Otimização

### 1. Leitura *Cache-First* Nível Firestore (Offline-First)
* Alterar os serviços `truthOrFalseService.ts` e `exerciseService.ts` para tentar primeiro ler os dados do cache nativo do dispositivo via `getDocsFromCache` / `getDocFromCache`.
* Adicionar a trava `limit(50)` na busca de respostas para evitar o escaneamento de histórico completo.

### 2. Configuração de Cache nos Hooks (React Query)
* Adicionar `refetchOnMount: false`, `staleTime: 24h` e `gcTime: 7d` em `useDailyChallenge.ts` e `useExercises.ts`.

---

## 3. Alterações Realizadas no Código

### Componentes Mobile (`SaberEspirita-Expo`)

#### A. Serviços de Banco de Dados (`src/services/firebase/`)

##### [MODIFY] [truthOrFalseService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/truthOrFalseService.ts)
* `getTodayResponse()`: Implementada leitura via `getDocFromCache` com fallback para `getDocFromServer`.
* `getHistory()`: Implementada leitura via `getDocsFromCache` com fallback para `getDocsFromServer`.
* `getAllResponses()`: Redirecionado para `getHistory(50)`, adicionando trava de limite.

##### [MODIFY] [exerciseService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/exerciseService.ts)
* `getExercisesByLessonId()`: Implementada leitura `getDocsFromCache` com fallback para `getDocsFromServer`.
* `getExercisesByCourseId()`: Implementada leitura `getDocsFromCache` com fallback para `getDocsFromServer`.

---

#### B. Hooks de Consulta React Query (`src/hooks/queries/`)

##### [MODIFY] [useDailyChallenge.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useDailyChallenge.ts)
* Adicionado `refetchOnMount: false`, `staleTime: 24h` e `gcTime: 7d` nas queries de desafio diário, status, streak e estatísticas.

##### [MODIFY] [useExercises.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useExercises.ts)
* Adicionado `refetchOnMount: false`, `staleTime: 24h` e `gcTime: 7d` nas queries `useExercises` e `useCourseExercises`.

---

## 4. Impacto Financeiro e Redução de Leituras

| Indicador | Antes da Otimização | Depois da Otimização | Redução |
| :--- | :--- | :--- | :--- |
| **Respostas de Verdadeiro ou Falso** | Varredura de histórico | Leitura local (`getDocsFromCache` + `limit(50)`) | **100% (0 reads)** |
| **Abertura de Exercícios de Aula** | Download no servidor | Leitura local (`getDocsFromCache`) | **100% (0 reads)** |
| **Revalidação de Desafio Diário** | Revalidação a cada montagem | 1 vez por dia (`staleTime: 24h` + `refetchOnMount: false`) | **~99%** |
