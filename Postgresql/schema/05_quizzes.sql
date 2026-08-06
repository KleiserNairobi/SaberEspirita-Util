-- =============================================================================
-- Script DDL: 05_quizzes.sql
-- Descrição: Tabelas do Módulo FIXE (Quizzes), Categorias, Questões e Histórico de Desempenho
-- =============================================================================

-- Categorias Gerais de Quizzes
CREATE TABLE quiz_categories (
  id VARCHAR(128) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  question_count INT DEFAULT 0 NOT NULL,
  subcategory_count INT DEFAULT 0 NOT NULL,
  icon VARCHAR(100) DEFAULT 'HelpCircle' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Subcategorias de Quizzes
CREATE TABLE quiz_subcategories (
  id VARCHAR(128) PRIMARY KEY,
  category_id VARCHAR(128) NOT NULL REFERENCES quiz_categories(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  question_count INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Quizzes (coleção principal agrupando perguntas por subcategoria)
CREATE TABLE quizzes (
  id VARCHAR(128) PRIMARY KEY,
  category_id VARCHAR(128) NOT NULL REFERENCES quiz_categories(id) ON DELETE CASCADE,
  subcategory_id VARCHAR(128) NOT NULL REFERENCES quiz_subcategories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Questões do Quiz
CREATE TABLE quiz_questions (
  id VARCHAR(128) PRIMARY KEY,
  quiz_id VARCHAR(128) NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  alternatives JSONB DEFAULT '[]'::jsonb NOT NULL, -- Array de strings com opções
  correct_index INT NOT NULL, -- Índice da opção correta (0-based)
  explanation TEXT,
  origin_category VARCHAR(255),
  origin_subcategory VARCHAR(255),
  origin_subcategory_subtitle TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Histórico de Quizzes Realizados pelo Usuário
CREATE TABLE user_quiz_history (
  id VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id VARCHAR(128) NOT NULL REFERENCES quiz_categories(id) ON DELETE CASCADE,
  subcategory_id VARCHAR(128) NOT NULL REFERENCES quiz_subcategories(id) ON DELETE CASCADE,
  quiz_id VARCHAR(128) NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL, -- Nome da categoria
  subtitle VARCHAR(255) NOT NULL, -- Nome da subcategoria
  completed BOOLEAN DEFAULT TRUE NOT NULL,
  score NUMERIC(5, 2) DEFAULT 0.00 NOT NULL,
  total_questions INT DEFAULT 0 NOT NULL,
  correct_answers INT DEFAULT 0 NOT NULL,
  percentage NUMERIC(5, 2) DEFAULT 0.00 NOT NULL,
  level quiz_history_level DEFAULT 'Regular' NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Reportes de Erros ou Problemas em Perguntas de Quiz
CREATE TABLE quiz_reports (
  id VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quiz_id VARCHAR(128) REFERENCES quizzes(id) ON DELETE SET NULL,
  question_id VARCHAR(128),
  reason TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'PENDING' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
