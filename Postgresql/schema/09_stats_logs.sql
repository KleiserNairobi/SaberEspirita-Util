-- =============================================================================
-- Script DDL: 09_stats_logs.sql
-- Descrição: Estatísticas Agregadas (Diárias e Globais), Métricas por Item e Logs do Sistema
-- =============================================================================

-- Estatísticas Diárias de Engajamento
CREATE TABLE daily_stats (
  date DATE PRIMARY KEY,
  new_users INT DEFAULT 0,
  prayer_sessions INT DEFAULT 0,
  prayer_sessions_guest INT DEFAULT 0,
  prayer_sessions_user INT DEFAULT 0,
  meditation_sessions INT DEFAULT 0,
  meditation_sessions_guest INT DEFAULT 0,
  meditation_sessions_user INT DEFAULT 0,
  quiz_attempts INT DEFAULT 0,
  general_quiz_attempts INT DEFAULT 0,
  lesson_quiz_attempts INT DEFAULT 0,
  lessons_completed INT DEFAULT 0,
  reflection_sessions INT DEFAULT 0,
  total_visits INT DEFAULT 0,
  guest_visits INT DEFAULT 0,
  user_visits INT DEFAULT 0,
  glossary_views INT DEFAULT 0,
  scientific_chat_messages INT DEFAULT 0,
  emotional_chat_messages INT DEFAULT 0,
  daily_challenge_completions INT DEFAULT 0,
  truth_or_false_answers INT DEFAULT 0,
  ambient_player_plays INT DEFAULT 0,
  podcasts_played INT DEFAULT 0,
  raw_data JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Estatísticas Globais Consolidadas
CREATE TABLE global_stats (
  id VARCHAR(128) PRIMARY KEY DEFAULT 'current',
  total_students INT DEFAULT 0,
  active_users INT DEFAULT 0,
  active_students_last_30_days INT DEFAULT 0,
  total_quizzes_taken INT DEFAULT 0,
  total_lesson_quizzes_taken INT DEFAULT 0,
  total_lessons_completed INT DEFAULT 0,
  total_prayers_read INT DEFAULT 0,
  total_reflections_read INT DEFAULT 0,
  total_meditations_completed INT DEFAULT 0,
  total_glossary_views INT DEFAULT 0,
  total_scientific_chat_messages INT DEFAULT 0,
  total_emotional_chat_messages INT DEFAULT 0,
  total_daily_challenge_completions INT DEFAULT 0,
  total_truth_or_false_answers INT DEFAULT 0,
  total_ambient_player_plays INT DEFAULT 0,
  total_podcasts_played INT DEFAULT 0,
  courses_metadata JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Contador e Métricas por Item individual (Meditação, Oração, Podcast, etc.)
CREATE TABLE item_stats (
  id VARCHAR(128) PRIMARY KEY, -- ex: meditation_stats/docId, podcast_stats/docId
  item_type VARCHAR(100) NOT NULL, -- "meditation", "ambient_player", "podcast", "prayer"
  title VARCHAR(255) NOT NULL,
  usage_count INT DEFAULT 0 NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Logs Unificados de Aplicação (lesson_logs, meditation_logs, quiz_logs, etc.)
CREATE TABLE app_logs (
  id VARCHAR(128) PRIMARY KEY,
  log_type VARCHAR(100) NOT NULL, -- "lesson_logs", "quiz_logs", "prayer_logs", "visit_logs", etc.
  user_id VARCHAR(128) NOT NULL, -- Pode ser Auth UID ou 'guest' / 'guest_...'
  processed BOOLEAN DEFAULT FALSE NOT NULL,
  payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);
