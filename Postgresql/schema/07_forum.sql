-- =============================================================================
-- Script DDL: 07_forum.sql
-- Descrição: Tabelas do Fórum de Discussão das Lições (Comentários e Reações)
-- =============================================================================

-- Tabela de Comentários no Fórum de Aulas
CREATE TABLE forum_comments (
  id VARCHAR(128) PRIMARY KEY,
  lesson_id VARCHAR(128) NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name VARCHAR(255) NOT NULL,
  user_avatar TEXT,
  is_anonymous BOOLEAN DEFAULT FALSE NOT NULL,
  user_community_level community_level_id DEFAULT 'sementeiro' NOT NULL,
  content VARCHAR(600) NOT NULL,
  reactions_me_tocou INT DEFAULT 0 NOT NULL,
  reactions_aprendi_algo INT DEFAULT 0 NOT NULL,
  reactions_quero_refletir INT DEFAULT 0 NOT NULL,
  reactions_gratidao INT DEFAULT 0 NOT NULL,
  reactions_luz INT DEFAULT 0 NOT NULL,
  reactions_total INT DEFAULT 0 NOT NULL,
  is_deleted BOOLEAN DEFAULT FALSE NOT NULL,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Reações Individuais nos Comentários do Fórum
CREATE TABLE forum_comment_reactions (
  id VARCHAR(128) PRIMARY KEY, -- ex: ${commentId}_${userId}
  comment_id VARCHAR(128) NOT NULL REFERENCES forum_comments(id) ON DELETE CASCADE,
  lesson_id VARCHAR(128) NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  course_id VARCHAR(128) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction_type forum_reaction_type NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(comment_id, user_id)
);
