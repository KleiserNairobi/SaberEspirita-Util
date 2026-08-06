# Mapeamento de Entidades: Firestore / TypeScript ➔ PostgreSQL

Este documento apresenta a matriz detalhada de conversão de dados do NoSQL (Firebase Firestore e interfaces TypeScript dos projetos `SaberEspirita-Expo` e `SaberEspirita-Web`) para o banco de dados relacional PostgreSQL.

---

## 🔍 Resumo Geral do Mapeamento

| Coleção / Entidade TypeScript | Tabela PostgreSQL | Descrição |
| :--- | :--- | :--- |
| `users/{userId}` | `users` | Perfil e cadastro de usuários do aplicativo |
| `users_scores/{userId}` | `user_scores` | Pontuação acumulada para o Leaderboard |
| `community_progress/{userId}` | `user_community_progress` | Nível comunitário e conquistas sociais do usuário |
| `chatLimits/{userId}` | `user_chat_limits` | Limite de uso diário de chatbots de IA |
| `banned_devices`, `blocked_emails`, `blocked_domains` | `banned_devices`, `blocked_emails`, `blocked_domains` | Moderação e segurança |
| `categories/{docId}` (Cursos) | `course_categories` | Categorias temáticas de cursos |
| `courses/{courseId}` | `courses` | Cursos espíritas cadastrados |
| `courses/{courseId}/lessons/{lessonId}` | `lessons` | Aulas do curso, incluindo slides em JSONB |
| `exercises/{docId}` | `exercises` | Exercícios práticos e avaliações |
| `exercises` (dissertativas) | `essay_questions` | Pergunta com critério de avaliação dissertativa |
| `quizes/{docId}` (Categorias CLI) | `quiz_categories`, `quiz_subcategories` | Categorias e subcategorias do módulo FIXE |
| `quizes/{docId}` | `quizzes`, `quiz_questions` | Quizzes e suas respectivas perguntas |
| `users_history/{userId}` | `user_quiz_history` | Histórico de tentativas de quizzes pelo usuário |
| `quiz_reports/{docId}` | `quiz_reports` | Reportes de erros em questões |
| `glossary/{docId}` | `glossary_terms` | Glossário de termos espíritas e doutrinários |
| `reflections/{docId}` | `reflections` | Reflexões diárias |
| `meditations/{docId}` | `meditations`, `meditation_categories` | Meditações guiadas e faixas |
| `podcasts/{docId}` | `podcasts` | Episódios de podcast |
| `prayers/{docId}` | `prayers` | Orações |
| `prayer_categories/{docId}` | `prayer_categories` | Categorias temáticas de oração |
| `prayer_category_links/{docId}` | `prayer_category_links` | Relacionamento N:N entre oração e categoria |
| `ambient_audios` | `ambient_audios` | Faixas do player ambiente |
| `lesson_forums/{lessonId}/comments/{commentId}` | `forum_comments` | Comentários nas aulas |
| `.../comments/{commentId}/reactions/{userId}` | `forum_comment_reactions` | Reações nos comentários do fórum |
| `users/{userId}/courseProgress/{courseId}` | `user_course_progress` | Matrícula e progresso do aluno nos cursos |
| `certificates/{certificateId}` | `certificates` | Certificados de conclusão emitidos |
| `user_prayer_favorites/{userId}` | `user_prayer_favorites` | Orações favoritadas pelo usuário |
| `user_reflection_favorites/{userId}` | `user_reflection_favorites` | Reflexões favoritadas pelo usuário |
| `truth_or_false_questions` | `truth_or_false_questions` | Perguntas do jogo Verdadeiro ou Falso |
| `user_truth_or_false_responses` | `user_truth_or_false_responses` | Respostas históricas de V/F |
| `users/{userId}/notifications/{notificationId}` | `user_notifications` | Notificações do aplicativo |
| `course_feedbacks/{docId}` | `course_feedbacks` | Avaliações e notas dos cursos |
| `daily_stats/{docId}`, `global_stats/{docId}` | `daily_stats`, `global_stats` | Estatísticas agregadas de acesso |
| `item_stats/{docId}` | `item_stats` | Métrica de acessos por conteúdo |
| `{logCol}/{logId}` | `app_logs` | Logs unificados de auditoria de uso |

---

## 📐 Detalhamento dos Campos e Tipos de Dados

### 1. Cursos e Conteúdo Didático (`ICourse`, `ILesson`)
- **JSONB para Slides (`slides`)**: Os slides de cada aula contêm tipos variáveis (`text`, `image`, `highlight`, `reference`) com objetos aninhados. No Postgres, `slides JSONB` mantém a flexibilidade sem perda de tipos ou schemas rígidos.
- **Configuração de Certificação (`certification`)**: Mapeado para `certification_enabled BOOLEAN`, `certification_min_grade NUMERIC`, etc., e também duplicado no objeto desnormalizado `certification_config JSONB`.

### 2. Quizzes e Exercícios (`IQuiz`, `IQuestion`, `IExercise`)
- **Alternativas (`alternatives`)**: Array de opções de resposta mantido como `JSONB` (`["Alternativa A", "Alternativa B", ...]`).
- **Histórico de Tentativas (`IExerciseAttempt`)**: Salvo em `exercise_attempts` com a coluna `answers JSONB` para armazenar as respostas fornecidas em cada tentativa.

### 3. Fórum e Comunidade (`ForumComment`, `CommunityProgress`)
- **Contagem de Reações (`reactions`)**: Mantido em colunas separadas (`reactions_me_tocou`, `reactions_aprendi_algo`, etc.) na tabela `forum_comments` para otimizar agregações rápidas.
- **Tabela de Reações Únicas (`forum_comment_reactions`)**: Mantém a chave composta `(comment_id, user_id)` garantindo que o usuário só reaja uma única vez com cada tipo de reação.

### 4. Notificações e Atividades (`NotificationItem`)
- **Nulos Opcionais**: Campos como `course_id`, `lesson_id`, `comment_id` e `reaction_type` são nulos (`NULL`) quando a notificação é do tipo `admin_broadcast`.

---

## 🛡️ Regras de Chaves e Integridade Relacional

1. **Chaves Primárias (`PRIMARY KEY`)**: `VARCHAR(128)` para suportar qualquer chave de documento alfanumérica do Firebase Auth UID e Firestore (ex: `vw3XkL9s8Z...`).
2. **Chaves Estrangeiras (`FOREIGN KEY`)**: Definidas com `ON DELETE CASCADE` ou `ON DELETE SET NULL` conforme o nível de dependência (ex: se um curso for removido, suas aulas são excluídas em cascata; se um usuário for deletado, suas notificações associadas são limpas).
3. **Timestamps**: Convertidos para `TIMESTAMPTZ` (Timestamp com Fuso Horário - `WITH TIME ZONE`) no PostgreSQL para total precisão global.
