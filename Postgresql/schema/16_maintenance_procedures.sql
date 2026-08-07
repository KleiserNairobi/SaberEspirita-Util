-- =============================================================================
-- Script DDL: 16_maintenance_procedures.sql
-- Descrição: Stored Procedures para Limpezas Periódicas e Manutenção de Placar
-- Fase: Fase 1 (Preparação Passiva - Segura para Criar Antes da Importação)
-- =============================================================================

-- 1. Reset de Ranking Semanal (Chamar toda Segunda-feira de madrugada)
CREATE OR REPLACE PROCEDURE proc_reset_weekly_scores()
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE user_scores 
  SET total_this_week = 0 
  WHERE total_this_week > 0;
END;
$$;

-- 2. Reset de Ranking Mensal (Chamar no Dia 1 de cada mês de madrugada)
CREATE OR REPLACE PROCEDURE proc_reset_monthly_scores()
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE user_scores 
  SET total_this_month = 0 
  WHERE total_this_month > 0;
END;
$$;

-- 3. Limpeza de Logs Históricos Excedentes (Mais de 180 dias)
CREATE OR REPLACE PROCEDURE proc_cleanup_old_logs()
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM app_logs 
  WHERE created_at < NOW() - INTERVAL '180 days';
END;
$$;
