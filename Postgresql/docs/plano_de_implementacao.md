# Plano de Implementação: Mapeamento e Migração para PostgreSQL

Mapeamento completo de todas as entidades do projeto (`src/types` e coleções do Firestore do app mobile e web) para um modelo relacional PostgreSQL, incluindo scripts de DDL, documentação de mapeamento, backup dos dados de produção do Firebase e migração.

## Visão Geral da Arquitetura do Banco de Dados PostgreSQL

A conversão respeita a fidelidade às entidades definidas em TypeScript (`SaberEspirita-Expo/src/types` e `SaberEspirita-Web/src/types`) e às regras/coleções existentes do Firestore.

### Estrutura de Pastas Criada em `Postgresql/`

```
Postgresql/
├── README.md                          # Instruções completas de uso, conexão e execução dos scripts
├── docs/
│   ├── entity_mapping.md              # De-para detalhado: Coleções/TypeScript -> Tabelas e Colunas do Postgres
│   ├── plano_de_implementacao.md      # Este plano de implementação arquivado
│   └── resumo_de_execucao.md          # Relatório do walkthrough e validações da execução
├── schema/
│   ├── 01_enums.sql                   # Tipos enumerados (ENUMs) do Postgres
│   ├── 02_users.sql                   # Usuários, perfis, pontuações, níveis e banimentos
│   ├── 03_courses.sql                 # Cursos, aulas, slides, materiais e questões de reflexão
│   ├── 04_exercises.sql               # Exercícios de cursos, perguntas dissertativas e resultados/tentativas
│   ├── 05_quizzes.sql                 # Módulo de Quizzes gerais (categorias, subcategorias, quizzes, perguntas, histórico)
│   ├── 06_content.sql                 # Glossário, reflexões, meditações, podcasts, orações e áudios ambientes
│   ├── 07_forum.sql                   # Comentários do fórum de lições e reações de usuários
│   ├── 08_user_activity.sql           # Progresso em cursos, certificados, favoritos, respostas V/F e notificações
│   ├── 09_stats_logs.sql              # Estatísticas diárias, globais, contadores por item e logs de aplicação
│   └── 10_views_indexes.sql           # Views (ex: Leaderboard/Ranking) e Índices de otimização
└── scripts/
    ├── package.json                   # Dependências do script de migração (firebase-admin, pg, dotenv, ts-node)
    ├── export_firebase_backup.ts      # Script para exportar backup completo das coleções Firestore em formato JSON
    └── migrate_json_to_postgres.ts    # Script de importação/migração do backup JSON para o banco de dados PostgreSQL
```

---

## Considerações de Arquitetura

1. **Tipos de Chave Primária**: Como os IDs no Firebase (document IDs e UIDs de Auth) são strings alfanuméricas de tamanho variável (ex: `vw3XkL9...`), as chaves primárias e estrangeiras nas tabelas PostgreSQL foram definidas como `VARCHAR(128)` / `TEXT` para garantir 100% de compatibilidade e preservar os relacionamentos existentes sem quebra.
2. **Campos Estruturados / JSONB**: Estruturas aninhadas com dinamismo de layout (como os `slides` das lições, as `alternatives` de questões ou dados complexos de logs) são representadas com a coluna nativa `JSONB` do PostgreSQL para máxima performance de consulta sem perder a flexibilidade do esquema original.
3. **Script de Backup de Produção**: O script `export_firebase_backup.ts` utiliza o Firebase Admin SDK (exigindo um `serviceAccountKey.json` ou credencial de ambiente de produção) para extrair coleções raiz e subcoleções.
4. **Paridade da API REST & Migração de Mídias (Cloudflare)**:
   - **Objetivo da API**: A nova API REST em Spring Boot (`SaberEspirita-Back`) deve ser **100% compatível** com todas as regras de negócio, dados e comportamentos originalmente mantidos no Firebase (Firestore e Cloud Functions).
   - **Migração do Storage**: Todos os ativos estáticos e mídias (imagens de aulas/cursos, áudios de meditações, podcasts e PDFs) armazenados no Firebase Storage serão migrados e servidos via **Cloudflare CDN / Cloudflare R2**, aproveitando a infraestrutura de distribuição já utilizada para a entrega do *hot-updater* (OTA) do aplicativo.


---

## Mapeamento por Módulo

### 1. Esquemas e Tabelas PostgreSQL

- **`01_enums.sql`**: Tipos enumerados PostgreSQL (`course_difficulty_level`, `course_status`, `lesson_status`, `slide_type`, `exercise_type`, `exercise_status`, `material_type`, `forum_reaction_type`, `community_level_id`, `notification_type`, `glossary_category`, `prayer_moment`, `quiz_history_level`, `truth_or_false_difficulty`, `ambient_audio_icon`).
- **`02_users.sql`**: `users`, `user_scores`, `user_community_progress`, `user_chat_limits`, `banned_devices`, `blocked_emails`, `blocked_domains`.
- **`03_courses.sql`**: `course_categories`, `courses`, `lessons`, `lesson_supplementary_materials`, `lesson_reflection_questions`.
- **`04_exercises.sql`**: `exercises`, `essay_questions`, `exercise_results`, `exercise_attempts`.
- **`05_quizzes.sql`**: `quiz_categories`, `quiz_subcategories`, `quizzes`, `quiz_questions`, `user_quiz_history`, `quiz_reports`.
- **`06_content.sql`**: `glossary_terms`, `reflections`, `meditation_categories`, `meditations`, `podcasts`, `prayer_categories`, `prayers`, `prayer_category_links`, `ambient_audios`.
- **`07_forum.sql`**: `forum_comments`, `forum_comment_reactions`.
- **`08_user_activity.sql`**: `user_course_progress`, `certificates`, `user_prayer_favorites`, `user_reflection_favorites`, `truth_or_false_questions`, `user_truth_or_false_responses`, `user_notifications`, `course_feedbacks`.
- **`09_stats_logs.sql`**: `daily_stats`, `global_stats`, `item_stats`, `app_logs`.
- **`10_views_indexes.sql`**: Índices em chaves primárias/estrangeiras e view `view_leaderboard`.

### 2. Scripts de Backup e Migração

- **`package.json`**: Projeto Node.js/TypeScript pré-configurado com dependências (`firebase-admin`, `pg`, `dotenv`, `typescript`, `ts-node`).
- **`export_firebase_backup.ts`**: Conecta ao Firebase Firestore e exporta todas as coleções e subcoleções para JSONs estruturados.
- **`migrate_json_to_postgres.ts`**: Lê o backup JSON e grava os registros nas tabelas PostgreSQL dentro de uma transação SQL de alta performance.
