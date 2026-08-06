# Plano de Otimização de Leituras de Orações (Firestore)

Este plano descreve a estratégia para otimizar as consultas e reduzir o volume de leituras no Firestore para a funcionalidade de **Orações (Preces)** no aplicativo Mobile e no painel administrativo Web.

---

## User Review Required

### 1. Escalabilidade de UX & Volume Estipulado (Até 500 Preces)
> [!IMPORTANT]
> Com a confirmação de que o acervo de orações clássicas (Doutrina Espírita, Allan Kardec, Divaldo Franco, etc.) terá um teto máximo de **até 500 preces**:
> *   **Decisão Arquitetural Definida:** Não há necessidade de paginação complexa (infinite scroll) ou de busca baseada em servidor no Firestore. 
> *   **Justificativa de Performance e Custos:** Baixar os 500 documentos uma única vez e fazer a pesquisa textual e categorização offline (na memória do aparelho) oferece uma UX imbatível com respostas instantâneas e menor consumo geral de rede do que fazer buscas fragmentadas repetidas.
> *   **Custos de Leituras Irrisórios:** No Firestore, 500 leituras custam menos de 3 centésimos de centavo de dólar e, como são protegidas pelo cache longo (1 hora) do React Query e pelo cache local persistente nativo do Firestore no dispositivo, o consumo no uso diário do aplicativo será extremamente baixo.


### 2. Estratégia de Migração de Dados (Zero Downtime)
> [!TIP]
> **Necessidade de Migração:** Sim, os documentos existentes na coleção `prayers` do Firestore precisam receber o novo campo `categories: string[]`.
> **Como será feita:** Não há necessidade de scripts complexos ou processos manuais. Como o painel Web (`Export.tsx`) é o detentor da base de dados e utiliza a estratégia de `setDoc(..., { merge: true })`, a migração consistirá simplesmente em:
> 1. Aplicar a alteração no código do Web (que mapeia e embute o campo `categories` na lista de exportação).
> 2. Executar a ação "Exportar Orações" uma única vez no painel administrativo Web.
> 3. Isso atualizará todos os documentos existentes no Firestore, adicionando o array `categories` sem apagar os campos dinâmicos existentes (graças ao `merge: true`).
> 4. Manteremos temporariamente a exportação da coleção `prayer_category_links` para que versões antigas do app em produção continuem funcionando perfeitamente sem quebras.

---

## Análise e Diagnóstico de Ineficiências

Atualmente, a funcionalidade de orações utiliza uma estrutura relacional no Firestore com três coleções principais:
1. `prayers`: Contém os dados das orações.
2. `prayer_categories`: Contém os dados das categorias/momentos.
3. `prayer_category_links`: Coleção de relacionamento N:N conectando uma oração a uma categoria.

Essa estrutura relacional causa as seguintes ineficiências:
* **Múltiplas queries por listagem (Join manual)**: Para obter orações de uma categoria, o aplicativo Mobile lê primeiro a coleção `prayer_category_links` para coletar os IDs das orações e, em seguida, faz consultas em lotes de 10 na coleção `prayers` usando o operador `in`.
* **Download de coleções inteiras**: Para listar e categorizar todas as preces no catálogo (`AllPrayersScreen`), o app baixa a coleção `prayers` inteira **e** a coleção `prayer_category_links` inteira do Firestore para fazer o agrupamento em memória.
* **Invalidação cega de cache**: Toda vez que a tela principal de orações (`PrayScreen`) ganha foco, o app executa `queryClient.invalidateQueries({ queryKey: ["prayers"] })`. Isso zera o cache do React Query de todas as orações (sugestões, em alta, categorias) e força refetches automáticos no Firestore a cada navegação, inclusive quando o usuário retorna de ler uma oração.
* **Hook Obsoleto e Ineficiente**: O hook `usePrayerMomentsCounts` (não utilizado no código atual, mas ainda mantido) faz 10 queries simultâneas no Firestore a cada 5 minutos para recontar itens.

---

## Proposta de Otimização

### 1. Desnormalização (Categorias Inbutidas no Documento)
* Adicionar o campo `categories: string[]` diretamente no documento de cada oração na coleção `prayers`.
* **Web (Exportação)**: O painel Web (`Export.tsx`), ao exportar as preces locais para o Firebase, irá mapear automaticamente as associações de `PrayerCategoryLinks` e embutir o array `categories` diretamente em cada prece no Firestore.
* **Web (Compatibilidade)**: Continuaremos exportando a coleção `prayer_category_links` no Firestore para garantir compatibilidade retroativa total com versões antigas do aplicativo móvel que ainda estejam em produção.

### 2. Simplificação das Consultas no Mobile
* **Buscar por categoria**: A função `getPrayersByCategory` passará a realizar uma única query direta na coleção `prayers` usando o operador `where("categories", "array-contains", categoryId)`, eliminando o join na tabela de links.
* **Listar todas com categorias**: A função `getAllPrayersWithCategories` passará a ler apenas a coleção `prayers`, pois o campo `categories` já virá integrado em cada documento. A leitura da coleção `prayer_category_links` será totalmente removida no app novo.

### 3. Preservação do Cache do React Query
* Remover a invalidação cega `queryClient.invalidateQueries({ queryKey: ["prayers"] })` no `useFocusEffect` do `PrayScreen`.
* As consultas de orações passarão a respeitar os tempos de cache configurados no React Query (1 hora para listagens e categorias, 2 horas para preces em alta).
* Mantemos apenas a invalidação específica para `["prayers", "trending"]` no momento exato em que o usuário de fato conclui uma oração (`handleFinishPrayer`), garantindo que o ranking local seja atualizado com precisão sem forçar o recarregamento de todas as preces estáticas.

---

## Alterações Propostas

### 1. Componente Web (SaberEspirita-Web)

#### [MODIFY] [prayer.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/types/prayer.ts)
* Adicionar o campo opcional `categories?: string[];` na interface `IPrayer`.

#### [MODIFY] [Prayers.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/files/prayers/data/Prayers.ts)
* Importar `PrayerCategoryLinks` e mapear as categorias para cada item do array `Prayers` antes da exportação:
```typescript
import { PrayerCategoryLinks } from './PrayerCategoryLinks';

export const Prayers: IPrayer[] = [
  ... // mapeamentos dos JSONs existentes
].map(prayer => {
  const categories = PrayerCategoryLinks
    .filter(link => link.prayerId === prayer.id)
    .map(link => link.categoryId);
  return {
    ...prayer,
    categories,
  };
});
```

#### [MODIFY] [firestore.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Web/src/services/firestore.ts)
* Atualizar a função `countPrayersInCategory` para fazer contagem via `getCountFromServer()` na coleção `prayers` filtrando pelo array-contains:
```typescript
export async function countPrayersInCategory(categoryId: string): Promise<number> {
  try {
    const prayersRef = collection(db, 'prayers');
    const q = query(prayersRef, where('categories', 'array-contains', categoryId));
    const snapshot = await getCountFromServer(q);
    return snapshot.data().count;
  } catch (error) {
    console.error('Erro ao contar as orações da categoria', error);
    return 0;
  }
}
```

---

### 2. Componente Mobile (SaberEspirita-Expo)

#### [MODIFY] [prayer.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/types/prayer.ts)
* Adicionar o campo opcional `categories?: string[];` na interface `IPrayer`.

#### [MODIFY] [prayerService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/prayerService.ts)
* Atualizar `mapDocToPrayer` para carregar o array `categories` do documento Firestore (fallback para array vazio se inexistente).
* Simplificar `getPrayersByCategory` para ler diretamente de `prayers` usando `where("categories", "array-contains", categoryId)`.
* Simplificar `getAllPrayersWithCategories` para retornar as preces diretamente sem ler a coleção `prayer_category_links`.
* Otimizar `getCategoryPrayerCount` para usar `getCountFromServer` na coleção `prayers`.

#### [MODIFY] [index.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/pray/index.tsx)
* Remover a linha `queryClient.invalidateQueries({ queryKey: ["prayers"] });` de dentro do `useFocusEffect`, de modo que o cache offline do React Query não seja resetado repetidamente no retorno à tela.

#### [DELETE] [usePrayerMomentsCounts.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/pray/hooks/usePrayerMomentsCounts.ts)
* Deletar o arquivo do hook obsoleto para limpar o código e prevenir futuras queries desnecessárias.

---

## Plano de Verificação

### Verificação Manual
1. **Rodar o Painel Web**: Acessar a tela de Exportações e exportar novamente as preces (`prayers`) e contadores (`prayer_counts`) no painel de administração.
2. **Validar no Firestore**: Acessar o console do Firebase (ou inspecionar localmente) para verificar se os documentos na coleção `prayers` agora contêm o array `categories`.
3. **Rodar o App Mobile**:
   - Navegar para a tela "Ore" (Aba de Orações).
   - Abrir o catálogo de preces (todas) e verificar se as orações aparecem corretamente, se os contadores por categoria na barra de categorias estão corretos e se a filtragem funciona perfeitamente.
   - Navegar até uma oração, finalizar a leitura e verificar se o log é gerado com sucesso.
   - Retornar à tela principal e validar se nenhuma requisição redundante é feita ao Firestore (ou seja, o React Query preserva o cache).
