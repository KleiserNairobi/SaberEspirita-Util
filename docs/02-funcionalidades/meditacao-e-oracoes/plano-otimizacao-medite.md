# Plano de Otimização de Leituras da Aba Medite (Podcasts, Meditações e Reflexões)

Este documento descreve o diagnóstico, a estratégia e as alterações implementadas para otimizar as consultas e zerar o consumo redundante de leituras no Cloud Firestore para as funcionalidades da aba **Medite** (Meditações e Reflexões) e da área de **Podcasts** no aplicativo Mobile (`SaberEspirita-Expo`).

---

## 1. Análise e Diagnóstico de Ineficiências

Antes da otimização, a navegação entre a tela principal "Medite", o catálogo de mídias e a abertura de players apresentava as seguintes ineficiências:

1. **`refetchOnMount: "always"` no Hook de Podcasts**:
   - O hook `usePodcasts` estava configurado com `refetchOnMount: "always"`.
   - Toda vez que a tela de podcasts era montada ou recebia foco, o aplicativo forçava um recarregamento completo no Firestore, ignorando o cache local.
2. **Consultas sem limite e sem estratégia Cache-First no Firestore**:
   - `getPodcasts()`, `getMeditations()` e `getAllReflections()` realizavam `getDocs(query(...))` direto no servidor do Firestore sem utilizar `getDocsFromCache` nem limitar a quantidade máxima de itens retornados (`limit(50)`).
3. **Desalinhamento de Chaves de Cache em Prefetchs na UI**:
   - As telas de listagem (`all-podcasts`, `all-meditations`, `all-reflections` e `meditate/index.tsx`) realizavam `prefetchQuery` com strings manuais (ex: `["podcasts", "detail", id]`), enquanto os hooks liam chaves com versionamento (ex: `["podcasts", "detail", id, "v1"]`).
   - Isso impedia o reaproveitamento do prefetch, forçando um novo *fetch* individual no Firestore quando o usuário clicava em um card para abrir o player.
4. **Tempos de Expiração Curtos (Stale Time)**:
   - As mídias e reflexões (conteúdos majoritariamente estáticos) possuíam `staleTime` de apenas 5 minutos ou 1 hora, causando revalidações frequentes ao longo do dia.

---

## 2. Proposta e Estratégia de Otimização

### 1. Leitura *Cache-First* Nível Firestore (Offline-First)
* Alterar os serviços `podcastService.ts`, `meditationService.ts` e `reflectionService.ts` para tentar primeiro obter os dados a partir do cache local do dispositivo via `getDocsFromCache` / `getDocFromCache`.
* Caso o cache local contiver os dados (qualquer acesso posterior ao primeiro), a leitura é resolvida instantaneamente com **0 leituras cobradas no servidor**.
* Caso o cache esteja vazio (primeira instalação do app), o serviço recorre ao `getDocsFromServer` / `getDocFromServer` e popula o cache nativo.

### 2. Trava Arquitetural de Escalabilidade (`limit`)
* Adicionar `.limit(50)` nas buscas gerais de catálogo (`getPodcasts`, `getMeditations`, `getAllReflections`) e `.limit(5)` nas buscas de destaques (`getFeaturedMeditations`, `getFeaturedReflections`).
* Isso previne que um crescimento futuro do catálogo sobrecarregue a rede do celular ou a cota do banco em instalações limpas.

### 3. Ajuste de Vida Útil do Cache (React Query)
* Alterar `staleTime` para **24 horas** (`1000 * 60 * 60 * 24`) e `gcTime` para **7 dias** (`1000 * 60 * 60 * 24 * 7`).
* Alterar `refetchOnMount` para `false`.

### 4. Padronização Unificada de Chaves de Cache (`KEYS`)
* Exportar constantes unificadas `PODCAST_KEYS`, `MEDITATION_KEYS` e `REFLECTION_KEYS` nos hooks de consulta.
* Atualizar todas as chamadas de `prefetchQuery` nas telas da UI para utilizar exatamente essas funções de chave (ex: `PODCAST_KEYS.detail(id)`), garantindo match perfeito de 100% no cache.

---

## 3. Alterações Realizadas no Código

### Componentes Mobile (`SaberEspirita-Expo`)

#### A. Serviços de Banco de Dados (`src/services/firebase/`)

##### [MODIFY] [podcastService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/podcastService.ts)
* `getPodcasts()`: Implementada tentativa via `getDocsFromCache` com fallback para `getDocsFromServer` e adicionada trava `limit(50)`.
* `getFeaturedPodcasts()`: Implementada tentativa via `getDocsFromCache` com `limit(5)`.
* `getPodcastById()`: Implementada tentativa via `getDocFromCache` com fallback para `getDocFromServer`.

##### [MODIFY] [meditationService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/meditationService.ts)
* `getMeditations()`: Implementada leitura `getDocsFromCache` + fallback `getDocsFromServer` e trava `limit(50)`.
* `getFeaturedMeditations()`: Implementada leitura `getDocsFromCache` com `limit(5)`.
* `getMeditationById()`: Implementada leitura `getDocFromCache` com fallback `getDocFromServer`.

##### [MODIFY] [reflectionService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/reflectionService.ts)
* `getAllReflections()`: Implementada leitura `getDocsFromCache` + fallback `getDocsFromServer` e trava `limit(50)`.
* `getFeaturedReflections()`: Implementada leitura `getDocsFromCache` com `limit(5)`.
* `getReflectionById()`: Implementada leitura `getDocFromCache` com fallback `getDocFromServer`.

---

#### B. Hooks de Consulta React Query (`src/hooks/queries/` e `src/pages/meditate/hooks/`)

##### [MODIFY] [usePodcasts.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/usePodcasts.ts)
* Removido `refetchOnMount: "always"` em favor de `refetchOnMount: false`.
* Ajustados `staleTime` para 24 horas e `gcTime` para 7 dias.

##### [MODIFY] [useMeditations.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/useMeditations.ts)
* Garantida exportação unificada de `MEDITATION_KEYS` e configurado `staleTime: 24h` e `gcTime: 7d`.

##### [MODIFY] [useReflections.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/meditate/hooks/useReflections.ts) & [useFeaturedReflections.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/meditate/hooks/useFeaturedReflections.ts)
* Criada e exportada a constante `REFLECTION_KEYS` (`all`, `featured`, `detail`).
* Ajustado `gcTime: 7d` e mantido `staleTime: 24h` com `refetchOnMount: false`.

---

#### C. Telas e Componentes de Interface (`src/pages/`)

##### [MODIFY] [all-podcasts/index.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/all-podcasts/index.tsx)
* Importado `PODCAST_KEYS` e atualizada a função `prefetchPodcast` para usar `PODCAST_KEYS.detail(id)`.

##### [MODIFY] [all-meditations/index.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/meditate/all-meditations/index.tsx)
* Importado `MEDITATION_KEYS` e atualizada a função `prefetchMeditation` para usar `MEDITATION_KEYS.detail(id)`.

##### [MODIFY] [all-reflections/index.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/meditate/all-reflections/index.tsx)
* Importado `REFLECTION_KEYS` e atualizada a função `prefetchReflection` para usar `REFLECTION_KEYS.detail(id)`.

##### [MODIFY] [meditate/index.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/meditate/index.tsx)
* Importadas as constantes `MEDITATION_KEYS` e `REFLECTION_KEYS` e alinhadas as funções de prefetch da tela inicial da aba Medite.

---

## 4. Plano de Verificação e Como Testar

### Teste 1: Validação de Leitura Cache-First (Navegação Repetida)
1. Abra o aplicativo em um emulador ou dispositivo físico com conexão à internet.
2. Navegue até a aba **Medite**.
3. Acesse os catálogos "Todas as Meditações", "Todas as Reflexões" e "Todos os Podcasts".
4. Volte para a Home do aplicativo e acesse novamente a aba Medite e os catálogos por várias vezes.
5. **Resultado Esperado:** O carregamento deve ser instantâneo (0ms de espera) e nenhum log de requisição de rede ao Firestore deve ser disparado nas navegações subsequentes.

### Teste 2: Validação de Funcionamento Offline (Modo Avião)
1. Com os dados carregados ao menos uma vez, ative o **Modo Avião** do dispositivo (desative Wi-Fi e Dados Móveis).
2. Feche o aplicativo no multitarefa e abra-o novamente.
3. Navegue pela aba Medite, abra a lista de podcasts e toque em um card para abrir o player.
4. **Resultado Esperado:** Os dados de podcasts, meditações e reflexões devem carregar perfeitamente a partir do cache local do Firestore nativo no aparelho, sem telas de erro ou spinners infinitos.

### Teste 3: Validação de Filtros de Busca na UI
1. Abra a tela "Todas as Meditações" ou "Todos os Podcasts".
2. Digite um termo na barra de busca ou aplique o filtro por autor / duração no Bottom Sheet.
3. **Resultado Esperado:** A filtragem deve ocorrer instantaneamente em memória (via `useMemo`), sem fazer requisições extras ao banco de dados.

---

## 5. Impacto Financeiro e Redução de Leituras

| Indicador | Antes da Otimização | Depois da Otimização | Redução |
| :--- | :--- | :--- | :--- |
| **Comportamento em Montagem** | `refetchOnMount: "always"` | `refetchOnMount: false` | Eliminado |
| **Frequência de Busca de Mídia** | A cada 5 min (servidor) | 1 vez a cada 24h (servidor) | **~99%** |
| **Navegação Repetida no App** | Revalidação no servidor | Leitura local (`getDocsFromCache`) | **100% (0 reads)** |
| **Prefetch de Player** | Desalinhado (forçava fetch) | Alinhado com `KEYS` | **100% de aproveitamento** |
