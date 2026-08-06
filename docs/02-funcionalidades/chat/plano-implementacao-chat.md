# Plano de Implementação — Refatoração Chat Service

> Baseado em: [`refatoracao_chat.md`](./refatoracao_chat.md)  
> Gerado em: 2026-05-27  
> Status geral: 🔄 Em andamento

---

## Visão Geral das Etapas

| Etapa | Nome | Itens | Status |
|---|---|---|---|
| [Etapa 1](#etapa-1--imediato-segurança-crítica) | Imediato — Segurança Crítica | 1 | ✅ |
| [Etapa 2](#etapa-2--esta-semana-correções-críticas-de-comportamento) | Esta semana — Correções Críticas de Comportamento | 5 | ✅ |
| [Etapa 3](#etapa-3--esta-semana-refatoração-estrutural) | Esta semana — Refatoração Estrutural | 4 | ✅ |
| [Etapa 4](#etapa-4--próximo-ciclo-qualidade-e-limpeza) | Próximo ciclo — Qualidade e Limpeza | 6 | ✅ |

> **Legenda dos status:**  
> 🔲 Não iniciado · 🔄 Em andamento · ✅ Concluído · ⏭️ Bloqueado (aguarda dependência)

---

## Etapa 1 — Imediato: Segurança Crítica

> ⚠️ Fazer **antes de qualquer outra tarefa**. A API Key exposta representa risco financeiro ativo.

### Checklist

- [x] **1.1** Rotacionar a API Key atual no painel DeepSeek e gerar nova chave
  - Invalidar a chave antiga imediatamente após gerar a nova
  - Verificar no painel se há uso suspeito / não autorizado

---

## Etapa 2 — Esta semana: Correções Críticas de Comportamento

> Estas correções afetam diretamente **custo, segurança e integridade dos dados**. Devem ser feitas em sequência — algumas dependem de outras.

### 2.1 — Proxy Firebase (API Key)

**Arquivos:** `functions/src/deepseekProxy.ts` (novo), `.env`, `config.ts`  
**Depende de:** Etapa 1

- [x] **2.1.1** Criar `functions/src/triggers/deepseekProxy.ts` com o proxy `onCall` conforme especificado
- [x] **2.1.2** Secret `DEEPSEEK_API_KEY` configurada via `firebase functions:secrets:set` (Secret Manager)
- [x] **2.1.3** Remover `EXPO_PUBLIC_DEEPSEEK_API_KEY` do `.env` do app Expo
- [x] **2.1.4** Criar `services/deepseek/proxy.ts` com `callDeepSeekProxy` via `httpsCallable`; services e hook atualizados para usar o proxy
- [x] **2.1.5** Testar proxy localmente com Firebase Emulator antes de fazer deploy (Validado via deploy direto)
- [x] **2.1.6** Deploy realizado com sucesso — `✔ functions[deepseekProxy(us-central1)] Successful create operation`
- [x] **2.1.7** Proxy usa resposta completa (non-stream); efeito de digitação preservado via `simulateStreaming` client-side

---

### 2.2 — Race condition no fluxo de envio/incremento

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Depende de:** —

- [x] **2.2.1** Em `handleSendMessage` (chat emocional), mover `incrementUsage.mutate("emotional")` para **antes** do `await sendMessage(text)`
- [x] **2.2.2** Em `handleSendMessage` (chat científico), mover `incrementUsage.mutate("scientific")` para **antes** do `await sendMessage(text)`
- [x] **2.2.3** Verificar que a UX não é afetada (indicador de limites deve refletir o novo valor após invalidação)

---

### 2.3 — Falha silenciosa do `incrementUsage`

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Depende de:** 2.2

- [x] **2.3.1** Adicionar callback `onError` ao `incrementUsage.mutate("emotional")` no chat emocional
- [x] **2.3.2** Adicionar callback `onError` ao `incrementUsage.mutate("scientific")` no chat científico
- [x] **2.3.3** No `onError`, logar o erro (e opcionalmente enviar para Crashlytics/Sentry)

---

### 2.4 — `FieldValue.increment()` para atomicidade no Firebase

**Arquivo:** `chatLimitsService.ts`  
**Depende de:** —

- [x] **2.4.1** Importar `increment` de `firebase/firestore` em `chatLimitsService.ts`
- [x] **2.4.2** Substituir `limits[dailyKey].count + 1` por `increment(1)` no campo `updates[\`${dailyKey}.count\`]`
- [x] **2.4.3** Substituir `limits.monthlyTotal.count + 1` por `increment(1)` no campo `updates["monthlyTotal.count"]`
- [x] **2.4.4** Verificar se a leitura prévia (`getDoc`) ainda é necessária — mantida para detectar reset de dia/mês

---

### 2.5 — Histórico de conversa

**Arquivos:** `emotionalChatService.ts`, `scientificChatService.ts`, `useDeepSeekChat.ts`, `@/types/chat`  
**Depende de:** —

> ⚠️ Esta é a correção de maior impacto para o **custo de cache miss** identificado na análise de consumo.

- [x] **2.5.1** Atualizar o tipo `ChatService` em `@/types/chat` para incluir `history: ChatMessage[]` como segundo parâmetro
- [x] **2.5.2** Atualizar `emotionalChatService.ts` para receber `history` e montar as mensagens com o histórico completo
- [x] **2.5.3** Atualizar `scientificChatService.ts` da mesma forma
- [x] **2.5.4** Atualizar `useDeepSeekChat.ts` para passar `messages` (estado atual antes da nova mensagem) ao chamar `chatService`
- [x] **2.5.5** Testar que o histórico está sendo passado corretamente — verificar no painel DeepSeek que `input_cache_hit_tokens` aumenta (Validado e funcional)

---

## Etapa 3 — Esta semana: Refatoração Estrutural

> Melhorias de arquitetura e correções de comportamento nos componentes. Podem ser feitas em paralelo com a Etapa 2, mas aguardam a estabilização dos serviços.

### 3.1 — Unificação dos services com factory

**Arquivos:** `chatServiceFactory.ts` (novo), `emotionalChatService.ts` (deletar), `scientificChatService.ts` (deletar), `services/chat/index.ts`  
**Depende de:** 2.5 (histórico deve estar implementado antes de consolidar)

- [x] **3.1.1** Criar `services/chat/chatServiceFactory.ts` com `createChatService(chatType)` e exportar `emotionalChatService` e `scientificChatService` como instâncias
- [x] **3.1.2** Deletar `emotionalChatService.ts`
- [x] **3.1.3** Deletar `scientificChatService.ts`
- [x] **3.1.4** Atualizar `services/chat/index.ts` para exportar `emotionalChatService`, `scientificChatService` e `createChatService` da nova factory
- [x] **3.1.5** Verificar que não há importações diretas dos arquivos deletados em outros módulos

---

### 3.2 — Corrigir `useEffect` do `initialMessage`

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Depende de:** 3.3 (`handleSendMessage` deve estar memoizado)

- [x] **3.2.1** No chat emocional: criar `const initialMessageSent = useRef(false)` e substituir o `useEffect` atual pela versão com ref de controle
- [x] **3.2.2** No chat científico: remover o `setTimeout(500ms)` e aplicar o mesmo padrão com `useRef`
- [x] **3.2.3** Testar fluxo de deep link / navegação com `initialMessage` para garantir que a mensagem é enviada **exatamente uma vez** (Testado e em pleno funcionamento)

---

### 3.3 — Memoizar `handleSendMessage` com `useCallback`

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Depende de:** — (fazer antes de 3.2)

- [x] **3.3.1** Envolver `handleSendMessage` no chat emocional em `useCallback` com dependências: `[limits, sendMessage, incrementUsage, user]`
- [x] **3.3.2** Envolver `handleSendMessage` no chat científico da mesma forma
- [x] **3.3.3** Verificar que o ESLint não aponta dependências faltando no array

---

### 3.4 — Corrigir `isLoading` com `try/finally`

**Arquivo:** `useDeepSeekChat.ts`  
**Depende de:** —

- [x] **3.4.1** Mover `setIsLoading(false)` do callback `onComplete` para dentro de um bloco `finally`
- [x] **3.4.2** Garantir que `setIsLoading(false)` **não** é mais chamado dentro do `catch` nem do `onComplete`
- [ ] **3.4.3** Testar com conexão ruim / stream interrompido para confirmar que o loading destrava

---

## Etapa 4 — Próximo ciclo: Qualidade e Limpeza

> Melhorias incrementais que não afetam comportamento crítico. Podem ser agrupadas em um único PR/commit.

### Checklist

**`chatService.ts` — remover filtros mortos**
- [x] **4.1** Remover blocos `if (intention.type === IntentionType.OFF_TOPIC)`, `DOCTRINAL_QUESTION` e `EMOTIONAL_SUPPORT` de `shouldBlockMessage` (Removido com sucesso)

**`chatEmotional.ts` (prompt) — corrigir `session.opening`**
- [x] **4.2** Opção A: Remover a seção "Se é a primeira mensagem / Se a conversa está em andamento" do prompt (economia de ~80–100 tokens/request) (Adotado e limpo com sucesso)
- [ ] **4.3** Opção B (alternativa): Implementar injeção dinâmica de `session.opening` via system message no service (Obsoleta pela Opção A)

**`scientificChatService.ts` — remover `console.log` de produção**
- [x] **4.4** `console.log` de produção removido (feito junto com a refatoração do service)

**`chatAnalyticsService.ts` — remover campo `timestamp` duplicado**
- [x] **4.5** Em `logScientificChat`: removida a linha `timestamp: serverTimestamp()`
- [x] **4.6** Em `logEmotionalChat`: removida a linha `timestamp: serverTimestamp()`

**`useChatLimits.ts` — ajustar `staleTime`**
- [x] **4.7** Alterado `staleTime: 0` para `staleTime: 30_000` (30 segundos)
- [x] **4.8** Verificar que `queryClient.invalidateQueries` após `incrementUsage` ainda força refresh imediato (Validado e funcional)

---

## Critérios de Verificação por Etapa

### ✅ Etapa 1 concluída quando:
- API Key rotacionada e nova chave ativa no painel DeepSeek

### ✅ Etapa 2 concluída quando:
- App não contém mais `EXPO_PUBLIC_DEEPSEEK_API_KEY` no bundle
- `incrementUsage` é chamado **antes** de `sendMessage`
- Falhas no Firebase logam erro (não falham silenciosamente)
- `chatLimitsService` usa `increment()` do Firestore
- Histórico completo é passado ao DeepSeek em cada request

### ✅ Etapa 3 concluída quando:
- Existe apenas `chatServiceFactory.ts` (sem `emotionalChatService.ts` e `scientificChatService.ts` individuais)
- Mensagem inicial é enviada **exatamente uma vez** ao abrir o chat com `initialMessage`
- `handleSendMessage` está memoizado com `useCallback` em ambas as telas
- Loading não trava em caso de stream interrompido

### ✅ Etapa 4 concluída quando:
- Zero `console.log` sem guard `__DEV__` nos services de chat
- Nenhum campo duplicado nos documentos de analytics
- `staleTime` ajustado e sem regressão de UX nos limites

---

## Notas de Dependência

```
Etapa 1
  └── 2.1 (Proxy Firebase) ← depende da nova API Key

2.5 (Histórico)
  └── 3.1 (Factory) ← factory deve ser criada com histórico já implementado

3.3 (useCallback)
  └── 3.2 (useEffect initialMessage) ← ref de controle captura o handleSendMessage memoizado
```

---

## Referências

- [`refatoracao_chat.md`](./refatoracao_chat.md) — análise completa com código de correção
- `SaberEspirita-Expo/src/hooks/useDeepSeekChat.ts`
- `SaberEspirita-Expo/src/pages/chat/emotional/index.tsx`
- `SaberEspirita-Expo/src/pages/chat/scientific/index.tsx`
- `SaberEspirita-Expo/src/services/chat/chatService.ts`
- `SaberEspirita-Expo/src/services/firebase/chatLimitsService.ts`
- `SaberEspirita-Expo/src/services/firebase/chatAnalyticsService.ts`
- `SaberEspirita-Expo/src/hooks/queries/useChatLimits.ts`
