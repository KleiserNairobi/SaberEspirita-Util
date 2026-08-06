# Plano de Otimização de Leituras do Glossário (Firestore)

Este documento descreve o diagnóstico, a estratégia e as alterações implementadas para otimizar as consultas e zerar o consumo redundante de leituras no Cloud Firestore no módulo do **Glossário** (1.144+ termos) no aplicativo Mobile (`SaberEspirita-Expo`).

---

## 1. Análise e Diagnóstico de Ineficiências

Antes da otimização, o acesso à tela de Glossário apresentava a maior vulnerabilidade de leituras do aplicativo:

1. **Download completo repetido (1.144+ documentos por busca)**:
   - A função `getAllGlossaryTerms()` executava `getDocs(collection(db, "glossary"))`, baixando o acervo inteiro de 1.144 termos do servidor Firestore sem utilizar cache local primário.
2. **Tempo de expiração curto no React Query (`staleTime: 5 min`)**:
   - O hook `useGlossaryTerms()` considerava os dados obsoletos após 5 minutos.
   - Qualquer navegação de retorno à tela de Glossário após 5 minutos de inatividade disparava **1.144 novas leituras cobradas no Firestore**.
3. **Ausência do padrão Cache-First no Firestore**:
   - As consultas para termo individual (`getGlossaryTermById`) e consultas por categoria (`getGlossaryTermsByCategory`) sempre recorriam ao servidor do Firestore.

---

## 2. Proposta e Estratégia de Otimização

### 1. Leitura *Cache-First* Nível Firestore (Offline-First)
* Alterar as funções em `glossaryService.ts` para tentar primeiro obter os termos a partir do cache local nativo do aparelho via `getDocsFromCache` / `getDocFromCache`.
* Como o Glossário é um dicionário estático, após o primeiro download, **todas as navegações subsequentes são resolvidas no dispositivo com 0 leituras cobradas no servidor**.
* Caso o cache esteja vazio (primeiro uso do app), o serviço faz o fallback transparente para `getDocsFromServer` / `getDocFromServer`.

### 2. Vida Útil de Cache Estendida (React Query)
* Elevar o `staleTime` de 5 minutos para **24 horas** (`1000 * 60 * 60 * 24`) no `useGlossaryTerms.ts`.
* Configurar `gcTime` para **7 dias** (`1000 * 60 * 60 * 24 * 7`) e `refetchOnMount: false`.

### 3. Padronização de Chaves (`GLOSSARY_KEYS`)
* Exportar a constante unificada `GLOSSARY_KEYS` (`all`, `term`, `byCategory`) para garantir alinhamento perfeito de cache no React Query.

---

## 3. Alterações Realizadas no Código

### Componentes Mobile (`SaberEspirita-Expo`)

#### A. Serviço de Banco de Dados (`src/services/firebase/glossaryService.ts`)

##### [MODIFY] [glossaryService.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/services/firebase/glossaryService.ts)
* `getAllGlossaryTerms()`: Implementada tentativa via `getDocsFromCache` com fallback para `getDocsFromServer`.
* `getGlossaryTermById()`: Implementada tentativa via `getDocFromCache` com fallback para `getDocFromServer`.
* `getGlossaryTermsByCategory()`: Implementada tentativa via `getDocsFromCache` com fallback para `getDocsFromServer`.

---

#### B. Hooks de Consulta React Query (`src/pages/glossary/hooks/useGlossaryTerms.ts`)

##### [MODIFY] [useGlossaryTerms.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/src/pages/glossary/hooks/useGlossaryTerms.ts)
* Criada a constante unificada `GLOSSARY_KEYS`.
* Ajustados `staleTime` de 5 minutos para **24 horas** e `gcTime` para **7 dias** com `refetchOnMount: false` nas queries `useGlossaryTerms()` e `useGlossaryTerm(id)`.

---

## 4. Plano de Verificação e Como Testar

### Teste 1: Validação de Leitura Cache-First (Navegação Repetida)
1. Abra o aplicativo e navegue até a tela do **Glossário Espírita**.
2. Aguarde o carregamento inicial dos termos.
3. Sair do Glossário para outra aba do aplicativo e retornar repetidamente à lista de termos.
4. **Resultado Esperado:** O carregamento da lista de 1.144 termos deve ser instantâneo e nenhuma requisição de rede deve ser disparada ao Firestore.

### Teste 2: Validação de Funcionamento Offline (Modo Avião)
1. Com os termos já baixados uma vez, ative o **Modo Avião** do celular/emulador.
2. Feche o aplicativo no multitarefa e abra-o novamente.
3. Navegue até a tela de Glossário, digite um termo na busca e clique em um card para abrir o detalhe do termo.
4. **Resultado Esperado:** A busca textual, filtragem alfabética e tela de detalhes do termo devem carregar 100% offline a partir do cache nativo do aparelho.

---

## 5. Impacto Financeiro e Redução de Leituras

| Indicador | Antes da Otimização | Depois da Otimização | Redução |
| :--- | :--- | :--- | :--- |
| **Custo por Acesso (>5 min)** | 1.144 leituras por acesso | **0 leituras** (resolvido em cache) | **100%** |
| **Frequência de Revalidação** | A cada 5 minutos | 1 vez a cada 24h | **~99.6%** |
| **Busca e Filtragem por Categoria** | Re-execução no servidor | Processamento local em memória | **100% (0 reads)** |
