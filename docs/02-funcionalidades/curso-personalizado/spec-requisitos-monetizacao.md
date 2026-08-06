# Documento de Visão e Requisitos
## Geração de Mini-cursos Personalizados — Monetização por Créditos
**App:** Saber Espírita
**Versão:** 1.0 — Rascunho inicial
**Data:** Junho/2026

---

## 1. Visão Geral

O Saber Espírita passará a oferecer uma funcionalidade premium em que o usuário pode **gerar seu próprio mini-curso** (7 aulas, 9 slides cada) sobre um tema espírita de sua escolha, usando IA.

Como essa geração tem **custo real de API** (Anthropic), **custo de armazenamento** (Firestore) e **custo de processamento financeiro** (gateway de pagamento), a funcionalidade será paga via **sistema de créditos pré-pagos**, comprados em uma página externa de checkout.

```
Usuário compra créditos (página externa)
        ↓
Créditos creditados na conta (Firestore)
        ↓
Usuário gera currículo (consome créditos — barato)
        ↓
Usuário revisa/edita currículo (grátis)
        ↓
Usuário gera conteúdo aula por aula (consome créditos — caro)
        ↓
Curso salvo e disponível para consumo (sem custo adicional)
```

---

## 2. Estrutura de Custos (estimativa)

> ⚠️ **Importante:** Os valores de tokens abaixo são **estimativas** baseadas no tamanho dos prompts já desenvolvidos. Devem ser recalibrados com dados reais de uso (`usage.input_tokens` / `usage.output_tokens` retornados pela API) após os primeiros testes em produção. A estrutura de cálculo, porém, já pode ser implementada.

### 2.1 Custo de IA por mini-curso completo (7 aulas)

| Etapa | Modelo | Chamadas | Input/chamada (est.) | Output/chamada (est.) | Custo input | Custo output | Subtotal |
|---|---|---|---|---|---|---|---|
| Currículo (7 aulas) | Haiku 4.5 ($1/$5 por MTok) | 1 | ~800 tokens | ~2.000 tokens | $0,0008 | $0,01 | **$0,0108** |
| Conteúdo — Prompt A (slides 1-5) | Sonnet 4.6 ($3/$15 por MTok) | 7 | ~700 tokens | ~3.500 tokens | $0,0147 | $0,3675 | **$0,3822** |
| Conteúdo — Prompt B (slides 6-9 + reflexão) | Sonnet 4.6 ($3/$15 por MTok) | 7 | ~700 tokens | ~3.000 tokens | $0,0147 | $0,315 | **$0,3297** |
| **Total estimado por mini-curso (7 aulas)** | | **15 chamadas** | | | | | **≈ $0,72 USD** |

Convertendo para BRL (cotação de referência: **R$ 5,50/USD**, ajustar conforme câmbio vigente):

> **Custo de IA estimado por mini-curso completo: ≈ R$ 3,96**

### 2.2 Custo de armazenamento (Firestore)

- Cada aula gerada gera ~1 documento de ~15-25 KB (9 slides com highlights, glossário, referências)
- 7 aulas + 1 documento de curso + 7 documentos de currículo ≈ **~180 KB por mini-curso**
- Custo de armazenamento Firestore: **$0,18/GB/mês** → custo por curso é negligível (<R$ 0,001/mês), mas deve ser considerado em escala (ex: 10.000 cursos = ~1,8 GB = ~$0,32/mês)

> **Custo de armazenamento: tratado como custo fixo de infraestrutura, não rateado individualmente no preço do crédito — revisar se a base de cursos gerados crescer muito.**

### 2.3 Custo do meio de pagamento (gateway)

Taxas típicas de gateways de pagamento no Brasil (cartão de crédito, referência de mercado):

| Gateway | Taxa aproximada |
|---|---|
| Stripe | ~4,99% + R$ 0,39 por transação (cartão internacional) |
| Mercado Pago | ~4,99% (cartão) a depender do plano |
| Pix (quando disponível) | ~0,99% a 1,99% |

> Para o documento, vamos assumir **taxa de gateway de 5% + R$ 0,50 fixo por transação** como cenário conservador (cartão de crédito). Pix, quando suportado, reduzirá esse custo significativamente — recomenda-se priorizá-lo.

---

## 3. Modelo de Créditos

### 3.1 Definição do crédito

Para simplificar a experiência do usuário (evitar expor "tokens" como conceito técnico), define-se:

> **1 crédito = 1 unidade de moeda interna do app, sem vínculo direto e visível com tokens de IA.**

O sistema internamente converte o custo real (em tokens/USD) para créditos, mas o usuário só vê "créditos".

### 3.2 Tabela de consumo por ação

| Ação | Custo real estimado (USD) | Créditos consumidos (proposta) |
|---|---|---|
| Gerar currículo (7 aulas) | ~$0,011 | **5 créditos** |
| Gerar 1 aula completa (9 slides) | ~$0,10 | **15 créditos** |
| Mini-curso completo (currículo + 7 aulas) | ~$0,72 | **5 + (15 × 7) = 110 créditos** |

> A separação currículo vs. conteúdo por aula é importante: o usuário pode gerar o currículo, **revisar, gerar de novo se não gostar (custo baixo)**, e só "gastar pesado" quando for gerar o conteúdo de cada aula — e pode fazer isso aula por aula (lazy generation já definida no schema).

### 3.3 Margem e precificação do crédito

Para definir o **preço de venda do crédito**, soma-se:

```
Preço do crédito = Custo de IA por crédito
                  + Rateio de armazenamento (marginal)
                  + Margem de contribuição (cobre infra geral, suporte, etc.)
                  + Taxa do gateway de pagamento (repassada ou absorvida)
```

**Cálculo de referência (cenário conservador):**

| Componente | Valor |
|---|---|
| Custo de IA por mini-curso (110 créditos) | R$ 3,96 |
| Custo de IA por crédito | R$ 3,96 / 110 ≈ **R$ 0,036** |
| Margem de contribuição sugerida (cobre infra + suporte + lucro) | 150% a 300% sobre custo de IA |
| **Preço sugerido por crédito** | **R$ 0,09 a R$ 0,15** |

**Exemplo de pacote:**

| Pacote | Créditos | Preço sugerido (R$) | Mini-cursos completos gerados | Margem aprox. |
|---|---|---|---|---|
| Starter | 120 créditos | R$ 14,90 | 1 mini-curso completo | ~3,3x custo IA |
| Popular | 350 créditos | R$ 34,90 | ~3 mini-cursos | ~3,4x custo IA |
| Plus | 800 créditos | R$ 69,90 | ~7 mini-cursos | ~3,2x custo IA |

> 💡 **Recomendação:** Antes de fixar valores definitivos, rodar **10-20 gerações reais** e capturar `usage.input_tokens`/`usage.output_tokens` de cada chamada para substituir as estimativas da seção 2.1 por números reais. A estrutura de cálculo acima (custo → créditos → preço) permanece válida, só os números mudam.

---

## 4. Requisitos Funcionais

### RF01 — Saldo de créditos do usuário
- Cada usuário possui um saldo de créditos armazenado em `users/{userId}/wallet`
- Saldo nunca pode ficar negativo
- Sistema deve registrar histórico de transações (compra, consumo, eventual reembolso)

### RF02 — Compra de créditos (checkout externo)
- App exibe pacotes de créditos disponíveis (RF06)
- Ao selecionar um pacote, o usuário é **redirecionado para uma página externa de checkout** (gateway de pagamento)
- A página externa processa o pagamento e notifica o backend via **webhook**
- Backend credita os créditos na carteira do usuário após confirmação do webhook
- App exibe status "processando" enquanto aguarda confirmação, e atualiza saldo automaticamente quando o webhook é recebido

### RF03 — Consumo de créditos
- Antes de iniciar geração de currículo: verificar se `saldo >= custoCurriculo (5 créditos)`. Se não, bloquear ação e direcionar para compra
- Antes de gerar conteúdo de uma aula: verificar se `saldo >= custoAula (15 créditos)`. Se não, bloquear e direcionar para compra
- Débito do saldo deve ocorrer **somente após sucesso confirmado da geração** (evitar cobrar por erro de API)
- Em caso de falha na geração (ex: JSON inválido), créditos não são debitados e usuário pode tentar novamente

### RF04 — Histórico de transações
- Usuário pode visualizar extrato: compras de créditos e consumos (com data, ação e quantidade)
- Cada consumo referencia o `courseId`/`lessonNumber` gerado, para rastreabilidade

### RF05 — Notificação de saldo baixo
- Quando saldo < custo de uma ação comum (ex: < 15 créditos), exibir aviso sutil sugerindo recarga

### RF06 — Pacotes de créditos configuráveis
- Pacotes (quantidade de créditos + preço) devem ser configuráveis remotamente (ex: Firestore `config/creditPackages`), sem necessidade de atualizar o app
- Permite ajustar preços/promoções sem nova versão na loja

### RF07 — Página externa de checkout
- Página web simples (fora do app) que:
  - Recebe `userId` e `packageId` via parâmetros seguros (ex: token assinado/JWT de curta duração)
  - Exibe resumo do pacote e formulário de pagamento do gateway escolhido
  - Após pagamento, redireciona de volta ao app (deep link) com status
  - Envia webhook ao backend confirmando pagamento, independente do redirecionamento (garante crédito mesmo se usuário fechar o navegador)

### RF08 — Segurança e idempotência
- Toda concessão de créditos via webhook deve ser **idempotente** (evitar duplo crédito em caso de reenvio do webhook)
- Toda operação de débito deve ser transacional (Firestore transaction) para evitar condição de corrida (ex: duas gerações simultâneas zerando saldo incorretamente)

---

## 5. Requisitos Não-Funcionais

### RNF01 — Auditabilidade
- Todo movimento de crédito (compra ou consumo) deve gerar um registro imutável em `users/{userId}/transactions/{transactionId}` com timestamp, tipo, valor e referência

### RNF02 — Resiliência a falhas de API
- Se uma chamada de IA falhar (timeout, JSON inválido, erro 5xx), o sistema deve permitir retry sem custo adicional ao usuário

### RNF03 — Transparência de custo
- Antes de cada ação que consome créditos, o app deve exibir claramente "Esta ação consome X créditos. Seu saldo: Y créditos."

### RNF04 — Atualização de preços sem fricção
- Mudanças no custo de IA (ex: Anthropic reajusta preços) devem poder ser refletidas ajustando apenas a tabela de conversão crédito↔ação, sem impactar saldo já comprado pelos usuários

---

## 6. Schema Firestore — Carteira e Transações

```typescript
// users/{userId}/wallet (documento único)
interface IUserWallet {
  balance: number;          // saldo atual em créditos
  updatedAt: string;
}

// users/{userId}/transactions/{transactionId}
interface ICreditTransaction {
  id: string;
  type: "purchase" | "consumption" | "refund";
  amount: number;           // positivo para purchase/refund, negativo para consumption
  balanceAfter: number;

  // Para "purchase"
  packageId?: string;
  paymentProvider?: string; // "stripe" | "mercadopago"
  paymentReference?: string; // id da transação no gateway

  // Para "consumption"
  action?: "generate_curriculum" | "generate_lesson_content";
  courseId?: string;
  lessonNumber?: number;

  createdAt: string;
}

// config/creditPackages (documento único, configurável remotamente)
interface ICreditPackagesConfig {
  packages: {
    id: string;
    label: string;          // "Pacote Popular"
    credits: number;
    priceBRL: number;
    highlight?: boolean;     // destaque visual no app
  }[];
  costs: {
    generateCurriculum: number; // créditos
    generateLessonContent: number; // créditos
  };
}
```

---

## 7. Fluxo de Pagamento Detalhado

```
1. [App] Usuário toca em "Comprar créditos" → vê pacotes (config/creditPackages)
2. [App] Usuário escolhe pacote → app solicita ao backend um "checkout token"
3. [Backend] Gera token assinado (JWT curto prazo) com {userId, packageId, exp}
4. [App] Abre navegador externo: https://checkout.saberespirita.app?token=<jwt>
5. [Página externa] Valida token, exibe resumo do pacote e form do gateway
6. [Usuário] Completa pagamento no gateway (Stripe/Mercado Pago)
7. [Gateway] Processa pagamento → dispara webhook para o backend
8. [Backend] Valida webhook (assinatura do gateway) → idempotência check
9. [Backend] Credita saldo em users/{userId}/wallet (transaction Firestore)
10. [Backend] Cria registro em users/{userId}/transactions (type: purchase)
11. [Página externa] Redireciona para deep link: saberespirita://payment-success
12. [App] Detecta deep link → atualiza saldo exibido (lê wallet atualizado)
```

> Passos 7-10 (webhook) são a **fonte da verdade** — o redirecionamento (11-12) é só UX, não pode ser o único gatilho de crédito (usuário pode fechar o app antes do redirect).

---

## 8. Itens Abertos / Próximos Passos

1. **Escolher gateway de pagamento** (Stripe vs Mercado Pago) — recomenda-se Mercado Pago para Pix no Brasil, considerando taxas menores
2. **Rodar testes reais de geração** para capturar `usage.input_tokens`/`usage.output_tokens` reais das 15 chamadas e recalibrar a Seção 2.1
3. **Definir cotação USD→BRL de referência** e processo de atualização periódica (a variação cambial impacta diretamente a margem)
4. **Definir página externa de checkout** — stack (ex: Next.js simples) e hospedagem (Cloudflare Pages, já usado no projeto)
5. **Definir política de reembolso** — o que acontece se o usuário comprar créditos e nunca gerar nada? Há prazo de validade dos créditos?
6. **Decidir se currículo "regenerar" tem custo reduzido** após a primeira geração (ex: 2ª regeneração custa menos, incentivando experimentação)
7. **Definir limites antifraude** — ex: máximo de gerações por hora/dia por usuário, mesmo com saldo disponível, para evitar abuso/custos inesperados

---

*Este documento é um ponto de partida vivo — deve ser atualizado conforme dados reais de uso, custos de API e decisões de produto forem confirmados.*
