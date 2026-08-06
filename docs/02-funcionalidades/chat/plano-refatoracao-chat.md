# Refatoração — Chat Service (DeepSeek + Expo)

> Documento gerado a partir de análise de código e revisão técnica.  
> Destinado ao Antigravity IDE para execução das correções descritas.

---

## Contexto

App Expo/React Native com dois assistentes de chat espírita:
- **Guia Emocional** — apoio emocional e consolo espiritual
- **Sr. Allan Kardec** — esclarecimentos doutrinários

Ambos utilizam a API DeepSeek com streaming via SDK OpenAI-compatible.

---

## Análise de Consumo (CSV maio/2026)

Durante a revisão, foram analisados arquivos de uso da API referentes a maio de 2026. O padrão identificado foi:

- Entre 01–18/mai: custo estável de ~$0,005–$0,01/dia, com ~30–45 requests/dia
- A partir de 20/mai: crescimento exponencial
- 25/mai: $1,21 — 411 requests — 6,6M tokens `input_cache_miss`
- 26/mai: $1,68 — 671 requests — 6,4M tokens `input_cache_miss`
- 27/mai: $2,06 — 793 requests — 9,8M tokens `input_cache_miss`

**Causa raiz identificada:** combinação de dois fatores:
1. Explosão no número de requests (~22x em uma semana)
2. `input_cache_miss_tokens` altíssimo — o cache do DeepSeek não está sendo aproveitado

---

## Problemas Identificados e Correções

---

### 1. 🔴 API Key exposta no bundle do app

**Arquivo:** `.env`  
**Problema:** A variável `EXPO_PUBLIC_DEEPSEEK_API_KEY` é embutida em texto claro no bundle do APK/IPA durante o build. Qualquer pessoa que descompile o app tem acesso à chave. Isso representa risco direto de uso indevido e custo não autorizado.

**Correção:**

Criar um proxy backend — recomendado via **Firebase Cloud Function** (já utilizado no projeto).

O app passa a chamar o endpoint próprio, que repassa ao DeepSeek:

```
App Expo → Firebase Cloud Function → DeepSeek API
```

**Passos:**
1. Rotacionar a chave atual no painel DeepSeek imediatamente
2. Criar Cloud Function `deepseekProxy` conforme abaixo
3. Remover `EXPO_PUBLIC_DEEPSEEK_API_KEY` do `.env` do app
4. No app, substituir a URL da API pela URL da Cloud Function

**Cloud Function (Firebase):**

```typescript
// functions/src/deepseekProxy.ts
import * as functions from "firebase-functions";
import OpenAI from "openai";

const deepseek = new OpenAI({
  apiKey: process.env.DEEPSEEK_API_KEY, // variável de ambiente do servidor
  baseURL: "https://api.deepseek.com/v1",
});

export const deepseekProxy = functions.https.onCall(async (data, context) => {
  // Validar autenticação
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login necessário");
  }

  const { messages, chatType } = data;

  const temperature = chatType === "emotional" ? 0.7 : 0.3;
  const maxTokens = chatType === "emotional" ? 800 : 1200;

  const response = await deepseek.chat.completions.create({
    model: "deepseek-chat",
    messages,
    temperature,
    max_tokens: maxTokens,
    stream: false, // Cloud Functions não suportam streaming nativo
  });

  return { content: response.choices[0]?.message?.content || "" };
});
```

> **Nota sobre streaming:** Cloud Functions HTTP não suportam streaming SSE de forma simples. A alternativa é usar respostas completas (non-stream) ou migrar para Cloud Run, que suporta streaming.

---

### 2. 🔴 Sem histórico de conversa

**Arquivos:** `emotionalChatService.ts`, `scientificChatService.ts`  
**Problema:** Ambos os services enviam apenas a mensagem atual ao modelo:

```typescript
// ❌ Atual — sem memória
const history = [{ role: "user", content: userMessage }];
```

O modelo não tem contexto da conversa anterior. Para um assistente emocional isso é crítico — o usuário precisa ser reconhecido entre turnos.

**Correção:**

Passar o histórico completo do hook para o service:

```typescript
// ✅ Correto
export const emotionalChatService: ChatService = async (
  userMessage,
  history,          // <-- novo parâmetro
  onChunkReceived,
  onComplete
) => {
  const messages = [
    ...history,
    { role: "user" as const, content: userMessage }
  ];

  const stream = await streamDeepSeekChat(messages, ChatType.EMOTIONAL);
  // ...
};
```

E no `useDeepSeekChat.ts`, passar `messages` ao chamar o service:

```typescript
// useDeepSeekChat.ts
await chatService(
  userMessage,
  messages, // histórico atual antes da nova mensagem
  (chunk) => { ... },
  (fullResponse) => { ... }
);
```

Atualizar também o tipo `ChatService` em `@/types/chat`:

```typescript
export type ChatService = (
  userMessage: string,
  history: ChatMessage[],
  onChunkReceived: (chunk: string) => void,
  onComplete: (fullResponse: string) => void
) => Promise<void>;
```

---

### 3. 🟠 Duplicação de código — services idênticos

**Arquivos:** `emotionalChatService.ts`, `scientificChatService.ts`  
**Problema:** Os dois arquivos são funcionalmente idênticos. A única diferença é o `ChatType` passado e um `console.log`. Qualquer alteração precisa ser feita nos dois lugares.

**Correção:** Unificar em uma factory:

```typescript
// chatServiceFactory.ts
import { ChatService } from "@/types/chat";
import { streamDeepSeekChat } from "../deepseek";
import { ChatType } from "../prompt";

export const createChatService = (chatType: ChatType): ChatService =>
  async (userMessage, history, onChunkReceived, onComplete) => {
    const messages = [
      ...history,
      { role: "user" as const, content: userMessage },
    ];

    const stream = await streamDeepSeekChat(messages, chatType);
    let fullResponse = "";

    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || "";
      if (content) {
        fullResponse += content;
        onChunkReceived(content);
      }
    }

    onComplete(fullResponse);
  };

// Instâncias exportadas
export const emotionalChatService = createChatService(ChatType.EMOTIONAL);
export const scientificChatService = createChatService(ChatType.SCIENTIFIC);
```

Após isso, deletar `emotionalChatService.ts` e `scientificChatService.ts` como arquivos separados.

---

### 4. 🟠 `chatService.ts` duplicado

**Arquivo:** `chatService.ts`  
**Problema:** O arquivo aparece duplicado no projeto — conteúdo idêntico em dois lugares.

**Correção:** Manter apenas uma instância. Verificar se há dois arquivos com o mesmo nome em paths diferentes e remover o redundante.

---

### 5. 🟡 Filtros mortos no `intentionDetector`

**Arquivos:** `intentionDetector.ts`, `chatService.ts`  
**Problema:** O `detectIntention` só retorna `GREETING`, `END_CONVERSATION` e `UNKNOWN`. Os valores `OFF_TOPIC`, `DOCTRINAL_QUESTION` e `EMOTIONAL_SUPPORT` **nunca são retornados**, tornando os blocos correspondentes em `shouldBlockMessage` código morto — executam zero vezes em produção.

**Opção A — Remover os blocos mortos** (mais simples):

```typescript
// chatService.ts — remover estes blocos:
// if (intention.type === IntentionType.OFF_TOPIC) { ... }
// if (intention.type === IntentionType.DOCTRINAL_QUESTION) { ... }
// if (intention.type === IntentionType.EMOTIONAL_SUPPORT) { ... }
```

**Opção B — Implementar detecção semântica via LLM** (mais completa):

Adicionar uma chamada leve ao DeepSeek antes de processar a mensagem, retornando apenas o tipo de intenção em JSON. Mais custoso, mas habilita o redirecionamento entre assistentes.

> Recomendação: adotar Opção A agora, Opção B em iteração futura se o redirecionamento for necessário.

---

### 6. 🟡 `isLoading` pode ficar preso em `true`

**Arquivo:** `useDeepSeekChat.ts`  
**Problema:** `setIsLoading(false)` é chamado apenas dentro de `onComplete`. Se o stream terminar sem acionar o callback (stream vazio, interrupção), o loading nunca é desligado — a UI trava.

**Correção:** Usar `try/finally`:

```typescript
// useDeepSeekChat.ts
try {
  await chatService(
    userMessage,
    messages,
    (chunk) => { ... },
    (fullResponse) => {
      setMessages((prev) => /* atualiza */);
      // NÃO chamar setIsLoading(false) aqui
    }
  );
} catch (err) {
  // trata erro
} finally {
  setIsLoading(false); // sempre executado
}
```

---

### 7. 🟢 `staleTime: 0` no `useChatLimits`

**Arquivo:** `useChatLimits.ts`  
**Problema:** `staleTime: 0` força refetch ao Firebase a cada montagem de componente que usa o hook, mesmo que os dados não tenham mudado.

**Correção:**

```typescript
// useChatLimits.ts
staleTime: 30_000, // 30 segundos — suficiente entre verificações
```

Os dados são invalidados corretamente via `queryClient.invalidateQueries` após `incrementUsage`, então não há risco de dados desatualizados.

---

## Novos Problemas Identificados (Análise de Código)

---

### 8. 🔴 Race condition: limite verificado antes, incremento executado depois

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Problema:** O fluxo atual em `handleSendMessage` é:

```
1. Verificar limits.canSend  ← snapshot do React Query (pode estar desatualizado)
2. await sendMessage(text)   ← chamada real à API (pode durar vários segundos)
3. incrementUsage.mutate()   ← só então incrementa o contador
```

Durante o `await sendMessage`, o usuário pode disparar um **segundo envio** (ou outro dispositivo pode enviar) antes do contador ser incrementado. Como `useChatLimits` tem `staleTime: 0` mas não invalida em tempo real, o sistema acredita que o limite ainda não foi atingido. Resultado: **bypass do limite por envio concorrente**.

**Correção:** Incrementar o uso **antes** de chamar `sendMessage`, ou usar transação atômica no Firebase (FieldValue.increment com verificação server-side).

```typescript
// Correto: incrementar antes de enviar
incrementUsage.mutate("emotional");
await sendMessage(text);
```

---

### 9. 🔴 `incrementUsage` falha silenciosamente sem feedback ao usuário

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Problema:** O `.mutate()` é chamado sem `onError`:

```typescript
incrementUsage.mutate("emotional"); // ← sem onError, sem await
```

Se o Firebase falhar (offline, permissão negada, timeout), o contador **não é incrementado** mas a mensagem já foi enviada e consumiu tokens da API. O usuário fica com uso não contabilizado — limite nunca é atingido, custo cresce sem controle.

**Correção:** Verificar o resultado da mutation e logar/alertar em caso de falha:

```typescript
incrementUsage.mutate("emotional", {
  onError: (err) => {
    console.error("[ChatLimits] Falha ao incrementar uso:", err);
    // Opcional: notificar Sentry/Crashlytics
  },
});
```

---

### 10. 🟠 `useEffect` do `initialMessage` com dependências incorretas (chat emocional)

**Arquivo:** `emotional/index.tsx` (linha 43–47)  
**Problema:** O `useEffect` que dispara a mensagem inicial lista `isLoading` no array de dependências:

```typescript
useEffect(() => {
  if (initialMessage && messages.length === 0 && !isLoading) {
    handleSendMessage(initialMessage);
  }
}, [initialMessage, messages.length, isLoading]); // ← isLoading causa re-trigger
```

Quando `sendMessage` é chamado, `isLoading` muda para `true` e depois para `false`. Isso **re-executa o effect** ao final do streaming — e como `messages.length` ainda pode ser 0 no momento da verificação (antes do setState committar), há risco de **envio duplicado da mensagem inicial**.

O chat científico resolve isso de forma diferente (linha 88) com `setTimeout` e removendo `messages.length` do dep array, mas isso apenas mascara o problema.

**Correção:** Usar uma `ref` de controle para garantir que a mensagem inicial seja enviada apenas uma vez:

```typescript
const initialMessageSent = useRef(false);

useEffect(() => {
  if (initialMessage && !initialMessageSent.current) {
    initialMessageSent.current = true;
    handleSendMessage(initialMessage);
  }
}, []); // eslint-disable-line react-hooks/exhaustive-deps
```

---

### 11. 🟠 `handleSendMessage` capturado em closure desatualizada no `useEffect`

**Arquivos:** `emotional/index.tsx`, `scientific/index.tsx`  
**Problema:** `handleSendMessage` é declarado como `function` regular no corpo do componente (não memoizado com `useCallback`). O `useEffect` que usa `initialMessage` captura a versão do primeiro render, quando `limits` ainda é `undefined`.

Isso significa que a verificação de limite dentro de `handleSendMessage` **não será executada** para a mensagem inicial — mesmo que o usuário já tenha atingido o limite.

**Correção:** Envolver `handleSendMessage` em `useCallback` com as dependências corretas:

```typescript
const handleSendMessage = useCallback(async (text: string) => {
  // ...lógica existente...
}, [limits, sendMessage, incrementUsage, user]);
```

---

### 12. 🟠 `console.log` de produção no `scientificChatService`

**Arquivo:** `scientificChatService.ts` (linha 14)  
**Problema:**

```typescript
console.log("🔵 scientificChatService: Processando mensagem");
```

Este log é executado a cada mensagem enviada no chat científico, em produção. Com 671 requests em 26/mai, isso gera 671 entradas de log desnecessárias. Em ambientes com ferramentas de monitoramento de performance (como Hermes profiler), logs excessivos afetam performance.

**Correção:** Envolver em guard `__DEV__` ou remover:

```typescript
if (__DEV__) {
  console.log("🔵 scientificChatService: Processando mensagem");
}
```

---

### 13. 🟠 `index.ts` do `services/chat` não exporta `scientificChatService`

**Arquivo:** `services/chat/index.ts`  
**Problema:** O barrel file exporta `emotionalChatService` diretamente, mas não exporta `scientificChatService`:

```typescript
export { emotionalChatService } from "./emotionalChatService";
// scientificChatService não é exportado pelo index
```

Isso cria assimetria e força importações diretas do arquivo. Após a refatoração com factory (item 4), esse index precisará ser atualizado para refletir a nova estrutura.

---

### 14. 🟡 Prompt instrui sobre `session.opening` mas o campo nunca é enviado

**Arquivos:** `chatEmotional.ts` (prompt), `emotionalChatService.ts`  
**Problema:** O prompt do Guia Emocional contém instruções que dependem de um campo `session.opening`:

```
### Se é a primeira mensagem (`session.opening = true`):
> "Olá, amigo(a). 🌿 ..."

### Se a conversa está em andamento (`session.opening = false`):
> "Sinto a intensidade das emoções..."
```

Porém, o service **nunca envia esse campo** ao modelo. O DeepSeek recebe apenas as mensagens sem qualquer metadado de sessão. O modelo simplesmente ignora essa instrução, tornando esse bloco do prompt **letra morta** — desperdício de tokens de input em cada request (~80–100 tokens extras).

**Correção:** Remover essa seção do prompt até que seja implementada de fato. Alternativamente, injetar via system message dinâmica:

```typescript
const sessionMeta = history.length === 0
  ? "session.opening = true"
  : "session.opening = false";

const systemPrompt = `${getSystemPrompt(chatType)}\n\n[${sessionMeta}]`;
```

---

### 15. 🟡 Dupla gravação de `timestamp` e `createdAt` no analytics

**Arquivo:** `chatAnalyticsService.ts` (linhas 27–32 e 62–65)  
**Problema:** Ambas as funções de log gravam dois campos de timestamp redundantes:

```typescript
createdAt: serverTimestamp(),
// ...
timestamp: serverTimestamp(), // duplicado
```

Cada document do Firestore tem dois campos de data idênticos. Além da redundância semântica, o Firebase cobra por byte escrito — campos desnecessários aumentam levemente o custo e o tamanho de cada documento.

**Correção:** Remover `timestamp`, manter apenas `createdAt` (nome semântico e consistente com o restante do projeto).

---

### 16. 🟡 `checkCanSendMessage` faz `getDoc` a cada verificação — sem cache local

**Arquivo:** `chatLimitsService.ts`  
**Problema:** Cada chamada a `checkCanSendMessage` faz um `getDoc` ao Firestore. Com `staleTime: 0` no React Query, isso pode gerar leituras repetidas em rápida sucessão — por exemplo, ao montar o componente + refetch automático + invalidação pós-envio. Em um dia com 671 requests, o número real de leituras ao Firestore pode ser 2–3x maior.

O React Query **já é o cache** aqui, então o problema é o `staleTime: 0` forçar sempre um novo `getDoc`. A correção do item 7 (`staleTime: 30_000`) resolve indiretamente esse problema também.

> Relacionado ao item 7 — a correção do `staleTime` elimina a maioria das leituras desnecessárias.

---

### 17. 🟡 `incrementUsage` no Firebase não é atômico — risco de contador incorreto

**Arquivo:** `chatLimitsService.ts` (linha 130–176)  
**Problema:** O `incrementUsage` faz read-then-write manualmente:

```typescript
const limitsSnap = await getDoc(limitsRef);  // lê o valor atual
const limits = limitsSnap.data();
updates[`${dailyKey}.count`] = limits[dailyKey].count + 1;  // incrementa em memória
await updateDoc(limitsRef, updates);  // grava
```

Em ambiente com múltiplos dispositivos (usuário logado em celular e tablet simultaneamente), duas operações concorrentes podem ler o mesmo valor `count = 5`, ambas calcularem `6` e gravarem `6` — quando o correto seria `7`. O Firestore tem `FieldValue.increment()` exatamente para isso.

**Correção:**

```typescript
import { increment } from "firebase/firestore";

updates[`${dailyKey}.count`] = increment(1);
updates["monthlyTotal.count"] = increment(1);
```

---

## Ordem de Execução Recomendada

| # | Prioridade | Tarefa | Arquivo(s) |
|---|---|---|---|
| 1 | 🔴 Imediato | Rotacionar API key no painel DeepSeek | — |
| 2 | 🔴 Esta semana | Criar Cloud Function proxy e remover chave do app | `functions/src/deepseekProxy.ts`, `.env`, `config.ts` |
| 3 | 🔴 Esta semana | Corrigir race condition no fluxo de envio/incremento | `emotional/index.tsx`, `scientific/index.tsx` |
| 4 | 🔴 Esta semana | Tratar falha silenciosa do `incrementUsage` | `emotional/index.tsx`, `scientific/index.tsx` |
| 5 | 🟠 Esta semana | Implementar histórico de conversa | `emotionalChatService.ts`, `scientificChatService.ts`, `useDeepSeekChat.ts`, `@/types/chat` |
| 6 | 🟠 Esta semana | Unificar services com factory + remover duplicação de `chatService.ts` | `chatServiceFactory.ts` |
| 7 | 🟠 Esta semana | Corrigir `useEffect` do `initialMessage` com ref de controle | `emotional/index.tsx`, `scientific/index.tsx` |
| 8 | 🟠 Esta semana | Memoizar `handleSendMessage` com `useCallback` | `emotional/index.tsx`, `scientific/index.tsx` |
| 9 | 🟠 Esta semana | Usar `FieldValue.increment()` no Firebase para atomicidade | `chatLimitsService.ts` |
| 10 | 🟠 Esta semana | Corrigir barrel file `index.ts` do chat | `services/chat/index.ts` |
| 11 | 🟡 Próximo ciclo | Remover filtros mortos do `intentionDetector` | `chatService.ts` |
| 12 | 🟡 Próximo ciclo | Corrigir `isLoading` com `finally` | `useDeepSeekChat.ts` |
| 13 | 🟡 Próximo ciclo | Remover seção `session.opening` do prompt ou implementá-la | `chatEmotional.ts`, `emotionalChatService.ts` |
| 14 | 🟡 Próximo ciclo | Remover `console.log` de produção no `scientificChatService` | `scientificChatService.ts` |
| 15 | 🟡 Próximo ciclo | Remover campo `timestamp` duplicado no analytics | `chatAnalyticsService.ts` |
| 16 | 🟢 Quando conveniente | Ajustar `staleTime` no `useChatLimits` | `useChatLimits.ts` |
