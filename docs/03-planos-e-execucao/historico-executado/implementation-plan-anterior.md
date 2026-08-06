# Adição da Feature de Podcasts na Aba Estude (Expo e Web)

Este plano detalha a implementação de um novo item de biblioteca ("Podcasts") no módulo Estude do aplicativo SaberEspirita-Expo, juntamente com seu painel administrativo, sincronização do Firestore e verificação de integridade no projeto SaberEspirita-Web.

## User Review Required

> [!IMPORTANT]
> A implementação propõe a criação de uma nova coleção dedicada no Firestore chamada `podcasts` e uma nova tabela de logs de reprodução chamada `podcast_logs`. Isso mantém o isolamento dos dados e estatísticas em relação às Meditações Guiadas e Reflexões.
> 
> O item **Podcasts** será adicionado à lista "Explore a Biblioteca" na tela inicial da aba **Estude** e será posicionado como a primeira opção (antes do Glossário Espírita) para aumentar o engajamento e a descoberta de conteúdo atualizado de áudio doutrinário.

---

## Proposed Changes

### 1. SaberEspirita-Expo (Frontend Mobile)

#### [NEW] [podcast.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/types/podcast.ts)
- Criação da interface `IPodcast` para representar a estrutura de dados de cada episódio de podcast:
  ```typescript
  export interface IPodcast {
    id: string;
    title: string;
    description: string;
    author: string;
    durationMinutes: number;
    audioUrl: string;
    imageUrl?: string;
    isPremium?: boolean;
    featured?: boolean;
    createdAt?: Date;
  }
  ```

#### [NEW] [podcastService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/podcastService.ts)
- Criação das funções de acesso ao Firebase Firestore para a coleção `podcasts`:
  - `getPodcasts()`: Retorna todos os podcasts ordenados por título.
  - `getFeaturedPodcasts()`: Retorna os podcasts sinalizados como destaque (`featured == true`, limitando a 5).
  - `getPodcastById(id)`: Retorna um podcast específico.
  - `logPodcastUsage(...)`: Grava o log de uso em `podcast_logs` (analytics de reprodução).

#### [NEW] [usePodcasts.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/hooks/queries/usePodcasts.ts)
- Criação dos hooks do React Query para podcasts:
  - `usePodcasts()`
  - `useFeaturedPodcasts()`
  - `usePodcast(id)`

#### [NEW] [podcastPlayerStore.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/stores/podcastPlayerStore.ts)
- Store do Zustand para gerenciar o podcast atualmente selecionado/em cache no player, evitando carregamento redundante do Firestore ao navegar.

#### [NEW] [PodcastCard](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/components/PodcastCard/index.tsx)
- Componente de card para exibição do podcast na listagem, similar ao `MeditationCard` mas utilizando um ícone de microfone/podcast (da biblioteca `lucide-react-native`).

#### [NEW] [AllPodcastsScreen](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/all-podcasts/index.tsx)
- Tela que lista todos os podcasts cadastrados, incluindo campo de pesquisa e filtros por duração, semelhante à listagem de meditações.

#### [NEW] [PodcastPlayerScreen](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/podcast-player/index.tsx)
- Tela com player de áudio dedicado para reprodução de podcasts utilizando o `react-native-track-player` e suporte a logs de uso.

#### [MODIFY] [Biblioteca.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/data/Biblioteca.tsx)
- Adição do item de id `"3"` para representar os Podcasts na constante `Biblioteca`.
- Posicionamento do item no topo do array (antes do Glossário Espírita).
- Utilização de ícone apropriado (ex: `Mic` ou `Headphones`).

#### [MODIFY] [StudyScreen](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/study/index.tsx)
- Atualização da função `handleLibraryItemPress` para tratar o clique no ID `"3"` correspondente aos Podcasts, navegando para a rota `"AllPodcasts"`.

#### [MODIFY] [AppNavigator.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/routers/AppNavigator.tsx)
- Registro das novas rotas de navegação de alto nível em tela cheia: `AllPodcasts` e `PodcastPlayer`.

#### [MODIFY] [types.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/routers/types.ts)
- Adição dos parâmetros tipados das rotas em `AppStackParamList`:
  - `AllPodcasts: undefined;`
  - `PodcastPlayer: { id: string };`

---

### 2. SaberEspirita-Web (Backend & Painel Admin)

#### [NEW] [Diretório assets/constants/podcasts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/assets/constants/podcasts)
- Criação da pasta dedicada para concentrar arquivos JSON de constantes e dados de semente relacionados a podcasts.

#### [NEW] [podcasts.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/assets/constants/podcasts/podcasts.json)
- Criação do arquivo de semente inicial dos episódios de podcasts dentro do novo diretório `assets/constants/podcasts`.

#### [NEW] [Diretório files/podcasts/data](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/files/podcasts/data)
- Criação da estrutura de pastas para conter a exportação/sincronização de dados locais na camada de dados da aplicação web.

#### [NEW] [podcasts.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/files/podcasts/data/podcasts.ts)
- Script de mapeamento e exportação da constante `AppPodcasts` a partir do JSON de podcasts dentro do novo diretório `files/podcasts/data`.

#### [MODIFY] [firestore.rules](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/firestore.rules)
- Adição da regra de acesso para a coleção `podcasts` no Firebase Firestore:
  ```javascript
  match /podcasts/{docId} {
    allow read: if true;
    allow write: if isAdmin();
  }
  ```

#### [MODIFY] [types/analytics.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/types/analytics.ts) (ou arquivo de tipos de analytics correspondente)
- Extensão do tipo `IIntegrityReport` para incluir a chave `podcasts: IIntegrityItem;`.

#### [MODIFY] [analytics.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/services/analytics.ts)
- Atualização da função `checkIntegrity()` para contar a coleção `podcasts` no Firestore e comparar com o tamanho de `AppPodcasts`.

#### [MODIFY] [IntegrityMonitor](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/components/dashboard/IntegrityMonitor.tsx)
- Inclusão da linha "Podcasts" na tabela comparativa de integridade de dados locais vs nuvem.

#### [MODIFY] [Export.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/pages/Export.tsx)
- Adição da funcionalidade de exportação (sincronização/seed) de podcasts para o Firestore:
  - Adicionar o valor `'podcasts'` na seleção de grupos.
  - Implementar a função `exportPodcasts()`.
  - Integrar a etapa de exportação de podcasts no fluxo global (`exportFirestore`).

---

## Verification Plan

### Manual Verification
1. **Semente/Deploy no Web**:
   - Abrir o Painel Web.
   - Navegar até a página **Exportar** e validar que "Podcasts" é exibido na lista de seleção.
   - Clicar em exportar/sincronizar Podcasts para gravar os itens seed no Firestore da coleção `podcasts`.
   - Navegar até a página **Monitor de Integridade** (IntegrityPage) e confirmar que o status da entidade "Podcasts" aparece como `OK`.

2. **Mobile Expo**:
   - Abrir o aplicativo Expo e acessar a aba **Estude**.
   - Validar que na lista **Explore a Biblioteca**, o item **Podcasts** aparece como a primeira opção (antes do Glossário).
   - Clicar em **Podcasts** e certificar-se de que a listagem de podcasts carrega e exibe os episódios disponíveis.
   - Testar o campo de pesquisa e filtros por duração.
   - Clicar em um podcast para abrir o player, validar o carregamento do áudio e se o play/pause e a barra de progresso respondem adequadamente.
