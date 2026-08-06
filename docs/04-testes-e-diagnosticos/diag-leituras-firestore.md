# Investigação de Consumo Excessivo de Leituras no Firestore — Saber Espírita

## Contexto

O app **Saber Espírita** (React Native/Expo, bare workflow) está consumindo um volume de leituras no Cloud Firestore considerado exagerado frente ao número de usuários ativos.

**Dados de referência (Firebase Console → Uso do Firestore, julho/2026):**

- Usuários ativos (Firestore real): **1.372**
- Cota gratuita diária de leituras: **50 mil/dia**
- Em vários dias do mês (5, 6, 7 e 8 de julho), o consumo **ultrapassou a cota gratuita**, entrando no nível pago (picos de 60-70 mil leituras/dia).
- Total do mês até o dia 9: **385 mil leituras**, sendo **110 mil já cobradas** no nível pago.
- Média aproximada: ~28 leituras/usuário/dia em dias normais, chegando a 50+/usuário/dia em dias de pico.

**Já descartado como causa:**
- A função "Sincronizar Estatísticas" do painel administrativo foi executada **apenas uma vez** — não é uma rotina recorrente, portanto não explica o consumo contínuo.
- Índices compostos sugeridos pelo próprio Firestore **já foram criados** quando solicitado pelo console.

## Objetivo da investigação

Identificar, no código-fonte do app e nas Cloud Functions (se houver), a(s) causa(s) do alto volume de leituras recorrentes, com foco nos pontos abaixo, extraídos do painel "Query Performance Insights" do Firestore.

## Pontos de atenção prioritários

### 1. `collectionGroup('courseProgress')` — suspeita principal

- Aparece repetidamente no painel de performance com números altos: até **41.182 documentos verificados em média por execução**, contra poucas centenas de resultados retornados.
- Isso é característico de uma query em `collectionGroup` **sem filtro (`where`) suficientemente seletivo**, forçando o Firestore a escanear a subcoleção `courseProgress` de todos os usuários antes de aplicar o filtro final — mesmo que exista um índice composto criado.
- **Ação solicitada:** localizar todas as ocorrências de `collectionGroup('courseProgress')` (ou equivalente) no código. Para cada uma, verificar:
  - Quais campos são usados no `.where()` — o filtro está usando o índice de forma eficiente ou fazendo escaneamento amplo antes de filtrar?
  - Em qual tela/fluxo essa query é disparada, e com que frequência (a cada abertura de tela? a cada render? em um `useEffect` sem dependências corretas?).
  - Se é possível reduzir o escopo (ex: filtrar por `userId` E `courseId` juntos, em vez de apenas um campo).

### 2. Consultas full-scan repetidas em coleções de estatísticas

O painel mostra múltiplas execuções, ao longo de várias sessões, retornando sempre um volume parecido (~300 documentos) nas seguintes coleções:

- `/active_days`
- `/prayer_logs` e `/prayer_stats`
- `/glossary_stats` e `/glossary_logs`
- `/item_stats`
- `/scientific_challenge`
- `/course_feedback`
- `/visit_logs`
- `/users` (SELECT completo, com proporção de 507 documentos verificados para 300 retornados — desperdício de leitura)

O padrão de "sempre ~300 documentos, em várias coleções diferentes, com múltiplas execuções" sugere uma rotina **recorrente** (não a de sincronização manual já descartada) que recalcula agregados/rankings/estatísticas fazendo leitura completa das coleções, em vez de usar contadores incrementais.

**Ação solicitada:**
- Fazer busca (`grep`/busca textual) no projeto por: `courseProgress`, `item_stats`, `glossary_stats`, `active_days`, `prayer_stats`, `visit_logs`, `scientific_challenge`, `course_feedback`.
- Verificar se alguma dessas leituras ocorre:
  - Em uma tela que **todo usuário** abre com frequência (ex: perfil, dashboard pessoal, ranking, tela inicial) — e não apenas em uma tela administrativa.
  - Dentro de uma **Cloud Function agendada** (`scheduler`/`pubsub.schedule`), que rode periodicamente (diária, horária etc.).
  - Em algum `useEffect` ou listener que seja re-executado a cada render, navegação, ou re-montagem de componente sem cleanup adequado.

### 3. Uso de `onSnapshot` (listeners em tempo real) em dados pouco voláteis

Verificar se telas de conteúdo majoritariamente estático — **Glossário** (1.144 termos), **Meditações**, **Orações**, **Aulas** — usam `onSnapshot` (listener permanente) em vez de `getDoc`/`getDocs` (leitura pontual).

- `onSnapshot` mantém conexão aberta e reenvia a coleção inteira a **todos os usuários conectados** sempre que qualquer documento da coleção é alterado por qualquer processo (inclusive scripts administrativos) — o que pode multiplicar leituras de forma desproporcional ao número de usuários simultâneos.

**Ação solicitada:**
- Buscar por `onSnapshot(` em todo o projeto.
- Para cada ocorrência, avaliar se o dado realmente precisa de atualização em tempo real ou se pode ser convertido para `getDoc`/`getDocs` com cache local (ex: `AsyncStorage`), revalidando apenas quando necessário (ex: flag de "conteúdo atualizado" ou pull-to-refresh manual).
- Verificar se os listeners têm cleanup correto (`return () => unsubscribe()` dentro do `useEffect`), evitando listeners duplicados por remontagem de componente.

### 4. Persistência offline do Firestore

- Verificar se a persistência offline (cache local) está habilitada na inicialização do Firestore no app. Se não estiver, cada abertura de tela força ida ao servidor mesmo para dados já vistos recentemente.

## Entregável esperado da análise

Para cada ponto acima, produzir:

1. Localização exata no código (arquivo + trecho relevante).
2. Diagnóstico: a query/listener está sendo executado de forma correta ou ineficiente, e por quê.
3. Frequência estimada de execução (por sessão de usuário, por dia, etc.).
4. Recomendação de correção (ex: adicionar filtro, trocar `onSnapshot` por `getDocs`, implementar contador agregado em vez de recontagem full-scan, habilitar cache offline, paginar com `.limit()`).
5. Estimativa de redução de leituras esperada com a correção, se possível.

## Observação final

O objetivo não é apenas confirmar índices — índices resolvem a *possibilidade* de eficiência, mas não garantem que a query em si esteja bem desenhada. A análise deve olhar o comportamento real de cada query (filtros aplicados, frequência de disparo, e se é listener permanente ou leitura pontual).
