# Estrutura do Banco de Dados PostgreSQL - Saber Espírita

Este diretório contém toda a definição de banco de dados relacional PostgreSQL, mapeamento de entidades (migrados dos tipos TypeScript e coleções do Firebase/Firestore) e scripts automatizados de backup e carga de dados.

---

## 📁 Estrutura de Arquivos

```
Postgresql/
├── README.md                          # Este arquivo de documentação
├── docs/
│   └── entity_mapping.md              # Mapeamento detalhado (Firestore/TypeScript -> PostgreSQL)
├── schema/
│   ├── 01_enums.sql                   # Definição dos tipos ENUM do Postgres
│   ├── 02_users.sql                   # Usuários, perfis, pontuações e regras de acesso
│   ├── 03_courses.sql                 # Cursos, categorias, aulas, slides e materiais
│   ├── 04_exercises.sql               # Exercícios de cursos, perguntas dissertativas e resultados
│   ├── 05_quizzes.sql                 # Módulo de Quizzes (categorias, subcategorias, perguntas, histórico)
│   ├── 06_content.sql                 # Glossário, reflexões, meditações, podcasts, orações e áudios
│   ├── 07_forum.sql                   # Fórum de lições (comentários e reações)
│   ├── 08_user_activity.sql           # Progresso do usuário, certificados, favoritos, V/F e notificações
│   ├── 09_stats_logs.sql              # Estatísticas diárias, globais e logs do sistema
│   └── 10_views_indexes.sql           # Views (Leaderboard/Rankings) e Índices de alta performance
└── scripts/
    ├── package.json                   # Dependências do Node.js (firebase-admin, pg, dotenv, etc.)
    ├── export_firebase_backup.ts      # Script para exportar backup completo do Firebase Firestore para JSON
    └── migrate_json_to_postgres.ts    # Script para ler o backup JSON e migrar para o PostgreSQL
```

---

## 🚀 Como Executar os Scripts SQL (DDL)

### 1. Criar o Banco de Dados no PostgreSQL

```sql
CREATE DATABASE saber_espirita_db WITH ENCODING = 'UTF8';
```

### 2. Aplicar a Ordem de Scripts SQL

Conectado ao banco `saber_espirita_db`, execute os scripts na ordem numérica:

```bash
psql -U postgres -d saber_espirita_db -f schema/01_enums.sql
psql -U postgres -d saber_espirita_db -f schema/02_users.sql
psql -U postgres -d saber_espirita_db -f schema/03_courses.sql
psql -U postgres -d saber_espirita_db -f schema/04_exercises.sql
psql -U postgres -d saber_espirita_db -f schema/05_quizzes.sql
psql -U postgres -d saber_espirita_db -f schema/06_content.sql
psql -U postgres -d saber_espirita_db -f schema/07_forum.sql
psql -U postgres -d saber_espirita_db -f schema/08_user_activity.sql
psql -U postgres -d saber_espirita_db -f schema/09_stats_logs.sql
psql -U postgres -d saber_espirita_db -f schema/10_views_indexes.sql
```

---

## 📦 Backup do Produção & Migração de Dados

### Pré-requisitos para os Scripts Node.js/TypeScript

1. Acesse o diretório de scripts:
   ```bash
   cd Postgresql/scripts
   npm install
   ```

2. Crie o arquivo `.env` baseado no `.env.example`:
   ```env
   # Credenciais do Firebase
   FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json

   # Conexão com o PostgreSQL
   PGHOST=localhost
   PGPORT=5432
   PGDATABASE=saber_espirita_db
   PGUSER=postgres
   PGPASSWORD=sua_senha
   ```

3. Baixe a chave de conta de serviço do Firebase Console (`serviceAccountKey.json`) e insira em `Postgresql/scripts/serviceAccountKey.json`.

---

### Executando o Backup do Firebase

O script realiza o download em formato JSON das coleções e subcoleções de produção:

```bash
npx ts-node export_firebase_backup.ts
```

Os arquivos serão armazenados em uma pasta com a data do backup, por exemplo: `Postgresql/scripts/backups/backup_YYYY-MM-DD_HH-mm-ss/`.

---

### Executando a Migração para o PostgreSQL

O script lê o diretório JSON gerado pelo backup e realiza a carga em lote no PostgreSQL dentro de uma transação SQL:

```bash
npx ts-node migrate_json_to_postgres.ts ./backups/backup_LATEST
```

---

## 📌 Principais Recursos de Projeto Relacional

1. **Chaves Primárias Únicas**: Todos os registros preservam o ID original da string do Firebase (como Auth UID e Firestore Document ID), usando a coluna `VARCHAR(128)` como Chave Primária (`PRIMARY KEY`).
2. **Estruturas Complexas (JSONB)**: Campos complexos como `slides` das lições, `options`/`alternatives` de perguntas, `stats` e configurações aninhadas utilizam a coluna nativa `JSONB` indexável do PostgreSQL.
3. **Views Dinâmicas de Leaderboard**: A view `view_leaderboard` unifica pontuações semanais, mensais e gerais calculadas dinamicamente com base nas interações e logs.
