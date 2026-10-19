# 20 — Infraestrutura

> Status: aprovado (transferência internacional e criptografia do Railway a confirmar) · Última atualização: 2026-10-13
> Decisões: D-026, D-031, D-075, D-108, D-153, D-223, D-500 a D-515, D-614 ([decisoes.md](decisoes.md))
> Os itens **[P-20-nn]** foram todos aprovados sem ajuste (D-515, seção 10).

## 1. Objetivo

Definir **onde e como o CatalystHR roda**:

- hospedagem, regiões e serviços (D-500, D-501);
- domínios e certificados (D-503);
- ambiente, CI/CD e deploy (D-504, D-505);
- dados, backups e recuperação de desastre (D-502, D-508);
- segurança da infraestrutura;
- observabilidade, alertas e plantão (D-506, D-509 a D-513);
- escala e desempenho.

## 2. Visão geral

```
                        Cloudflare (DNS, sem proxy)
          *.painel.catalysthr.com.br · admin.catalysthr.com.br
                                   │
┌──────────────────── Railway · US East (Virgínia) ────────────────────┐
│                                                                       │
│   web (Puma) ×2 ──────────┬────────── Postgres (pgvector, PITR)       │
│        │                  │                                           │
│        │            Redis (só Sidekiq, AOF)                           │
│        │                  │                                           │
│        │     worker-time (fila do ponto)                              │
│        │     worker (demais filas, sidekiq-cron)                      │
│        │                                                              │
│        └──── clamav (clamd, rede privada)                             │
│                                                                       │
│   backup (cron: pg_dump diário)                                       │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
  AWS sa-east-1 (São Paulo): S3 (arquivos e backups) · KMS · SES · SNS
  Externos: Anthropic e Voyage (retenção zero) · Twilio · Mercado Pago · Sentry · eSocial
```

## 3. Histórias

1. Como **equipe CatalystHR**, quero publicar uma versão nova sem derrubar o ponto de ninguém.
2. Como **equipe CatalystHR**, quero ser acordado por WhatsApp se o ponto parar às 7h50.
3. Como **equipe CatalystHR**, quero restaurar o banco como estava 10 minutos antes de um erro grave.
4. Como **cliente**, quero saber onde meus dados ficam, para responder ao meu encarregado de dados.

## 4. Regras

### 4.1 Onde os dados ficam (D-500, D-501)

- **RN-20-001** — Mapa dos dados, que vai para a política de privacidade e para a lista de suboperadores (spec 05) **[P-20-01]**:

  | Serviço | Região | O que guarda |
  |---|---|---|
  | Railway | EUA (Virgínia) | Aplicação, banco, Redis, ClamAV |
  | AWS S3, KMS, SES, SNS | Brasil (São Paulo) | Arquivos, backups, chaves, e-mails enviados |
  | Anthropic e Voyage | EUA | Nada, com retenção zero (D-380) |
  | Twilio | EUA | Celular e texto dos avisos |
  | Mercado Pago | Brasil | Dados de cobrança de parceiros e empresas diretas |
  | Asaas | Brasil | Dados fiscais de parceiros e empresas diretas, para a NFS-e |
  | Sentry | EUA | Erros, desempenho e logs, sem dados pessoais (RN-20-071) |
  | Cloudflare | Global | Só DNS |

- **RN-20-002** — A transferência internacional (LGPD, art. 33) usa as **cláusulas-padrão contratuais** aprovadas pela ANPD, nos contratos com os clientes e com os fornecedores, com validação do jurídico (item em aberto) **[P-20-02]**.
- **RN-20-003** — A região do Sentry é a dos **EUA**, junto dos outros fornecedores americanos **[P-20-03]**.

### 4.2 Serviços no Railway

- **RN-20-010** — Um projeto do Railway, com os serviços **[P-20-04]**:

  | Serviço | O que roda | Tamanho inicial |
  |---|---|---|
  | `web` | Puma, com 2 réplicas, health check em `/up` e deploy sem queda | 2 vCPU, 2 GB por réplica |
  | `worker-time` | Sidekiq só com a fila `time` (ponto: comprovantes, assinatura, AFD), para nunca esperar atrás de outros jobs (P-10-26) | 1 vCPU, 1 GB |
  | `worker` | Sidekiq com as demais filas e o sidekiq-cron | 2 vCPU, 2 GB |
  | `postgres` | PostgreSQL com a extensão pgvector, PITR ligado | 2 vCPU, 4 GB, 50 GB de disco |
  | `redis` | Redis só para o Sidekiq (D-511), com persistência AOF e `maxmemory-policy noeviction` | 512 MB |
  | `clamav` | clamd e freshclam, só na rede privada, porta 3310 | 1 vCPU, 3 GB |
  | `backup` | Serviço de cron do Railway com o pg_dump (RN-20-041) | Sob demanda |

  Toda tabela tem chave primária UUIDv7, gerada pelo banco (`uuidv7()`, Postgres 18), e toda referência é UUID; só a `solid_cache_entries` tem id numérico (D-614).

- **RN-20-011** — **Filas do Sidekiq e prioridades** no `worker`, com limites de concorrência por fila (capsules do Sidekiq 7+) **[P-20-05]**:

  | Fila | Uso | Concorrência |
  |---|---|---|
  | `critical` | Códigos de acesso, convites, avisos de segurança | Prioridade mais alta |
  | `esocial` | Transmissão e consulta (spec 13) | 3 |
  | `notifications` | Envio de avisos (spec 15) | 10 |
  | `default` | Demais jobs | 5 |
  | `ai` | IA (spec 14) | 4 |
  | `reports` | Exportações e fotos diárias (spec 17) | 2 |
  | `imports` | Importações e exportação completa (spec 18) | 1 |

- **RN-20-012** — Os serviços conversam pela **rede privada** do Railway (`*.railway.internal`). O banco, o Redis e o ClamAV **não têm endereço público** **[P-20-06]**.
- **RN-20-013** — **Build** pelo `Dockerfile` do Rails, com jemalloc, YJIT e o **7-Zip** (pacote `7zip` do Debian 13, comando `7z`, versão 25) para os ZIPs com AES-256 (D-514). A senha do ZIP não pode aparecer na linha de comando nem nos logs **[P-20-07]**. **Nota de implementação (2026-10-14):** o 7-Zip não lê a senha de variável de ambiente; ele aceita o argumento `-p` ou a digitação no terminal. A forma de passar a senha sem expô-la (por exemplo, pela entrada do processo num pseudo-terminal) será resolvida e testada na implementação da exportação (fase 2).
- **RN-20-014** — **Migrações** rodam no *pre-deploy command* do Railway (`bin/rails db:migrate`), só no serviço `web`. Se falharem, o deploy não acontece **[P-20-08]**. A configuração dos serviços fica no Railway e é documentada no README, porque o `railway.json` foi descontinuado pelo Railway (D-517).
- **RN-20-015** — O **ClamAV** é chamado pela aplicação via TCP (gem `clamav-client`). Se o ClamAV estiver fora do ar, o arquivo fica em `scanning` e o job tenta de novo. Nada é liberado sem varredura (P-05-30) **[P-20-09]**.

### 4.3 Domínios e certificados (D-153, D-503)

- **RN-20-020** — DNS na Cloudflare, **sem proxy** (nuvem cinza):
  - `*.painel.catalysthr.com.br`: CNAME para o Railway, mais o CNAME `_acme-challenge` e o TXT de verificação que o Railway pede;
  - `admin.catalysthr.com.br`: CNAME para o mesmo serviço `web`;
  - registros do SES no domínio da plataforma: DKIM, SPF e DMARC (`p=quarantine`) **[P-20-10]**.
- **RN-20-021** — O certificado wildcard é emitido e renovado pelo Railway (Let's Encrypt). Ele cobre um nível só, o que basta para os slugs (spec 01). Um monitor do Sentry confere a validade do certificado.
- **RN-20-022** — O site institucional (`catalysthr.com.br` e `www`) fica fora desta aplicação.

### 4.4 Ambientes, CI e deploy (D-504, D-505)

- **RN-20-030** — Só **produção** (D-504). Para reduzir o risco **[P-20-11]**:
  - uma **empresa de demonstração** em produção, com dados fictícios, eSocial em produção restrita e marcada como interna (fora da cobrança e dos painéis de receita), para a equipe testar depois de cada deploy;
  - **feature flags** (gem `flipper`, guardada no Postgres) para ligar funções novas por empresa antes de liberar para todos;
  - migrações seguras com a gem `strong_migrations`, no padrão expandir e depois contrair, para que a versão anterior continue funcionando durante o deploy.
- **RN-20-031** — **CI no GitHub Actions**, em todo pull request **[P-20-12]**:
  - RuboCop, brakeman, bundler-audit e `importmap audit`;
  - RSpec com Postgres (pgvector) e Redis como serviços, e cobertura pelo SimpleCov;
  - o merge na `main` exige o CI verde (proteção da branch). A revisão aprovada passa a ser exigida quando entrar a segunda pessoa no desenvolvimento (D-516).
- **RN-20-032** — **Deploy** por um workflow do GitHub Actions, que publica pela CLI do Railway. É **automático** (D-575): quando o CI de um push na `main` termina verde, a `main` é publicada. Nenhum deploy começa entre 7h e 9h nem entre 17h e 19h, que são os picos de marcação de ponto; o que ficar pendente sai às 9h05 e às 19h05. O disparo manual continua disponível, e só ele pode forçar um deploy no pico **[P-20-13]**.
- **RN-20-033** — **Volta de versão:** o Railway republica a versão anterior com um clique. Por isso as migrações precisam ser compatíveis com a versão anterior (RN-20-030).
- **RN-20-034** — **Desenvolvimento local:** tudo no Docker Compose (D-587): web, Tailwind e Sidekiq numa imagem de desenvolvimento (`Dockerfile.dev`), com o código montado como volume, junto com o Postgres (pgvector) e o Redis; letter_opener (D-026), varredura de vírus simulada e chamadas externas (IA, Twilio, Mercado Pago, eSocial) em modo de teste ou simulado **[P-20-14]**.
- **RN-20-035** — **Dependências:** Dependabot ligado para gems, imagens Docker e GitHub Actions, com revisão semanal **[P-20-15]**.

### 4.5 Dados, backups e recuperação (D-223, D-502, D-508)

- **RN-20-040** — **PITR** do Railway ligado no Postgres: recuperação a qualquer momento das últimas 4 semanas, para uma réplica nova. Garante a perda máxima de **5 minutos**.
- **RN-20-041** — **pg_dump diário**, às 3h (horário de Brasília), pelo serviço `backup` **[P-20-16]**:
  - formato custom do Postgres, criptografado com uma chave do KMS antes do envio;
  - num bucket S3 próprio de São Paulo (`catalysthr-backups`), com uma regra de ciclo de vida que apaga aos **35 dias** (D-223);
  - gravado por um usuário IAM que **só pode gravar**, e não ler nem apagar;
  - com o resultado registrado e monitorado no Sentry (monitor de cron). Falha gera alerta crítico.
- **RN-20-042** — Os backups mensais e semanais do Railway ficam **desligados**, para nada passar de 35 dias. O PITR do Railway guarda cerca de 4 semanas, o que fica dentro do ciclo (D-502).
- **RN-20-043** — **S3 dos arquivos:** versionamento ligado, com as versões antigas apagadas aos 35 dias. Exclusões definitivas (RN-08-083, encerramento) apagam também as versões antigas **[P-20-17]**.
- **RN-20-044** — **Redis:** com AOF, um reinício não perde as filas. Se o Redis se perder por completo, os jobs agendados voltam pelo sidekiq-cron, e os jobs são escritos para poder rodar de novo sem duplicar (idempotentes) **[P-20-18]**.
- **RN-20-045** — **Recuperação de desastre** (D-508):

  | Cenário | Como volta | Perda máxima | Tempo para voltar |
  |---|---|---|---|
  | Erro grave nos dados | PITR para o momento anterior | 5 minutos | 4 horas |
  | Perda do serviço de banco | PITR numa réplica nova | 5 minutos | 4 horas |
  | Perda total do Railway | Novo ambiente (Railway em outra região ou outro provedor) com o pg_dump do S3 | 24 horas | 4 horas, com o roteiro ensaiado |

- **RN-20-046** — **Ensaio de restauração** a cada 3 meses: restaurar o último pg_dump num serviço temporário, rodar uma checagem (contagens por tabela, último NSR de cada empresa) e registrar o tempo. O roteiro fica no repositório **[P-20-19]**.

### 4.6 Segurança da infraestrutura

- **RN-20-050** — **Segredos** nas variáveis do Railway (P-05-32). Cada serviço recebe só as variáveis de que precisa **[P-20-20]**.
- **RN-20-051** — **AWS:** um usuário IAM para cada finalidade, com o mínimo de permissão **[P-20-21]**:
  - aplicação: S3 dos arquivos (ler e gravar), KMS (criptografar e descriptografar o A1), SES (enviar), SNS (só o tópico de eventos de e-mail);
  - backup: só gravar no bucket de backups;
  - restauração: só ler os backups, usado só no ensaio e na recuperação.
- **RN-20-052** — **KMS:** chaves separadas para o certificado A1 (D-075), para os arquivos (SSE-KMS) e para os backups, com rotação anual automática **[P-20-22]**.
- **RN-20-053** — **Acesso da equipe:** Railway, GitHub, AWS, Cloudflare e Sentry com 2FA obrigatório. O acesso ao banco de produção é só pela CLI do Railway e fica num registro de acessos mantido pela equipe **[P-20-23]**.
- **RN-20-054** — **Criptografia em repouso** no Railway: confirmar no Trust Center (item em aberto). O S3 usa SSE-KMS, e os campos sensíveis já são criptografados pela aplicação (spec 05), o que protege os dados mais críticos de qualquer forma.
- **RN-20-055** — **Proteção contra abuso:** rack-attack (spec 02) com limites por IP e por usuário, e o Railway na borda. Sem proxy da Cloudflare (D-503).

### 4.7 Observabilidade, alertas e plantão (D-506, D-509 a D-513)

- **RN-20-070** — **Sentry** para erros e desempenho do Rails e do Sidekiq, com amostragem de traces de 10% (100% nas rotas do ponto) **[P-20-24]**.
- **RN-20-071** — **Sem dados pessoais no Sentry:** `send_default_pii` desligado, filtro de parâmetros (P-05-33) e um `before_send` que mascara CPF, e-mail e telefone em mensagens e contextos. O contexto do erro leva só IDs (usuário, empresa) **[P-20-25]**.
- **RN-20-072** — **Logs** (D-510): JSON pelo `lograge`, enviados pela aplicação e pelo Sidekiq ao **Sentry Logs**, com 30 dias de retenção. Cada linha leva o ID da requisição, da empresa e do usuário, nunca dados pessoais.
- **RN-20-073** — **Monitores do Sentry** (D-512) **[P-20-26]**:
  - **externos**, a cada minuto: tela de login, portal, `/up` da API do ponto e do totem, e admin. O `/up` geral é conferido em `health.painel.catalysthr.com.br`, e não no endereço do Railway (D-573);
  - **de jobs agendados:** pg_dump, foto diária, geração e cobrança de faturas, régua de inadimplência, prazos do eSocial, fim do período de leitura, liberação dos avisos retidos.
- **RN-20-074** — **Saúde detalhada:** `/up/deep`, protegido por token, confere o banco, o Redis, o ClamAV e o atraso das filas do Sidekiq. É usado pelos monitores externos **[P-20-27]**.
- **RN-20-075** — **Níveis de alerta** **[P-20-28]**:

  | Nível | Exemplos | Para onde |
  |---|---|---|
  | **Crítico** | Sistema fora do ar; ponto falhando; fila `time` com atraso acima de 2 minutos; disco do banco acima de 85%; pg_dump falhou; certificado vencendo em 7 dias | WhatsApp ou SMS ao plantão e e-mail da equipe |
  | **Alto** | Erros em massa; disjuntor da IA (RN-14-123); falhas de comunicação com o eSocial; entregas de e-mail falhando | E-mail da equipe |
  | **Informativo** | Novas versões de dependências, uso de recursos | Resumo semanal por e-mail |

- **RN-20-076** — **Reenvio ao plantão** (D-512): os alertas críticos do Sentry chamam um endpoint interno (`/internal/alerts`, com assinatura conferida), que manda WhatsApp ou SMS pela Twilio aos plantonistas cadastrados na área admin (seção Equipe). Se o WhatsApp falhar, vai por SMS. O mesmo alerta não se repete por 15 minutos **[P-20-29]**.
- **RN-20-077** — **Sidekiq Web** na área admin, só para o superadmin e o suporte **[P-20-30]**.
- **RN-20-078** — Sem página pública de status (D-513). Incidentes são comunicados por e-mail ao responsável de cada contrato e por uma faixa no sistema, publicada pela área admin **[P-20-31]**.

### 4.8 Escala e desempenho

- **RN-20-080** — **Metas** **[P-20-32]**:
  - páginas do painel e do portal: p95 abaixo de 500 ms no servidor;
  - registro de ponto: p95 abaixo de 1 s, do toque até a confirmação;
  - disponibilidade mensal de 99,5%, com o ponto como prioridade.
- **RN-20-081** — **Teste de carga** antes do lançamento (k6): pico de **2.000 marcações por minuto** (por exemplo, 20.000 colaboradores entrando entre 7h50 e 8h) e o painel aberto por 500 usuários ao mesmo tempo **[P-20-33]**.
- **RN-20-082** — **Puma:** 2 workers por réplica, 5 threads cada. O pool de conexões do banco acompanha os threads do Puma e do Sidekiq, abaixo do limite do Postgres. Sem PgBouncer no MVP **[P-20-34]**.
- **RN-20-083** — O Railway escala vertical e horizontalmente pelo painel. Os limites de cada serviço são revistos todo mês, com o uso real **[P-20-35]**.

## 5. Modelo de dados

```
on_call_contacts                                     -- plantão (RN-20-076)
  id, user_id (equipe CatalystHR), phone, channels (text[]), active, order

infra_alerts                                         -- alertas recebidos e reenviados
  id, source ('sentry'), level, title, fingerprint, received_at, relayed_at,
  relayed_to (jsonb), suppressed (bool)

backup_runs                                          -- pg_dump e ensaios
  id, kind ('daily_dump'|'restore_drill'), started_at, finished_at, status,
  size_bytes, s3_key, checks (jsonb), duration_seconds

system_banners                                       -- faixa de incidente (RN-20-078)
  id, text, level, starts_at, ends_at, created_by_id
```

## 6. Jobs e integrações

| Item | Quando | O que faz |
|---|---|---|
| Serviço `backup` (cron do Railway) | 3h, diário | pg_dump, criptografia e envio ao S3 |
| `Infra::AlertRelayJob` | Ao receber um alerta crítico | Envia WhatsApp ou SMS ao plantão |
| `Infra::RestoreDrillReminderJob` | A cada 3 meses | Lembra a equipe do ensaio de restauração |

Gems e ferramentas novas: `sentry-ruby`, `sentry-rails`, `sentry-sidekiq`, `lograge`, `clamav-client`, `flipper`, `strong_migrations`, `simplecov`, 7-Zip no container, k6 para o teste de carga **[P-20-36]**.

## 7. Critérios de aceite

- **CA-20-001** — Dado um deploy novo, quando ele é publicado às 10h, então nenhuma marcação de ponto falha durante a troca de versão.
- **CA-20-002** — Dada uma migração que falha, quando o deploy roda, então a versão anterior continua no ar.
- **CA-20-003** — Dado o pg_dump das 3h, quando termina, então o arquivo está no S3 de São Paulo, criptografado, e o monitor do Sentry registra o sucesso.
- **CA-20-004** — Dado um backup com 36 dias, quando a regra do S3 roda, então ele é apagado.
- **CA-20-005** — Dado o ClamAV fora do ar, quando um colaborador envia um documento, então o documento fica em varredura e só é liberado quando o ClamAV voltar.
- **CA-20-006** — Dada a fila `time` com 3 minutos de atraso, quando o monitor percebe, então o plantonista recebe um WhatsApp.
- **CA-20-007** — Dado um erro com um CPF na mensagem, quando ele chega ao Sentry, então o CPF aparece mascarado.
- **CA-20-008** — Dado um ensaio de restauração, quando termina, então o registro mostra o tempo, o tamanho e as checagens.
- **CA-20-009** — Dado um ZIP de exportação, quando o RH abre no 7-Zip com a senha mostrada, então os arquivos abrem; sem a senha, não.

## 8. Fora do MVP

- Ambiente de homologação e ambientes por pull request (D-504).
- Página pública de status (D-513).
- Réplica do banco em outra região e PgBouncer.

## 9. Em aberto

- Validação jurídica da transferência internacional (D-500).
- Criptografia em repouso no Railway: confirmar no Trust Center.

## 10. Propostas aprovadas (D-515)

| # | Proposta |
|---|---|
| P-20-01 | Mapa de onde os dados ficam |
| P-20-02 | Cláusulas-padrão contratuais da ANPD para a transferência internacional |
| P-20-03 | Sentry na região dos EUA |
| P-20-04 | Serviços do Railway e tamanhos iniciais (worker separado para o ponto) |
| P-20-05 | Filas do Sidekiq e concorrência |
| P-20-06 | Rede privada; banco, Redis e ClamAV sem endereço público |
| P-20-07 | Dockerfile com jemalloc, YJIT e 7-Zip; senha por variável de ambiente |
| P-20-08 | Migrações no pre-deploy |
| P-20-09 | ClamAV via TCP; nada liberado sem varredura |
| P-20-10 | Registros de DNS, com DMARC em quarentena |
| P-20-11 | Empresa de demonstração, feature flags e migrações seguras |
| P-20-12 | Etapas do CI e proteção da branch |
| P-20-13 | Deploy fora dos picos do ponto; automático depois do CI verde desde a D-575 |
| P-20-14 | Desenvolvimento local com Docker Compose e serviços simulados |
| P-20-15 | Dependabot |
| P-20-16 | pg_dump criptografado, IAM só de gravação, monitorado |
| P-20-17 | Versionamento do S3 com 35 dias |
| P-20-18 | Redis com AOF e jobs idempotentes |
| P-20-19 | Roteiro do ensaio de restauração |
| P-20-20 | Variáveis por serviço |
| P-20-21 | Usuários IAM por finalidade |
| P-20-22 | Chaves do KMS separadas, com rotação anual |
| P-20-23 | 2FA em todas as ferramentas e acesso ao banco só pela CLI |
| P-20-24 | Amostragem de traces de 10% (100% no ponto) |
| P-20-25 | Máscara de dados pessoais no Sentry |
| P-20-26 | Lista de monitores externos e de jobs |
| P-20-27 | `/up/deep` protegido por token |
| P-20-28 | Níveis de alerta |
| P-20-29 | Reenvio ao plantão por WhatsApp ou SMS, sem repetir em 15 minutos |
| P-20-30 | Sidekiq Web só para superadmin e suporte |
| P-20-31 | Incidentes por e-mail e faixa no sistema |
| P-20-32 | Metas de desempenho e disponibilidade |
| P-20-33 | Teste de carga com 2.000 marcações por minuto |
| P-20-34 | Puma e pool de conexões, sem PgBouncer |
| P-20-35 | Revisão mensal dos limites dos serviços |
| P-20-36 | Gems e ferramentas novas |
