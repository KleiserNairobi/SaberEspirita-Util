-- =============================================================================
-- Script DDL: 06_content.sql
-- Descrição: Glossário, Reflexões, Meditações, Podcasts, Orações e Áudios Ambientes
-- =============================================================================

-- Glossário Espírita
CREATE TABLE glossary_terms (
  id VARCHAR(128) PRIMARY KEY,
  term VARCHAR(255) NOT NULL,
  definition TEXT NOT NULL,
  category glossary_category DEFAULT 'Doutrina Básica' NOT NULL,
  references JSONB DEFAULT '[]'::jsonb NOT NULL,
  related_terms JSONB DEFAULT '[]'::jsonb NOT NULL,
  synonyms JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Reflexões Diárias
CREATE TABLE reflections (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  subtitle TEXT,
  content TEXT NOT NULL,
  author VARCHAR(255),
  source VARCHAR(255),
  image_url TEXT,
  reading_time_minutes INT DEFAULT 1 NOT NULL,
  topic VARCHAR(100) NOT NULL,
  tags JSONB DEFAULT '[]'::jsonb,
  featured BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Categorias de Meditação
CREATE TABLE meditation_categories (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  image TEXT,
  meditation_count INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Meditações Guiadas
CREATE TABLE meditations (
  id VARCHAR(128) PRIMARY KEY,
  category_id VARCHAR(128) REFERENCES meditation_categories(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  author VARCHAR(255) NOT NULL,
  duration_minutes INT DEFAULT 0 NOT NULL,
  audio_url TEXT NOT NULL,
  image_url TEXT,
  is_premium BOOLEAN DEFAULT FALSE NOT NULL,
  featured BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Episódios de Podcast
CREATE TABLE podcasts (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  author VARCHAR(255) NOT NULL,
  duration_minutes INT DEFAULT 0 NOT NULL,
  audio_url TEXT NOT NULL,
  image_url TEXT,
  is_premium BOOLEAN DEFAULT FALSE NOT NULL,
  featured BOOLEAN DEFAULT FALSE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Categorias de Oração
CREATE TABLE prayer_categories (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  image TEXT,
  prayer_count INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Orações
CREATE TABLE prayers (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  source VARCHAR(255),
  author VARCHAR(255),
  featured BOOLEAN DEFAULT FALSE NOT NULL,
  views_day INT DEFAULT 0 NOT NULL,
  views_week INT DEFAULT 0 NOT NULL,
  views_total INT DEFAULT 0 NOT NULL,
  categories JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Vínculo de N:N entre Orações e Categorias
CREATE TABLE prayer_category_links (
  id VARCHAR(128) PRIMARY KEY,
  prayer_id VARCHAR(128) NOT NULL REFERENCES prayers(id) ON DELETE CASCADE,
  category_id VARCHAR(128) NOT NULL REFERENCES prayer_categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(prayer_id, category_id)
);

-- Áudios Ambientes do Player
CREATE TABLE ambient_audios (
  id VARCHAR(128) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  file_name VARCHAR(255),
  storage_path TEXT,
  icon ambient_audio_icon DEFAULT 'music' NOT NULL,
  type VARCHAR(50) DEFAULT 'music',
  url TEXT,
  local_uri TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
