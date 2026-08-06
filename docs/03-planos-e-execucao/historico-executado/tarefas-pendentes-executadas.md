---
description: Histórico e Tarefas Pendentes do Projeto (V2 Consolidada)
---

# Roadmap e Tarefas Pendentes - SaberEspirita-Expo (V2)

**Data de Atualização**: 30/05/2026 (Atualização de pendências V2)
**Fase Atual**: Expansão e Retenção (Pós-Lançamento MVP).

---

## 📊 Resumo Executivo (V2)

| Categoria            | Quantidade | Prioridade |
| -------------------- | ---------- | ---------- |
| 🔴 Alta Prioridade   | 3          | Alta       |
| 🟡 Média Prioridade  | 1          | Média      |
| 🟢 Melhorias (UI/UX) | 2          | Baixa      |
| **TOTAL V2**         | **6**      | -          |

---

## 🔴 Features de Alta Prioridade (Core & Retenção)

### 2. **Material Complementar (Módulo Estude)**

- **Status**: 🔄 PENDENTE
- **Descrição**: Adicionar seção de PDFs, links e referências externas dentro das aulas.
- **Estratégia Backend (Firestore):**
  - Popular campo `supplementaryMaterials` no modelo `ILesson` (`src/types/course.ts`) com URLs do Storage.
- **Estratégia Frontend (Expo):**
  - **Telas**: Adicionar ícone/aba de "Materiais" no `CourseCurriculum` ou `LessonPlayer`.
  - **Componentes**: Criar `AttachmentCard` (Ícone + Nome + Peso).
  - **Nativo**: Integrar `expo-file-system` e `expo-sharing` para download e abertura.

### 3. **Aulas Multimídia (Módulo Estude)**

- **Status**: 🔄 PENDENTE
- **Descrição**: Suporte nativo a Vídeo e Áudio nas lições, além do conteúdo literal.
- **Estratégia Backend (Firestore):**
  - Usar campos `videoUrl` e `audioUrl` em `ILesson`.
- **Estratégia Frontend (Expo):**
  - **Dependências**: Instalar `expo-video`.
  - **Navegação**: Refatorar `LessonPlayer` para identificar o tipo de conteúdo e renderizar dinamicamente o `VideoPlayer` ou mini-player colapsável para áudio.

### 4. **Paywall e Monetização (Recursos Premium)**

- **Status**: 🔄 PENDENTE
- **Descrição**: Preparar o app para modelo Freemium e assinaturas pagas via **RevenueCat**.
- **Estratégia Backend:**
  - Configurar RevenueCat e injetar field `isPro: boolean` ou Claim no Firestore em `users/{uid}`.
- **Estratégia Frontend (Expo):**
  - **Dependências**: `react-native-purchases`.
  - **Zustand**: Adaptar `authStore.ts` para capturar a _entitlement_ premium em real-time.
  - **Bloqueio UI**: Implementar ícone de cadeado 🔒 em conteúdos `isPremium: true` e redirecionar para tela de Paywall estilizada.

---

## 🟡 Evolução de Sistema (Média Prioridade)

### 5. **Histórico do Chat com IA**

- **Status**: 🔄 PENDENTE
- **Descrição**: Salvar e exibir o histórico de conversas do usuário com os Guias Mentais no Firestore (estilo ChatGPT).

---

## 🟢 Melhorias (Baixa Prioridade)

### 6. **Fase 7: Polish - Animações e UX**

- **Status**: 🔄 PENDENTE
- **Descrição**: Micro-animações nas listas, quizzes e transições de tela premium (`Lottie`/`Moti`).

---

## 📋 Recomendações de Próximos Passos (Workflow)

1. 🎯 **Módulo Estude**: Materiais Complementares (PDF).
2. 🎯 **Módulo Estude**: Multimídia (Vídeo/Áudio).
3. 🎯 **Monetização**: Criar Paywall e integração RevenueCat.

---

## ✅ Histórico de Conclusões (V2)

- **Transformação Módulo Ore**: ✅ Acolhimento e personalização finalizados (30/05).
- **Engajamento e Gamificação**: ✅ Streak e Loop Espiritual implementados (30/05).
- **Chat Contextual (Sr. Allan)**: ✅ Integrado via `DoubtCard` ao final da aula (29/03).
- **Glossário Contextual**: ✅ `BottomSheetModal` dinâmico e sinônimos (29/03).
- **Padronização BottomSheets**: ✅ Hierarquia visual unificada (29/03).
- **Avaliação (Rate App)**: ✅ Hook `useRateApp` integrado (28/03).
- **Audio Cache/TTS**: ✅ Consolidação de cache e TTS estável.
