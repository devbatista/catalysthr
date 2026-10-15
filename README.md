# CatalystHR

Plataforma de RH white label e multiempresa da DevBatista: admissão, documentos, solicitações, ponto eletrônico (REP-P), folha, eSocial, IA, portal do colaborador, recrutamento e avaliação.

| Onde | O quê |
|---|---|
| `docs/specs/` | Especificação funcional e técnica (specs 00 a 22) e o registro de decisões (`decisoes.md`) |
| `docs/checklist/` | Plano de fases, pacotes para o jurídico e o especialista em DP, pendências com fornecedores |
| `docs/prototype/` | Protótipos HTML de referência visual |
| `AGENTS.md` | Regras para agentes de código e para quem desenvolve |

## Stack

Ruby 4.0 e Rails 8.1 (ERB, sem Hotwire e sem React), Tailwind e JavaScript puro pelo importmap, PostgreSQL com pgvector, Sidekiq com Redis, Solid Cache, RSpec. Detalhes em `docs/specs/00-visao-geral.md` e `docs/specs/20-infraestrutura.md`.

## Desenvolvimento local

Pré-requisitos: rbenv com Ruby 4.0.7 (`.ruby-version`) e Docker.

```bash
docker compose up -d     # Postgres com pgvector (porta 5433) e Redis (porta 6380)
bin/setup                # instala as gems, prepara o banco e sobe o servidor
bin/dev                  # web, Tailwind e Sidekiq
```

Cada requisição é resolvida pelo host (spec 01, RN-01-001), então `http://localhost` responde 404. Depois de `bin/rails db:seed`, que cria dados fictícios só em desenvolvimento:

| Endereço local | O que abre |
|---|---|
| http://aurora.painel.localhost | Marca de um parceiro, com cores próprias |
| http://serraazul.painel.localhost | Empresa direta sem marca configurada (nome em texto) |
| http://admin.localhost | Área administrativa CatalystHR |

Os domínios vêm de `ADMIN_HOST` e `PANEL_DOMAIN` (padrão em produção: `admin.catalysthr.com.br` e `painel.catalysthr.com.br`).

Portas locais:

| Serviço | Porta | Observação |
|---|---|---|
| `web` (Rails) | 80 | Escuta em `0.0.0.0`, porque o macOS só libera portas abaixo de 1024 sem `sudo` nesse modo. Aparelhos da mesma rede conseguem acessar; só use dados fictícios |
| Postgres (Docker) | 5433 | Não conflita com um Postgres local na 5432 |
| Redis (Docker) | 6380 | Não conflita com um Redis local na 6379 |

Tailwind (`css`) e Sidekiq (`worker`) não usam porta.

## Testes e qualidade

```bash
bundle exec rspec        # testes; nenhum teste chama APIs externas de verdade (WebMock)
bin/rubocop              # estilo
bin/brakeman --no-pager  # segurança do código
bin/bundler-audit        # vulnerabilidades nas gems
bin/importmap audit      # vulnerabilidades no JavaScript
```

O CI do GitHub Actions roda tudo isso em cada pull request (`.github/workflows/ci.yml`).

## Deploy

Só existe o ambiente de produção, no Railway (D-504). O deploy é manual, pelo workflow **Deploy** na aba Actions, e só segue com o CI verde no commit. Ele recusa os horários de pico do ponto (7h às 9h e 17h às 19h), a não ser que seja forçado.

### Domínios

| Endereço | Para quê | Certificado |
|---|---|---|
| `https://<slug>.painel.catalysthr.com.br` | Painel e portal de cada marca (spec 01, D-153) | Wildcard Let's Encrypt, emitido e renovado pelo Railway |
| `https://admin.catalysthr.com.br` | Área da equipe CatalystHR | Let's Encrypt, emitido e renovado pelo Railway |

O DNS fica na Cloudflare, **sem proxy** (D-503). Os registros do Railway são: CNAME `*.painel`, CNAME `_acme-challenge.painel`, TXT `_railway-verify.painel`, CNAME `admin` e TXT `_railway-verify.admin`.

### Configuração dos serviços no Railway

Projeto `catalyst_hr`, ambiente `production`, região **US East (Virgínia)** em todos os serviços (D-500). A configuração fica no Railway (painel e API), e não em arquivo no repositório (D-517). **Qualquer mudança no Railway deve ser registrada nesta tabela.**

| Serviço | Origem | Início | Pre-deploy | Health check | Réplicas | Variáveis próprias |
|---|---|---|---|---|---|---|
| `web` | `Dockerfile` | padrão do Dockerfile (Thruster na porta 80, Puma na 3000) | `bin/rails db:migrate` | `/up`, 120 s | 2 | `PORT=80`, para o Railway rotear e fazer o health check na porta do Thruster |
| `worker` | `Dockerfile` | `bundle exec sidekiq` | — | — | 1 | — |
| `worker-time` | `Dockerfile` | `bundle exec sidekiq` | — | — | 1 | `SIDEKIQ_ROLE=time` (só a fila do ponto) |
| `Postgres` | template do Railway (Postgres 18 com pgvector) | — | — | — | 1 | Sem endereço público |
| `Redis` | template do Railway (Redis 8) | `redis-server` com `--appendonly yes --maxmemory-policy noeviction` | — | — | 1 | Sem endereço público |

Os serviços `clamav` e `backup` entram na fase 1. Os três serviços da aplicação usam a política de reinício `ON_FAILURE`.

Variáveis comuns aos três serviços da aplicação: `DATABASE_URL` (referência `${{Postgres.DATABASE_URL}}`), `REDIS_URL` (referência `${{Redis.REDIS_URL}}`), `RAILS_MASTER_KEY` e `APP_HOST`. O `SENTRY_DSN` (organização e projeto `catalysthr` no Sentry, região EUA) também está nos três serviços. Segredos nunca entram no repositório.
