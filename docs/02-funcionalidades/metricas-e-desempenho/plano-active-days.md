# Retomada: Corrigir leituras em `/active_days` — TTL Nativo

> Contexto criado em 21/07/2026. Retomar aqui na próxima sessão.

---

## O problema (já diagnosticado)

A coleção `active_days` acumulou **~301 documentos históricos** que nunca expiram.
Como ela é a primeira coleção listada alfabeticamente no console do Firestore,
**cada abertura do console cobra ~301 leituras** — isso foi a principal causa do estouro de hoje.

- O trigger `onLessonLogCreated` foi **desativado intencionalmente** (redução de custo) e não criará novos documentos
- Os 301 documentos existentes são resíduos históricos — inúteis após o dia UTC em que foram criados
- Nenhuma query de produção varre essa coleção — o problema é exclusivamente o console

---

## A solução (aprovada, aguardando execução)

**TTL Nativo do Firestore** — gratuito, sem nova Cloud Function, zero impacto no negócio.

### Passo 1 — Configurar TTL policy em `firestore.indexes.json`

Adicionar a seção `ttlPolicies` ao arquivo existente na raiz do projeto web:

```json
"ttlPolicies": [
  {
    "collectionGroup": "active_days",
    "fieldPath": "expiresAt"
  }
]
```

Deploy:
```bash
firebase deploy --only firestore:indexes
```

> A política demora até 48h para ativar. Após ativa, deleta docs com `expiresAt` no passado em até 24h. **Deleções por TTL são gratuitas.**

---

### Passo 2 — Adicionar `expiresAt` na criação de novos documentos

**Arquivo:** `SaberEspirita-Web/functions/src/community/updateCommunityProgress.ts`  
**Função:** `touchActiveDayInTransaction` (linha 108)

```diff
+  const expiresAt = new Date(params.now.getTime() + 48 * 60 * 60 * 1000); // +48h

   params.tx.create(ref, {
     userId: params.userId,
     dayKey: params.dayKey,
     yearMonth: params.yearMonth,
     createdAt: admin.firestore.FieldValue.serverTimestamp(),
+    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
   });
```

Deploy junto com o Passo 1:
```bash
firebase deploy --only firestore:indexes,functions
```

---

### Passo 3 — Backfill dos 301 documentos existentes

Script já escrito em `functions/scripts/backfill_active_days_ttl.js` (criar o arquivo).

Executa **uma única vez** após o TTL policy ser ativado:
```bash
node functions/scripts/backfill_active_days_ttl.js
```

O script adiciona `expiresAt = agora - 1s` em todos os docs sem o campo.
O TTL os deleta em até 24h.

**Conteúdo do script:**

```js
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function run() {
  const expiredAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000));
  let last = null;
  let totalUpdated = 0;

  while (true) {
    let q = db.collection('active_days').limit(400);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      if (!doc.data().expiresAt) {
        batch.update(doc.ref, { expiresAt: expiredAt });
        totalUpdated++;
      }
    }
    await batch.commit();
    last = snap.docs[snap.docs.length - 1];
    console.log(`Atualizado: ${totalUpdated}`);
  }
  console.log(`Concluído. Total: ${totalUpdated} documentos marcados para expirar.`);
}

run().catch(console.error);
```

---

## O que NÃO muda

- Semântica de `active_days` como token de idempotência ✅
- Contador `community_progress.stats.activeDays` ✅  
- Critério de nível 3 (`activeDays >= 30`) ✅
- App mobile — zero alterações ✅
- Registros de guest — TTL se aplica igualmente ✅

---

## Contexto mais amplo (análise completa em andamento)

Ver `docs/novos/analise-consultas.md` para o mapa completo de todas as queries do módulo de cursos (tela Estude), com 5 problemas identificados e plano de ação em 2 fases.

Os próximos itens prioritários após este fix são (em ordem):
1. `useCommunityProgress` com `refetchOnMount: "always"` → mudar para `false` + `staleTime: 30min`
2. `useForumHasNewComments` com `staleTime` de 1 minuto → aumentar para 10min
3. `useLessonForumComments` N+1 reads → `staleTime: 10min` + desnormalizar reações (médio prazo)
4. `useCourseProgress` sem Cache-First → adicionar `getDocFromCache` + fallback
