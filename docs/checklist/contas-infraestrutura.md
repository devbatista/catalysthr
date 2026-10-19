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
- [x] **[você]** Criar um token de API com permissão **Zone → DNS → Edit**, só para a zona `catalysthr.com.br` (guardado em `~/.config/catalysthr/cloudflare_token`, fora do repositório)
- [x] **[Claude]** Criar pela API, sem proxy: CNAME `*.painel`, CNAME `_acme-challenge.painel`, TXT `_railway-verify.painel`, CNAME `admin` e TXT `_railway-verify.admin` (2026-10-14)
- [x] **[Claude]** Registros do SES, sem proxy: 3 CNAME do DKIM, MX e SPF (`v=spf1 include:amazonses.com ~all`) em `bounce`, e o DMARC da raiz trocado de `p=reject` para `p=quarantine` (P-20-10). O MX nulo e o SPF `-all` da raiz continuam (2026-10-14)

## 3. Sentry (erros, desempenho, logs e monitores — D-506)

- [x] **[você]** Conta no sentry.io (a conta já existia, de outro app)
- [ ] **[você]** Confirmar que o 2FA está ligado na conta do Sentry
- [x] **[você]** Organização própria `catalysthr`, separada do outro app, na região de dados **EUA** (P-20-03)
- [x] **[você]** Plano gratuito (Developer). A troca para o Team fica para quando precisar de mais monitores
- [x] **[você]** Projeto **Rails** `catalysthr` com Error monitoring, Logging e Tracing (sem Profiling); DSN copiado para `~/.config/catalysthr/sentry_dsn`
- [x] **[você]** Security & Privacy: Data Scrubber, scrubbers padrão e sem guardar IPs
- [x] **[Claude]** Pôr o `SENTRY_DSN` nas variáveis do `web`, do `worker` e do `worker-time` e publicar (2026-10-14)
- [x] **[Claude]** Enviar um erro de teste da produção: chegou ao Sentry (2026-10-14)
- [ ] **[você]** Conferir no Sentry que o CPF do erro de teste aparece como `[cpf]` e que o log de teste aparece em Explore → Logs com `[email]`
- [x] **[você]** Criar o primeiro monitor externo para `/up` pelo painel, porque a API pública do Sentry não cria monitores externos: `https://health.painel.catalysthr.com.br/up`, a cada minuto, timeout de 10 s, issue depois de 3 falhas, alerta por e-mail. O endereço do Railway foi recusado pelo Sentry (limite de 1.000 monitores por domínio no `railway.app`), e o Hobby não aceita um terceiro domínio no `web` (D-573, 2026-10-14)
- [x] **[Claude]** Conferir nos logs do Railway que o `SentryUptimeBot` chega e recebe 200 (2026-10-14)

## 4. AWS em São Paulo (sa-east-1 — D-501)

**Segurança da conta**

- [x] **[você]** Ligar o MFA no usuário raiz (root) da `devbatista` e parar de usá-lo no dia a dia: só em emergência
- [x] **[você]** AWS Organizations na `devbatista` (753974168544), que passa a ser a conta gestora, e conta-membro **`catalysthr` (464986173446)** só para o CatalystHR. Motivo: a `devbatista` tem usuários IAM de outros sistemas, e o SES é compartilhado por conta. **Atenção:** criar a organização passa a conta do plano gratuito para o pago, sem volta (a conta não tinha créditos, então nada se perdeu) (2026-10-14)
- [x] **[você]** Gestão centralizada do acesso raiz das contas-membro. A `catalysthr` não tem credenciais raiz: sem senha, chaves, MFA nem certificados, conferido por `sts assume-root` (2026-10-14)
- [x] **[você]** IAM Identity Center em São Paulo, instância de região única com chave da AWS (sem custo), MFA em todo login, usuário `devbatista` com `AdministratorAccess` nas duas contas. Portal: `https://d-9467531773.awsapps.com/start` (2026-10-14)
- [x] **[Claude]** AWS CLI 2.38 e perfis `catalysthr` e `devbatista` em `~/.aws/config`, pelo SSO (`aws sso login --sso-session devbatista`), sem chaves gravadas (2026-10-14)
- [x] **[você]** Alerta de orçamento (AWS Budgets) na `devbatista`: US$ 10 por mês, modelo de custo mensal (2026-10-14)

**Recursos** na conta `catalysthr` (eu rodo pela CLI, com confirmação a cada bloco e aviso do custo antes)

*Agora (fase 0), sem custo até enviar e-mails:*

- [x] **[Claude]** SNS: tópico `catalysthr-ses-eventos` para os eventos de entrega, devolução e reclamação do SES (P-15-24). A assinatura do app entra na fase 1 (2026-10-14)
- [x] **[Claude]** SES: domínio `catalysthr.com.br` verificado (DKIM e MAIL FROM `bounce.catalysthr.com.br`), *configuration set* `catalysthr-padrao` como padrão da identidade, com os eventos no SNS. Lista de supressão da conta ligada para devoluções e reclamações. Sem o Virtual Deliverability Manager e sem IP dedicado (2026-10-14)
- [x] **[Claude]** Pedido de **saída do sandbox** enviado pela CLI: e-mails transacionais, site `https://admin.catalysthr.com.br`, contato `rafael@devbatista.com`. Status `PENDING` (2026-10-14)
- [ ] **[você]** Acompanhar a resposta da AWS no e-mail e me avisar. Se pedirem mais informações, eu escrevo a resposta
- [ ] **[você]** Decidir o plano do SES antes do primeiro cliente: Essentials (padrão, US$ 0,16 a cada 1.000) ou avulso (US$ 0,10)

*Fase 1, depois do deploy do bloco 15b (D-609). Custo: 100 mil entregas HTTP do SNS por mês gratuitas, depois US$ 0,06 a cada 100 mil:*

- [x] **[Claude]** SNS: assinatura HTTPS do tópico `catalysthr-ses-eventos` em `https://admin.catalysthr.com.br/webhooks/ses-events`. O app confirma sozinho a assinatura, conferindo a mensagem do SNS. Depois, conferir que a assinatura ficou `Confirmed` (confirmada pelo app em 2026-10-19)
- [x] **[você]** IAM: política inline `catalysthr-app-email` no usuário `catalysthr-app`, com `ses:DeleteSuppressedDestination` para o suporte liberar pelo admin um e-mail que voltou (D-609). O usuário não tinha nenhuma permissão do SES, então a política também cobre o envio (`ses:SendEmail` nas identidades da conta e no configuration set `catalysthr-padrao`) e os domínios das marcas (criar, ler, apagar e MAIL FROM das identidades), com um `Deny` que impede o app de apagar ou alterar a identidade `catalysthr.com.br`. Conferida pela simulação do IAM (2026-10-19)
- [x] **[você]** `aws sso login` antes dos dois passos acima, que eu rodo pela CLI com a sua confirmação (2026-10-19)

*Fase 1, troca para chaves UUID (D-614). O banco de produção é recriado; não havia dado a manter. O deploy é automático depois do CI verde da `main` (D-575), então o schema é recriado antes do merge:*

- [x] **[Claude]** Conferir o que havia em produção: nenhum usuário, parceiro, empresa, marca, arquivo, flag ou texto legal (2026-10-19)
- [x] **[você]** Dispensar o backup, porque não havia dado (2026-10-19)
- [x] **[Claude]** Apagar e recriar o schema `public` do banco de produção, pelo `railway ssh` no `web`, e limpar as filas do Sidekiq no Redis (2026-10-19)
- [x] **[você]** Mergear o PR da D-614 logo em seguida (PR #45). O deploy automático subiu o `web`, o `worker` e o `worker-time` às 13h13, e o `db:prepare` criou o banco pela migração base (2026-10-19)
- [x] **[Claude]** Conferir o banco novo: 55 tabelas, nenhuma fora da regra da D-614 (2026-10-19)
- [x] **[Claude]** Carregar a CBO com `bin/rails cbo:import` pelo `railway ssh` no `web`: 2.725 ocupações. Num banco vazio, o `db:prepare` carrega o `schema.rb` e marca as migrações como feitas sem rodá-las, então a migração de carga da CBO não carregou nada (2026-10-19)
- [x] **[Claude]** Declarar as flags (`FeatureFlags.declare`) e ligar a `sign_in`. As demais (`billing`, `brand_email_domain`, `company_transfer`) continuam desligadas (2026-10-19)
- [x] **[Claude]** Criar o superadmin (Rafael Batista) com um link de criar senha, e **[você]** definir a senha e ativar o MFA (2026-10-19)
- [ ] **[você]** Publicar os termos de uso e a política de privacidade da CatalystHR no admin. Sem eles, ninguém conclui o primeiro acesso nas marcas sem textos próprios (D-578)

> **Banco novo, em qualquer ambiente:** dados de referência (hoje, a CBO) ficam em tarefas idempotentes, e não em migrações, porque o `db:prepare` de um banco vazio não roda as migrações. Depois de criar um banco do zero, rode `bin/rails cbo:import`, e acrescente aqui cada tarefa nova de carga (tabelas legais da folha, feriados).

*Fase 1, antes da primeira função que grava arquivo em produção ou do pg_dump (cerca de US$ 2 por mês nas chaves, mais o uso):*

- [ ] **[Claude]** KMS: chaves dos arquivos e dos backups, com rotação anual (P-20-22)
- [ ] **[Claude]** S3 `catalysthr-files` (nome confirmado em 2026-10-16, D-595): privado, bloqueio de acesso público, SSE-KMS com S3 Bucket Key, versionamento com as versões antigas apagadas aos 35 dias (P-20-17)
- [ ] **[Claude]** S3 `catalysthr-backups` (nome a confirmar): privado, SSE-KMS com S3 Bucket Key, regra de ciclo de vida que apaga aos 35 dias (D-502)
- [ ] **[Claude]** IAM: usuários `catalysthr-app`, `catalysthr-backup` (só gravar) e `catalysthr-restore` (só ler), com as políticas mínimas (P-20-21). Cada um também precisa da permissão de KMS na chave do seu bucket (`GenerateDataKey` para gravar, `Decrypt` para ler), senão o SSE-KMS recusa a operação. O usuário da aplicação recebe também o envio pelo SES (feito em 2026-10-19, política `catalysthr-app-email`). Faltam o `catalysthr-backup` e o `catalysthr-restore`, com o pg_dump

*Fase 3, junto com o certificado A1 (cerca de US$ 1 por mês):*

- [ ] **[Claude]** KMS: chave do certificado A1, com rotação anual (D-075, P-20-22)

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
- [x] **[Claude]** Depois do domínio e da Cloudflare: adicionar `*.painel.catalysthr.com.br` e `admin.catalysthr.com.br` no serviço `web` e acompanhar o certificado (emitido em minutos; Let's Encrypt válido até 12/01/2027, renovação automática)

> Os serviços `clamav` e `backup` (pg_dump diário) entram na fase 1, junto das funções que dependem deles.

## 6. GitHub

- [x] Repositório privado e proteção da `main` com o CI obrigatório
- [x] **[você]** Secret `RAILWAY_TOKEN` (passo 5)
- [ ] **[você]** Revisar os PRs do Dependabot. O #1 (`image_processing` 1.14 → 2.2) é uma versão nova grande e precisa de cuidado

## Pronto quando

- [x] A página "CatalystHR" responde com HTTPS em `https://<slug>.painel.catalysthr.com.br` e em `/up`, publicada pelo workflow Deploy (2026-10-14)
