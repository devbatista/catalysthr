# AWS de arquivos — passo a passo (bloco 2b da spec 01)

> Decisão: D-595. Regras: spec 20, RN-20-042, RN-20-043, RN-20-051 e RN-20-052; spec 01, RN-01-014.
> Conta `catalysthr` (464986173446), região **São Paulo (sa-east-1)** em todos os passos.
> Custo: US$ 1 por chave KMS por mês (US$ 2 pelas duas), mais US$ 1 por chave a cada rotação anual, até a segunda (US$ 4 no 2º ano e US$ 6 do 3º em diante), mais o uso do S3, que começa em centavos. A cobrança das chaves começa quando elas são criadas.

Nenhuma chave de acesso passa pelo chat. A chave do usuário IAM vai direto do console da AWS para as variáveis do Railway.

## 0. Entrar na conta certa

A conta `devbatista` (753974168544) é a de gerenciamento, com a Organization e o IAM Identity Center, e guarda recursos de outros sistemas. Nada do CatalystHR é criado nela (D-574).

- [x] Abrir o portal de acesso https://d-9467531773.awsapps.com/start e entrar com o usuário do Identity Center `devbatista`, com MFA.
- [x] Abrir **catalysthr (464986173446)** → **AdministratorAccess** → **Console de gerenciamento**.
- [x] Conferir no canto superior direito: `catalysthr (464986173446)` e a região **América do Sul (São Paulo)**. O console pode abrir em outra região (por exemplo Ohio); troque antes de criar qualquer coisa.

## 1. Chaves KMS

Console: **KMS → Chaves gerenciadas pelo cliente → Criar chave**.

- [x] Chave dos arquivos:
  - tipo **Simétrica**, uso **Criptografar e descriptografar**, chave de região única;
  - alias `catalysthr-files`;
  - descrição: "Arquivos do CatalystHR (SSE-KMS do S3)";
  - **Administradores de chaves:** só o perfil `AWSReservedSSO_AdministratorAccess_…` (você, pelo Identity Center). Nenhum usuário, nem a `OrganizationAccountAccessRole`;
  - **Permissões de uso:** ninguém. O usuário da aplicação ganha a permissão pela política dele, no passo 3;
  - **Política de chaves:** a gerada pelo console, sem mudança.
- [x] Chave `catalysthr-files` criada em 2026-10-16: ID `62fd6e2f-dae0-4c09-9f36-4dd62b6be752`.
- [x] Na chave criada, aba **Material chave e alternâncias**: ligar a alternância (rotação) automática a cada 365 dias (RN-20-052).
- [x] Chave dos backups: igual, com o alias `catalysthr-backups` e a descrição "Backups do CatalystHR". Criada em 2026-10-16: ID `0692876d-247d-49c2-8e22-d96b3caad0e0`. Rotação anual ligada (conferida: 365 dias, próxima em 2027-10-16).

O alias só serve para achar a chave no console: o código não usa o alias, e a política do passo 3 usa o **ID da chave**.

## 2. Buckets S3

Console: **S3 → Buckets → Criar bucket**.

O bucket de arquivos fica no **namespace regional da conta**, a opção recomendada pela AWS: o console acrescenta ao nome o sufixo `-464986173446-sa-east-1-an` (conta, região e `an`), e nenhuma outra conta consegue criar um bucket com esse nome. Os nomes completos são:

| Bucket | Você digita | Nome completo (usado nas políticas e no Railway) |
|---|---|---|
| Arquivos | `catalysthr-files` | `catalysthr-files-464986173446-sa-east-1-an` |
| Backups | `catalysthr-backups` | `catalysthr-backups` (criado no namespace global, sem sufixo) |

Se o console mostrar um sufixo diferente depois de criar, me avise: o nome completo vai nas políticas e na variável do passo 4.

### Arquivos (`catalysthr-files`)

**Configuração geral**
- [x] Região da AWS: **América do Sul (São Paulo) sa-east-1**.
- [x] Tipo de bucket: **Propósito geral**.
- [x] Namespace do bucket: **Namespace regional da conta (recomendado)**.
- [x] Nome do bucket: `catalysthr-files`.
- [x] Copiar configurações de bucket existente: não usar.

**Propriedade de objeto**
- [x] **ACLs desabilitadas (recomendado)** (fica "Imposto pelo proprietário do bucket").

**Configurações de bloqueio do acesso público deste bucket**
- [x] **Bloquear todo o acesso público** marcado (as quatro opções embaixo ficam marcadas juntas).

**Versionamento de bucket**
- [x] **Ativar** (RN-20-043). O padrão vem em "Desativar": troque.

**Tags**
- [x] Nenhuma.

**Criptografia padrão**
- [x] Tipo de criptografia: **Criptografia do lado do servidor com chaves do AWS Key Management Service (SSE-KMS)**. O padrão vem em SSE-S3: troque.
- [x] Chave do AWS KMS: **Escolher entre suas chaves do AWS KMS** → `catalysthr-files`.
- [x] Chave do bucket: **Ativar** (já vem ativada; diminui as chamadas ao KMS e o custo).

**Configurações avançadas**
- [x] Não mexer. Clicar em **Criar bucket**.
- [x] Bucket criado em 2026-10-16: `catalysthr-files-464986173446-sa-east-1-an`.

**Depois de criado**, abrir o bucket:
- [x] Aba **Gerenciamento → Criar regra de ciclo de vida** (regra `versoes-antigas-35-dias` ativa em 2026-10-16):
  - nome `versoes-antigas-35-dias`, escopo: aplicar a todos os objetos do bucket (confirme o aviso);
  - em **Ações de regras de ciclo de vida**, marcar só **Excluir permanentemente versões desatualizadas de objetos** e **Excluir marcadores de exclusão de objetos expirados ou carregamentos fracionados incompletos**;
  - no quadro **Excluir permanentemente versões desatualizadas de objetos**: **Dias após os objetos ficarem desatualizados** = **35** (RN-20-043); **Número de versões mais recentes a serem retidas** fica vazio;
  - no quadro **Excluir marcadores de exclusão…**: marcar **Excluir marcadores de exclusão de objeto expirados** e **Excluir uploads de várias partes incompletos**, com **7** dias no campo que aparece;
  - conferir o resumo (**Ações de versões desatualizadas**: dia 0, o objeto fica desatualizado; dia 35, é excluído) e clicar em **Criar regra**.
- [x] Aba **Permissões → Política do bucket → Editar**: recusar acesso sem HTTPS (aplicada em 2026-10-16). Cole:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SomenteHttps",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::catalysthr-files-464986173446-sa-east-1-an",
        "arn:aws:s3:::catalysthr-files-464986173446-sa-east-1-an/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

### Backups (`catalysthr-backups`)

- [x] Bucket criado em 2026-10-16 no **namespace global**: `catalysthr-backups` (sem o sufixo da conta; o nome já é nosso, então não há risco de outra conta tomá-lo). As mesmas opções do bucket de arquivos, com o nome `catalysthr-backups`, a chave `catalysthr-backups` na criptografia padrão e o **versionamento desativado** (deixar o padrão).
- [x] Propriedades conferidas em 2026-10-16: versionamento desabilitado, SSE-KMS com a chave `catalysthr-backups` (ID `0692876d-247d-49c2-8e22-d96b3caad0e0`), chave do bucket habilitada.
- [x] Aba **Gerenciamento → Criar regra de ciclo de vida**: nome `backups-35-dias`, aplicada a todos os objetos, com **Expirar versões atuais de objetos** em **35** dias (RN-20-042, D-223). Regra ativa em 2026-10-16.
- [x] Aba **Permissões → Política do bucket** (aplicada em 2026-10-16):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SomenteHttps",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::catalysthr-backups",
        "arn:aws:s3:::catalysthr-backups/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

## 3. Usuário IAM da aplicação

O IAM é global: a região do console não importa neste passo. O IAM Identity Center continua sendo o acesso das pessoas. A aplicação roda no Railway, fora da AWS, então precisa de um usuário IAM com chave de acesso, só com o mínimo (RN-20-051).

Console: **IAM → Usuários → Criar usuário**.

- [x] Nome `catalysthr-app`, **sem** acesso ao Console de Gerenciamento da AWS (criado em 2026-10-16).
- [x] Sem grupos nem políticas gerenciadas (política em linha `catalysthr-app-files` criada em 2026-10-16). Depois de criado, aba **Permissões → Adicionar permissões → Criar política em linha → JSON**, nome `catalysthr-app-files`. A política já está com o ID da chave `catalysthr-files` (o ID não é segredo):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListarArquivos",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::catalysthr-files-464986173446-sa-east-1-an"
    },
    {
      "Sid": "LerEGravarArquivos",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::catalysthr-files-464986173446-sa-east-1-an/*"
    },
    {
      "Sid": "ChaveDosArquivos",
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "arn:aws:kms:sa-east-1:464986173446:key/62fd6e2f-dae0-4c09-9f36-4dd62b6be752"
    }
  ]
}
```

- [x] Aba **Credenciais de segurança → Criar chave de acesso** (criada em 2026-10-16, descrição `railway-producao`) → caso de uso **Aplicação em execução fora da AWS** (o nome exato pode variar um pouco no console). Deixe a página aberta: o segredo só aparece uma vez.
- [ ] As permissões de SES entram no bloco 2c (passo 6). As de SNS entram com os eventos de e-mail (spec 15). Os usuários de backup e de restauração entram com o pg_dump diário (spec 20).

## 4. Variáveis no Railway

Nos serviços **web**, **worker** e **worker-time**, aba **Variables** (configuradas em 2026-10-16), cole direto da página da AWS (sem passar pelo chat nem pelo terminal):

- [x] `AWS_ACCESS_KEY_ID`
- [x] `AWS_SECRET_ACCESS_KEY`
- [x] `AWS_REGION` = `sa-east-1`
- [x] `S3_FILES_BUCKET` = `catalysthr-files-464986173446-sa-east-1-an`

Depois de salvar, feche a página da chave na AWS. Se o segredo vazar, desative a chave no IAM e crie outra.

## 5. Conferência

- [ ] Me avise "feito". Eu confiro só o que dá para ver sem segredo: que o deploy sobe e que o upload de um logo de teste funciona em produção, depois do merge do 2b, fora do horário de pico.

## 6. Permissões de e-mail (bloco 2c da spec 01)

Decisão: D-596. Regras: RN-01-040, RN-20-051. O bloco 2c liga o envio pelo SES em produção e cadastra os domínios de e-mail das marcas. O usuário `catalysthr-app` precisa de uma segunda política em linha. Faça isto **antes do merge do 2c**: sem a política, os e-mails de produção falham.

Console: **IAM → Usuários do IAM → `catalysthr-app` → Permissões → Adicionar permissões → Criar política em linha → JSON**, nome `catalysthr-app-email`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnviarEmail",
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": [
        "arn:aws:ses:sa-east-1:464986173446:identity/*",
        "arn:aws:ses:sa-east-1:464986173446:configuration-set/catalysthr-padrao"
      ]
    },
    {
      "Sid": "DominiosDasMarcas",
      "Effect": "Allow",
      "Action": [
        "ses:CreateEmailIdentity",
        "ses:GetEmailIdentity",
        "ses:DeleteEmailIdentity",
        "ses:PutEmailIdentityMailFromAttributes"
      ],
      "Resource": [
        "arn:aws:ses:sa-east-1:464986173446:identity/*",
        "arn:aws:ses:sa-east-1:464986173446:configuration-set/catalysthr-padrao"
      ]
    },
    {
      "Sid": "ProtegerDominioDaPlataforma",
      "Effect": "Deny",
      "Action": [
        "ses:CreateEmailIdentity",
        "ses:DeleteEmailIdentity",
        "ses:PutEmailIdentityMailFromAttributes"
      ],
      "Resource": "arn:aws:ses:sa-east-1:464986173446:identity/catalysthr.com.br"
    }
  ]
}
```

O `Deny` impede que a aplicação apague ou altere a identidade `catalysthr.com.br`, mesmo com um defeito no código. O código também recusa esse domínio.

- [ ] Política em linha `catalysthr-app-email` criada.
- [ ] Nenhuma variável nova no Railway: a região, as chaves e o configuration set (`catalysthr-padrao`, padrão no código) já bastam.
- [ ] Enquanto o SES estiver no sandbox, só saem e-mails para endereços verificados no SES. Os outros falham e aparecem no Sentry.
