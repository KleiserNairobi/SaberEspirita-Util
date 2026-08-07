-- =============================================================================
-- Script DDL: 13_stats_counters_triggers.sql
-- Descrição: Triggers para Manutenção de Estatísticas, Contadores Globais e Níveis de Alunos
-- Fase: Fase 2 (Executar DEPOIS de concluir a migração dos dados históricos)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Sincronização ao Criar/Deletar Usuário
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION on_user_created_or_deleted()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE;
BEGIN
  v_date := CURRENT_DATE;

  -- Garante registro de estatísticas globais
  INSERT INTO global_stats (id) VALUES ('current') ON CONFLICT (id) DO NOTHING;

  IF TG_OP = 'INSERT' THEN
    -- Incrementa alunos no global
    UPDATE global_stats SET total_students = total_students + 1 WHERE id = 'current';

    -- Inicializa progresso de comunidade
    INSERT INTO user_community_progress (user_id, community_level_id, lessons_completed, courses_completed, forum_comments, active_days, has_course_over_50)
    VALUES (NEW.id, 'sementeiro', 0, 0, 0, 0, FALSE)
    ON CONFLICT (user_id) DO NOTHING;

    -- Inicializa scores para o Leaderboard
    INSERT INTO user_scores (user_id, score, total_all_time, total_this_week, total_this_month, level)
    VALUES (NEW.id, 0, 0, 0, 0, 'Iniciante')
    ON CONFLICT (user_id) DO NOTHING;

    -- Inicializa limites diários de chatbot
    INSERT INTO user_chat_limits (user_id, daily_scientific_count, daily_emotional_count)
    VALUES (NEW.id, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;

    -- Incrementa novos cadastros do dia
    INSERT INTO daily_stats (date, new_users)
    VALUES (v_date, 1)
    ON CONFLICT (date) DO UPDATE SET new_users = daily_stats.new_users + 1;

  ELSIF TG_OP = 'DELETE' THEN
    -- Decrementa alunos no global
    UPDATE global_stats SET total_students = GREATEST(0, total_students - 1) WHERE id = 'current';
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_users_on_insert_delete
AFTER INSERT OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION on_user_created_or_deleted();


-- -----------------------------------------------------------------------------
-- 2. Progresso de Estudos do Aluno (Cursos/Aulas e Nível de Comunidade)
-- -----------------------------------------------------------------------------

-- Função auxiliar para calcular o nível da comunidade a partir dos status atuais
CREATE OR REPLACE FUNCTION get_calculated_community_level(
  p_lessons_completed INT,
  p_courses_completed INT,
  p_forum_comments INT,
  p_reactions_received JSONB,
  p_active_days INT,
  p_has_course_over_50 BOOLEAN
) RETURNS community_level_id AS $$
DECLARE
  v_me_tocou INT;
  v_gratidao INT;
  v_total INT;
  v_qualitative INT;
BEGIN
  v_me_tocou := COALESCE((p_reactions_received->>'me_tocou')::int, 0);
  v_gratidao := COALESCE((p_reactions_received->>'gratidao')::int, 0);
  v_total    := COALESCE((p_reactions_received->>'total')::int, 0);
  v_qualitative := v_me_tocou + v_gratidao;

  -- Nível 3 (arvore_frondosa)
  IF p_lessons_completed >= 40 
     AND p_courses_completed >= 2 
     AND p_forum_comments >= 20 
     AND v_total >= 50 
     AND v_qualitative >= 15 
     AND p_active_days >= 30 THEN
    RETURN 'arvore_frondosa'::community_level_id;
  END IF;

  -- Nível 2 (cultivador)
  IF p_lessons_completed >= 10 
     AND p_forum_comments >= 5 
     AND v_total >= 10 
     AND p_has_course_over_50 THEN
    RETURN 'cultivador'::community_level_id;
  END IF;

  -- Nível 1 (sementeiro)
  RETURN 'sementeiro'::community_level_id;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para atualizar o nível da comunidade
CREATE OR REPLACE FUNCTION update_community_level(p_user_id VARCHAR(128))
RETURNS VOID AS $$
DECLARE
  r RECORD;
  v_new_level community_level_id;
BEGIN
  SELECT * INTO r FROM user_community_progress WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_new_level := get_calculated_community_level(
    r.lessons_completed,
    r.courses_completed,
    r.forum_comments,
    r.reactions_received,
    r.active_days,
    r.has_course_over_50
  );

  IF v_new_level <> r.community_level_id THEN
    UPDATE user_community_progress
    SET community_level_id = v_new_level,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger para recalcular progresso de estudos e nível
CREATE OR REPLACE FUNCTION on_user_course_progress_written()
RETURNS TRIGGER AS $$
DECLARE
  v_lessons_completed INT;
  v_courses_completed INT;
  v_has_course_over_50 BOOLEAN;
  v_user_id VARCHAR(128);
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;
  ELSE
    v_user_id := NEW.user_id;
  END IF;

  -- Recalcula métricas do usuário baseando-se em todo o seu histórico atual de progresso
  SELECT 
    COALESCE(SUM(jsonb_array_length(completed_lessons)), 0) AS lessons_completed,
    COUNT(CASE WHEN (c.lesson_count > 0 AND jsonb_array_length(completed_lessons) >= c.lesson_count) OR ucp.completed_at IS NOT NULL THEN 1 END) AS courses_completed,
    EXISTS (
      SELECT 1 FROM user_course_progress u
      JOIN courses cr ON u.course_id = cr.id
      WHERE u.user_id = v_user_id 
        AND cr.lesson_count > 0 
        AND (jsonb_array_length(u.completed_lessons)::numeric / cr.lesson_count::numeric) * 100 > 50
    ) AS has_course_over_50
  INTO v_lessons_completed, v_courses_completed, v_has_course_over_50
  FROM user_course_progress ucp
  JOIN courses c ON ucp.course_id = c.id
  WHERE ucp.user_id = v_user_id;

  -- Sincroniza tabela de progresso da comunidade
  UPDATE user_community_progress
  SET 
    lessons_completed = v_lessons_completed,
    courses_completed = v_courses_completed,
    has_course_over_50 = COALESCE(v_has_course_over_50, FALSE),
    updated_at = CURRENT_TIMESTAMP
  WHERE user_id = v_user_id;

  -- Reavalia o nível do usuário
  PERFORM update_community_level(v_user_id);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_user_course_progress_study_stats
AFTER INSERT OR UPDATE OR DELETE ON user_course_progress
FOR EACH ROW
EXECUTE FUNCTION on_user_course_progress_written();


-- -----------------------------------------------------------------------------
-- 3. Média de Avaliação de Feedbacks dos Cursos
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_course_feedback_aggregates()
RETURNS TRIGGER AS $$
DECLARE
  v_course_id VARCHAR(128);
  v_avg_rating NUMERIC(3, 2);
  v_rating_count INT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_course_id := OLD.course_id;
  ELSE
    v_course_id := NEW.course_id;
  END IF;

  -- Calcula nova média aritmética
  SELECT 
    COALESCE(ROUND(AVG(rating)::numeric, 1), 0.00),
    COUNT(*)
  INTO v_avg_rating, v_rating_count
  FROM course_feedbacks
  WHERE course_id = v_course_id;

  -- Atualiza na tabela courses
  UPDATE courses
  SET 
    rating = v_avg_rating,
    average_rating = v_avg_rating,
    rating_count = v_rating_count,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_course_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_course_feedbacks_rating_sync
AFTER INSERT OR UPDATE OR DELETE ON course_feedbacks
FOR EACH ROW
EXECUTE FUNCTION update_course_feedback_aggregates();
