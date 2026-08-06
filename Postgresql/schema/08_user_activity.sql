-- =============================================================================
-- Script DDL: 08_user_activity.sql
-- Descrição: Progresso do Usuário, Certificados, Favoritos, Verdadeiro ou Falso, Notificações e Feedbacks
-- =============================================================================

-- Matrícula e Progresso do Usuário nos Cursos
CREATE TABLE user_course_progress (
  id VARCHAR(128) PRIMARY KEY, -- ex: ${userId}_${courseId}
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  last_lesson_id VARCHAR(128) REFERENCES lessons(id) ON DELETE SET NULL,
  completed_lessons JSONB DEFAULT '[]'::jsonb NOT NULL, -- Array de IDs das lições concluídas
  exercise_results JSONB DEFAULT '[]'::jsonb NOT NULL, -- Array de IExerciseResult
  final_grade NUMERIC(5, 2),
  certificate_eligible BOOLEAN DEFAULT FALSE NOT NULL,
  certificate_issued BOOLEAN DEFAULT FALSE NOT NULL,
  certificate_issued_at TIMESTAMPTZ,
  certificate_url TEXT,
  course_title VARCHAR(255),
  course_lesson_count INT,
  last_lesson_title VARCHAR(255),
  last_lesson_order INT,
  started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  last_accessed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, course_id)
);

-- Certificados de Conclusão Emitidos
CREATE TABLE certificates (
  id VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  student_name VARCHAR(255) NOT NULL,
  student_email VARCHAR(255) NOT NULL,
  student_document VARCHAR(100),
  course_title VARCHAR(255) NOT NULL,
  course_author VARCHAR(255) NOT NULL,
  course_workload_minutes INT DEFAULT 0 NOT NULL,
  final_grade NUMERIC(5, 2) DEFAULT 0.00 NOT NULL,
  lessons_completed INT DEFAULT 0 NOT NULL,
  exercises_completed INT DEFAULT 0 NOT NULL,
  certificate_number VARCHAR(100) UNIQUE NOT NULL,
  pdf_url TEXT NOT NULL,
  validation_code VARCHAR(100) UNIQUE NOT NULL,
  validation_url TEXT NOT NULL,
  issued_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Orações Favoritadas pelo Usuário
CREATE TABLE user_prayer_favorites (
  id VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  prayer_id VARCHAR(128) NOT NULL REFERENCES prayers(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, prayer_id)
);

-- Reflexões Favoritadas pelo Usuário
CREATE TABLE user_reflection_favorites (
  id VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reflection_id VARCHAR(128) NOT NULL REFERENCES reflections(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, reflection_id)
);

-- Perguntas do Módulo Verdadeiro ou Falso
CREATE TABLE truth_or_false_questions (
  id VARCHAR(128) PRIMARY KEY,
  topic VARCHAR(100) NOT NULL,
  question TEXT NOT NULL,
  correct BOOLEAN NOT NULL,
  explanation TEXT NOT NULL,
  reference TEXT NOT NULL,
  difficulty truth_or_false_difficulty DEFAULT 'Médio' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Respostas do Usuário no Verdadeiro ou Falso
CREATE TABLE user_truth_or_false_responses (
  id VARCHAR(128) PRIMARY KEY, -- formato: `${userId}_${dateString}` ou UUID
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  question_id VARCHAR(128) NOT NULL REFERENCES truth_or_false_questions(id) ON DELETE CASCADE,
  user_answer BOOLEAN NOT NULL,
  is_correct BOOLEAN NOT NULL,
  time_spent INT DEFAULT 0 NOT NULL, -- em segundos
  saved_to_library BOOLEAN DEFAULT FALSE NOT NULL,
  responded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Notificações dos Usuários
CREATE TABLE user_notifications (
  id VARCHAR(128) PRIMARY KEY,
  type notification_type NOT NULL,
  to_user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_user_id VARCHAR(128) REFERENCES users(id) ON DELETE SET NULL,
  course_id VARCHAR(128) REFERENCES courses(id) ON DELETE SET NULL,
  lesson_id VARCHAR(128) REFERENCES lessons(id) ON DELETE SET NULL,
  comment_id VARCHAR(128) REFERENCES forum_comments(id) ON DELETE CASCADE,
  reaction_type forum_reaction_type,
  from_user_name VARCHAR(255),
  lesson_title VARCHAR(255),
  title VARCHAR(255),
  body TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  read_at TIMESTAMPTZ
);

-- Feedbacks e Avaliações de Cursos
CREATE TABLE course_feedbacks (
  id VARCHAR(128) PRIMARY KEY,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name VARCHAR(255),
  user_email VARCHAR(255),
  rating INT CHECK (rating >= 1 AND rating <= 5) NOT NULL,
  comment TEXT,
  viewed_at TIMESTAMPTZ,
  viewed_by_uid VARCHAR(128),
  viewed_by_email VARCHAR(255),
  replied_at TIMESTAMPTZ,
  replied_by_uid VARCHAR(128),
  replied_by_email VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);
