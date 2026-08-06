# Estratégia de Gestão de Atividade e Retenção de Usuários

Este documento descreve a estratégia proposta para monitorar o engajamento dos usuários, gerenciar a retenção via notificações e manter a higiene da base de dados (Firebase Auth e Firestore).

## 1. O Desafio: Login Persistente vs. Atividade Real
No ecossistema mobile, o padrão de manter o usuário logado indefinidamente é essencial para uma boa Experiência do Usuário (UX). Entretanto, isso cria um "ponto cego" onde usuários que não acessam o aplicativo há meses ainda constam como "logados", dificultando a distinção entre usuários ativos e "zumbis".

## 2. Proposta Técnica: O Campo `lastSeenAt`
Para resolver o problema da visibilidade sem forçar logouts indesejados, propõe-se a implementação de um rastro de atividade.

*   **Implementação**: Adicionar um campo `lastSeenAt` (Timestamp) no documento do usuário em `/users`.
*   **Gatilho**: Atualização silenciosa sempre que o app é aberto ou retorna do background (`AppState`).
*   **Vantagem**: Permite métricas precisas de usuários inativos e segmentação para campanhas de marketing.

## 3. Estratégia de Retenção (Push Notifications)
Utilizando a integração já existente com o **OneSignal**, a retenção pode ser automatizada sem necessidade de código adicional complexo:

*   **Segmentação**: Criar segmentos automáticos baseados na "Last Session" (ex: Inativo há 7 dias, 15 dias, 30 dias).
*   **Re-engajamento**: Configurar notificações automáticas (Drip Campaigns) para convidar o usuário de volta com gatilhos de curiosidade (ex: "Veja o desafio do dia").

## 4. Higiene de Dados (Varrer Inativos)
Para manter o banco de dados otimizado e reduzir custos/riscos, propõe-se um fluxo de limpeza via **Cloud Functions** (Scheduled Functions):

| Período de Inatividade | Ação Proposta | Canal |
| :--- | :--- | :--- |
| **6 meses** | Notificação de "Sentimos sua falta" | Push |
| **11 meses** | Aviso de desativação de conta por inatividade | Push / E-mail |
| **12 meses** | Exclusão definitiva dos dados (Auth + Firestore) | - |

### 4.1 Processo de Limpeza (Fase 12 Meses):
1.  **Firebase Auth**: Deletar o UID do Authentication via Admin SDK.
2.  **Firebase Storage**: Deletar prefixo `certificates/{uid}/`.
3.  **OneSignal**: Deletar registro via API usando o `external_user_id` (UID).
4.  **Firestore**: Realizar o delete de todos os documentos e subcoleções vinculados ao UID.

### 4.2 Mapeamento de Rastros (Footprint)
Para garantir a exclusão definitiva, a Cloud Function deve processar os seguintes caminhos:

| Tipo | Caminho / Coleção | Identificador |
| :--- | :--- | :--- |
| **Documento** | `users/{uid}` | ID do Documento |
| **Documento** | `users_scores/{uid}` | ID do Documento |
| **Documento** | `users_completed_subcategories/{uid}` | ID do Documento |
| **Documento** | `users_history/{uid}` | ID do Documento |
| **Documento** | `chatLimits/{uid}` | ID do Documento |
| **Documento** | `user_prayer_favorites/{uid}` | ID do Documento |
| **Documento** | `user_reflection_favorites/{uid}` | ID do Documento |
| **Coleção** | `ambient_player_logs` | Campo `userId` |
| **Coleção** | `scientific_chat_logs` | Campo `userId` |
| **Coleção** | `emotional_chat_logs` | Campo `userId` |
| **Coleção** | `meditation_logs` | Campo `userId` |
| **Coleção** | `prayer_logs` | Campo `userId` |
| **Coleção** | `certificates` | Campo `userId` |
| **Coleção** | `course_feedbacks` | Campo `userId` |
| **Subcoleção** | `users/{uid}/truthOrFalseResponses` | Recursivo |
| **Subcoleção** | `users/{uid}/courseProgress` | Recursivo |
| **Subcoleção** | `users/{uid}/history` | Recursivo |
| **Subcoleção** | `users/{uid}/progress` | Recursivo |
| **Array** | `broadcast_logs/{hash}` | Campo `sentToEmails` |


## 5. Benefícios Estratégicos
*   **Métricas Reais**: Foco no DAU (Daily Active Users) e MAU (Monthly Active Users), e não em downloads brutos.
*   **Conformidade (LGPD)**: Atendimento às normas de privacidade que sugerem a não manutenção de dados desnecessários.
*   **Performance**: Consultas mais rápidas em coleções globais (rankings, estatísticas) ao remover dados obsoletos.
*   **Custo**: Redução no faturamento do Firebase por armazenamento e, principalmente, por leitura de documentos em consultas de larga escala.

---
**Nota**: Esta estratégia é um roteiro evolutivo. A fase 1 (coleta de `lastSeenAt`) é o pré-requisito para todas as demais ações.
