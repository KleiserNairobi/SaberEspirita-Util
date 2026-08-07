-- =============================================================================
-- Script DDL: 15_app_logs_trigger.sql
-- Descrição: Trigger Unificada de Engajamento para Processamento do Histórico de Logs
-- Fase: Fase 2 (Executar DEPOIS de concluir a migração dos dados históricos)
-- =============================================================================

CREATE OR REPLACE FUNCTION process_app_log()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE;
  v_item_id VARCHAR(128);
  v_item_title VARCHAR(255);
  v_is_guest BOOLEAN;
  v_quiz_type VARCHAR(50);
BEGIN
  v_date := NEW.created_at::date;
  
  -- Garante registro de estatísticas globais
  INSERT INTO global_stats (id) VALUES ('current') ON CONFLICT (id) DO NOTHING;

  -- Garante registro de estatísticas diárias
  INSERT INTO daily_stats (date) VALUES (v_date) ON CONFLICT (date) DO NOTHING;

  CASE NEW.log_type
    -- -------------------------------------------------------------------------
    -- LOG DE VISITAS
    -- -------------------------------------------------------------------------
    WHEN 'visit_logs' THEN
      v_is_guest := (NEW.user_id = 'guest' OR NEW.user_id LIKE 'guest_%');
      
      UPDATE daily_stats
      SET 
        total_visits = total_visits + 1,
        guest_visits = guest_visits + CASE WHEN v_is_guest THEN 1 ELSE 0 END,
        user_visits = user_visits + CASE WHEN NOT v_is_guest THEN 1 ELSE 0 END
      WHERE date = v_date;

    -- -------------------------------------------------------------------------
    -- LOG DE ORAÇÕES
    -- -------------------------------------------------------------------------
    WHEN 'prayer_logs' THEN
      v_item_id := NEW.payload->>'prayerId';
      v_item_title := COALESCE(NEW.payload->>'prayerTitle', v_item_id);
      
      UPDATE daily_stats SET prayer_sessions = prayer_sessions + 1 WHERE date = v_date;
      UPDATE global_stats SET total_prayers_read = total_prayers_read + 1 WHERE id = 'current';
      
      IF v_item_id IS NOT NULL THEN
        INSERT INTO item_stats (id, item_type, title, usage_count)
        VALUES (v_item_id, 'prayer', v_item_title, 1)
        ON CONFLICT (id) DO UPDATE SET usage_count = item_stats.usage_count + 1, updated_at = CURRENT_TIMESTAMP;
      END IF;

    -- -------------------------------------------------------------------------
    -- LOG DE MEDITAÇÕES
    -- -------------------------------------------------------------------------
    WHEN 'meditation_logs' THEN
      v_item_id := NEW.payload->>'meditationId';
      v_item_title := COALESCE(NEW.payload->>'meditationTitle', v_item_id);
      
      UPDATE daily_stats SET meditation_sessions = meditation_sessions + 1 WHERE date = v_date;
      UPDATE global_stats SET total_meditations_completed = total_meditations_completed + 1 WHERE id = 'current';
      
      IF v_item_id IS NOT NULL THEN
        INSERT INTO item_stats (id, item_type, title, usage_count)
        VALUES (v_item_id, 'meditation', v_item_title, 1)
        ON CONFLICT (id) DO UPDATE SET usage_count = item_stats.usage_count + 1, updated_at = CURRENT_TIMESTAMP;
      END IF;

    -- -------------------------------------------------------------------------
    -- LOG DE PODCASTS
    -- -------------------------------------------------------------------------
    WHEN 'podcast_logs' THEN
      v_item_id := NEW.payload->>'podcastId';
      v_item_title := COALESCE(NEW.payload->>'podcastTitle', v_item_id);
      
      UPDATE daily_stats SET podcasts_played = podcasts_played + 1 WHERE date = v_date;
      UPDATE global_stats SET total_podcasts_played = total_podcasts_played + 1 WHERE id = 'current';
      
      IF v_item_id IS NOT NULL THEN
        INSERT INTO item_stats (id, item_type, title, usage_count)
        VALUES (v_item_id, 'podcast', v_item_title, 1)
        ON CONFLICT (id) DO UPDATE SET usage_count = item_stats.usage_count + 1, updated_at = CURRENT_TIMESTAMP;
      END IF;

    -- -------------------------------------------------------------------------
    -- LOG DE SINTONIA / PLAYER AMBIENTE
    -- -------------------------------------------------------------------------
    WHEN 'ambient_player_logs' THEN
      v_item_id := NEW.payload->>'trackId';
      v_item_title := COALESCE(NEW.payload->>'trackTitle', v_item_id);
      
      UPDATE daily_stats SET ambient_player_plays = ambient_player_plays + 1 WHERE date = v_date;
      UPDATE global_stats SET total_ambient_player_plays = total_ambient_player_plays + 1 WHERE id = 'current';
      
      IF v_item_id IS NOT NULL THEN
        INSERT INTO item_stats (id, item_type, title, usage_count)
        VALUES (v_item_id, 'ambient_player', v_item_title, 1)
        ON CONFLICT (id) DO UPDATE SET usage_count = item_stats.usage_count + 1, updated_at = CURRENT_TIMESTAMP;
      END IF;

    -- -------------------------------------------------------------------------
    -- LOG DE QUIZZES (GERAIS E DE AULA)
    -- -------------------------------------------------------------------------
    WHEN 'quiz_logs' THEN
      v_quiz_type := NEW.payload->>'quizType'; -- 'general' ou 'lesson'
      
      UPDATE daily_stats 
      SET 
        quiz_attempts = quiz_attempts + 1,
        general_quiz_attempts = general_quiz_attempts + CASE WHEN v_quiz_type = 'general' THEN 1 ELSE 0 END,
        lesson_quiz_attempts = lesson_quiz_attempts + CASE WHEN v_quiz_type = 'lesson' THEN 1 ELSE 0 END
      WHERE date = v_date;
      
      UPDATE global_stats 
      SET 
        total_quizzes_taken = total_quizzes_taken + CASE WHEN v_quiz_type = 'general' THEN 1 ELSE 0 END,
        total_lesson_quizzes_taken = total_lesson_quizzes_taken + CASE WHEN v_quiz_type = 'lesson' THEN 1 ELSE 0 END
      WHERE id = 'current';

    -- -------------------------------------------------------------------------
    -- LOG DE DESAFIOS DIÁRIOS
    -- -------------------------------------------------------------------------
    WHEN 'challenge_logs' THEN
      UPDATE daily_stats SET daily_challenge_completions = daily_challenge_completions + 1 WHERE date = v_date;
      UPDATE global_stats SET total_daily_challenge_completions = total_daily_challenge_completions + 1 WHERE id = 'current';

    -- -------------------------------------------------------------------------
    -- LOG DE VERDADEIRO OU FALSO
    -- -------------------------------------------------------------------------
    WHEN 'truth_or_false_logs' THEN
      UPDATE daily_stats SET truth_or_false_answers = truth_or_false_answers + 1 WHERE date = v_date;
      UPDATE global_stats SET total_truth_or_false_answers = total_truth_or_false_answers + 1 WHERE id = 'current';

    -- -------------------------------------------------------------------------
    -- LOG DE GLOSSÁRIO
    -- -------------------------------------------------------------------------
    WHEN 'glossary_logs' THEN
      UPDATE daily_stats SET glossary_views = glossary_views + 1 WHERE date = v_date;
      UPDATE global_stats SET total_glossary_views = total_glossary_views + 1 WHERE id = 'current';

    -- -------------------------------------------------------------------------
    -- LOG DE CHATBOT IA CIENTÍFICO
    -- -------------------------------------------------------------------------
    WHEN 'scientific_chat_logs' THEN
      UPDATE daily_stats SET scientific_chat_messages = scientific_chat_messages + 1 WHERE date = v_date;
      UPDATE global_stats SET total_scientific_chat_messages = total_scientific_chat_messages + 1 WHERE id = 'current';

    -- -------------------------------------------------------------------------
    -- LOG DE CHATBOT IA EMOCIONAL
    -- -------------------------------------------------------------------------
    WHEN 'emotional_chat_logs' THEN
      UPDATE daily_stats SET emotional_chat_messages = emotional_chat_messages + 1 WHERE date = v_date;
      UPDATE global_stats SET total_emotional_chat_messages = total_emotional_chat_messages + 1 WHERE id = 'current';

    ELSE
      -- ignora outros tipos de log
  END CASE;

  -- Define o log como já processado antes de salvar
  NEW.processed := TRUE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_app_logs_process
BEFORE INSERT ON app_logs
FOR EACH ROW
EXECUTE FUNCTION process_app_log();
