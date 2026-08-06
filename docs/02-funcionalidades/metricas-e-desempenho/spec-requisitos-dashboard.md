# Especificação de Requisitos: Dashboard Analítico & Estratégico do Quiz-Web

**Autor:** Equipe de Produto (Arquiteto de Soluções / Analista de Negócios)  
**Data:** 18 de Fevereiro de 2026  
**Contexto:** Evolução do Dashboard Administrativo para uma Central de Inteligência do Produto.

---

## 1. Visão Geral e Objetivo

Atualmente, o Dashboard cumpre um papel operacional (**Gestão de Conteúdo e Exportação**). O objetivo desta especificação é transformá-lo em uma ferramenta estratégica de **Gestão do Sucesso do Aluno e Saúde do Produto**.  
Um dashboard "rico" deve responder não apenas _"O que temos de conteúdo?"_, mas principalmente _"Como o conteúdo está impactando os usuários?"_.

---

## 2. Dimensões de Monitoramento (KPIs)

Para um monitoramento eficaz, sugerimos dividir o dashboard em 4 grandes pilares de visão:

### 2.1. Pilar Pedagógico (Cursos e Lições)

_Objetivo: Acompanhar a jornada de aprendizado e identificar gargalos no ensino._

| Métrica                                  | Descrição                                                                           | Importância (Pergunta de Negócio)                        |
| :--------------------------------------- | :---------------------------------------------------------------------------------- | :------------------------------------------------------- |
| **Alunos Matriculados (Total & Ativos)** | Quantidade total de inscritos vs. alunos que acessaram o curso nos últimos 30 dias. | _Qual o alcance real dos nossos cursos?_                 |
| **Taxa de Conclusão (Completion Rate)**  | Porcentagem de alunos que completaram 100% das lições de um curso iniciado.         | _Nossos cursos engajam até o fim? Onde perdemos alunos?_ |
| **Funil de Evasão por Lição**            | Identificação exata da lição onde ocorre a maior desistência (Drop-off).            | _Qual conteúdo é maçante, difícil ou desinteressante?_   |
| **Tempo Médio de Conclusão**             | Média de dias/horas que um aluno leva para terminar um curso.                       | _O ritmo do curso está adequado à proposta pedagógica?_  |

### 2.2. Pilar de Conteúdo e Avaliação (Quizzes e Exercícios)

_Objetivo: Avaliar a eficácia do material didático e o nível de conhecimento dos alunos._

| Métrica                                       | Descrição                                                              | Importância (Pergunta de Negócio)                                         |
| :-------------------------------------------- | :--------------------------------------------------------------------- | :------------------------------------------------------------------------ |
| **Taxa Global de Acertos**                    | Média de acertos em todos os quizzes realizados na plataforma.         | _O nível de dificuldade geral está balanceado?_                           |
| **Questões "Problemáticas" (Hard Questions)** | Top 10 perguntas com maior índice de erro (> 70-80% de erro).          | _Quais conceitos precisam ser revisados ou explicados melhor nas lições?_ |
| **Desempenho por Categoria**                  | Média de acertos agrupada por tema (ex: "Leis Morais", "Mediunidade"). | _Em quais temas nossos alunos têm mais dificuldade de compreensão?_       |
| **Engajamento com Exercícios**                | % de alunos que realizam os exercícios opcionais vs. obrigatórios.     | _Os alunos buscam aprofundamento voluntário?_                             |

### 2.3. Pilar Espiritual e Funcionalidades de Apoio (Orações e Reflexões)

_Objetivo: Monitorar o uso das ferramentas de suporte emocional/espiritual do app._

| Métrica                                   | Descrição                                                                | Importância (Pergunta de Negócio)                                            |
| :---------------------------------------- | :----------------------------------------------------------------------- | :--------------------------------------------------------------------------- |
| **Orações Mais Acessadas (Last 30 Days)** | Ranking das orações mais lidas/utilizadas no último mês.                 | _Quais são as necessidades espirituais mais urgentes do nosso público hoje?_ |
| **Horários de Pico de Oração**            | Distribuição de acessos a orações ao longo do dia (Manhã, Tarde, Noite). | _Quando nosso usuário mais precisa de amparo?_                               |
| **Reflexões Populares**                   | Textos de reflexão com maior taxa de "favoritos" ou tempo de leitura.    | _Que tipo de mensagem ressoa mais com o público?_                            |
| **Taxa de Retorno Diário (Stickiness)**   | Quantos usuários acessam a área de orações diariamente.                  | _Estamos criando um hábito saudável de conexão espiritual?_                  |
| **Categorias de Oração Mais Buscadas**    | Quais temas (ex: "Saúde", "Paz Interior") são mais procurados.           | _O que o usuário busca ao abrir o app?_                                      |

### 2.4. Pilar de Crescimento e Saúde do Produto (Growth & Health)

_Objetivo: Monitorar a base de usuários e a estabilidade técnica._

| Métrica                          | Descrição                                                     | Importância (Pergunta de Negócio)                        |
| :------------------------------- | :------------------------------------------------------------ | :------------------------------------------------------- |
| **Novos Usuários (Acquisition)** | Cadastros realizados por dia/semana.                          | _Nossa base está crescendo de forma saudável?_           |
| **Usuários Ativos (DAU/MAU)**    | Usuários Únicos Diários e Mensais.                            | _O app faz parte da rotina das pessoas?_                 |
| **Retenção de D+1, D+7, D+30**   | % de usuários que voltam ao app após 1 dia, 1 semana e 1 mês. | _O produto mantém o interesse a longo prazo?_            |
| **Plataforma de Acesso**         | Distribuição de acesso (Android vs iOS).                      | _Onde devemos focar nossos testes e melhorias de UI/UX?_ |

### 2.5. Pilar de Integridade de Dados (Data Integrity)

_Objetivo: Garantir que o Dashboard reflita a realidade exata do sistema._

> [!WARNING] > **Ponto Crítico de Atenção**: Antes de implementar qualquer métrica avançada, é fundamental garantir que os contadores básicos (Total de Cursos, Lições, etc.) estejam corretos. Discrepâncias nessas métricas iniciais minam a confiança em todo o painel analítico.

| Métrica                     | Descrição                                                                                   | Importância                 |
| :-------------------------- | :------------------------------------------------------------------------------------------ | :-------------------------- |
| **Integridade do Catálogo** | Validação se o total de itens no Dashboard bate com o total real na base de dados/arquivos. | _O número que vejo é real?_ |

---

---

## 3. Sugestão de Mockup Visual (Layout do Dashboard Rico)

Imagine a tela do Dashboard (`/dashboard`) reestruturada em seções lógicas para facilitar a leitura rápida:

### Seção 1: Visão Executiva (Topo da Página)

4 Cards Grandes com números consolidados e indicadores de tendência (seta verde/vermelha comparando com o mês anterior):

- **Alunos Ativos Hoje**
- **Total de Matrículas (Mês)**
- **Quizzes Respondidos (24h)**
- **Orações Realizadas (24h)**

### Seção 2: Gráficos de Tendência (Corpo Principal)

- **Gráfico de Linha:** _Novas Matrículas vs. Conclusões de Curso_ (Últimos 6 meses). Permite ver se o crescimento de alunos está acompanhado de sucesso escolar.
- **Gráfico de Barras:** _Atividade Diária por Horário_ - Curva de uso ao longo das 24h do dia.

### Seção 3: Tabelas de Insights (Fundo da Página)

Listas curtas (Top 5 ou Top 10) para ação imediata:

1.  **Top 5 Cursos Mais Populares** (Nome do Curso | Alunos | Avaliação Média)
2.  **Top 5 Lições com Maior Abandono** (Nome da Lição | Taxa de Evasão | Curso) -> _Sinal de alerta para revisão de conteúdo._
3.  **Top 10 Questões "Difíceis"** (Pergunta Resumida | % de Erro | Assunto) -> _Sinal de alerta pedagógico._

---

## 4. Requisitos Técnicos para Implementação

Para viabilizar este dashboard rico, o sistema precisará **ler** dados de uso que hoje são gerados pelo App Mobile e salvos no Firestore, mas não consumidos pelo painel administrativo (que hoje foca apenas em _escrita_ de conteúdo estático).

### Mudanças Necessárias:

1.  **Acesso de Leitura:** O painel precisará de permissões e hooks para ler as coleções de usuários (`users`), progresso (`user_progress`), tentativas de quiz (`quiz_attempts`) e logs de oração (`prayer_logs`).
2.  **Agregação de Dados:** Como ler todos os documentos individuais seria custoso e lento, sugere-se criar _Cloud Functions_ (triggers) no Firebase que atualizem documentos de estatísticas agregadas (`stats_dashboard`, `course_stats`) sempre que um evento ocorrer.
    - _Exemplo:_ Ao finalizar uma lição, a function incrementa `completions` no documento do curso.
3.  **Visualização:** Integrar uma biblioteca de gráficos robusta ao projeto React, como **Recharts** ou **Chart.js**, para renderizar as métricas visuais.

---

## 5. Status da Implementação (Fevereiro 2026)

### ✅ Implementado (100%) - Semana 3 (19/02/2026)

- **Correção e Refinamento de Dados:**

  - **Usuários Ativos:** Ajuste na leitura da coleção `users` (case-sensitive) para contagem correta.
  - **Monitoramento de Visitantes (Visitor Tracking):** Nova métrica diária (`daily_stats`) para contagem de aberturas do app, integrado no `StatsService` (Mobile) e visualizado no Gráfico de Tendências (Web).
  - **Separação de Métricas de Quizzes:**
    - **Mobile:** Implementada distinção no `StatsService` entre **Quizzes Gerais** (Lúdico) e **Lições/Exercícios** (Pedagógico).
    - **Dashboard:** KPIs separados ("Quizzes Gerais" vs "Lições Concluídas") e séries distintas no gráfico.

- **UI/UX Dashboard:**
  - **TrendChart:** Reorganização visual das camadas (Visitantes na base -> Orações no topo) e renomeação de "Meditações" para "Reflexões" para alinhamento com o produto.

### ✅ Implementado (100%) - Base (Início Fev/2026)

- **Infrastructure Frontend:**
  - Instalação e configuração do **Recharts**.
  - Migração para **Chakra UI v3** (compatibilidade garantida).
- **Service Layer (`AnalyticsService`):**
  - Conectores para leitura do Firestore.
  - Método `checkIntegrity` para validação Local vs Cloud.
- **UI Components:**
  - `KPICards`: Exibe métricas principais.
  - `TrendChart`: Gráfico de evolução temporal.
  - `CourseRanking`: Visualização de popularidade de cursos.
  - `IntegrityMonitor`: Ferramenta visual de auditoria de dados.
- **Backend Aggregations (Cloud Functions 2nd Gen):**
  - Triggers implantadas para incremento de contadores em tempo real (`onUserCreated`, `onLessonCompleted`, `onQuizAttempt`, `onPrayerUsage`, `onMeditationUsage`).
  - Suporte a monitoramento de usuários anônimos e logados.

### ⚠️ Parcialmente Implementado

- **Deep Analytics:**
  - Métricas de retenção (Cohort Analysis) e Funil de Evasão dependem de histórico maior de dados agregados.
