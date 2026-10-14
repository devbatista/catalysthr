# Contas e infraestrutura — roteiro (checklist)

> Última atualização: 2026-10-14
> Ordem sugerida: o domínio primeiro, porque o certificado wildcard, o e-mail (SES) e a Cloudflare dependem dele. Railway e Sentry podem andar em paralelo.
> Legenda: **[você]** = feito por você no navegador (cadastro, pagamento, verificação de identidade); **[Claude]** = posso rodar pela linha de comando depois que você liberar o acesso, sempre mostrando o comando antes.

## 1. Domínio `catalysthr.com.br`

- [x] **[você]** Ver se o domínio está disponível em registro.br
- [x] **[você]** Registrar no nome da DevBatista (CNPJ) ou no seu CPF (registrado em 2026-10-14)
- [x] **[você]** Depois do passo 2, trocar os servidores DNS no Registro.br pelos dois que a Cloudflare indicar (`casey.ns.cloudflare.com` e `laylah.ns.cloudflare.com`, alterado em 2026-10-14)
- [x] Propagação: o `.br` passar a responder com os servidores da Cloudflare e a Cloudflare mostrar o domínio como **Active** (2026-10-14)

> Até o domínio existir, o teste de deploy usa o endereço provisório do Railway (`*.up.railway.app`).

## 2. Cloudflare (DNS, plano Free, sem proxy — D-503)

- [x] **[você]** Criar a conta em cloudflare.com
- [x] **[você]** Ligar o 2FA na conta da Cloudflare
- [x] **[você]** Adicionar o site `catalysthr.com.br` no plano **Free** e anotar os dois servidores DNS (passo 1). Na tela de configuração: Search e Agent em Allow, Training em Block (opcional), Bot Preference Sync **desligado** (sem proxy ele não tem efeito), importação de DNS automática
- [ ] **[você]** Criar um token de API com permissão **Zone → DNS → Edit**, só para a zona `catalysthr.com.br`, e me passar quando formos criar os registros
- [ ] **[Claude]** Criar os registros pela API: wildcard `*.painel`, `_acme-challenge.painel` e o TXT que o Railway pedir, `admin`, e os registros do SES (DKIM, SPF, DMARC), todos **sem proxy** (nuvem cinza)

## 3. Sentry (erros, desempenho, logs e monitores — D-506)

- [ ] **[você]** Criar a conta em sentry.io, com 2FA
- [ ] **[você]** Na criação da organização, escolher a região de dados **EUA** (P-20-03). Ela não pode ser trocada depois
- [ ] **[você]** Começar no plano gratuito (Developer). A troca para o Team fica para quando precisar de mais monitores
- [ ] **[você]** Criar o projeto **Rails** `catalysthr` e copiar o **DSN**
- [ ] **[Claude]** Pôr o `SENTRY_DSN` nas variáveis do Railway (o código já está pronto e mascara os dados pessoais)
- [ ] **[Claude]** Criar o primeiro monitor externo para `/up`, depois do primeiro deploy

## 4. AWS em São Paulo (sa-east-1 — D-501)

**Segurança da conta**

- [ ] **[você]** Ligar o MFA no usuário raiz (root) e parar de usá-lo no dia a dia
- [ ] **[você]** Criar um usuário administrativo para você (IAM Identity Center ou IAM), com MFA
- [ ] **[Claude]** Instalar a AWS CLI (`brew install awscli`) e configurar o acesso com o seu usuário administrativo (`aws configure sso` ou chave temporária)

**Recursos** (eu rodo pela CLI, com confirmação a cada bloco)

- [ ] **[Claude]** KMS: três chaves (certificado A1, arquivos, backups) com rotação anual (P-20-22)
- [ ] **[Claude]** S3 `catalysthr-arquivos` (nome a confirmar): privado, bloqueio de acesso público, SSE-KMS, versionamento com as versões antigas apagadas aos 35 dias (P-20-17)
- [ ] **[Claude]** S3 `catalysthr-backups` (nome a confirmar): privado, SSE-KMS, regra de ciclo de vida que apaga aos 35 dias (D-502)
- [ ] **[Claude]** IAM: usuários `catalysthr-app`, `catalysthr-backup` (só gravar) e `catalysthr-restore` (só ler), com as políticas mínimas (P-20-21)
- [ ] **[Claude]** SNS: tópico para os eventos de entrega, devolução e reclamação do SES (P-15-24)
- [ ] **[Claude]** SES: verificar o domínio `catalysthr.com.br` (depende do passo 1) e criar o *configuration set* ligado ao SNS
- [ ] **[você]** Pedir ao SES a **saída do sandbox** pelo console (formulário de caso de uso). Eu escrevo o texto do pedido
- [ ] **[você]** Criar um alerta de orçamento (AWS Budgets), por exemplo US$ 20 por mês, para não ter surpresa

## 5. Railway (US East — D-500)

> **Atenção ao plano Hobby.** O painel informa que o plano inclui até 8 GB de RAM, 8 vCPU e 100 GB de disco compartilhado. Não está claro se os 8 GB valem por serviço ou para o plano todo. Os tamanhos da spec 20 somam mais que isso. Há indicação, **não confirmada** na documentação oficial, de que o PITR (perda máxima de 5 minutos, D-508) é recurso do **Pro**. Para a fase 0 o Hobby basta, mas isso precisa ser revisto **antes do primeiro cliente**.

- [x] **[você]** Definir o limite de gasto em railway.com/workspace/usage → **Set limits** → Compute: **só o alerta por e-mail, em US$ 25** (decidido em 2026-10-14). **Sem limite rígido:** ele vale para o workspace inteiro e derrubaria também os outros projetos (`prescsign`, `launch_os`, `devbatista-app`)
- [ ] **[você]** Avaliar um workspace separado para o CatalystHR (cobrança e limites isolados dos outros projetos)
- [x] **[Claude]** `railway init --name catalyst_hr`: criar o projeto
- [x] **[Claude]** Adicionar o Postgres e conferir se ele aceita `CREATE EXTENSION vector` (Postgres 18.6 com pgvector 0.8.7 disponível)
- [x] **[Claude]** Adicionar o Redis (só para o Sidekiq), com AOF e `noeviction`
- [x] **[Claude]** Criar os serviços vazios `web`, `worker` e `worker-time`, **sem** ligar ao GitHub, porque o deploy é feito pelo nosso workflow (`railway up`), e não a cada push
- [x] **[Claude]** Colocar todos na região **US East (Virgínia)** (o Postgres e o Redis nasceram em US West e foram movidos)
- [x] **[Claude]** Definir as variáveis: `RAILS_MASTER_KEY` (de `config/master.key`, sem passar pelo chat), `DATABASE_URL` e `REDIS_URL` (referências do Railway), `SIDEKIQ_ROLE=time` só no `worker-time`, `APP_HOST`
- [x] **[Claude]** Definir pela API o início dos workers (`bundle exec sidekiq`), o pre-deploy e o health check do `web` e as réplicas. O `railway.json` foi descontinuado pelo Railway, então a configuração ficou documentada no README (D-517)
- [x] **[você]** Criar o token de projeto no painel do Railway (projeto `catalyst_hr` → Settings → Tokens, ambiente `production`). O login da CLI não tem permissão para criar tokens pela API
- [x] **[você]** Gravar o token como secret no GitHub: `gh secret set RAILWAY_TOKEN --repo devbatista/catalysthr` (o comando pede o valor sem mostrar na tela)
- [x] **[Claude]** Rodar o workflow **Deploy** e conferir a página e o `/up` no endereço provisório do Railway (https://web-production-4e2f3.up.railway.app, 2026-10-14)
- [ ] **[Claude]** Depois do domínio e da Cloudflare: adicionar `*.painel.catalysthr.com.br` e `admin.catalysthr.com.br` no serviço `web` e acompanhar o certificado (até 72 horas)

> Os serviços `clamav` e `backup` (pg_dump diário) entram na fase 1, junto das funções que dependem deles.

## 6. GitHub

- [x] Repositório privado e proteção da `main` com o CI obrigatório
- [x] **[você]** Secret `RAILWAY_TOKEN` (passo 5)
- [ ] **[você]** Revisar os PRs do Dependabot. O #1 (`image_processing` 1.14 → 2.2) é uma versão nova grande e precisa de cuidado

## Pronto quando

- [ ] A página "CatalystHR" responde com HTTPS em `https://<slug>.painel.catalysthr.com.br` e em `/up`, publicada pelo workflow Deploy
