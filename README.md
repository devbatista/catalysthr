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

A aplicação abre em http://localhost:3000.

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

### Configuração dos serviços no Railway

Projeto `catalyst_hr`, ambiente `production`, região **US East (Virgínia)** em todos os serviços (D-500). A configuração fica no Railway (painel e API), e não em arquivo no repositório (D-517). **Qualquer mudança no Railway deve ser registrada nesta tabela.**

| Serviço | Origem | Início | Pre-deploy | Health check | Réplicas | Variáveis próprias |
|---|---|---|---|---|---|---|
| `web` | `Dockerfile` | padrão do Dockerfile (Thruster e Puma) | `bin/rails db:migrate` | `/up`, 120 s | 2 | — |
| `worker` | `Dockerfile` | `bundle exec sidekiq` | — | — | 1 | — |
| `worker-time` | `Dockerfile` | `bundle exec sidekiq` | — | — | 1 | `SIDEKIQ_ROLE=time` (só a fila do ponto) |
| `Postgres` | template do Railway (Postgres 18 com pgvector) | — | — | — | 1 | Sem endereço público |
| `Redis` | template do Railway (Redis 8) | `redis-server` com `--appendonly yes --maxmemory-policy noeviction` | — | — | 1 | Sem endereço público |

Os serviços `clamav` e `backup` entram na fase 1. Os três serviços da aplicação usam a política de reinício `ON_FAILURE`.

Variáveis comuns aos três serviços da aplicação: `DATABASE_URL` (referência `${{Postgres.DATABASE_URL}}`), `REDIS_URL` (referência `${{Redis.REDIS_URL}}`), `RAILS_MASTER_KEY` e `APP_HOST`. O `SENTRY_DSN` entra quando o projeto do Sentry existir. Segredos nunca entram no repositório.
