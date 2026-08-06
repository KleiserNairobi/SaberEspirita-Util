-- =============================================================================
-- Script DDL: 02_users.sql
-- Descrição: Tabelas relativas a usuários, perfis, pontuação e segurança/moderação
-- =============================================================================

-- Tabela principal de usuários
CREATE TABLE users (
  id VARCHAR(128) PRIMARY KEY, -- UID do Firebase Auth ou ID personalizado
  email VARCHAR(255) UNIQUE,
  display_name VARCHAR(255),
  photo_url TEXT,
  is_anonymous BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMPTZ
);

-- Tabela de pontuações e rankings (utilizada pelo Leaderboard)
CREATE TABLE user_scores (
  user_id VARCHAR(128) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  score INT DEFAULT 0 NOT NULL,
  total_all_time INT DEFAULT 0,
  total_this_week INT DEFAULT 0,
  total_this_month INT DEFAULT 0,
  position INT,
  level VARCHAR(100) DEFAULT 'Iniciante',
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de progresso social e nível da comunidade
CREATE TABLE user_community_progress (
  user_id VARCHAR(128) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  community_level_id community_level_id DEFAULT 'sementeiro' NOT NULL,
  lessons_completed INT DEFAULT 0 NOT NULL,
  courses_completed INT DEFAULT 0 NOT NULL,
  forum_comments INT DEFAULT 0 NOT NULL,
  reactions_received JSONB DEFAULT '{"me_tocou": 0, "aprendi_algo": 0, "quero_refletir": 0, "gratidao": 0, "luz": 0, "total": 0}'::jsonb NOT NULL,
  active_days INT DEFAULT 0 NOT NULL,
  last_active_at TIMESTAMPTZ,
  has_course_over_50 BOOLEAN DEFAULT FALSE NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Limites diários de uso de Chatbot / IA por usuário
CREATE TABLE user_chat_limits (
  user_id VARCHAR(128) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_scientific_count INT DEFAULT 0 NOT NULL,
  daily_emotional_count INT DEFAULT 0 NOT NULL,
  last_reset_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Moderação: Dispositivos Banidos
CREATE TABLE banned_devices (
  device_id VARCHAR(255) PRIMARY KEY,
  reason TEXT,
  banned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Moderação: E-mails Bloqueados
CREATE TABLE blocked_emails (
  email VARCHAR(255) PRIMARY KEY,
  reason TEXT,
  blocked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Moderação: Domínios Bloqueados
CREATE TABLE blocked_domains (
  domain VARCHAR(255) PRIMARY KEY,
  reason TEXT,
  blocked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
