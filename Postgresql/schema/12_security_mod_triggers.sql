-- =============================================================================
-- Script DDL: 12_security_mod_triggers.sql
-- Descrição: Triggers de Segurança e Moderação (Blocklist de E-mails/Domínios)
-- Fase: Fase 2 (Executar DEPOIS de concluir a migração dos dados históricos)
-- =============================================================================

-- Função auxiliar para normalizar e-mails
CREATE OR REPLACE FUNCTION normalize_email(email VARCHAR) 
RETURNS VARCHAR AS $$
DECLARE
  v_clean VARCHAR;
  v_parts TEXT[];
BEGIN
  IF email IS NULL THEN
    RETURN NULL;
  END IF;

  v_clean := LOWER(TRIM(email));
  v_parts := string_to_array(v_clean, '@');
  
  IF array_length(v_parts, 1) = 2 THEN
    -- Se for do Gmail, remove sufixo "+" para evitar bypass de bloqueio
    IF v_parts[2] = 'gmail.com' THEN
      v_parts[1] := split_part(v_parts[1], '+', 1);
    END IF;
    RETURN v_parts[1] || '@' || v_parts[2];
  END IF;
  
  RETURN v_clean;
END;
$$ LANGUAGE plpgsql;

-- Função da trigger para validar bloqueios
CREATE OR REPLACE FUNCTION check_user_blocklist()
RETURNS TRIGGER AS $$
DECLARE
  v_normalized_email VARCHAR(255);
  v_domain VARCHAR(255);
  v_parts TEXT[];
BEGIN
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  v_normalized_email := normalize_email(NEW.email);
  v_parts := string_to_array(v_normalized_email, '@');
  IF array_length(v_parts, 1) = 2 THEN
    v_domain := v_parts[2];
  END IF;

  -- 1. Verifica se o e-mail normalizado está na lista de bloqueados
  IF EXISTS (SELECT 1 FROM blocked_emails WHERE email = v_normalized_email) THEN
    RAISE EXCEPTION 'Cadastro Recusado: Este e-mail não possui permissão para se cadastrar no aplicativo.';
  END IF;

  -- 2. Verifica se o e-mail original (caso diferente) está bloqueado
  IF LOWER(TRIM(NEW.email)) <> v_normalized_email THEN
    IF EXISTS (SELECT 1 FROM blocked_emails WHERE email = LOWER(TRIM(NEW.email))) THEN
      RAISE EXCEPTION 'Cadastro Recusado: Este e-mail não possui permissão para se cadastrar no aplicativo.';
    END IF;
  END IF;

  -- 3. Verifica se o domínio está na lista de domínios bloqueados
  IF v_domain IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM blocked_domains WHERE domain = v_domain) THEN
      RAISE EXCEPTION 'Cadastro Recusado: Cadastros com este provedor de e-mail não são permitidos.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criação da trigger na tabela de usuários
CREATE OR REPLACE TRIGGER trg_users_check_blocklist
BEFORE INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION check_user_blocklist();
