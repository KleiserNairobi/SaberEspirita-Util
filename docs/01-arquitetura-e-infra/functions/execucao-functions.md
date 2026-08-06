# O Fluxo Correto no dia 01/06/2026

## Passo 1 — No dia 01/06/2026

Você executa **APENAS** o `resetAllStats` uma única vez.

```bash
curl -X POST https://us-central1-saber-espirita.cloudfunctions.net/resetAllStats \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer saber-espirita-admin-key-2026"
```

A partir deste momento, o seu banco estará zerado e limpo. Conforme os novos usuários reais utilizarem o aplicativo, os contadores em tempo real começarão a subir sozinhos e de forma fidedigna (1, 2, 3...) através dos gatilhos normais do app.

---

## Passo 2 — Em datas futuras (ex.: 15/06 ou 01/07) — Apenas se necessário

Se em algum momento futuro você achar que as estatísticas do painel saíram de sincronia e desejar recontar os dados reais para corrigir, aí sim você rodará o `syncAllStats`.

**IMPORTANTE:** você DEVE passar a data de início (`from`) como `2026-06-01` (a data oficial de lançamento).

```bash
curl -X POST https://syncallstats-joejk4doua-uc.a.run.app \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer saber-espirita-admin-key-2026" \
  -d '{"from":"2026-06-01T00:00:00.000Z","to":"2026-06-15T23:59:59.999Z"}'
```

Isso garante que a sincronização buscará e somará apenas as interações legítimas ocorridas a partir do lançamento, ignorando por completo qualquer log de teste antigo de maio.

---

## Como gerenciar essa chave?

### Chave padrão (sem mexer em nada)

O valor `saber-espirita-admin-key-2026` já está programado como fallback. Assim que você terminar o deploy das funções em produção, os comandos acima funcionarão perfeitamente.

### Personalizando a chave

Caso queira alterar para um segredo mais forte no futuro:

1. Acesse o console do **Google Cloud** ou **Firebase**
2. Vá até as configurações de variáveis de ambiente da **Cloud Function**
3. Cadastre a variável `ADMIN_SECRET_TOKEN` com o valor de sua preferência

A partir desse momento, as funções em produção passarão a exigir a sua nova chave no lugar da padrão.

## MMKV

Segurança (Criptografia Nativa): Se em algum momento no futuro você precisar armazenar dados locais sensíveis do usuário (como um token de sessão ou dados privados de perfil), o próprio MMKV já possui suporte nativo a criptografia AES-256 integrada de forma muito simples (basta passar uma chave de criptografia na inicialização do storage).

https://console.firebase.google.com/project/saber-espirita/overview

https://console.cloud.google.com/apis/credentials?project=saber-espirita
