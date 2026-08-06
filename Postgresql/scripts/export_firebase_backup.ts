import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

// Inicialização do Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccountKey.json';

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`❌ Arquivo de conta de serviço não encontrado no caminho: ${serviceAccountPath}`);
  console.error(`Por favor, insira o arquivo serviceAccountKey.json obtido no Firebase Console.`);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Formatação recursiva de Timestamps e tipos complexos para JSON serializável
function sanitizeDocData(data: any): any {
  if (data === null || data === undefined) return data;
  if (typeof data !== 'object') return data;

  if (data instanceof admin.firestore.Timestamp) {
    return data.toDate().toISOString();
  }

  if (data instanceof admin.firestore.GeoPoint) {
    return { latitude: data.latitude, longitude: data.longitude };
  }

  if (Array.isArray(data)) {
    return data.map(sanitizeDocData);
  }

  const result: Record<string, any> = {};
  for (const key of Object.keys(data)) {
    result[key] = sanitizeDocData(data[key]);
  }
  return result;
}

// Lista de coleções raiz do projeto
const ROOT_COLLECTIONS = [
  'users',
  'users_scores',
  'community_progress',
  'chatLimits',
  'banned_devices',
  'blocked_emails',
  'blocked_domains',
  'categories',
  'courses',
  'exercises',
  'quizes',
  'lesson_quizzes',
  'users_history',
  'quiz_reports',
  'glossary',
  'reflections',
  'meditations',
  'podcasts',
  'prayers',
  'prayer_categories',
  'prayer_category_links',
  'ambient_audios',
  'certificates',
  'user_prayer_favorites',
  'user_reflection_favorites',
  'truth_or_false_questions',
  'user_truth_or_false_responses',
  'course_feedbacks',
  'daily_stats',
  'global_stats',
  'item_stats',
  'lesson_logs',
  'quiz_logs',
  'prayer_logs',
  'visit_logs',
  'meditation_logs',
  'ambient_player_logs',
  'podcast_logs'
];

async function exportBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outputDir = path.join(__dirname, 'backups', `backup_${timestamp}`);

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  console.log(`🚀 Iniciando backup do Firebase Firestore de Produção...`);
  console.log(`📁 Destino: ${outputDir}\n`);

  for (const colName of ROOT_COLLECTIONS) {
    try {
      console.log(`⏳ Exportando coleção: ${colName}...`);
      const snapshot = await db.collection(colName).get();

      const docsData: any[] = [];

      for (const doc of snapshot.docs) {
        const item = {
          id: doc.id,
          ...sanitizeDocData(doc.data())
        };

        // Exportação de subcoleções conhecidas
        if (colName === 'users') {
          const progressSnap = await doc.ref.collection('courseProgress').get();
          item._subcollection_courseProgress = progressSnap.docs.map(d => ({ id: d.id, ...sanitizeDocData(d.data()) }));

          const notificationsSnap = await doc.ref.collection('notifications').get();
          item._subcollection_notifications = notificationsSnap.docs.map(d => ({ id: d.id, ...sanitizeDocData(d.data()) }));
        }

        if (colName === 'courses') {
          const lessonsSnap = await doc.ref.collection('lessons').get();
          item._subcollection_lessons = lessonsSnap.docs.map(d => ({ id: d.id, ...sanitizeDocData(d.data()) }));
        }

        if (colName === 'lesson_forums') {
          const commentsSnap = await doc.ref.collection('comments').get();
          item._subcollection_comments = [];

          for (const cDoc of commentsSnap.docs) {
            const commentObj = { id: cDoc.id, ...sanitizeDocData(cDoc.data()), _subcollection_reactions: [] as any[] };
            const reactionsSnap = await cDoc.ref.collection('reactions').get();
            commentObj._subcollection_reactions = reactionsSnap.docs.map(r => ({ id: r.id, ...sanitizeDocData(r.data()) }));
            item._subcollection_comments.push(commentObj);
          }
        }

        docsData.push(item);
      }

      const filePath = path.join(outputDir, `${colName}.json`);
      fs.writeFileSync(filePath, JSON.stringify(docsData, null, 2), 'utf8');
      console.log(`✅ Coleção ${colName} salva (${docsData.length} documentos).`);
    } catch (err) {
      console.error(`⚠️ Erro ao exportar coleção ${colName}:`, err);
    }
  }

  console.log(`\n🎉 Backup do Firebase concluído com sucesso em: ${outputDir}`);
}

exportBackup().catch(err => {
  console.error('❌ Falha fatal no backup do Firebase:', err);
  process.exit(1);
});
