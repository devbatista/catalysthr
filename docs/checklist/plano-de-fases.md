# Plano de fases — CatalystHR (checklist)

> Última atualização: 2026-10-13
> Base: specs 00 a 22 e `docs/specs/decisoes.md`.
> Definições do responsável: ponto antes de folha e eSocial; IA de documentos no núcleo e o restante da IA no fim; cobrança completa já na fundação; 1 desenvolvedor com apoio de agentes de IA; sem piloto definido; estimativa pedida, sem data-alvo.

Marque `[x]` quando o item estiver pronto. Cada fase tem os pré-requisitos (o que precisa estar resolvido antes), as entregas e o critério de pronto.

## Resumo

| Fase | Entrega | Estimativa | O que libera |
|---|---|---|---|
| 0 | Preparação | 2 a 3 semanas | Começar a desenvolver |
| 1 | Fundação e cobrança | 12 a 16 semanas | Cadastrar parceiros e empresas, cobrar, administrar |
| 2 | Núcleo de RH, com a IA de documentos | 16 a 22 semanas | **Primeiro cliente**, sem ponto e sem folha |
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
- [ ] Enviar o `pacote-juridico.md` ao jurídico
- [ ] Enviar o `pacote-especialista-dp.md` ao especialista em DP
- [ ] Abrir os pedidos da `pendencias-fornecedores.md` (Mercado Pago, Asaas e contador, AWS SES, WhatsApp pela Twilio, Anthropic, Voyage, Railway)
- [ ] Redigir as minutas jurídicas em `juridico/` (termos de uso, política de privacidade, aviso do recrutamento, contrato de tratamento de dados) e mandar ao jurídico para revisão
- [ ] Começar a procurar um parceiro piloto

### Desenvolvimento
- [x] `rails new` com a stack da spec 20: Postgres com pgvector, Redis, Sidekiq, Tailwind, importmap, Dockerfile com jemalloc, YJIT e 7-Zip (Ruby 4.0.7, Rails 8.1.4)
- [x] Repositório privado `devbatista/catalysthr`, com proteção da `main` (CI verde obrigatório)
- [x] Revisão obrigatória no merge: só quando entrar a segunda pessoa; até lá, só o CI verde (D-516)
- [ ] Exigir uma revisão aprovada na proteção da `main` quando entrar a segunda pessoa
- [x] GitHub Actions: RuboCop, brakeman, bundler-audit, `importmap audit`, RSpec com Postgres e Redis, SimpleCov
- [x] Dependabot (gems, Docker, Actions)
- [x] Railway US East: projeto `catalyst_hr` com `web`, `worker`, `worker-time`, `Postgres` (18 com pgvector) e `Redis` (AOF e `noeviction`), só na rede privada. `clamav` e `backup` ficam para a fase 1
- [ ] AWS em São Paulo: S3 (arquivos e backups), KMS (três chaves), SES, SNS e usuários IAM por finalidade
- [ ] Cloudflare DNS: `*.painel`, `_acme-challenge`, `admin`, DKIM, SPF e DMARC
- [ ] Sentry: criar o projeto e definir `SENTRY_DSN` (a integração e a máscara de dados pessoais já estão no código); primeiro monitor externo
- [x] Docker Compose para o desenvolvimento local
- [x] Workflow de deploy manual, com CI verde exigido e bloqueio nos picos do ponto; migrações no pre-deploy do serviço `web`, configurado no Railway (D-517)
- [ ] Secret `RAILWAY_TOKEN` no GitHub, depois de criar o projeto no Railway

### Pronto quando
- [ ] Uma página "olá" passa pelo CI, é publicada com aprovação manual e responde com HTTPS num subdomínio wildcard

---

## Fase 1 — Fundação e cobrança (12 a 16 semanas)

### Pré-requisitos
- [ ] Mercado Pago: conta habilitada para cobrar o cartão salvo sem o CVV
- [ ] Contador da CatalystHR: código do serviço, ISS, retenções e fato gerador da NFS-e
- [ ] Asaas: conta configurada na prefeitura ou no Portal Nacional
- [ ] AWS SES: fora do sandbox em São Paulo
- [ ] Railway: criptografia em repouso confirmada no Trust Center

### Entregas
- [ ] **Spec 01:** tenant pelo host, subdomínios e redirecionamento, marcas e modos de marca, domínio de e-mail no SES, transferência de empresa
- [ ] **Spec 02:** login por CPF ou e-mail, convites por e-mail e link (por WhatsApp quando a Twilio estiver aprovada), senha, bloqueio, MFA, sessões, impersonate em simulação
- [ ] **Spec 03:** perfis, escopos, módulos liberados e contratados, `Ability`
- [ ] **Spec 04:** empresa, unidades, departamentos, cargos, ficha, vínculos, revisões com vigência, campos personalizados
- [ ] **Spec 05:** criptografia de campos, PaperTrail sem campos sensíveis, `access_events`, confirmação de senha, mascaramento
- [ ] **Spec 15 (base):** sino, e-mail, catálogo e preferências
- [ ] **Spec 19:** planos, módulos e adicionais; consumo e cotas; teste grátis; faturas; Mercado Pago (cartão salvo e PIX); novas tentativas; régua de inadimplência; cancelamento; ajustes; NFS-e pelo Asaas; área admin; painel CatalystHR
- [ ] **Spec 20:** pg_dump diário, PITR, monitores de jobs, níveis de alerta, reenvio ao plantão pela Twilio

### Pronto quando
- [ ] O superadmin cria um parceiro e uma empresa direta em teste
- [ ] Eles configuram a marca e convidam o RH, que entra com MFA
- [ ] Contratam um plano e pagam por cartão e por PIX
- [ ] A NFS-e sai pelo Asaas e aparece na fatura
- [ ] A régua de inadimplência roda de ponta a ponta com datas simuladas
- [ ] Os critérios de aceite das specs 01 a 05 e 19 passam

---

## Fase 2 — Núcleo de RH (16 a 22 semanas) · primeiro cliente

### Pré-requisitos
- [ ] Anthropic: retenção zero contratada
- [ ] Voyage: retenção zero confirmada (ou decisão sobre a alternativa)
- [ ] Jurídico: prazos de retenção e transferência internacional validados; minutas de termos de uso, política de privacidade e contrato de tratamento de dados revisadas
- [ ] WhatsApp pela Twilio: empresa verificada na Meta, remetente registrado e modelos aprovados
- [ ] Especialista em DP: spec 09 conferida, menos as férias
- [ ] Parceiro ou empresa piloto definido

### Entregas
- [ ] **Spec 06:** motor de modelos de processo
- [ ] **Spec 07:** admissão completa, sem as etapas de eSocial
- [ ] **Spec 08:** documentos, revisão, vencimentos, pedidos, ciência, lote, exclusão recuperável
- [ ] **Spec 14 (parte):** leitura de documentos e lote, com créditos, teto, falhas e retenção zero
- [ ] **Spec 09:** solicitações e aprovações, **sem férias** (que ficam na fase 4)
- [ ] **Spec 15 (resto):** WhatsApp, push, horário de silêncio, resumo diário por e-mail, mural
- [ ] **Spec 16:** portal PWA, service worker, convite para instalar, passkeys, "Minha equipe"
- [ ] **Spec 17 (parte):** painel do RH e do gestor e visão consolidada do parceiro
- [ ] **Spec 18 (parte):** importação da implantação (estrutura, pessoas, dependentes, bancários, gestores, histórico), desfazer, importação assistida, exportação completa
- [ ] **Spec 05 (resto):** anonimização, retenção por processo, direitos do titular, encerramento de contrato

### Pronto quando
- [ ] O piloto é implantado pela planilha
- [ ] Admissões reais com documentos lidos pela IA e revisados pelo RH
- [ ] Os colaboradores usam o portal no celular
- [ ] As solicitações fluem com aprovação e escalada
- [ ] Os critérios de aceite das specs 06, 07, 08, 09, 15 e 16 passam

---

## Fase 3 — Ponto e jornada (12 a 16 semanas)

### Pré-requisitos
- [ ] Jurídico: CatalystHR como fabricante, assinatura com o A1 do empregador, bloqueio pela cerca, layouts do AFD, do AEJ e do comprovante
- [ ] Registro do programa no INPI e o atestado técnico
- [ ] Especialista em DP: spec 11 conferida

### Entregas
- [ ] **Spec 10:** marcação no PWA, cerca, selfie com consentimento, IPs, externos, totem, NSR, marcação imutável (trigger), comprovante assinado, tratamento, AFD e AEJ
- [ ] **Spec 13 (parte):** upload do certificado A1 no KMS, que o ponto já exige
- [ ] **Spec 11:** regras de ponto, jornadas, feriados, apuração, banco de horas, fechamento, espelho, contestação
- [ ] **Spec 15:** lembrete de marcação
- [ ] **Spec 17:** blocos de ponto e relatório de absenteísmo e jornada
- [ ] **Spec 18:** importação de jornadas e saldos
- [ ] **Spec 20:** teste de carga com 2.000 marcações por minuto

### Pronto quando
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
- [ ] Uma competência real do piloto, calculada em paralelo com o sistema atual dele, bate nos casos conferidos
- [ ] Os eventos são aceitos na produção restrita
- [ ] A empresa passa para produção (D-374)
- [ ] Os critérios de aceite das specs 12 e 13 passam

---

## Fase 5 — IA restante, recrutamento, avaliação e relatórios (12 a 16 semanas)

### Entregas
- [ ] **Spec 14 (resto):** resumo operacional, assistente (materiais, pgvector, Voyage, citações), redação
- [ ] **Spec 21:** recrutamento completo
- [ ] **Spec 22:** avaliação de experiência e de desempenho, feedbacks
- [ ] **Spec 17 (resto):** foto diária, relatórios gerenciais, diversidade, comparação entre empresas, agendamento

### Pronto quando
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
