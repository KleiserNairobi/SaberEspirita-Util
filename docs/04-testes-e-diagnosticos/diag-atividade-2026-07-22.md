# Atividade 22/07/2026

> Sessão de priorização dos problemas de leitura excessiva no Firestore, identificados após o estouro de 109 mil leituras em 21/07/2026 (cota gratuita: 50 mil/dia).

---

## Ordem de Ataque — Prioridade por Impacto × Esforço × Risco

### 🥇 1º — `active_days` TTL Nativo ← Começar agora

| Critério | Avaliação |
|---|---|
| **Impacto** | Elimina 301 leituras **por abertura do console** — foi a maior causa isolada do estouro |
| **Esforço** | ~30 min — solução 100% pronta no doc, script já escrito |
| **Risco** | Zero — não toca o app mobile, não muda lógica de negócio |
| **Status** | ✅ Aprovado, aguardando execução |

> Não há motivo para adiar. É o fix mais barato com maior impacto imediato.
> Ver detalhes completos em `docs/novos/retomada-active-days.md`.

---

### 🥈 2º — Cloud Function `getTopCoursesData` (Fase 0)

| Critério | Avaliação |
|---|---|
| **Impacto** | 200 leituras por acionamento — varre **todos os usuários** sem filtro |
| **Esforço** | Pequeno — garantir que `global_stats/top_courses` seja sempre válido + guarda de admin |
| **Risco** | Baixo — só afeta painel web admin |

> É uma bomba de tempo: qualquer acesso ao painel com cache frio dispara 200 leituras.

Ações (Fase 0 de `analise-consultas.md`):

| # | Ação | Arquivo |
|---|---|---|
| 0a | Garantir que `global_stats/top_courses` seja sempre válido para evitar fallback | `getTopCoursesData.ts` |
| 0b | Adicionar guarda de autenticação admin (`customClaims.admin`) antes de executar fallback | `getTopCoursesData.ts` |

---

### 🥉 3º — Trio de hooks (Fase 1 de `analise-consultas.md`)

Todos na mesma sessão, ~1–2h de trabalho. Estimativa de **40–60% de redução** nas leituras diárias.

| Ordem | Hook | Mudança | Arquivo | Impacto |
|---|---|---|---|---|
| 3a | `useCommunityProgress` | `refetchOnMount: false` + `staleTime: 30min` | `useLessonForum.ts` | 🔴 Alto |
| 3b | `useForumHasNewComments` | `staleTime: 10min` + `refetchOnMount: false` | `useLessonForum.ts` | 🔴 Alto |
| 3c | `useLessonForumComments` | `staleTime: 10min` + `refetchOnMount: false` | `useLessonForum.ts` | 🔴 Alto |
| 3d | `useCourseProgress` | Cache-First (`getDocFromCache` + fallback) + `refetchOnMount: false` + `gcTime: 7 dias` | `useCourseProgress.ts` | 🟠 Médio |

---

### 4º — Desnormalização (Fase 2) — Médio prazo

| # | Ação | Impacto |
|---|---|---|
| 6 | Eliminar N+1 de reações: salvar `myReactions` no doc do comentário via Cloud Function | 🔴 Crítico |
| 7 | Desnormalizar `courseTitle` + `lessonTitle` no doc de progresso (elimina 2 leituras em `useLastAccessedCourse`) | 🟠 Médio |

> Maior esforço, requer Cloud Function. Deixar para depois das fases anteriores estabilizarem.

---

## Resumo da Sequência

```
active_days TTL  →  CF getTopCoursesData  →  Trio de hooks  →  Desnormalização
     ~30 min              ~1h                    ~1–2h             ~1–2 dias
```

---

## Referências

- `docs/novos/retomada-active-days.md` — detalhes completos da solução TTL + script de backfill
- `docs/novos/analise-consultas.md` — mapa completo de todas as queries do módulo de cursos (tela Estude), 5 problemas identificados e plano de ação em 2 fases
