-- =============================================================================
-- Script DDL: 10_views_indexes.sql
-- Descrição: Índices de Alta Performance e Views Relacionais (Leaderboard/Ranking)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ÍNDICES DE DESEMPENHO
-- -----------------------------------------------------------------------------

-- Índices em Usuários e Pontuações
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_scores_score ON user_scores(score DESC);
CREATE INDEX idx_user_scores_week ON user_scores(total_this_week DESC);
CREATE INDEX idx_user_scores_month ON user_scores(total_this_month DESC);

-- Índices em Cursos e Lições
CREATE INDEX idx_courses_status ON courses(status);
CREATE INDEX idx_courses_category ON courses(category_id);
CREATE INDEX idx_lessons_course_order ON lessons(course_id, order_index);
CREATE INDEX idx_lessons_status ON lessons(status);

-- Índices em Exercícios e Avaliações
CREATE INDEX idx_exercises_course ON exercises(course_id);
CREATE INDEX idx_exercises_lesson ON exercises(lesson_id);
CREATE INDEX idx_exercise_results_user ON exercise_results(user_id);
CREATE INDEX idx_exercise_attempts_result ON exercise_attempts(result_id);

-- Índices no Módulo de Quizzes
CREATE INDEX idx_quiz_subcategories_cat ON quiz_subcategories(category_id);
CREATE INDEX idx_quizzes_subcategory ON quizzes(subcategory_id);
CREATE INDEX idx_quiz_questions_quiz ON quiz_questions(quiz_id);
CREATE INDEX idx_user_quiz_history_user ON user_quiz_history(user_id, completed_at DESC);

-- Índices no Fórum de Aulas
CREATE INDEX idx_forum_comments_lesson ON forum_comments(lesson_id, created_at DESC);
CREATE INDEX idx_forum_comments_course ON forum_comments(course_id);
CREATE INDEX idx_forum_comments_user ON forum_comments(user_id);
CREATE INDEX idx_forum_comment_reactions_comment ON forum_comment_reactions(comment_id);

-- Índices em Atividade do Usuário e Progresso
CREATE INDEX idx_user_course_progress_user ON user_course_progress(user_id);
CREATE INDEX idx_user_course_progress_course ON user_course_progress(course_id);
CREATE INDEX idx_certificates_user ON certificates(user_id);
CREATE INDEX idx_certificates_number ON certificates(certificate_number);
CREATE INDEX idx_certificates_code ON certificates(validation_code);
CREATE INDEX idx_user_notifications_to_user ON user_notifications(to_user_id, read_at);

-- Índices em Logs de Aplicação
CREATE INDEX idx_app_logs_log_type_created ON app_logs(log_type, created_at DESC);
CREATE INDEX idx_app_logs_user ON app_logs(user_id);

-- -----------------------------------------------------------------------------
-- VIEWS RELACIONAIS
-- -----------------------------------------------------------------------------

-- View Dinâmica de Leaderboard / Ranking Geral
CREATE OR REPLACE VIEW view_leaderboard AS
SELECT
  us.user_id,
  COALESCE(u.display_name, 'Usuário Espírita') AS user_name,
  u.photo_url,
  us.score,
  us.total_all_time,
  us.total_this_week,
  us.total_this_month,
  DENSE_RANK() OVER (ORDER BY us.score DESC) AS position,
  us.level
FROM user_scores us
LEFT JOIN users u ON us.user_id = u.id;
