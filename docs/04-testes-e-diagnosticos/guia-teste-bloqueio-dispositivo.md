# Guia de Teste - Bloqueio por Dispositivo (Banimento na Raiz)

Este documento explica como realizar o teste manual do sistema de bloqueio por dispositivo para garantir que a detecção nativa e a interceptação de rotas estejam funcionando corretamente.

## Passo 1: Capturar os identificadores do dispositivo de teste

1. Abra o aplicativo no simulador ou em um dispositivo físico de testes.
2. Faça login com uma conta de testes ou abra o app já autenticado em sua conta.
3. No console do **Firebase Firestore**, acesse a coleção `users`.
4. Procure pelo documento correspondente ao UID do seu usuário de teste.
5. Verifique a presença do campo `deviceIds`. Ele conterá um objeto semelhante a este:
   ```json
   {
     "androidId": "97a23b9d0317e3a2",
     "iosIdfv": "87654321-4321-4321-4321-1234567890ab",
     "secureDeviceId": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
   }
   ```
6. Copie um dos valores dos identificadores de dispositivo (por exemplo, o `secureDeviceId` ou o `androidId`/`iosIdfv`).

## Passo 2: Simular o banimento do dispositivo no Firestore

1. No console do Firestore, crie uma nova coleção raiz chamada **`banned_devices`** (se ela ainda não existir).
2. Adicione um novo documento a essa coleção:
   - **ID do Documento:** Cole exatamente o identificador que você copiou no Passo 1 (ex: `f81d4fae-7dec-11d0-a765-00a0c91e6bf6`).
   - **Campos do Documento:** Adicione campos opcionais de rastreamento:
     - `bannedAt`: timestamp (data atual)
     - `reason`: string (ex: "Teste de bloqueio por dispositivo")
     - `userRef`: string (o UID do usuário associado)

## Passo 3: Testar o bloqueio no aplicativo

1. **Teste Online:**
   - Com a internet ligada, reinicie o aplicativo completamente (feche e abra novamente).
   - O aplicativo deverá identificar o ID na coleção `banned_devices`, setar o bloqueio local e exibir imediatamente a tela premium de **Acesso Suspenso**.
   - Verifique se a tela impede qualquer interação com as abas ou telas anteriores (o menu inferior e barra superior devem sumir).
   - Teste o botão "Contatar Suporte" para ver se ele abre o cliente de e-mail com os dados preenchidos.

2. **Teste Offline (Bypass Protection):**
   - Com o dispositivo já bloqueado, feche o aplicativo.
   - Coloque o celular em **Modo Avião** (sem wi-fi e sem dados móveis) e abra o aplicativo.
   - O aplicativo deve carregar a tela de **Acesso Suspenso** instantaneamente, puxando a informação do cache local (MMKV/Zustand persistido) mesmo sem acesso à rede.

## Passo 4: Como revogar o banimento (Desbanir)

Se desejar liberar o dispositivo para uso novamente:
1. No console do Firestore, vá até a coleção `banned_devices`.
2. Delete o documento com o ID correspondente ao aparelho.
3. Abra o aplicativo com conexão ativa de internet.
4. O app fará a verificação, validará que o ID não está mais na lista de banidos e restaurará o acesso convencional do app, limpando o cache offline.
