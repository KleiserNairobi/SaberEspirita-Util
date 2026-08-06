-- =============================================================================
-- Script DDL: 03_courses.sql
-- Descrição: Tabelas de Cursos, Categorias, Aulas, Slides e Conteúdos didáticos
-- =============================================================================

-- Categorias de Cursos
CREATE TABLE course_categories (
  id VARCHAR(128) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  icon_name VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tabela Principal de Cursos
CREATE TABLE courses (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  order_index INT DEFAULT 0 NOT NULL,
  workload_minutes INT DEFAULT 0 NOT NULL,
  difficulty_level course_difficulty_level DEFAULT 'Iniciante' NOT NULL,
  author VARCHAR(255) NOT NULL,
  lesson_count INT DEFAULT 0 NOT NULL,
  image_url TEXT,
  category_id VARCHAR(128) REFERENCES course_categories(id) ON DELETE SET NULL,
  release_year INT,
  featured BOOLEAN DEFAULT FALSE NOT NULL,
  status course_status DEFAULT 'DRAFT' NOT NULL,
  allow_new_enrollments BOOLEAN DEFAULT TRUE NOT NULL,
  certification_config JSONB DEFAULT '{"enabled": true, "minimumGrade": 70, "requiredLessonsPercent": 100, "requiredExercisesPercent": 100}'::jsonb NOT NULL,
  rating NUMERIC(3, 2),
  average_rating NUMERIC(3, 2),
  rating_count INT DEFAULT 0,
  has_forum BOOLEAN DEFAULT TRUE NOT NULL,
  stats JSONB DEFAULT '{"exerciseCount": 0, "totalDurationMinutes": 0, "enrolledStudents": 0, "completionRate": 0}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Lições / Aulas
CREATE TABLE lessons (
  id VARCHAR(128) PRIMARY KEY,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  module_id VARCHAR(128),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  order_index INT DEFAULT 0 NOT NULL,
  slides JSONB DEFAULT '[]'::jsonb NOT NULL, -- Array de objetos ISlide (slideType, title, content, imagePrompt, highlights, references)
  duration_minutes INT DEFAULT 0 NOT NULL,
  source TEXT,
  chapter TEXT,
  forum_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  forum_prompt TEXT,
  forum_focus_tag VARCHAR(100),
  status lesson_status DEFAULT 'DRAFT' NOT NULL,
  video_url TEXT,
  audio_url TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Materiais Complementares da Aula
CREATE TABLE lesson_supplementary_materials (
  id VARCHAR(128) PRIMARY KEY,
  lesson_id VARCHAR(128) NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type material_type DEFAULT 'PDF' NOT NULL,
  url TEXT,
  file_url TEXT,
  content TEXT,
  order_index INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Perguntas de Reflexão da Aula
CREATE TABLE lesson_reflection_questions (
  id VARCHAR(128) PRIMARY KEY,
  lesson_id VARCHAR(128) NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  focus VARCHAR(100) NOT NULL, -- "Autoconhecimento" | "Aplicação prática" | "Transformação moral"
  order_index INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
