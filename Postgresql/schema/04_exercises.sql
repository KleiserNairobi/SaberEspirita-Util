-- =============================================================================
-- Script DDL: 04_exercises.sql
-- Descrição: Tabelas de Exercícios de Cursos, Perguntas Dissertativas e Histórico de Tentativas
-- =============================================================================

-- Tabela de Exercícios
CREATE TABLE exercises (
  id VARCHAR(128) PRIMARY KEY,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  lesson_id VARCHAR(128) REFERENCES lessons(id) ON DELETE CASCADE,
  module_id VARCHAR(128),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  order_index INT DEFAULT 0 NOT NULL,
  type exercise_type DEFAULT 'QUIZ' NOT NULL,
  weight NUMERIC(5, 2) DEFAULT 1.00 NOT NULL,
  passing_grade NUMERIC(5, 2) DEFAULT 70.00 NOT NULL,
  max_attempts INT,
  time_limit INT, -- em minutos
  status exercise_status DEFAULT 'DRAFT' NOT NULL,
  quiz_id VARCHAR(128), -- referência ao quiz do banco de quizzes se aplicável
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Perguntas Dissertativas do Exercício
CREATE TABLE essay_questions (
  id VARCHAR(128) PRIMARY KEY,
  exercise_id VARCHAR(128) NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  expected_answer TEXT,
  max_words INT,
  min_words INT,
  order_index INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Resultado consolidado do usuário no Exercício
CREATE TABLE exercise_results (
  id VARCHAR(128) PRIMARY KEY, -- ex: ${userId}_${exerciseId}
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_id VARCHAR(128) NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  best_score NUMERIC(5, 2) DEFAULT 0.00 NOT NULL,
  passed BOOLEAN DEFAULT FALSE NOT NULL,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, exercise_id)
);

-- Tentativas individuais de resolução do exercício
CREATE TABLE exercise_attempts (
  id VARCHAR(128) PRIMARY KEY,
  result_id VARCHAR(128) NOT NULL REFERENCES exercise_results(id) ON DELETE CASCADE,
  attempt_number INT NOT NULL,
  score NUMERIC(5, 2) NOT NULL,
  answers JSONB DEFAULT '[]'::jsonb NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ NOT NULL,
  time_spent INT DEFAULT 0 NOT NULL, -- em segundos
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
