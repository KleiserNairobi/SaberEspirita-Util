import { Pool } from "./node_modules/@types/pg";
import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config();

// Conexão com o PostgreSQL
const pool = new Pool({
  host: process.env.PGHOST || "localhost",
  port: parseInt(process.env.PGPORT || "5432", 10),
  database: process.env.PGDATABASE || "saber_espirita_db",
  user: process.env.PGUSER || "postgres",
  password: process.env.PGPASSWORD || "postgres",
});

const backupDirectoryArg = process.argv[2];

if (!backupDirectoryArg) {
  console.error("❌ Por favor especifique o diretório do backup JSON.");
  console.error(
    "Exemplo: npx ts-node migrate_json_to_postgres.ts ./backups/backup_2026-08-06...",
  );
  process.exit(1);
}

const backupDir = path.resolve(__dirname, backupDirectoryArg);

if (!fs.existsSync(backupDir)) {
  console.error(`❌ Diretório de backup não encontrado: ${backupDir}`);
  process.exit(1);
}

function loadJson(fileName: string): any[] {
  const filePath = path.join(backupDir, `${fileName}.json`);
  if (!fs.existsSync(filePath)) return [];
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (e) {
    console.warn(
      `⚠️ Aviso: Não foi possível ler ou parsear o arquivo ${fileName}.json`,
    );
    return [];
  }
}

async function migrateData() {
  const client = await pool.connect();
  console.log(
    `🚀 Conectado ao PostgreSQL (${process.env.PGDATABASE || "saber_espirita_db"})...`,
  );
  console.log(`📦 Lendo backup do diretório: ${backupDir}\n`);

  try {
    await client.query("BEGIN");

    // 1. Usuários
    const users = loadJson("users");
    console.log(`⏳ Migrando ${users.length} usuários...`);
    for (const u of users) {
      await client.query(
        `
        INSERT INTO users (id, email, display_name, photo_url, is_anonymous, created_at, updated_at, last_active_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO UPDATE SET
          email = EXCLUDED.email,
          display_name = EXCLUDED.display_name,
          photo_url = EXCLUDED.photo_url,
          last_active_at = EXCLUDED.last_active_at;
      `,
        [
          u.id,
          u.email || null,
          u.displayName || u.name || null,
          u.photoURL || u.photo_url || u.avatarUrl || null,
          u.isAnonymous || false,
          u.createdAt || u.created_at || new Date(),
          u.updatedAt || u.updated_at || new Date(),
          u.lastActiveAt || u.last_active_at || null,
        ],
      );
    }

    // 2. Pontuações de Usuários
    const scores = loadJson("users_scores");
    console.log(`⏳ Migrando ${scores.length} pontuações de usuários...`);
    for (const s of scores) {
      await client.query(
        `
        INSERT INTO user_scores (user_id, score, total_all_time, total_this_week, total_this_month, position, level, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (user_id) DO UPDATE SET
          score = EXCLUDED.score,
          total_all_time = EXCLUDED.total_all_time,
          total_this_week = EXCLUDED.total_this_week,
          total_this_month = EXCLUDED.total_this_month;
      `,
        [
          s.userId || s.id,
          s.score || 0,
          s.totalAllTime || s.total_all_time || 0,
          s.totalThisWeek || s.total_this_week || 0,
          s.totalThisMonth || s.total_this_month || 0,
          s.position || null,
          s.level || "Iniciante",
          s.updatedAt || new Date(),
        ],
      );
    }

    // 3. Categorias de Cursos
    const categories = loadJson("categories");
    console.log(`⏳ Migrando ${categories.length} categorias de cursos...`);
    for (const c of categories) {
      await client.query(
        `
        INSERT INTO course_categories (id, name, description, icon_name, created_at)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (id) DO NOTHING;
      `,
        [
          c.id,
          c.name || c.title || "Categoria Sem Nome",
          c.description || null,
          c.iconName || c.icon || null,
          c.createdAt || new Date(),
        ],
      );
    }

    // 4. Cursos
    const courses = loadJson("courses");
    console.log(`⏳ Migrando ${courses.length} cursos...`);
    for (const crs of courses) {
      await client.query(
        `
        INSERT INTO courses (
          id, title, description, order_index, workload_minutes, difficulty_level,
          author, lesson_count, image_url, category_id, release_year, featured,
          status, allow_new_enrollments, certification_config, rating, average_rating, rating_count, has_forum, stats
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
        ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description;
      `,
        [
          crs.id,
          crs.title || "Curso Sem Título",
          crs.description || "",
          crs.order || crs.order_index || 0,
          crs.workloadMinutes || 0,
          crs.difficultyLevel || "Iniciante",
          crs.author || "Saber Espírita",
          crs.lessonCount || 0,
          typeof crs.imageUrl === "string" ? crs.imageUrl : null,
          crs.categoryId || null,
          crs.releaseYear || null,
          crs.featured || false,
          crs.status || "PUBLISHED",
          crs.allowNewEnrollments !== false,
          JSON.stringify(
            crs.certification || { enabled: true, minimumGrade: 70 },
          ),
          crs.rating || null,
          crs.averageRating || null,
          crs.ratingCount || 0,
          crs.hasForum !== false,
          JSON.stringify(crs.stats || {}),
        ],
      );

      // Subcoleção de Lições se houver
      if (
        crs._subcollection_lessons &&
        Array.isArray(crs._subcollection_lessons)
      ) {
        for (const les of crs._subcollection_lessons) {
          await client.query(
            `
            INSERT INTO lessons (
              id, course_id, module_id, title, description, order_index,
              slides, duration_minutes, source, chapter, forum_enabled, forum_prompt,
              forum_focus_tag, status, video_url, audio_url
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            ON CONFLICT (id) DO NOTHING;
          `,
            [
              les.id,
              crs.id,
              les.moduleId || null,
              les.title || "Lição Sem Título",
              les.description || null,
              les.order || les.order_index || 0,
              JSON.stringify(les.slides || []),
              les.durationMinutes || 0,
              les.source || null,
              les.chapter || null,
              les.forumEnabled !== false,
              les.forumPrompt || null,
              les.forumFocusTag || null,
              les.status || "PUBLISHED",
              les.videoUrl || null,
              les.audioUrl || null,
            ],
          );
        }
      }
    }

    // 5. Glossário
    const glossary = loadJson("glossary");
    console.log(`⏳ Migrando ${glossary.length} termos do glossário...`);
    for (const g of glossary) {
      await client.query(
        `
        INSERT INTO glossary_terms (id, term, definition, category, "references", related_terms, synonyms, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO NOTHING;
      `,
        [
          g.id,
          g.term || "Termo",
          g.definition || "",
          g.category || "Doutrina Básica",
          JSON.stringify(g.references || []),
          JSON.stringify(g.relatedTerms || []),
          JSON.stringify(g.synonyms || []),
          g.createdAt || new Date(),
        ],
      );
    }

    // 6. Orações
    const prayers = loadJson("prayers");
    console.log(`⏳ Migrando ${prayers.length} orações...`);
    for (const p of prayers) {
      await client.query(
        `
        INSERT INTO prayers (id, title, content, source, author, featured, views_day, views_week, views_total, categories, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        ON CONFLICT (id) DO NOTHING;
      `,
        [
          p.id,
          p.title || "Oração Sem Título",
          p.content || "",
          p.source || null,
          p.author || null,
          p.featured || false,
          p.viewsDay || 0,
          p.viewsWeek || 0,
          p.viewsTotal || 0,
          JSON.stringify(p.categories || []),
          p.createdAt || new Date(),
        ],
      );
    }

    // 7. Reflexões
    const reflections = loadJson("reflections");
    console.log(`⏳ Migrando ${reflections.length} reflexões...`);
    for (const r of reflections) {
      await client.query(
        `
        INSERT INTO reflections (id, title, subtitle, content, author, source, image_url, reading_time_minutes, topic, tags, featured, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (id) DO NOTHING;
      `,
        [
          r.id,
          r.title || "Reflexão",
          r.subtitle || null,
          r.content || "",
          r.author || null,
          r.source || null,
          r.imageUrl || null,
          r.readingTimeMinutes || 1,
          r.topic || "Geral",
          JSON.stringify(r.tags || []),
          r.featured || false,
          r.createdAt || new Date(),
        ],
      );
    }

    await client.query("COMMIT");
    console.log("\n🎉 Carga de migração finalizada com sucesso!");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("❌ Erro na migração! Transação abortada (ROLLBACK):", error);
  } finally {
    client.release();
    await pool.end();
  }
}

migrateData();
