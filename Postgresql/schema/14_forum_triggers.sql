-- =============================================================================
-- Script DDL: 14_forum_triggers.sql
-- Descrição: Triggers do Fórum de Discussão, Reações e Emissão de Notificações
-- Fase: Fase 2 (Executar DEPOIS de concluir a migração dos dados históricos)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Criação de Comentários e Notificações de Linha de Discussão
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION on_forum_comment_created()
RETURNS TRIGGER AS $$
DECLARE
  v_recipient_id VARCHAR(128);
  v_lesson_title VARCHAR(255);
BEGIN
  -- 1. Obtém o título da aula
  SELECT title INTO v_lesson_title FROM lessons WHERE id = NEW.lesson_id;

  -- 2. Incrementa a contagem de comentários no progresso do autor
  UPDATE user_community_progress
  SET forum_comments = forum_comments + 1
  WHERE user_id = NEW.user_id;

  -- 3. Re-calcula o nível do autor
  PERFORM update_community_level(NEW.user_id);

  -- 4. Cria notificações para todos os outros que já comentaram nesta aula (thread)
  FOR v_recipient_id IN 
    SELECT DISTINCT user_id 
    FROM forum_comments 
    WHERE lesson_id = NEW.lesson_id 
      AND user_id <> NEW.user_id 
      AND is_deleted = FALSE
  LOOP
    INSERT INTO user_notifications (
      id, type, to_user_id, from_user_id, course_id, lesson_id, comment_id, 
      from_user_name, lesson_title, title, body, created_at
    ) VALUES (
      NEW.id || '_' || v_recipient_id, -- ID Único composto
      'forum_new_comment_thread',
      v_recipient_id,
      NEW.user_id,
      NEW.course_id,
      NEW.lesson_id,
      NEW.id,
      NEW.user_name,
      v_lesson_title,
      'Novo comentário no fórum',
      SUBSTRING(NEW.content FROM 1 FOR 100),
      CURRENT_TIMESTAMP
    ) ON CONFLICT (id) DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_on_forum_comment_created
AFTER INSERT ON forum_comments
FOR EACH ROW
EXECUTE FUNCTION on_forum_comment_created();


-- -----------------------------------------------------------------------------
-- 2. Sincronização de Reações em Comentários e Notificações do Autor
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sync_forum_comment_reaction()
RETURNS TRIGGER AS $$
DECLARE
  v_author_id VARCHAR(128);
  v_course_id VARCHAR(128);
  v_lesson_id VARCHAR(128);
  v_lesson_title VARCHAR(255);
  v_from_user_name VARCHAR(255);
BEGIN
  -- Identifica o autor do comentário e metadados
  IF TG_OP = 'DELETE' THEN
    SELECT user_id, course_id, lesson_id INTO v_author_id, v_course_id, v_lesson_id 
    FROM forum_comments WHERE id = OLD.comment_id;
  ELSE
    SELECT user_id, course_id, lesson_id INTO v_author_id, v_course_id, v_lesson_id 
    FROM forum_comments WHERE id = NEW.comment_id;
    
    SELECT display_name INTO v_from_user_name FROM users WHERE id = NEW.user_id;
    SELECT title INTO v_lesson_title FROM lessons WHERE id = v_lesson_id;
  END IF;

  -- ---------------------------------------------------------------------------
  -- CASO 1: Inserção de Nova Reação
  -- ---------------------------------------------------------------------------
  IF TG_OP = 'INSERT' THEN
    -- Incrementa no comentário
    EXECUTE format(
      'UPDATE forum_comments SET reactions_%I = reactions_%I + 1, reactions_total = reactions_total + 1 WHERE id = $1',
      NEW.reaction_type::text, NEW.reaction_type::text
    ) USING NEW.comment_id;
    
    -- Incrementa nos recebidos do autor do comentário
    UPDATE user_community_progress
    SET reactions_received = jsonb_set(
          jsonb_set(
            reactions_received,
            ARRAY[NEW.reaction_type::text],
            to_jsonb(COALESCE((reactions_received->>NEW.reaction_type::text)::int, 0) + 1)
          ),
          '{total}',
          to_jsonb(COALESCE((reactions_received->>'total')::int, 0) + 1)
        )
    WHERE user_id = v_author_id;

    -- Emite notificação de reação para o autor (se não for ele mesmo)
    IF NEW.user_id <> v_author_id THEN
      INSERT INTO user_notifications (
        id, type, to_user_id, from_user_id, course_id, lesson_id, comment_id, reaction_type,
        from_user_name, lesson_title, title, body, created_at
      ) VALUES (
        NEW.id, -- ID composto ex: reactionId
        'forum_reaction_received',
        v_author_id,
        NEW.user_id,
        v_course_id,
        v_lesson_id,
        NEW.comment_id,
        NEW.reaction_type::forum_reaction_type,
        COALESCE(v_from_user_name, 'Estudante'),
        v_lesson_title,
        'Reação recebida',
        'Alguém reagiu ao seu comentário no fórum.',
        CURRENT_TIMESTAMP
      ) ON CONFLICT (id) DO NOTHING;
    END IF;

  -- ---------------------------------------------------------------------------
  -- CASO 2: Exclusão de Reação
  -- ---------------------------------------------------------------------------
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrementa no comentário
    EXECUTE format(
      'UPDATE forum_comments SET reactions_%I = GREATEST(0, reactions_%I - 1), reactions_total = GREATEST(0, reactions_total - 1) WHERE id = $1',
      OLD.reaction_type::text, OLD.reaction_type::text
    ) USING OLD.comment_id;

    -- Decrementa nos recebidos do autor do comentário
    UPDATE user_community_progress
    SET reactions_received = jsonb_set(
          jsonb_set(
            reactions_received,
            ARRAY[OLD.reaction_type::text],
            to_jsonb(GREATEST(0, COALESCE((reactions_received->>OLD.reaction_type::text)::int, 0) - 1))
          ),
          '{total}',
          to_jsonb(GREATEST(0, COALESCE((reactions_received->>'total')::int, 0) - 1))
        )
    WHERE user_id = v_author_id;

    -- Remove notificação
    DELETE FROM user_notifications WHERE id = OLD.id;

  -- ---------------------------------------------------------------------------
  -- CASO 3: Atualização de Tipo de Reação
  -- ---------------------------------------------------------------------------
  ELSIF TG_OP = 'UPDATE' THEN
    -- Decrementa tipo anterior e incrementa novo tipo no comentário
    EXECUTE format(
      'UPDATE forum_comments SET reactions_%I = GREATEST(0, reactions_%I - 1), reactions_%I = reactions_%I + 1 WHERE id = $1',
      OLD.reaction_type::text, OLD.reaction_type::text, NEW.reaction_type::text, NEW.reaction_type::text
    ) USING NEW.comment_id;

    -- Ajusta contador nos recebidos do autor
    UPDATE user_community_progress
    SET reactions_received = jsonb_set(
          jsonb_set(
            reactions_received,
            ARRAY[OLD.reaction_type::text],
            to_jsonb(GREATEST(0, COALESCE((reactions_received->>OLD.reaction_type::text)::int, 0) - 1))
          ),
          ARRAY[NEW.reaction_type::text],
          to_jsonb(COALESCE((reactions_received->>NEW.reaction_type::text)::int, 0) + 1)
        )
    WHERE user_id = v_author_id;

    -- Sincroniza o tipo na notificação
    UPDATE user_notifications
    SET reaction_type = NEW.reaction_type::forum_reaction_type
    WHERE id = NEW.id;
  END IF;

  -- Re-avalia o nível de comunidade do autor do comentário
  PERFORM update_community_level(v_author_id);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_forum_comment_reactions_sync
AFTER INSERT OR UPDATE OR DELETE ON forum_comment_reactions
FOR EACH ROW
EXECUTE FUNCTION sync_forum_comment_reaction();
