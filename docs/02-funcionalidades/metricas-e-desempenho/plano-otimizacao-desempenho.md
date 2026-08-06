# Plano de Otimização: Tela Meu Desempenho e Cálculos de Scores

Este documento registra o diagnóstico e a proposta de solução para a otimização de leituras no Firestore na tela **Meu Desempenho** e no processo de finalização de quizzes no aplicativo mobile `SaberEspirita-Expo`.

---

## 1. O Diagnóstico do Problema

Atualmente, duas funções principais dependem de ler a subcoleção de histórico de quizzes inteira do usuário (`/users_history/{userId}/history`), gerando um consumo de leituras linear $N$ (onde $N$ é a quantidade total de quizzes que o usuário já respondeu):

1. **Tela "Meu Desempenho" (`getUserDetailedStats`):** A cada abertura da tela, o aplicativo realiza um `getDocs` em todo o histórico de quizzes daquele usuário para somar e calcular as médias de desempenho em tempo real.
2. **Cálculo e Atualização de Scores (`updateUserScore`):** Toda vez que o usuário encerra uma partida, para atualizar suas pontuações semanais, mensais e gerais de ranking, o aplicativo busca a subcoleção de histórico inteira do usuário no Firestore, faz a soma local no celular e sobrescreve o documento `users_scores/{userId}`.

### O Impacto Financeiro (Consumo de Leituras):
Se um usuário ativo tiver **300 quizzes concluídos** em seu histórico:
* Abrir a tela de estatísticas consome **300 leituras** do Firestore.
* Finalizar um novo quiz consome **300 leituras** do Firestore para atualizar a pontuação no ranking.

Para milhares de usuários, esse consumo escala de forma insustentável.

---

## 2. A Solução Proposta: Modelo Incremental Consolidado

A solução consiste em migrar do cálculo reativo (que lê todo o histórico do zero) para um **modelo de dados incremental e consolidado**. Armazenamos as métricas acumuladas diretamente no documento `users_scores/{userId}` e as incrementamos à medida que novas partidas são finalizadas.

### Passo 1: Atualização Incremental ao Finalizar o Quiz (Mobile)
Ao concluir uma partida com $Q$ questões (sendo $C$ corretas) e somar $S$ pontos, o aplicativo apenas faz uma escrita de atualização usando `increment()` do Firestore.
* **Custo de Leituras:** Reduzido de $N$ para **0 leituras**.
* **Escritas:** 1 escrita de atualização.

Exemplo conceitual de escrita:
```typescript
import { doc, updateDoc, increment, serverTimestamp } from "firebase/firestore";

const scoreRef = doc(db, "users_scores", userId);
await updateDoc(scoreRef, {
  totalAllTime: increment(scoreObtido),
  totalThisWeek: increment(scoreObtido),
  totalThisMonth: increment(scoreObtido),
  totalQuestions: increment(questoesRespondidas),
  totalCorrect: increment(questoesCorretas),
  bestScore: Math.max(existingBestScore, percentage),
  lastUpdated: serverTimestamp()
});
```

*(Nota: Como a Cloud Function de agendamento no backend zera `totalThisWeek` e `totalThisMonth` na virada do ciclo, a gravação incremental no mobile funcionará de forma perfeitamente sincronizada).*

### Passo 2: Otimização da Leitura na Tela "Meu Desempenho" (Mobile)
Em vez de buscar todo o histórico de quizzes, a tela realiza uma leitura única de documento em `users_scores/{userId}`.
* **Custo de Leituras:** Reduzido de $N$ para **1 leitura**.

Exemplo conceitual de leitura:
```typescript
import { doc, getDoc } from "firebase/firestore";

const docSnap = await getDoc(doc(db, "users_scores", userId));
const data = docSnap.data();

const stats = {
  totalQuestions: data.totalQuestions || 0,
  accuracyRate: data.totalQuestions > 0 
    ? Math.round((data.totalCorrect / data.totalQuestions) * 100) 
    : 0,
  activeDays: data.activeDays || 1, // calculado incrementalmente no banco
  bestScore: data.bestScore || 0,
};
```

---

## 3. Benefícios
1. **Redução Drástica na Conta do Firebase:** Substitui o crescimento linear $N$ de leituras por apenas **1 leitura** para carregar a tela e **0 leituras** para registrar a pontuação.
2. **Escalabilidade:** O aplicativo consumirá o mesmo volume de leituras quer o usuário tenha 10 ou 10.000 quizzes respondidos no histórico.
3. **Velocidade de Carregamento:** A tela de desempenho carregará instantaneamente, pois não precisará baixar centenas de documentos do banco.

---

## 4. Estratégia de Transição e Migração

Para realizar a implantação dessa melhoria com segurança para a base de usuários existente, o processo envolve um plano de migração no backend e publicação do app.

### Passo 1: Migração de Dados (Backend)
* **Necessidade:** Usuários antigos não possuem os novos campos consolidados (`totalQuestions`, `totalCorrect`, etc.) preenchidos no documento `/users_scores/{userId}`. Se abrirmos a nova tela para eles sem a migração, as estatísticas apareceriam zeradas.
* **Solução:** Criar uma Cloud Function HTTPS de uso único (ou script de manutenção) no backend para varrer todos os usuários, somar os históricos existentes e inicializar/popular os respectivos campos consolidados em `/users_scores/{userId}`. Isso roda em background, sem tirar o app do ar.

### Passo 2: Publicação Suave (Rollout Zero-Downtime)
1. **Deploy e Migração:** Subir o código de suporte do backend e rodar a rotina de migração para que 100% dos usuários antigos tenham os campos populados no banco de dados.
2. **Atualização do App:** Publicar a nova versão do aplicativo na App Store/Play Store.
   * **Retrocompatibilidade:** Os usuários que demorarem a atualizar o aplicativo continuarão a usar a lógica antiga (que lê o histórico e sobrescreve o documento de scores). Isso continua funcionando normalmente no banco de dados, sem quebrar.
   * **Nova Lógica:** Os usuários que atualizarem passarão imediatamente a salvar de forma incremental (0 reads) e a ler o resumo (1 read).

### Passo 3: Retenção de Dados Históricos (Histórico Frio)
* **Recomendação:** **NÃO apagar** a subcoleção de histórico bruto `/users_history/{userId}/history`.
* **Motivo:**
  1. **Fonte da Verdade:** Serve como backup histórico em caso de necessidade de recalcular pontuações ou se as regras de ranqueamento mudarem no futuro.
  2. **Novas Funcionalidades:** Essencial caso futuramente se decida implementar gráficos temporais de desempenho (ex: evolução mensal do usuário).
  3. **Custo Mínimo:** O custo de armazenamento no Firestore é extremamente baixo (centavos por GB). O que encarece a fatura são as leituras ativas. Ao mover a tela de desempenho para ler o resumo, o histórico passa a ser um "dado frio" (sem uso ativo de rede), gerando custo de leitura nulo.
