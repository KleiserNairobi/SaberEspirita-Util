# Integração do Hot-Updater com Cloudflare no Expo

Este documento detalha a implementação real e a infraestrutura configurada para o sistema de atualizações Over-The-Air (OTA) utilizando o **Hot-Updater** integrado à **Cloudflare** no projeto `SaberEspirita-Expo` (Expo SDK 54).

---

## 1. Infraestrutura Realizada na Cloudflare

Os seguintes recursos foram criados e vinculados à conta da Cloudflare associada ao e-mail `kleiser.nairobi@gmail.com` (Account ID: `94e60c7eb5e397f81f1ec622c8dd4756`):

*   **Cloudflare D1 (Banco de Dados)**:
    *   **Nome**: `saber-espirita-hot-updater`
    *   **Database ID**: `de8cb74b-8a75-4a7b-bd7c-60d8e2100c4d`
    *   *Nota: As tabelas iniciais e as 5 migrações do banco de dados foram aplicadas com sucesso pelo assistente de inicialização.*
*   **Cloudflare R2 (Storage)**:
    *   **Nome do Bucket**: `saber-espirita-hot-updater-bundles`
    *   *Nota: Configurado utilizando um Token de API R2 com permissões de Leitura e Escrita (Edit) para upload de assets e bundles.*
*   **Cloudflare Worker (API de Distribuição)**:
    *   **Nome do Worker**: `saber-espirita-hot-updater-worker`
    *   **URL Pública**: `https://saber-espirita-hot-updater-worker.kleiser-nairobi.workers.dev`

---

## 2. Alterações e Configurações no Projeto

Para adotar o Hot-Updater, os seguintes arquivos foram criados e modificados no projeto:

### A. Dependências Instaladas
As dependências do ecossistema foram adicionadas no [package.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/package.json):
*   **Cliente**: `@hot-updater/react-native`
*   **Ferramentas de Dev**: `hot-updater`, `@hot-updater/expo`, `@hot-updater/cloudflare`, `dotenv`

### B. Variáveis de Ambiente e Segurança
O arquivo local [.env.hotupdater](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/.env.hotupdater) foi gerado e configurado com as chaves privadas de deploy e tokens da API Cloudflare.
Este arquivo foi explicitamente adicionado às regras do [.gitignore](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/.gitignore) para impedir o vazamento de chaves privadas:
```gitignore
.env.hotupdater
.env.hotupdater*
```

### C. Arquivo de Configuração CLI (`hot-updater.config.ts`)
O arquivo [hot-updater.config.ts](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/hot-updater.config.ts) foi criado na raiz da pasta `SaberEspirita-Expo` para instruir o CLI sobre o build do Expo e onde enviar os deploys:
```typescript
import { expo } from '@hot-updater/expo';
import { d1Database, r2Storage } from '@hot-updater/cloudflare';
import { defineConfig } from 'hot-updater';
import { config } from 'dotenv';

config({ path: '.env.hotupdater' });

export default defineConfig({
  build: expo({
    outDir: 'dist',
    resetCache: true,
  }),
  updateStrategy: "fingerprint", // Configurado para validação baseada em Fingerprint Nativo do Expo
  storage: r2Storage({
    bucketName: process.env.HOT_UPDATER_CLOUDFLARE_R2_BUCKET_NAME!,
    accountId: process.env.HOT_UPDATER_CLOUDFLARE_ACCOUNT_ID!,
    credentials: {
      accessKeyId: process.env.HOT_UPDATER_CLOUDFLARE_R2_ACCESS_KEY_ID!,
      secretAccessKey: process.env.HOT_UPDATER_CLOUDFLARE_R2_SECRET_ACCESS_KEY!,
    },
  }),
  database: d1Database({
    databaseId: process.env.HOT_UPDATER_CLOUDFLARE_D1_DATABASE_ID!,
    accountId: process.env.HOT_UPDATER_CLOUDFLARE_ACCOUNT_ID!,
    cloudflareApiToken: process.env.HOT_UPDATER_CLOUDFLARE_API_TOKEN!,
  }),
});
```

### D. Configuração do Plugin no `app.json`
O plugin do Hot-Updater foi adicionado no array de `plugins` do [app.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/app.json) do Expo para configurar nativamente o canal padrão (`production`):
```json
{
  "expo": {
    "name": "Saber Espírita",
    "plugins": [
      ...
      [
        "@hot-updater/react-native",
        {
          "channel": "production"
        }
      ]
    ]
  }
}
```

### E. Inicialização e Wrapper no `App.tsx`
O ponto de entrada principal no [App.tsx](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/App.tsx) foi modificado para envelopar o componente raiz `App` usando o `HotUpdater.wrap`.
O fluxo foi desenhado para rodar silenciosamente e de forma transparente em segundo plano, **coexistindo** com o seu `UpdateModal` existente (que continuará tratando exclusivamente das versões nativas de loja):
```typescript
import { HotUpdater } from "@hot-updater/react-native";

// Componente original App...
function App() {
  ...
}

// Envolve e registra o componente raiz apontando para o Worker
const WrappedApp = HotUpdater.wrap({
  baseURL: "https://saber-espirita-hot-updater-worker.kleiser-nairobi.workers.dev/api/check-update",
  updateStrategy: "fingerprint", // Validação baseada no Fingerprint Nativo do Expo
})(App);

registerRootComponent(WrappedApp);

export default WrappedApp;
```

---

## 3. Scripts e Comandos de Execução

Configuramos o seguinte script facilitador no [package.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/package.json):

```json
"scripts": {
  "deploy:ota": "hot-updater deploy"
}
```

### Fluxo de Trabalho de Deploy OTA:

Para corrigir bugs ou atualizar telas JavaScript/TypeScript e assets sem precisar gerar uma nova build na loja (App Store/Google Play):

1. Acesse o terminal da pasta `SaberEspirita-Expo`.
2. Rode o comando:
   ```bash
   npm run deploy:ota
   ```
   *Este comando realiza o build de produção do JS, calcula as diferenças incrementais (diffing), faz o upload automático dos novos assets para o Cloudflare R2, registra a versão no Cloudflare D1 e envia a notificação de nova versão para os aplicativos instalados.*

---

## 4. Fluxo de Publicação e Testes Locais

Como o aplicativo atualmente publicado nas lojas não possui o SDK do Hot-Updater configurado nem a URL do seu Worker, você deve seguir a ordem abaixo para iniciar a distribuição:

### Passo 1: Enviar a primeira versão nativa para as lojas
1. Altere o número da versão e código de build no [app.json](file:///Users/nairobi/Documents/Desenv/2026/SaberEspirita-Expo/app.json) (ex: de `2.0.18` para `2.0.19` e versionCode/buildNumber correspondente).
2. Gere a build física de produção (.aab ou .ipa) e envie a atualização para a Google Play Store e a Apple App Store.
3. Assim que os usuários instalarem essa nova versão, eles passarão a escutar e a baixar automaticamente qualquer deploy que você enviar posteriormente via `npm run deploy:ota`.

### Passo 2: Como testar localmente em modo Release (Opcional)
Se você deseja validar o funcionamento das atualizações OTA silenciosas antes de publicá-las nas lojas, você pode emular o comportamento gerando compilações locais em modo **Release** (o Hot-Updater é desativado em modo de depuração/debug):

1. Gere e instale o aplicativo localmente em modo Release no seu dispositivo de testes ou emulador:
   * **Android**: `npx expo run:android --variant release`
   * **iOS**: `npx expo run:ios --configuration Release`
2. Abra o aplicativo instalado para garantir que o estado inicial está correto.
3. Faça uma pequena alteração visual no seu código Javascript (ex: altere algum texto visível).
4. Realize o deploy OTA:
   ```bash
   npm run deploy:ota
   ```
5. No aparelho de testes, feche o aplicativo (remova-o do multitarefa/segundo plano) e abra-o novamente.
6. Na primeira inicialização, ele fará o download silencioso do bundle em segundo plano.
7. Feche o aplicativo novamente e abra-o mais uma vez. Na segunda inicialização, o aplicativo aplicará o novo bundle atualizado de forma transparente.
