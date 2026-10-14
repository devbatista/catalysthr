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

Serviços no Railway (spec 20, RN-20-010):

| Serviço | Comando de início | Observação |
|---|---|---|
| `web` | padrão do Dockerfile | Usa o `railway.json`: migrações no pre-deploy e health check em `/up` |
| `worker` | `bundle exec sidekiq` | Desligar o pre-deploy neste serviço |
| `worker-time` | `bundle exec sidekiq` com `SIDEKIQ_ROLE=time` | Só a fila do ponto. Desligar o pre-deploy |
| `postgres`, `redis`, `clamav`, `backup` | — | Só na rede privada |

Variáveis de ambiente principais: `DATABASE_URL`, `REDIS_URL`, `RAILS_MASTER_KEY`, `SENTRY_DSN`, `APP_HOST`. Segredos nunca entram no repositório.
