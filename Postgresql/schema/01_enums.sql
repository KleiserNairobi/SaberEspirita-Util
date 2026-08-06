-- =============================================================================
-- Script DDL: 01_enums.sql
-- Descrição: Definição de todos os tipos enumerados (ENUMs) do PostgreSQL
-- =============================================================================

-- Nível de dificuldade dos cursos
CREATE TYPE course_difficulty_level AS ENUM (
  'Iniciante',
  'Intermediário',
  'Avançado'
);

-- Status de publicação de cursos
CREATE TYPE course_status AS ENUM (
  'PUBLISHED',
  'COMING_SOON',
  'DRAFT',
  'LEGACY'
);

-- Status de publicação de aulas
CREATE TYPE lesson_status AS ENUM (
  'PUBLISHED',
  'COMING_SOON',
  'DRAFT'
);

-- Tipos de slides de uma aula
CREATE TYPE slide_type AS ENUM (
  'text',
  'image',
  'highlight',
  'reference'
);

-- Tipos de exercícios
CREATE TYPE exercise_type AS ENUM (
  'QUIZ',
  'TRUE_FALSE',
  'ESSAY',
  'MIXED'
);

-- Status de publicação de exercícios
CREATE TYPE exercise_status AS ENUM (
  'PUBLISHED',
  'COMING_SOON',
  'DRAFT'
);

-- Tipos de materiais complementares
CREATE TYPE material_type AS ENUM (
  'PDF',
  'LINK',
  'TEXT',
  'VIDEO',
  'AUDIO',
  'REFERENCE'
);

-- Tipos de reações no fórum
CREATE TYPE forum_reaction_type AS ENUM (
  'me_tocou',
  'aprendi_algo',
  'quero_refletir',
  'gratidao',
  'luz'
);

-- Níveis do usuário na comunidade
CREATE TYPE community_level_id AS ENUM (
  'sementeiro',
  'cultivador',
  'arvore_frondosa'
);

-- Tipos de notificações
CREATE TYPE notification_type AS ENUM (
  'forum_reaction_received',
  'forum_new_comment_thread',
  'admin_broadcast'
);

-- Categorias de glossário espírita
CREATE TYPE glossary_category AS ENUM (
  'Doutrina Básica',
  'Mediunidade',
  'Moral e Ética',
  'Ciência Espírita',
  'Evangelho',
  'Filosofia Espírita'
);

-- Momentos de Oração
CREATE TYPE prayer_moment AS ENUM (
  'AO-ACORDAR',
  'AO-DORMIR',
  'DIARIO',
  'POR-ANIMO',
  'POR-ALGUEM',
  'POR-CURA',
  'POR-GRATIDAO',
  'POR-PAZ',
  'REUNIOES'
);

-- Nível de desempenho no histórico de quiz
CREATE TYPE quiz_history_level AS ENUM (
  'Ótimo',
  'Bom',
  'Regular',
  'Fraco'
);

-- Dificuldade no Verdadeiro ou Falso
CREATE TYPE truth_or_false_difficulty AS ENUM (
  'Fácil',
  'Médio',
  'Difícil'
);

-- Ícones do Player Ambiente
CREATE TYPE ambient_audio_icon AS ENUM (
  'music',
  'waves',
  'moon'
);
