# Plano de fases — CatalystHR (checklist)

> Última atualização: 2026-10-29
> Base: specs 00 a 22 e `docs/specs/decisoes.md`.
> Definições do responsável: ponto antes de folha e eSocial; IA de documentos no núcleo e o restante da IA no fim; cobrança completa já na fundação; 1 desenvolvedor com apoio de agentes de IA; sem piloto definido; estimativa pedida, sem data-alvo.

Marque `[x]` quando o item estiver pronto. Cada fase tem os pré-requisitos (o que precisa estar resolvido antes), as entregas e o critério de pronto.

## Resumo

| Fase | Entrega | Estimativa | O que libera |
|---|---|---|---|
| 0 | Preparação | 2 a 3 semanas | Começar a desenvolver |
| 1 | Fundação e cobrança | 12 a 16 semanas | Cadastrar parceiros e empresas, cobrar, administrar |
| 2 | Núcleo de RH, com a IA de documentos | 16 a 22 semanas | Núcleo de RH pronto, testado com dados fictícios |
| V | Validação: fornecedores, jurídico, especialista em DP e teste de ponta a ponta (D-637) | Depende dos terceiros | **Primeiro cliente**, sem ponto e sem folha |
| 3 | Ponto (REP-P) e jornada | 12 a 16 semanas | Vender o módulo de ponto |
| 4 | Folha e eSocial | 22 a 30 semanas | Vender o módulo de folha |
| 5 | IA restante, recrutamento, avaliação e relatórios | 12 a 16 semanas | MVP completo |
| **Total** | | **76 a 103 semanas** (cerca de 18 a 24 meses) | |

**Sobre as estimativas:**
- São estimativas, não compromissos.
- Supõem uma pessoa em tempo integral, com agentes de IA, specs estáveis e respostas dos terceiros dentro do prazo.
- A faixa é maior na folha e no eSocial, por causa das regras legais e da homologação.

**Risco principal:** o primeiro cliente só entra no fim da fase 2, por volta de 7 a 10 meses, e o MVP completo leva de 18 a 24 meses. Para encurtar, as alternativas (decisões suas) são:
- tirar escopo da fase 1;
- adiar recrutamento e avaliação para depois do MVP;
- aumentar a equipe a partir da fase 3.

---

## Fase 0 — Preparação (2 a 3 semanas)

### Fora do desenvolvimento
- [x] Abrir os pedidos da `pendencias-fornecedores.md` (2026-10-14): Mercado Pago (chamado WCS-54705, aguardando o comercial), contador (respondido em parte), AWS SES (saída do sandbox em análise) e Meta (empresa já verificada). Reagendados de propósito: Anthropic na metade da fase 1, Voyage na fase 5, Railway antes do primeiro cliente, número do WhatsApp antes da fase 2
- [x] Redigir as minutas jurídicas em `juridico/` (termos de uso, política de privacidade, aviso do recrutamento, contrato de tratamento de dados) (2026-10-13)
- O envio dos pacotes ao jurídico e ao especialista em DP e a procura do piloto passaram para a fase de validação (D-637)

### Desenvolvimento
- [x] `rails new` com a stack da spec 20: Postgres com pgvector, Redis, Sidekiq, Tailwind, importmap, Dockerfile com jemalloc, YJIT e 7-Zip (Ruby 4.0.7, Rails 8.1.4)
- [x] Repositório privado `devbatista/catalysthr`, com proteção da `main` (CI verde obrigatório)
- [x] Revisão obrigatória no merge: só quando entrar a segunda pessoa; até lá, só o CI verde (D-516)
- [ ] Exigir uma revisão aprovada na proteção da `main` quando entrar a segunda pessoa
- [x] GitHub Actions: RuboCop, brakeman, bundler-audit, `importmap audit`, RSpec com Postgres e Redis, SimpleCov
- [x] Dependabot (gems, Docker, Actions)
- [x] Railway US East: projeto `catalyst_hr` com `web`, `worker`, `worker-time`, `Postgres` (18 com pgvector) e `Redis` (AOF e `noeviction`), só na rede privada. `backup` fica para a fase 1, e o `clamav` para a spec 08, na fase 2 (D-606)
- [x] AWS: conta própria `catalysthr` (464986173446) no AWS Organizations, separada dos outros sistemas; IAM Identity Center em São Paulo com MFA em todo login; CLI por SSO, sem chaves gravadas; alerta de orçamento de US$ 10 por mês (D-574, 2026-10-14)
- [x] AWS em São Paulo: SES (domínio `catalysthr.com.br` verificado, DKIM, MAIL FROM `bounce.catalysthr.com.br` com SPF, DMARC `p=quarantine` na Cloudflare, *configuration set* `catalysthr-padrao`) e SNS (tópico `catalysthr-ses-eventos` com entrega, devolução e reclamação). Pedido de saída do sandbox enviado, em análise (2026-10-14). KMS, S3 e usuários IAM ficam para a fase 1, e a chave do A1 para a fase 3, para não pagar antes de usar
- [x] Cloudflare DNS: `*.painel`, `_acme-challenge`, `admin` e os registros do SES (DKIM, MAIL FROM e DMARC)
- [x] Sentry: organização e projeto `catalysthr` (EUA), `SENTRY_DSN` em produção, erro de teste recebido
- [x] Sentry: primeiro monitor externo para `/up`, em `health.painel.catalysthr.com.br`, a cada minuto, com alerta por e-mail (D-573, 2026-10-14)
- [x] Docker Compose para o desenvolvimento local
- [x] Workflow de deploy manual, com CI verde exigido e bloqueio nos picos do ponto; migrações no pre-deploy do serviço `web`, configurado no Railway (D-517)
- [x] Deploy automático depois do CI verde na `main`, sem começar nos picos do ponto, com o pendente saindo às 9h05 e 19h05 (D-575, PR #17). Primeiro disparo automático em 2026-10-14, às 23h05
- [x] Secret `RAILWAY_TOKEN` no GitHub, depois de criar o projeto no Railway
- [x] Primeiro deploy pelo workflow, no endereço provisório do Railway (https://web-production-4e2f3.up.railway.app)

### Pronto quando
- [x] Uma página "olá" passa pelo CI, é publicada com aprovação manual e responde com HTTPS num subdomínio wildcard (2026-10-14)

---

## Fase 1 — Fundação e cobrança (12 a 16 semanas)

### Pré-requisitos
- [x] Contador da DevBatista: código do serviço (item 01.05, código municipal 02798), ISS no DAS do Simples, sem retenções, emissão depois do pagamento aceita (2026-10-14)
- [x] Contador da DevBatista: competência da fatura que junta dois ciclos, alíquota do Simples na nota e código 02798 no CCM (com um especialista) (2026-10-22, D-628)
- [x] Asaas: conta configurada no Portal Nacional (D-628, D-634, 2026-10-29)
- [x] Railway: criptografia em repouso confirmada no Trust Center (relatório SOC 2, 2026-10-29)
- O Mercado Pago (cartão salvo sem o CVV) e o SES (saída do sandbox e escolha do plano) passaram para a fase de validação (D-637)

### Entregas
- [x] **AWS (spec 20):** criar no bloco 2b da spec 01 (D-595). KMS com as chaves dos arquivos e dos backups, buckets S3 `catalysthr-files` e `catalysthr-backups`, e usuários IAM da aplicação, do backup e da restauração. Criar antes da primeira função que grava arquivo em produção (o logo da marca, na spec 01) ou do pg_dump diário, o que vier primeiro. Custo a partir daí: cerca de US$ 2 por mês nas chaves, mais o uso. Criados em 2026-10-16: as duas chaves KMS, os dois buckets e o usuário `catalysthr-app` (PR #29). Os usuários do backup e da restauração entraram com o pg_dump diário (20a, 2026-10-26)
- [x] **Spec 01:** tenant pelo host, subdomínios e redirecionamento, marcas e modos de marca, domínio de e-mail no SES, transferência de empresa. O `/up` continua respondendo em `health.painel` sem tenant, login nem redirecionamento, senão o monitor externo dispara (D-573)
  - [x] Parte 1: base do tenant (`acts_as_tenant` com `require_tenant`, jobs com a empresa), parceiros, empresas, marcas, subdomínios com reservados e redirecionamento de 90 dias, resolução pelo host com cache, tema por variáveis CSS com contraste mínimo, manifest do PWA, CNPJ numérico e alfanumérico, Flipper instalado
  - [x] Parte 2, depois das specs 02 e 03: login por marca, empresa atual e seletor (adiantados para o bloco 4a das specs 02 e 03), ponto único de consulta entre empresas, edição da marca com permissões e modos, transferência, domínio de e-mail no SES, prefixo por empresa no S3. Em 4 PRs (D-594):
    - [x] 2a. Ponto único de consulta entre empresas (RN-01-011), edição da marca sem imagens no painel do parceiro e no admin, com os modos `alongside` e `replace` (RN-01-034, RN-01-035), e a troca de slug pelo superadmin (PR #28)
    - [x] 2b. AWS de arquivos (D-595, passo a passo em `aws-arquivos.md`), Active Storage no S3 com prefixo por empresa (RN-01-014) e as imagens da marca, servidas só pela aplicação (PR #29)
    - [x] 2c. Domínio de e-mail da marca no SES, com o job de verificação (RN-01-040, CA-01-008, CA-01-009) (PR #30)
    - [x] 2d. Transferência de empresa (RN-01-050 a RN-01-053, D-599) (PR #32)
- [x] **Spec 02:** login por CPF ou e-mail, convites por e-mail e link (por WhatsApp quando a Twilio estiver aprovada), senha, bloqueio, MFA, sessões, impersonate em simulação. Feita nos 5 blocos abaixo; WhatsApp e passkeys ficam para depois
- [x] **Spec 03:** perfis, escopos, módulos liberados e contratados, `Ability`. Feita nos 5 blocos abaixo; os escopos U, E e K e as regras de cada módulo entram com a spec 04 em diante, e os módulos contratados com a spec 19
  - Specs 02 e 03 no mesmo ciclo, em 5 PRs (2026-10-15):
    - [x] 1. Base: criptografia de campos, `User`, `Membership`, login por marca, senha, bloqueio, recuperação por e-mail, Rack::Attack, esqueleto da `Ability` e teste de cobertura de autorização (PR #19)
    - [x] 2. Motor de convites (e-mail e link), primeiro acesso, `consents`, `legal_documents` (D-577, D-578) e a tela de publicação dos termos da CatalystHR (D-579). As telas de convidar entram no bloco 4 e na spec 19, e o QR code entra com elas (PR #20)
    - [x] Depois do deploy do bloco 2: migração que remove `terms_text` e `privacy_policy_text` da `brands` (entrou no PR #21)
    - [x] 3. MFA (D-580), dispositivos lembrados, `user_sessions` (D-576) e uma tela mínima de Segurança no painel e no admin (senha, MFA, códigos, dispositivos e sessões). O visual do portal vem com a spec 16, e a redefinição do MFA de outra pessoa (RN-02-044) entra no bloco 4 (PR #21)
    - [x] 4a-1. Auditoria (trazida da spec 05): PaperTrail sem campos sensíveis (RN-05-010, RN-05-011), `access_events` só de inclusão (RN-05-020 a RN-05-022) e os eventos `auth` dos blocos 1 a 3 (PR #22)
    - [x] 4a-2. Empresa atual e seletor (RN-01-004, RN-01-005, trazidos da parte 2 da spec 01), `CompanyAbility` e a tela de usuários da empresa: convidar RH e gestores (com QR code), perfis (RN-03-012), último RHA (RN-03-013), redefinição de MFA (RN-02-044) e correção de contato (P-02-17), as duas limitadas a quem só tem acesso a esta organização (D-582), e os módulos do RHN. As unidades do RHN entram com a spec 04 (PR #23)
    - [x] 4b-1. Painel do parceiro (D-583): `PartnerAbility`, equipe (D-584), empresas e módulos do consultor (D-052, P-03-06), consultor como RHN com escopo T nas empresas atribuídas (D-192) e o PA vendo, alterando, removendo e convidando RHAs das empresas clientes (P-03-35, D-585) (PR #24)
    - [x] 4b-2. Escritório contábil (D-583): cadastro e ligação pelo RHA com aceite ou recusa (RN-02-070, P-02-29, D-588 a D-590), equipe (RN-02-071, D-584), login por marca (D-586), desligamento (RN-02-073) e `AccountingFirmAbility` (PR #25)
    - [x] 5a. Impersonate em simulação (RN-02-080 a RN-02-088), o ponto único de dado sensível com a máscara (RN-05-001, D-592) e os eventos `impersonation` (D-591) (PR #26)
    - [x] 5b. Entrada do suporte nas empresas diretas pelo admin (D-581), com todos os módulos contratados (D-593), e as telas do suporte para corrigir contato e redefinir MFA (D-582) (PR #27)
  - O cadastro de empresa cliente pelo parceiro (P-03-14) entra com a spec 19, junto com o plano e os módulos (RN-19-081)
  - Ficam para a spec 04: o convite de `employee` e de `client_manager` e os escopos U, E e K, que dependem de vínculos, unidades, departamentos e clientes de alocação
  - Ficam para depois: WhatsApp, inclusive o consentimento no primeiro acesso (quando a Twilio for aprovada), e passkeys (fase 2, spec 16)
- [x] **Base visual (D-597):** cores, fontes e componentes do protótipo, barra lateral e cabeçalho, e o novo visual das telas que já existem (painel da empresa, do parceiro e do escritório, admin e login). Entra antes da spec 04. O portal do colaborador continua na spec 16 (PR #31)
- [x] **Chaves UUID (D-614):** toda tabela com chave primária UUIDv7 e toda referência em UUID, como regra inalterável, conferida por teste do schema e pelo `strong_migrations`. As migrações das fases 0 e 1 viraram uma migração base, e o banco de produção foi recriado (PR #45)
- [x] **Telas na largura inteira (D-615):** sem limite de largura nas telas logadas, com os campos em colunas (`form-grid`, `field-wide`, `field-full`). Login, telas do MFA, confirmação de senha e "Em breve" continuam centralizados (PR #47)
- [x] **Tela das feature flags (D-617):** no admin, só do superadmin, ver as flags do código e ligar e desligar cada uma para todos, com o registro de quem mudou. A `sign_in` só desliga pelo console
- [x] **Envio duplicado de formulário:** cada formulário é enviado uma vez, e a ativação repetida do MFA leva à página de segurança, em vez de "código inválido" (PR #46)
- [x] **Spec 04:** empresa, unidades, departamentos, cargos, ficha, vínculos, revisões com vigência, campos personalizados
  - Em 5 PRs (D-600, D-602):
    - [x] 4a. Empresa (tipo de empregador e documento, endereço, configurações) e unidades (matriz, raiz do CNPJ, fuso, CEP, posição no mapa), com as unidades do RH analista (escopo U) (RN-04-001 a RN-04-014, CA-04-001) (PR #33)
    - [x] 4b. Departamentos em árvore com gestores e "gestor acima" (escopo E), cargos e tabela da CBO (RN-04-020 a RN-04-032, CA-04-002, CA-04-003) (PR #35)
    - [x] 4c-1. Ficha, vínculos com matrícula, revisões com vigência, lista de colaboradores (escopos T, U e E), cadastro manual "Novo colaborador" (reaproveitando o CPF que já tem conta) e confirmação de senha para dado sensível com o evento de leitura (RN-04-040 a RN-04-042, RN-04-050 a RN-04-064, CA-04-004, CA-04-005, CA-04-007, CA-04-010, RN-02-052, D-592, D-602, D-603) (PR #36)
    - [x] 4c-2. Contatos de emergência, dependentes, contas bancárias, efetivação de estagiário e vínculo novo numa ficha que já existe (RN-04-043, RN-04-044, RN-04-051, RN-04-054, CA-04-006, D-602, D-604). A certidão e o comprovante da conta entram com a spec 08 (PR #37)
    - [x] 4d. Campos personalizados e clientes de alocação (escopo K), com o convite do gestor do cliente (RN-04-080, RN-04-081, RN-04-090 a RN-04-096, CA-04-011 a CA-04-013, RN-02-064, D-605) (PR #38)
    - [x] Depois do deploy do 4a: migração que remove `companies.cnpj`
  - Ficam para depois: atualização pelo colaborador (specs 09 e 16), pendências de eSocial e correspondência dos campos de lista com os códigos do eSocial (spec 13), convite do colaborador (spec 16), itens de admissão do gestor do cliente (spec 07), job diário das revisões `Employments::ApplyScheduledRevisionsJob` (spec 15, D-602), o desligamento e o afastamento (specs 11, 12 e 13), a jornada da revisão (spec 11) e a consulta dos colaboradores pelo escritório contábil (escopo F, com a spec 12)
- [x] **Spec 05:** criptografia de campos, PaperTrail sem campos sensíveis, `access_events`, confirmação de senha, mascaramento, CSP e cabeçalhos de segurança
  - Criptografia de campos (bloco 1 das specs 02 e 03), PaperTrail sem campos sensíveis e `access_events` com os eventos `auth` (bloco 4a-1), o ponto único com a máscara do impersonate (bloco 5a, D-592) e a confirmação de senha com o evento de leitura (bloco 4c-1)
  - CSP com nonce e cabeçalhos de segurança (P-05-29, D-606) (PR #39)
  - A varredura de vírus dos uploads (P-05-30) entra com a spec 08 (D-606)
- [x] **Spec 15 (base):** sino, e-mail, catálogo e preferências
  - Em 2 PRs (D-607):
    - [x] 15a. Catálogo no código (só os tipos que o sistema já gera), notificações e entregas, e-mail com a marca, sino nos painéis, duplicidade, novas tentativas, retenção, job diário das revisões (P-04-29, D-602) e a migração dos avisos de MFA redefinido, contato alterado e domínio de e-mail da marca (RN-15-001, RN-15-002, RN-15-005 a RN-15-013, RN-15-084, RN-15-085, RN-15-090, D-608) (PR #40)
    - [x] 15b. Preferências da empresa e da pessoa e eventos do SES pelo SNS, com o e-mail inválido (RN-15-020 a RN-15-023, RN-15-080, RN-15-083, CA-15-007, CA-15-009, D-609) (PR #41). Depois do deploy: assinatura do SNS e permissão no IAM (`contas-infraestrutura.md`), feitas em 2026-10-19
  - Até o resumo diário (fase 2), os avisos não urgentes do RH vão por e-mail um a um (D-607)
- [ ] **Spec 19:** planos, módulos e adicionais; consumo e cotas; teste grátis; faturas; Mercado Pago (cartão salvo e PIX); novas tentativas; régua de inadimplência; cancelamento; ajustes; NFS-e pelo Asaas; área admin; painel CatalystHR. Na integração: conferir se os Pagamentos Automáticos usam `/v1/orders` (a documentação atual) em vez do `/v1/payments` citado na spec, e tratar a recusa por "limite de tentativas atingido" sem tentar de novo
  - Em 9 PRs (D-610):
    - [x] 19a. Planos, módulos e adicionais, com as versões de preço (RN-19-010, RN-19-011, RN-19-013, RN-19-014, D-611)
    - [x] 19b-1. Contrato e assinatura com os status, cadastro de parceiro e de empresa direta pelo admin e valor de pré-ativação do parceiro (RN-19-001, RN-19-002, RN-19-035, RN-19-081, D-612, D-613)
    - [x] 19b-2. Empresa cliente pelo parceiro (P-03-14), módulo por empresa da carteira, módulos contratados na `Ability` e no menu, job do teste com os avisos e o status de teste vencido (RN-19-012, RN-19-030 a RN-19-032, RN-19-034, CA-19-003, D-613, D-616). A virada da pré-ativação para a faixa entra com o job diário do 19c
    - [x] 19c. Consumo, cotas com avisos de 80% e 100% e relatório do parceiro (RN-19-020 a RN-19-024, CA-19-002, CA-19-010, D-618), com a virada da pré-ativação (RN-19-035). Os créditos de IA e as mensagens de WhatsApp ficam em zero até as specs 14 e 15, que trazem os lançamentos e os próprios avisos
    - [x] 19d. Faturas, proporcional, troca de plano, planos privados e ajustes, sem pagamento, em três PRs (D-613, D-619 a D-621):
      - [x] 19d-1. Faturas de cada ciclo com as linhas (plano ou pré-ativação, módulos, adicionais e excedentes do último mês fechado), a primeira no cadastro do contrato, a numeração, o aviso `billing.invoice_issued` e as telas no admin, no parceiro e na empresa direta (RN-19-040, RN-19-041, CA-19-001)
      - [x] 19d-2. Troca de plano, módulos e adicionais pelo admin, com o proporcional e a redução no próximo ciclo, o proporcional da ativação do parceiro, planos privados e migração de preço com aviso de 30 dias (RN-19-014, RN-19-015, RN-19-060, RN-19-061, CA-19-005, D-612)
      - [x] 19d-3. Ajustes manuais (desconto, crédito, isenção de excedente) com a aprovação do superadmin acima de 20%, comparados com a prévia da próxima fatura (RN-19-070, RN-19-071, CA-19-009)
    - [x] 19e. PIX pelo Mercado Pago, webhook e conferência diária, e a contratação pelo cliente durante o teste (RN-19-033, RN-19-042, RN-19-046, CA-19-007, CA-19-008, D-613, D-622, D-623)
      - [x] 19e-1. PIX das faturas pela API de Orders, webhook com assinatura e conferência diária (RN-19-042, RN-19-046, RN-19-053, CA-19-007, CA-19-008)
      - [x] 19e-2. Contratação pelo cliente durante o teste ou depois dele, valendo com o pagamento do PIX (RN-19-033, RN-19-034)
    - [x] 19f. Régua de inadimplência, somente leitura (também do teste vencido) e cancelamento (RN-19-034, RN-19-050 a RN-19-053, RN-19-062, RN-19-063, CA-19-006, D-613, D-624, D-625)
      - [x] 19f-1. Régua, `past_due`, `read_only` e `closing`, bloqueio de escrita no painel (também do teste vencido), faixas, avisos e reativação pelo superadmin (RN-19-050 a RN-19-053, CA-19-006)
      - [x] 19f-2. Cancelamento pelo cliente, com senha e motivo, desfazível até o fim do ciclo, e o aviso às empresas da carteira (RN-19-062, RN-19-063)
    - [x] 19g. Painel da equipe CatalystHR: Receita e Clientes, com o risco de cancelamento pelos logins já gravados (RN-19-090, RN-19-091, D-626). A cotação do dólar (RN-19-092) entra com o bloco Custos, na spec 14
    - [ ] 19h. Cartão salvo pelo Mercado Pago e novas tentativas (RN-19-042, RN-19-043). Trava: liberação dos Pagamentos Automáticos
    - [x] 19i. NFS-e pelo Asaas (RN-19-100 a RN-19-111, CA-19-012 a CA-19-015, D-628, D-632, D-633), em quatro PRs, atrás da flag `nfse` (2026-10-28). Asaas de produção configurado em 2026-10-29 (D-634); falta conferir a primeira nota real (`pendencias-fornecedores.md`)
    - [x] 19j. Endereço de cobrança no contrato, pedido no cadastro pelo admin e na contratação, editável pelo cliente e pelo financeiro, e enviado ao Asaas com a NFS-e (RN-19-033, RN-19-081, RN-19-103, D-635), e o e-mail de cobrança, depois que o Asaas desligou o envio da nota por e-mail na conta de produção (D-636), em três PRs (PR #91, #92 e 19j-3, 2026-10-29)
  - Ficam para a fase 2 (D-610): a exportação e a exclusão do teste vencido e do encerramento (CA-19-004), os blocos Custos e Operação do painel (CA-19-011) e a adoção
- [x] **Spec 20:** pg_dump diário, PITR, monitores de jobs, níveis de alerta, reenvio ao plantão pela Twilio
  - Em 2 PRs (D-627, D-629):
    - [x] 20a. pg_dump diário pelo serviço `backup` (cliente 18 do PGDG, SSE-KMS num envio único), `backup_runs`, monitor `pg-dump-diario` no Sentry, ensaio de restauração com roteiro em `docs/runbooks/restauracao.md` e lembrete trimestral (RN-20-041, RN-20-046, CA-20-003, CA-20-008). Depois do merge: usuários IAM e serviço no Railway (`aws-arquivos.md`, passo 7)
    - [x] 20b. `/up/deep` com token (banco, Redis e atraso das filas, com a `time` acima de 2 minutos como falha), Sidekiq Web no admin para o superadmin e o suporte com MFA, e os níveis de alerta configurados no Sentry (`contas-infraestrutura.md`), com as lacunas do plano gratuito (RN-20-074, RN-20-075, RN-20-077)
  - Ficam para antes do primeiro cliente: o PITR (plano do Railway), os outros monitores de job e os externos além do `/up` (plano do Sentry, D-627), o reenvio ao plantão (RN-20-076, com o plano pago do Sentry e a Twilio, D-629) e a faixa de incidente (RN-20-078, fase 2)

### Pronto quando
- [x] As telas novas da fase seguem a base visual e o protótipo, conferidas no computador e no celular, e os módulos entregues saíram do "Em breve" (D-598). Conferência de 2026-10-23: 93 telas de 5 perfis em 1440, 1920 e 390 px, sem rolagem horizontal nem erro de console, com a página 403 na base visual, as tabelas largas ajustadas no celular e a ficha sem vazar a largura
- [x] A régua de inadimplência roda de ponta a ponta com datas simuladas (`spec/requests/dunning_end_to_end_spec.rb`, 2026-10-23): duas faturas vencidas, somente leitura, pagamento por PIX que reativa, encerramento e reativação pelo superadmin
- [x] Os critérios de aceite das specs 01 a 05 e 19 do escopo da fase 1 passam: 59 de 70 com teste, e as outras 11 dependem de módulos das fases 2 e 4 (`criterios-de-aceite-fase-1.md`, 2026-10-28)
- O teste de ponta a ponta (cadastro, marca, convite com MFA, pagamento por cartão e PIX e a NFS-e na fatura), o bloco 19h e a primeira nota real passaram para a fase de validação (D-637). A fase 1 fica encerrada para o desenvolvimento

---

## Fase 2 — Núcleo de RH (16 a 22 semanas)

> O desenvolvimento segue sem esperar os terceiros, e as pendências vão para a fase de validação, antes do primeiro cliente (D-637). A exceção é o que muda o desenho do código: essas partes só são construídas depois da resposta, na leva 2.

### Pré-requisitos
- [ ] Railway: nunca usar limite rígido de gasto em produção, só o alerta por e-mail. O limite rígido derruba todos os serviços, inclusive o ponto, o que contraria a D-116 e a RN-10-006

### Entregas

**Leva 1, sem depender de terceiros, nesta ordem: 06, 08, 16 e 07, depois 15, 17 e 18 (D-638):**
- [x] **Spec 06:** motor de modelos de processo, em 3 PRs (D-638):
  - [x] 06a. Feriados: importação anual da BrasilAPI para revisão e publicação pela equipe, estaduais e municipais à mão no admin, feriados e pontos facultativos da unidade pelo RH (com a Sexta-feira da Paixão desmarcável) e o cálculo de dias úteis (RN-06-026, RN-06-029, RN-11-020, P-06-20, CA-06-003) (PR #97). Depois do deploy: buscar no admin os nacionais de 2026 e 2027 e publicá-los
  - 06b, em dois PRs (D-639):
    - [x] 06b-1. Modelos na biblioteca, no parceiro e na empresa (Empresa → Modelos de processo), editor, adoção, padrão por tipo, modelo de admissão do cargo, integração ligada à admissão, condições, dependências sem ciclo e o teste da transferência (RN-06-001 a RN-06-042, RN-01-053, D-599, CA-06-001, CA-06-008). O envio de documento entra com a spec 08 (PR #99)
    - [x] 06b-2. Material em PDF do item de leitura e aceite, com o cliente próprio do clamd e a varredura de vírus (clamav no Docker Compose; o serviço no Railway fica para a validação) (RN-06-060, P-05-30, D-640) (PR #100)
  - [x] 06c. Processo: início, responsáveis, prazos, bloqueio, ajustes com histórico, dispensa, conclusão, recálculo, troca de cliente, jobs, avisos e a tela genérica do processo (RN-06-050 a RN-06-066, CA-06-004 a CA-06-007, CA-06-009, CA-06-010, D-641) (PR #101). O início do processo vem com a 07 e a 09; o que o colaborador conclui, com a 16
- [ ] **Spec 08:** documentos, revisão, vencimentos, pedidos, ciência, lote, exclusão recuperável. A varredura de vírus vem do 06b (D-638). O texto da ciência eletrônica segue a resposta do jurídico (itens 3.1 e 3.2), sem mudar o mecanismo. Em 3 PRs (D-642); as telas do colaborador entram com a 16:
  - [x] 08a. Tipos de documento (plataforma no admin, empresa, desativação, periodicidade por cargo), pasta da pessoa, envio pelo RH com o PDF único das imagens, varredura, revisão sem a IA, versões, sensível com senha, fila "Documentos", item de envio de documento no editor de modelos, certidão do dependente e comprovante da conta (RN-08-001 a RN-08-024, RN-08-070, RN-08-080, RN-08-081, CA-08-001, CA-08-002, CA-08-008, CA-08-009, D-604) (PR #102)
  - [x] 08b. Vencimentos, pedido avulso e ciência eletrônica (RN-08-030 a RN-08-054, CA-08-003 a CA-08-005, CA-08-007, D-643) (PR #103)
  - [ ] 08c. Lote sem a IA, ZIP da pasta e exclusão recuperável (RN-08-060 a RN-08-063, RN-08-082, RN-08-083, CA-08-006, CA-08-010)
- [ ] **Spec 16:** portal PWA, service worker, convite para instalar, passkeys, "Minha equipe"
- [ ] **Spec 07:** admissão completa, sem as etapas de eSocial
- [ ] **Spec 15 (resto, sem o WhatsApp):** push, horário de silêncio, resumo diário por e-mail, mural
- [ ] **Spec 17 (parte):** painel do RH e do gestor e visão consolidada do parceiro
- [ ] **Spec 18 (parte):** importação da implantação (estrutura, pessoas, dependentes, bancários, gestores, histórico), desfazer, importação assistida, exportação completa

**Leva 2, cada uma depois da resposta que muda o desenho:**
- [ ] **Spec 09:** solicitações e aprovações, **sem férias** (que ficam na fase 4). Depois da conferência do especialista em DP
- [ ] **Spec 14 (parte):** leitura de documentos e lote, com créditos, teto, falhas e retenção zero. Depois da retenção zero confirmada por escrito e da base legal do jurídico (item 2.1); antes disso, só com dados fictícios. Quando entrarem os materiais do assistente e as perguntas e respostas, incluir a cópia deles no serviço de transferência, com teste (RN-01-053, D-599). Nenhum dado pessoal nos esquemas JSON das saídas estruturadas (nomes de campo, `enum`, padrões): a Anthropic guarda o esquema por até 24 horas, mesmo com a retenção zero
- [ ] **Spec 05 (resto):** anonimização, retenção por processo, direitos do titular, encerramento de contrato. Depois dos prazos de retenção e do encerramento validados pelo jurídico (itens 1.1, 1.9 e 1.10)
- [ ] **Spec 15 (WhatsApp):** depois do remetente e dos modelos aprovados na Twilio e da resposta do jurídico sobre o convite e a desconexão (itens 3.6 e 3.7)

### Pronto quando
- [ ] As telas novas da fase seguem a base visual e o protótipo, conferidas no computador e no celular, e os módulos entregues saíram do "Em breve" (D-598)
- [ ] Admissões com documentos lidos pela IA e revisados pelo RH, com dados fictícios
- [ ] As solicitações fluem com aprovação e escalada
- [ ] Os critérios de aceite das specs 06, 07, 08, 09, 15 e 16 passam

---

## Fase de validação — antes do primeiro cliente (D-637)

> Junta o que depende de terceiros e o teste de ponta a ponta. Não trava o desenvolvimento da fase 3; trava o primeiro cliente. Os pedidos podem sair antes, para a validação não virar um tempo parado.

### Pendências da fase 1
- [ ] Mercado Pago: conta habilitada para cobrar o cartão salvo sem o CVV, e o bloco 19h (cartão salvo e novas tentativas)
- [ ] AWS SES: fora do sandbox em São Paulo (pedido enviado em 2026-10-14, recusado e reaberto em 2026-10-27)
- [ ] AWS SES: decidir entre o plano Essentials (padrão da conta, US$ 0,16 a cada 1.000 e-mails) e o avulso (US$ 0,10), com a estimativa de volume do primeiro cliente
- [ ] Asaas: a primeira NFS-e real, com a flag `nfse` ligada (`pendencias-fornecedores.md`)
- [ ] Teste de ponta a ponta da fase 1: o superadmin cria um parceiro e uma empresa direta em teste; eles configuram a marca e convidam o RH, que entra com MFA; contratam um plano e pagam por cartão e por PIX; a NFS-e sai pelo Asaas e aparece na fatura
- [ ] Serviço `clamav` no Railway (1 vCPU, 3 GB, de US$ 12 a 24 por mês), antes de ligar a flag de qualquer módulo com upload para um cliente (D-638)
- [ ] Spec 20: o PITR (plano do Railway), os outros monitores de job e os externos além do `/up` (plano do Sentry, D-627) e o reenvio ao plantão (RN-20-076, com o plano pago do Sentry e a Twilio, D-629)

### Terceiros
- [ ] Anthropic: retenção zero confirmada por escrito (pedido enviado em 2026-10-20)
- [ ] Jurídico: enviar o `pacote-juridico.md` (etapa 1: seções 1, 2, 3 sem o 3.5 e 6) e as minutas de `juridico/`, incluindo a política e os termos já publicados no site; prazos de retenção e transferência internacional validados; minutas revisadas; contrato comercial redigido
- [ ] Especialista em DP: enviar o `pacote-especialista-dp.md`; spec 09 conferida, menos as férias
- [ ] WhatsApp pela Twilio: empresa verificada na Meta, remetente registrado e modelos aprovados
- [ ] Sentry: rever o plano (D-627, D-629). O gratuito tem 1 usuário, 1 monitor de job e 1 externo, e só alerta por e-mail. Com o pago, entram os monitores que faltam da RN-20-073 e o reenvio ao plantão (RN-20-076, com a Twilio)
- [ ] Railway: rever o plano Hobby (8 GB de RAM e 8 vCPU contra os tamanhos da spec 20; PITR para a D-508, que a documentação do Railway não cita em nenhum plano; limite de 2 domínios próprios por serviço, já usados por `*.painel` e `admin`) e decidir sobre um workspace separado para o CatalystHR antes do upgrade, porque o Pro vale para o workspace inteiro
- [ ] Parceiro ou empresa piloto definido

### Pronto quando
- [ ] Todos os itens acima estão resolvidos, ou aceitos como risco em `riscos-aceitos.md`
- [ ] O piloto é implantado pela planilha
- [ ] Admissões reais com documentos lidos pela IA e revisados pelo RH
- [ ] Os colaboradores usam o portal no celular

---

## Fase 3 — Ponto e jornada (12 a 16 semanas)

### Pré-requisitos
- [ ] Jurídico: CatalystHR como fabricante, assinatura com o A1 do empregador, bloqueio pela cerca, layouts do AFD, do AEJ e do comprovante
- [ ] Registro do programa no INPI e o atestado técnico
- [ ] Especialista em DP: spec 11 conferida
- [ ] Rever o deploy automático (D-575) antes de o primeiro cliente usar o ponto: manter ou voltar à aprovação manual

### Entregas
- [ ] **Spec 10:** marcação no PWA, cerca, selfie com consentimento, IPs, externos, totem, NSR, marcação imutável (trigger), comprovante assinado, tratamento, AFD e AEJ
- [ ] **Spec 13 (parte):** upload do certificado A1 no KMS, que o ponto já exige. Criar antes a chave `alias/catalysthr-a1` no KMS, com rotação anual (RN-20-052), e dar ao usuário da aplicação a permissão de criptografar e descriptografar com ela
- [ ] **Spec 11:** regras de ponto, jornadas, feriados, apuração, banco de horas, fechamento, espelho, contestação
- [ ] **Spec 15:** lembrete de marcação
- [ ] **Spec 17:** blocos de ponto e relatório de absenteísmo e jornada
- [ ] **Spec 18:** importação de jornadas e saldos
- [ ] **Spec 20:** teste de carga com 2.000 marcações por minuto

### Pronto quando
- [ ] As telas novas da fase seguem a base visual e o protótipo, conferidas no computador e no celular, e os módulos entregues saíram do "Em breve" (D-598)
- [ ] O AFD e o AEJ gerados passam na validação contra o leiaute oficial
- [ ] O teste de carga cumpre as metas da spec 20
- [ ] O piloto usa o ponto por um período completo e fecha o espelho
- [ ] Os critérios de aceite das specs 10 e 11 passam

---

## Fase 4 — Folha e eSocial (22 a 30 semanas)

### Pré-requisitos
- [ ] Especialista em DP: anexo de rubricas e incidências
- [ ] Especialista em DP: casos de teste com os resultados esperados
- [ ] Especialista em DP: specs 12 e 13 conferidas, incluindo a tabela de prazos, e as regras de férias da spec 09
- [ ] Leiaute vigente do eSocial, XSD e MOS conferidos
- [ ] Regras do Crédito do Trabalhador
- [ ] Layout do CSV de pagamentos validado com os bancos do piloto
- [ ] Piloto disposto a homologar na produção restrita

### Entregas
- [ ] **Spec 12:** dados fiscais, tabelas legais, rubricas e fórmulas, ciclo da competência, tipos de folha, benefícios, pensão, consignado, NF do PJ, lista de pagamentos, holerite e prévia, informe, relatórios contábeis
- [ ] **Spec 13:** construtores de eventos versionados, XSD, XMLDSig, lotes, retorno, painel de revisão, rejeições explicadas pela IA, retificação, S-3000, migração por corte, guias, CPRB
- [ ] **Spec 09:** férias (pedido, validações, férias coletivas, calendário, aviso com ciência) e rescisão com pagamento
- [ ] **Spec 07:** S-2190 e S-2200 na admissão
- [ ] **Spec 18:** acumulados da folha, XMLs do eSocial e conversores de Domínio, Questor e Alterdata
- [ ] **Spec 17:** bloco de folha e relatório de custo de pessoal

### Pronto quando
- [ ] As telas novas da fase seguem a base visual e o protótipo, conferidas no computador e no celular, e os módulos entregues saíram do "Em breve" (D-598)
- [ ] Uma competência real do piloto, calculada em paralelo com o sistema atual dele, bate nos casos conferidos
- [ ] Os eventos são aceitos na produção restrita
- [ ] A empresa passa para produção (D-374)
- [ ] Os critérios de aceite das specs 12 e 13 passam

---

## Fase 5 — IA restante, recrutamento, avaliação e relatórios (12 a 16 semanas)

### Pré-requisitos
- [ ] Voyage: retenção zero pelo opt-out do painel, feito **antes da primeira chamada**, inclusive de teste (o opt-out não vale para o que foi enviado antes). Só o assistente usa a Voyage

### Entregas
- [ ] **Spec 14 (resto):** resumo operacional, assistente (materiais, pgvector, Voyage, citações), redação
- [ ] **Spec 21:** recrutamento completo
- [ ] **Spec 22:** avaliação de experiência e de desempenho, feedbacks
- [ ] **Spec 17 (resto):** foto diária, relatórios gerenciais, diversidade, comparação entre empresas, agendamento

### Pronto quando
- [ ] As telas novas da fase seguem a base visual e o protótipo, conferidas no computador e no celular, e os módulos entregues saíram do "Em breve" (D-598)
- [ ] Os critérios de aceite das specs 14, 17, 21 e 22 passam

---

## Pontos para você decidir

Estas são escolhas minhas para encaixar o escopo e precisam da sua confirmação:

- [x] **Férias:** na fase 4 (decidido em 2026-10-13)
- [ ] **Ponto sem férias na fase 3:** a apuração do ponto usa as férias como ausência justificada (RN-11-040). Sem o módulo de férias, os dias de férias apareceriam como falta. Opções: (a) antecipar para a fase 3 só o **registro das férias pelo RH**, sem o pedido do colaborador, as validações e o pagamento; (b) o RH lança as férias como abono ou afastamento à mão até a fase 4
- [ ] **WhatsApp e push na fase 2:** na fase 1 ficam só o sino e o e-mail, menos os convites por WhatsApp
- [ ] **Anonimização automática na fase 2:** nenhum prazo vence antes
- [ ] **Exportação completa na fase 2:** o encerramento de contrato exige
- [ ] **Visão consolidada do parceiro na fase 2:** os relatórios com histórico ficam na 5
- [ ] **Piloto:** procurar já, porque sem ele a fase 2 termina sem validação real
