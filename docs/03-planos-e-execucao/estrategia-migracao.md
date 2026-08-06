# Estratégia de Migração — Sistema de Monitoramento Saber Espírita
*Versão 1.0 — 16/05/2026*

---

## 1. Contexto e Decisões

### Fontes primárias confiáveis
Três indicadores independem de reconstrução — suas fontes são primárias e sempre auditáveis:

- **Credenciais:** número real do Firebase Auth. Sempre pode ser recalculado.
- **Usuários Ativos:** contagem direta da coleção `users` no Firestore. Sempre reflete a realidade.
- **Lições Concluídas:** recontagem dos documentos existentes na coleção de logs. O `syncAllStats` produz o número correto.

### Sobre os demais contadores
Os contadores restantes estão contaminados por monitoramento híbrido (incremento manual no app + Cloud Functions) ou por ausência de monitoramento back-end. Não valem como histórico confiável. A decisão é reconstruí-los via `syncAllStats` a partir dos logs existentes antes de iniciar o novo ciclo.

### Divisor de águas
O `syncAllStats` é o marco de transição. Tudo antes dele é estimativa. Tudo depois é dado auditável e confiável.

---

## 2. Plano de Execução

### Etapa 1 — Deploy das novas Cloud Functions (v2)
- Implementar todas as functions conforme especificadas no `plano_cloud_functions_v2.md`.
- As funções v2 convivem com as antigas neste momento — nenhuma é excluída ainda.
- As functions antigas são **desativadas** (não excluídas) logo após o deploy das novas.

### Etapa 2 — Remoção dos incrementos manuais no app Expo
- Remover todos os `increment()` do `statsService.ts`, especialmente o de `ambient_player` (dupla contagem confirmada).
- O app passa a apenas criar documentos de log. Nenhuma estatística é calculada no cliente.
- Deploy do app atualizado.

### Etapa 3 — Execução do `syncAllStats`
- Rodar a função com a janela de tempo definida (ex: `from = início do novo mês`, `to = momento da execução`).
- A função reconstrói todos os contadores de `global_stats` e `item_stats` a partir dos logs existentes.
- Os três indicadores primários (Credenciais, Usuários, Lições) são validados neste momento como referência de sanidade.

### Etapa 4 — Validação
- Acompanhar o painel por alguns dias após o `syncAllStats`.
- Confirmar que os contadores estão crescendo de forma consistente e sem duplicidade.
- Verificar logs com `processed: false` ou `error` para identificar eventuais problemas de schema.

### Etapa 5 — Exclusão das functions antigas
- Com os dados validados e o novo sistema estável, excluir as Cloud Functions da versão anterior.
- Manter apenas as functions v2 e a `syncAllStats`.

---

## 3. Observações Importantes

- **Não zerar Credenciais e Usuários Ativos.** São fontes primárias — o reset não faz sentido para esses dois.
- **syncAllStats não é destrutivo.** Pode ser executado múltiplas vezes. Em caso de dúvida, rodar novamente recalcula tudo do zero dentro da janela definida.
- **Functions antigas desativadas antes de excluídas.** O período de convivência entre v1 desativada e v2 ativa serve como rede de segurança caso algum comportamento inesperado apareça.
- **Validação por alguns dias antes da exclusão.** A exclusão das functions antigas é irreversível — só executar após confirmação de estabilidade.

---

*Documento de Estratégia de Migração v1.0 — 16/05/2026*
