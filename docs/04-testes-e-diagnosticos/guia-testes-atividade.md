# Guia de Testes: Gestão de Atividade e Retenção

Este documento descreve como validar e testar manualmente o fluxo de monitoramento de atividade (`lastSeenAt`) e as rotinas de limpeza/retenção via Cloud Functions.

---

## 1. Validando o Rastro de Atividade (Mobile)

O objetivo é garantir que o aplicativo está "carimbando" a atividade do usuário no Firestore corretamente.

1.  **Acesso Inicial**: Abra o aplicativo e faça login.
2.  **Verificação no Firestore**:
    *   Vá ao Console do Firebase -> Firestore.
    *   Localize o documento do seu usuário em `/users/{uid}`.
    *   Verifique se o campo `lastSeenAt` existe e contém o horário atual.
3.  **Teste de Throttling (30 min)**:
    *   Feche e abra o app. O campo `lastSeenAt` **não** deve mudar.
    *   Para forçar uma nova atualização: No Firestore, mude manualmente o `lastSeenAt` para uma data de **ontem**.
    *   Abra o app novamente. O campo deve ser atualizado para o horário de **agora**.

---

## 2. Simulando Ciclos de Inatividade

Para testar as fases de 6, 11 e 12 meses sem esperar o tempo real, devemos manipular as datas diretamente no banco de dados.

### Preparação do Usuário de Teste
No documento do usuário no Firestore (`/users/{uid}`), ajuste os campos conforme o cenário desejado:

| Cenário de Teste | Ajuste no `lastSeenAt` | Flags Adicionais |
| :--- | :--- | :--- |
| **Fase 6 Meses (Saudade)** | Alterar para **7 meses atrás** | `notified6Months` = `false` ou inexistente |
| **Fase 11 Meses (Aviso)** | Alterar para **11 meses e meio atrás** | `notified11Months` = `false` ou inexistente |
| **Fase 12 Meses (Limpeza)** | Alterar para **13 meses atrás** | N/A |

---

## 3. Disparando a Cloud Function Manualmente

A função `cleanupInactiveUsers` está agendada para as 03:00 AM. Para testar agora:

1.  Acesse o [Google Cloud Console](https://console.cloud.google.com/).
2.  Navegue até **Cloud Scheduler**.
3.  Localize a tarefa: `firebase-schedule-cleanupInactiveUsers-us-central1`.
4.  Clique no botão **"Force Run"** (ou "Executar agora").

### Monitoramento de Logs
Acompanhe o que está acontecendo em tempo real pelo terminal (na pasta do projeto Web):
```bash
pnpm run logs
```
Você verá mensagens como `[Cleanup] Aviso de 11 meses enviado para...` ou `[Cleanup] Usuário removido por inatividade...`.

---

## 4. Checklist de Verificação Pós-Limpeza (12 Meses)

Após simular a limpeza de 12 meses, verifique se o "footprint" do usuário foi totalmente apagado:

- [ ] **Auth**: O usuário foi removido da aba "Authentication"?
- [ ] **Perfil**: O documento em `/users/{uid}` foi deletado?
- [ ] **Pontuação**: O documento em `/users_scores/{uid}` foi deletado?
- [ ] **Histórico**: A subcoleção `/users/{uid}/history` e seus documentos foram removidos?
- [ ] **Storage**: A pasta `certificates/{uid}/` no Firebase Storage foi limpa?
- [ ] **Logs**: Se o usuário gerou logs em `prayer_logs` ou `meditation_logs`, eles foram apagados?
- [ ] **E-mail**: Se o usuário estava em `broadcast_logs`, o e-mail dele foi removido do array `sentToEmails`?

---

## 5. Ferramentas de Apoio
*   **OneSignal Dashboard**: Verifique na aba "Messages" -> "Sent" se os Pushes de retenção foram disparados.
*   **Resend Dashboard**: Verifique na aba "Emails" se o aviso de desativação foi entregue.
