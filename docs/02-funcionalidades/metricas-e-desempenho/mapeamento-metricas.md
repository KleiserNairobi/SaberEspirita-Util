# Mapeamento de Métricas e Telemetria (App e Firebase)

Este documento centraliza a análise e o comportamento dos disparos de métricas analíticas e de progresso dentro do aplicativo **Saber Espírita (Expo)** e sua integração com a arquitetura orientada a eventos (**Cloud Functions / Triggers**) hospedada no projeto Web.

---

## 1. Síntese dos Módulos Analisados

O aplicativo lida primariamente com dois tipos de dados nas métricas: **Estatística Global** (para medir uso, engajamento e alcance do app) e **Progresso Pessoal** (gravação em banco de dados para evolução e emissão de certificados). Visitantes (guests) costumam somar para Estatísticas Globais na maioria dos módulos, mas são bloqueados de reter Progresso Pessoal.

### 1.1. Oração (Pray)
- **Gatilho:** Ação manual. Ao final da tela de leitura, clicando no botão *"Finalizei Minha Prece"*.
- **Controle:** Há uma trava (`hasLogged.current`) para evitar que cliques duplos contem como mais de uma oração por sessão.
- **Funcionamento Padrão:** Insere documento em `prayer_logs` que ativa Trigger no backend. (Visitantes e logados contam).

### 1.2. Melodia / Player Ambiente (Prayer Prep)
- **Gatilho:** Automático perante navegação. Acionado ao clicar *"Iniciar Prece"* na tela de preparação.
- **Controle:** O log só é disparado caso haja uma melodia selecionada e ela não esteja mais na fila de carregamento (em download).
- **Funcionamento Padrão:** Insere documento em `ambient_player_logs` ativando Trigger no backend.

### 1.3. Lições de Cursos (Study)
- **Gatilho:** Ação manual progressiva. Acionado ao clicar em *"Finalizar"* **apenas** no último slide de uma lição (`LessonPlayerScreen`).
- **Controle:** *Visitantes não contam e não retêm progresso.* Usuários não logados recebem apenas um alerta. 
- **Funcionamento Padrão:** Usa `markLessonAsCompleted` inserindo o ID da lição no array `completedLessons` do documento do usuário (`users/{userId}/courseProgress/{courseId}`). A Cloud Function `onCourseProgressWritten.ts` intercepta essa gravação e faz os cálculos matemáticos para o dashboard global de cursos.

### 1.4. Meditação (Meditações Guiadas e Reflexões)
O módulo se divide em duas experiências, mas converge para a mesma arquitetura.
- **Gatilho Guiada (Áudio):** Automático, acionado assim que a faixa entra no estado *Playing*.
- **Gatilho Reflexão (Texto):** Manual, através do botão *"Finalizei a Leitura"* no fim do texto.
- **Funcionamento Padrão:** Cria documento em `meditation_logs` especificando o tipo (`guided` ou `reflection`).

### 1.5. Chat IA (Sr. Allan e Guia)
- **Gatilho:** Ao confirmar o envio da mensagem ao longo da conversa, após validação das cotas diárias de uso por usuário.
- **Adendo de Negócio:** Grava o tamanho em caracteres (`messageLength`) para auditorias de custo e engajamento.
- **Funcionamento Padrão:** Insere documento em `scientific_chat_logs` ou `emotional_chat_logs` e ativa a Cloud Function correspondente.

### 1.6. Glossário
- **Gatilho:** Acionado ao clicar no Card da palavra na tela de listagem de todos os termos, rumo à tela de detalhes.
- **Funcionamento Padrão:** Registra o evento `view` em `glossary_logs` ativando Triggers.

---

## 2. Refatorações e Melhorias Necessárias

Abaixo estão listadas melhorias críticas de arquitetura para padronizar e otimizar as métricas em conformidade com as regras de **Firebase Cloud Functions**.

### 🔴 REATORAÇÃO CRÍTICA: Módulo de Quizzes (Course, Daily e Standard)
O módulo de Quizzes (`CourseQuizScreen`, `DailyQuizScreen` e `StandardQuizScreen`) está atualmente quebrando o padrão de arquitetura da aplicação.

**O Problema Técnico:**
Enquanto todos os outros módulos trabalham com o *Event-Driven Pattern* (onde o app cria um "log seguro" na sua coleção restrita e o Cloud Function assume a soma matemática com privilégios de Admin), o módulo de Quizzes está instruindo o Frontend a editar e somar (`increment`) **diretamente nas tabelas de root** do Firebase (`global_stats` e `daily_stats`) através do `statsService.ts`.
Isso gera problemas de segurança (abertura das regras de segurança públicas) e de desempenho e integridade em cenários de uso concorrente (muitas requisições simultâneas escrevendo no mesmo doc do Firestore simultaneamente).

**A Solução Recomendada:**
1. Criar uma nova Cloud Function no projeto Web, idealmente nomeada `onQuizCompletion.ts`.
2. Essa função deve escutar gatilhos na coleção `quiz_logs` ou similares.
3. No lado do App Expo, os arquivos de telas de Quiz devem parar de usar o `StatsService.incrementQuizCount` e passar a submeter um documento de log simples (identificando a ação, tipo de usuário, e se a categoria é `lesson` ou `general`).
4. A Cloud Function absorverá a responsabilidade de incrementar o Banco de Dados, isolando assim o front do back-end.

### 🟡 MELHORIA DE NEGÓCIO: Ampliação de Gatilho no Glossário
Atualmente, o Glossário só registra contagem de estatísticas quando acessado pela lista principal (`AllTermsScreen`). 
- **Oportunidade:** Com a inclusão da UI "Referências" dentro das Lições, o aluno tem o benefício de acessar definições em um *BottomSheet* ("painel rápido") ali mesmo na interface. Hoje essa consulta *não pontua* para a utilidade do módulo de glossário e nem reflete engajamento no painel de administração.
- **Solução:** Integrar o gatilho `logGlossaryView(term.id, userId)` dentro do painel `GlossaryTermBottomSheet`, contabilizando a abertura real do componente como uma consulta bem-sucedida da palavra. 
