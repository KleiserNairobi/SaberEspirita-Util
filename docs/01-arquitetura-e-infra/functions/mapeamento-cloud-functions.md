# Mapeamento e Classificação das Cloud Functions

Este documento lista todas as Cloud Functions ativas no projeto, descrevendo suas finalidades e classificando-as entre as que **podem ser desativadas** para redução de custos (sem impacto direto na experiência do usuário final do app) e as que são **críticas** e devem ser mantidas ativas.

---

## 📋 Tabela de Classificação das Funções

| Cloud Function | Gatilho / Tipo | Status de Desativação | O que faz / Impacto da Desativação |
| :--- | :--- | :--- | :--- |
| **`onPrayerLog`** | `prayer_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Conta as orações lidas no app para estatísticas globais e mensais. *Impacto:* Os gráficos de orações lidas no dashboard de administração congelarão em tempo real. |
| **`onGlossaryLog`** | `glossary_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Rastreia visualizações de termos do glossário para ranking no painel. *Impacto:* Gráficos de acesso ao glossário congelarão. |
| **`onMeditationLog`** | `meditation_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Conta a conclusão de áudios de meditação/reflexão. *Impacto:* Contadores do dashboard não serão atualizados em tempo real. |
| **`onPodcastLog`** | `podcast_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Rastreia reprodução de episódios de podcast. *Impacto:* Perda das métricas de audição em tempo real no dashboard. |
| **`onAmbientPlayerLog`** | `ambient_player_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Monitora a reprodução dos sons ambientes do app. *Impacto:* Perda das métricas de reproduções no painel do administrador. |
| **`onVisitLog`** | `visit_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Monitora logins e sessões ativas diárias. *Impacto:* O gráfico de atividade de usuários diários do dashboard ficará estático. |
| **`onChallengeLog`** | `challenge_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Monitora as conclusões dos desafios diários. *Impacto:* Contagem global do painel de administração não atualizará. |
| **`onTruthOrFalseLog`** | `truth_or_false_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Registra as respostas certas/erradas do jogo de V ou F. *Impacto:* Estatísticas agregadas do jogo congelarão. |
| **`onQuizLog`** | `quiz_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Registra tentativas nos quizzes. *Impacto:* Estatísticas agregadas de tentativas de quizzes gerais e de aulas congelarão. |
| **`onCertificateLog`** | `certificate_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Rastreia emissão de certificados dos cursos. *Impacto:* Contagem global de graduados por curso no painel não atualizará. |
| **`onLessonLog`** | `lesson_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Rastreia visualizações/conclusões de aulas individuais. *Impacto:* O contador do histórico de aulas assistidas no painel congelará. |
| **`onEmotionalChatLog`** | `emotional_chat_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Registra o tráfego de mensagens do chat emocional. *Impacto:* Perda de monitoramento de tráfego de mensagens do chat de acolhimento. |
| **`onScientificChatLog`** | `scientific_chat_logs/{logId}` (Firestore onCreate/onDelete) | **Pode Desativar** | Registra o tráfego de mensagens do chat de IA. *Impacto:* Perda de monitoramento do tráfego do chat de IA científico. |
| **`syncUserCountDaily`** | Cron (`every day 02:30`) | **Pode Desativar** | Corrige estatísticas diárias com o Auth. *Impacto:* Os dados no banco só atualizarão quando rodados manualmente. |
| **`syncTopCoursesStatsDaily`** | Cron (Diário) | **Pode Desativar** | Atualiza métricas detalhadas dos cursos para o dashboard. *Impacto:* Os rankings de cursos no dashboard só atualizarão sob demanda. |
| **`onUserCreated`** | Auth Trigger (onCreate) | **Não Desativar (Crítica)** | Inicializa o progresso, conquistas e níveis do usuário no Firestore quando ele se cadastra. |
| **`onUserDeleted`** | Auth Trigger (onDelete) | **Não Desativar (Crítica)** | Limpa os registros de progresso e estatísticas do usuário que excluiu a conta. |
| **`beforeUserCreated`** | Blocking Auth Trigger | **Não Desativar (Crítica)** | Validações de segurança para controle e barreira na criação de novas contas. |
| **`onCourseProgressWritten`** | `courseProgress/{id}` (Firestore) | **Não Desativar (Crítica)** | Detecta a conclusão de cursos (100%) para dar premiações e subir rankings. |
| **`onCourseProgressForCommunity`** | `courseProgress/{id}` (Firestore) | **Não Desativar (Crítica)** | Atualiza o XP e o nível do estudante na comunidade baseado em seus estudos. |
| **`updateCourseFeedbackAggregates`**| `courseFeedback/{id}` (Firestore) | **Não Desativar (Crítica)** | Recalcula a nota média de avaliação por estrelas de um curso ao receber feedback. |
| **`onForumCommentCreated`** | `comments/{id}` (Firestore) | **Não Desativar (Crítica)** | Gerencia novos comentários nos fóruns das aulas e dispara push notifications aos participantes. |
| **`onForumReactionWritten`** | `reactions/{id}` (Firestore) | **Não Desativar (Crítica)** | Processa as reações e curtidas nos posts do fórum, alterando XP e pontuação. |
| **`notifyAbandonedCourses`** | Cron (Diário) | **Não Desativar (Crítica)** | Dispara push notifications automáticos a usuários que abandonaram estudos no meio. |
| **`deepseekProxy`** | HTTPS Callable | **Não Desativar (Crítica)** | Intermedeia a comunicação da IA de chat (Deepseek) sem expor a chave de API no celular do usuário. |
| **`deleteMyAccount`** | HTTPS Callable | **Não Desativar (Crítica)** | Implementa a remoção do usuário por solicitações LGPD/App Store. |
| **`cleanupInactiveUsers`** | Cron (Diário) | **Não Desativar (Crítica)** | Executa a faxina de dados e exclusão de contas totalmente abandonadas/inativas. |
| **`getCourseManagementData`** | HTTPS Callable | **Não Desativar (Dashboard)** | API chamada pelo painel administrativo para trazer a lista de progresso dos alunos no curso. |
| **`getTopCoursesData`** | HTTPS Callable | **Não Desativar (Dashboard)** | API chamada pelo painel administrativo para puxar o ranking de engajamento dos cursos. |
| **`sendBulkEmail`** / **`sendDirectEmail`** | HTTPS Callable | **Não Desativar (Crítica)** | Responsável pelo envio de e-mails transacionais e comunicados do sistema. |

---

## 💡 Estratégia Recomendada para Redução de Custos

Para manter o painel administrativo funcional sem pagar pelas milhares de invocações diárias causadas pelas interações dos usuários no app (cliques em orações, áudios, glossário, etc.):

1.  **Desativar os Triggers de Log (coluna "Pode Desativar" da tabela):** Isso reduzirá instantaneamente as execuções de Functions em mais de 70% em momentos de pico.
2.  **Executar Sincronização Sob Demanda:** Em vez de atualizar os contadores em tempo real, use a Cloud Function `syncAllStats` de forma manual ou em um script semanal no painel do administrador para re-calcular todos os números e recalibrar os dados apenas no momento em que você precisar de relatórios de auditoria reais.
