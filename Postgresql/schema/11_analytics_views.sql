-- =============================================================================
-- Script DDL: 11_analytics_views.sql
-- Descrição: Views Dinâmicas para Analytics de Cursos, Progresso de Alunos e KPIs Globais
-- Fase: Fase 1 (Preparação Passiva - Segura para Criar Antes da Importação)
-- =============================================================================

-- 1. View de Estatísticas Consolidadas dos Cursos (Ranking e Taxa de Conclusão)
-- Substitui a Cloud Function 'getTopCoursesData' e o processamento em memória no JavaScript.
CREATE OR REPLACE VIEW view_course_analytics AS
SELECT 
  c.id AS course_id,
  c.title,
  c.author,
  c.lesson_count,
  COALESCE(COUNT(ucp.user_id), 0) AS student_count,
  COALESCE(COUNT(CASE WHEN ucp.completed_at IS NOT NULL THEN 1 END), 0) AS completed_count,
  CASE 
    WHEN COUNT(ucp.user_id) > 0 THEN 
      ROUND((COUNT(CASE WHEN ucp.completed_at IS NOT NULL THEN 1 END)::numeric / COUNT(ucp.user_id)::numeric) * 100)
    ELSE 0 
  END AS completion_rate
FROM courses c
LEFT JOIN user_course_progress ucp ON c.id = ucp.course_id
GROUP BY c.id, c.title, c.author, c.lesson_count;

-- 2. View de Detalhamento do Progresso dos Alunos por Curso
-- Substitui o carregamento em lotes e junção client-side do 'getCourseManagementData'.
CREATE OR REPLACE VIEW view_student_course_progress AS
SELECT 
  ucp.course_id,
  ucp.user_id,
  COALESCE(u.display_name, u.email) AS display_name,
  u.email,
  ucp.completed_lessons,
  CASE 
    WHEN ucp.course_lesson_count > 0 THEN 
      LEAST(100, ROUND((jsonb_array_length(ucp.completed_lessons)::numeric / ucp.course_lesson_count::numeric) * 100))
    ELSE 0 
  END AS completion_percent,
  ucp.started_at,
  ucp.last_accessed_at,
  (ucp.completed_at IS NOT NULL) AS is_completed,
  cf.comment AS feedback_comment,
  cf.rating AS feedback_rating
FROM user_course_progress ucp
JOIN users u ON ucp.user_id = u.id
LEFT JOIN course_feedbacks cf ON ucp.user_id = cf.user_id AND ucp.course_id = cf.course_id;

-- 3. View de Métricas Globais de Engajamento em Tempo Real
-- Substitui as 15 chamadas em paralelo de 'getKeyMetrics' do Firestore.
CREATE OR REPLACE VIEW view_real_global_stats AS
SELECT
  (SELECT COUNT(*) FROM users) AS total_students,
  (SELECT COUNT(*) FROM users WHERE last_active_at > NOW() - INTERVAL '30 days') AS active_users,
  (SELECT COUNT(*) FROM user_quiz_history) AS total_quizzes_taken,
  (SELECT COUNT(*) FROM user_course_progress WHERE completed_at IS NOT NULL) AS total_lessons_completed,
  -- Contadores agregados na tabela global_stats (para eventos vindos de logs e outras fontes)
  COALESCE(gs.total_prayers_read, 0) AS total_prayers_read,
  COALESCE(gs.total_reflections_read, 0) AS total_reflections_read,
  COALESCE(gs.total_meditations_completed, 0) AS total_meditations_completed,
  COALESCE(gs.total_glossary_views, 0) AS total_glossary_views,
  COALESCE(gs.total_scientific_chat_messages, 0) AS total_scientific_chat_messages,
  COALESCE(gs.total_emotional_chat_messages, 0) AS total_emotional_chat_messages,
  COALESCE(gs.total_daily_challenge_completions, 0) AS total_daily_challenge_completions,
  COALESCE(gs.total_truth_or_false_answers, 0) AS total_truth_or_false_answers,
  COALESCE(gs.total_ambient_player_plays, 0) AS total_ambient_player_plays,
  COALESCE(gs.total_podcasts_played, 0) AS total_podcasts_played
FROM global_stats gs
WHERE gs.id = 'current';
