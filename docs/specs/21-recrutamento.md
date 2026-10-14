# 21 — Recrutamento

> Status: aprovado · Última atualização: 2026-10-13
> Decisões: D-146, D-204, D-207, D-251, D-390, D-448, D-520 a D-534 ([decisoes.md](decisoes.md))
> Os itens **[P-21-nn]** foram todos aprovados sem ajuste (D-534, seção 10).

## 1. Objetivo

Levar a empresa **da vaga aberta à admissão**, com a decisão sempre humana e o candidato bem tratado:

- pedido e aprovação de vaga (D-527);
- página pública de vagas e link por vaga (D-520);
- funil configurável em quadro (D-521);
- leitura de currículos e apoio da IA, sem nota nem ordenação (D-522, D-523);
- entrevistas e fichas de avaliação (D-530, D-531);
- comunicação e acompanhamento do candidato (D-524, D-525);
- carta-proposta e passagem para a admissão (D-532);
- banco de talentos e recrutamento interno (D-526, D-533).

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Pedido de vaga | `JobRequisition` | O pedido do gestor, com aprovação do RH (D-527) |
| Vaga | `JobOpening` | A vaga publicada, com requisitos, funil e responsáveis |
| Etapa | `PipelineStage` | Uma coluna do funil da vaga |
| Candidato | `Candidate` | Uma pessoa interessada, **por empresa** (como a ficha da spec 04) |
| Candidatura | `Application` | O candidato numa vaga, com a etapa e o resultado |
| Entrevista | `Interview` | Uma entrevista agendada, com entrevistadores |
| Ficha de avaliação | `Scorecard` | A avaliação de um entrevistador numa etapa (D-531) |
| Proposta | `Offer` | A carta-proposta, com aceite ou recusa (D-532) |

## 3. Histórias de usuário

1. Como **gestor**, quero pedir um auxiliar de produção para substituir quem saiu e acompanhar a aprovação.
2. Como **RH**, quero publicar a vaga e mandar o link no grupo de WhatsApp do bairro.
3. Como **candidato**, quero me inscrever pelo celular em 2 minutos, sem criar conta.
4. Como **RH**, quero ver, para cada requisito, se o currículo mostra a experiência, com o trecho que comprova.
5. Como **gestora**, quero registrar minha avaliação da entrevista sem ser influenciada pela do RH.
6. Como **candidato**, quero saber em que etapa estou e receber uma resposta mesmo quando não passar.
7. Como **RH**, quero enviar a proposta e, quando o candidato aceitar, já ter a admissão aberta com os dados dele.
8. Como **colaboradora**, quero me candidatar a uma vaga interna de outra área pelo portal.

## 4. Regras de negócio

### 4.1 Pedido e abertura de vaga (D-527)

- **RN-21-001** — O **gestor** pede a vaga para a equipe dele, informando cargo, quantidade, unidade, departamento, justificativa (**aumento de quadro** ou **substituição**, com o nome de quem saiu), faixa salarial e data desejada.
- **RN-21-002** — O **RH administrador**, ou o **RH analista** da unidade com o módulo `recrutamento`, aprova (completando a vaga) ou recusa com justificativa. O gestor é avisado.
- **RN-21-003** — O RH abre vagas sem pedido e sem aprovação.
- **RN-21-004** — **Campos da vaga** **[P-21-01]**:
  - título público, cargo (D-204), unidade, departamento, tipo de vínculo, modalidade (presencial, híbrido, remoto) e local;
  - descrição, atividades e benefícios, com "Escrever com IA" (D-391) a partir do cargo;
  - **requisitos**, cada um marcado como obrigatório ou desejável (é a base da aderência, RN-21-041);
  - faixa salarial, com a opção de mostrar ou não na página;
  - quantidade de posições e prazo de inscrição;
  - perguntas de triagem (RN-21-022), critérios de avaliação (RN-21-061) e funil (RN-21-030);
  - **visibilidade**: externa, interna ou as duas (D-533);
  - **vaga afirmativa** para PcD (RN-21-024);
  - responsáveis: recrutador do RH, gestor e entrevistadores.
- **RN-21-005** — A vaga fecha quando todas as posições são preenchidas, ou manualmente (cancelada ou suspensa). Ao fechar, o RH escolhe se envia a devolutiva a todos os candidatos ainda ativos (RN-21-071).

### 4.2 Página de vagas e inscrição (D-520, D-528, D-529)

- **RN-21-010** — **Página pública** com a marca (spec 01), no subdomínio da marca **[P-21-02]**:
  - empresa direta: `<slug>.painel.catalysthr.com.br/vagas`;
  - empresa de parceiro: `<slug-do-parceiro>.painel.catalysthr.com.br/vagas/<slug-da-empresa>`, com um **slug público da empresa**, cadastrado pelo RH administrador;
  - cada vaga tem o próprio link, com uma página otimizada para compartilhamento (título, cargo e local na prévia do WhatsApp e do LinkedIn).
- **RN-21-011** — A página lista as vagas externas abertas, com filtros de cidade, área e modalidade, e funciona bem no celular.
- **RN-21-012** — **Fonte:** o link aceita um parâmetro de origem (por exemplo, `?origem=linkedin`), e o formulário pergunta "Como soube da vaga?", com a opção "Indicação de colaborador" e o nome de quem indicou **[P-21-03]**.

**Inscrição**

- **RN-21-020** — **Campos fixos** (minimização, LGPD) **[P-21-04]**: nome, e-mail, celular, cidade e UF, LinkedIn (opcional), currículo em **PDF ou DOCX até 10 MB** (opcional se a vaga permitir) e pretensão salarial (opcional, se a vaga pedir). **CPF não é pedido** na inscrição, só no aceite da proposta (RN-21-091).
- **RN-21-021** — **Consentimentos**, cada um registrado com data, hora, IP e versão do texto:
  - aviso de privacidade do recrutamento (obrigatório);
  - **banco de talentos** por 12 meses (opcional, D-526);
  - **WhatsApp** para os avisos do processo (opcional, D-524).
- **RN-21-022** — **Perguntas de triagem** (D-528): texto, sim/não ou múltipla escolha, com a resposta esperada. Uma resposta diferente da esperada aparece **destacada** na triagem ("não atende: CNH D"), mas **ninguém é reprovado automaticamente**.
- **RN-21-023** — **Diversidade** (D-529): gênero, raça/cor e PcD, por autodeclaração opcional, com "prefiro não informar". Esses dados ficam **separados** da candidatura: quem avalia não vê, e eles só aparecem agregados num relatório, com a regra do "< 5" (D-448) **[P-21-05]**.
- **RN-21-024** — **Vaga afirmativa PcD** (cota da Lei 8.213/91): o formulário pede a condição e as adaptações necessárias para a entrevista e o trabalho. O RH vê essas respostas. O laudo só é pedido na admissão **[P-21-06]**.
- **RN-21-025** — **Proteção contra abuso:** campo escondido (honeypot), limite por IP e por e-mail (rack-attack) e validação do arquivo com varredura de vírus (P-05-30) **[P-21-07]**.
- **RN-21-026** — **Mesmo candidato:** o e-mail identifica o candidato na empresa. Uma nova inscrição cria outra candidatura e atualiza os dados e o currículo dele **[P-21-08]**.
- **RN-21-027** — O RH também **cadastra candidatos à mão**, com o currículo recebido por outro canal, registrando a origem. Nesse caso, o RH declara que avisou o candidato do tratamento dos dados, e o sistema manda o e-mail de confirmação com o aviso de privacidade e o link de acompanhamento **[P-21-09]**.

### 4.3 Funil (D-521)

- **RN-21-030** — **Funil padrão** da empresa, editado pelo RH administrador: Inscritos → Triagem → Entrevista com RH → Entrevista com gestor → Proposta → Contratado. Cada vaga começa com o padrão e pode acrescentar, tirar ou renomear etapas, menos **Inscritos**, **Proposta** e **Contratado**, que são fixas **[P-21-10]**.
- **RN-21-031** — Cada etapa tem um **tipo**: triagem, entrevista, teste, proposta ou contratado. O tipo define o que a etapa oferece (agendar entrevista, ficha de avaliação, carta-proposta).
- **RN-21-032** — **Quadro** com uma coluna por etapa. O RH move os candidatos com os botões **Avançar** e **Reprovar**, e também por arrastar e soltar no computador (JavaScript puro). Mover é sempre uma ação de uma pessoa (D-523).
- **RN-21-033** — **Reprovar** pede um **motivo interno** de uma lista (não atende requisito, salário, desistiu, outro candidato escolhido, sem retorno, outro) e um comentário opcional. O motivo **nunca** vai ao candidato.
- **RN-21-034** — A lista de candidatos é em **ordem de inscrição** (ou de última movimentação), nunca pela IA. Filtros: etapa, origem, resposta de triagem e "requisitos obrigatórios não evidenciados" **[P-21-11]**.
- **RN-21-035** — Toda movimentação fica no histórico da candidatura, com quem moveu, quando e o motivo.

### 4.4 IA (D-522, D-523, spec 14)

- **RN-21-040** — Ao chegar um currículo (se a função `recruitment` estiver ligada, RN-14-010), a IA, numa só chamada:
  - **extrai** contatos, formação, experiências (empresa, cargo e período), cursos e idiomas, para o RH conferir na ficha;
  - escreve um **resumo** de até 5 linhas da trajetória;
  - avalia a **aderência** a cada requisito (RN-21-041).
- **RN-21-041** — **Aderência por requisito**: para cada requisito da vaga, a IA responde **evidenciado**, **não evidenciado** ou **pouco claro**, citando o trecho do currículo. Não há nota, percentual nem ordenação (D-523).
- **RN-21-042** — **Perguntas de entrevista**: sob demanda, a IA sugere de 5 a 8 perguntas para explorar os requisitos "não evidenciados" e "pouco claros".
- **RN-21-043** — **Proteção contra viés** **[P-21-12]**:
  - as instruções proíbem considerar ou mencionar idade, gênero, raça, cor, estado civil, filhos, religião, deficiência, aparência, foto, endereço ou nome de instituições como sinal de qualidade;
  - a IA nunca recebe as respostas de diversidade (RN-21-023);
  - a tela mostra o aviso "A análise da IA é um apoio. A decisão é sua".
- **RN-21-044** — **Créditos** (spec 14): **1** por currículo analisado (extração, resumo e aderência) e **1** pelas perguntas de entrevista. Se o currículo mudar, a nova análise consome de novo **[P-21-13]**.
- **RN-21-045** — Toda análise da IA guarda a versão das instruções e do currículo usados. O candidato pode pedir a revisão humana de qualquer tratamento (LGPD, art. 20), pelo pedido de privacidade da página de acompanhamento **[P-21-14]**.

### 4.5 Entrevistas e avaliação (D-530, D-531)

- **RN-21-050** — Ao mover para uma etapa de entrevista, o RH pode **agendar**: data, hora, duração, entrevistadores, presencial (endereço) ou online (link informado pelo RH).
- **RN-21-051** — O candidato e os entrevistadores recebem e-mail com o arquivo **.ics**. Remarcar ou cancelar manda um novo .ics que atualiza o evento na agenda **[P-21-15]**.
- **RN-21-052** — **Entrevistadores** podem ser o gestor da vaga ou **qualquer usuário da empresa** indicado pelo RH (por exemplo, um técnico experiente). O entrevistador vê **só** os candidatos que vai entrevistar: currículo, resumo da IA e respostas de triagem, sem os dados de diversidade **[P-21-16]**.

**Ficha de avaliação**

- **RN-21-060** — Cada entrevistador preenche a ficha da etapa: nota de **1 a 5** por critério, parecer escrito e recomendação (**seguir** ou **não seguir**).
- **RN-21-061** — Os **critérios** são definidos na vaga, com sugestões a partir do cargo e dos requisitos.
- **RN-21-062** — Um entrevistador só vê as fichas dos outros **depois de enviar a sua** (D-531). O RH responsável vê todas quando chegam.
- **RN-21-063** — A ficha enviada não pode ser editada. Correções viram um comentário complementar **[P-21-17]**.

### 4.6 Comunicação com o candidato (D-524)

- **RN-21-070** — **Mensagens**, por e-mail com a marca e, se o candidato autorizou, também por WhatsApp (modelos da plataforma, D-406, consumindo a cota):

  | Mensagem | Quando |
  |---|---|
  | Confirmação da inscrição | Na hora, com o link de acompanhamento |
  | Convite de entrevista | Ao agendar, com o .ics (só por e-mail) e o resumo no WhatsApp |
  | Devolutiva | Ao reprovar ou ao fechar a vaga |
  | Proposta | Ao enviar a carta-proposta |

- **RN-21-071** — **Devolutiva**: texto padrão da empresa, editável por vaga, sem o motivo interno. Ao reprovar, o RH escolhe **enviar agora**, **agendar** (por exemplo, para 2 dias depois) ou **não enviar** (por exemplo, se já avisou por telefone) **[P-21-18]**.
- **RN-21-072** — As mensagens a candidatos seguem o horário de silêncio fixo da spec 15 no WhatsApp (20h às 8h e fins de semana). O e-mail sai na hora.
- **RN-21-073** — Candidatos não são usuários do sistema. As mensagens deles ficam fora do catálogo de avisos da spec 15, num registro próprio de entregas, com os mesmos provedores e o tratamento de falhas da RN-15-080 **[P-21-19]**.

### 4.7 Página de acompanhamento (D-525)

- **RN-21-080** — Cada candidato tem um **link pessoal** (token longo e aleatório), enviado na confirmação. Pedir o link de novo é possível pelo e-mail, na página de vagas **[P-21-20]**.
- **RN-21-081** — A página mostra cada candidatura com a **etapa em termos gerais**: Inscrição recebida, Em análise, Em entrevistas, Proposta, Processo encerrado. Os nomes internos das etapas e os motivos não aparecem.
- **RN-21-082** — O candidato pode: atualizar o currículo e os contatos; **desistir** de uma candidatura; ver e mudar os consentimentos (banco de talentos, WhatsApp); responder à proposta (RN-21-090); e pedir a **exclusão dos dados**, executada na hora, a menos que haja uma proposta aceita ou uma admissão em andamento **[P-21-21]**.

### 4.8 Proposta e passagem para a admissão (D-532)

- **RN-21-090** — Na etapa **Proposta**, o RH gera a **carta-proposta** pelo motor de modelos de documento da spec 07 (RN-07-040), com variáveis como cargo, salário, benefícios, tipo de vínculo, jornada, unidade e data de início. O PDF é gerado pelo Prawn. A proposta tem um **prazo de resposta**, de 5 dias úteis por padrão **[P-21-22]**.
- **RN-21-091** — O candidato vê a proposta na página de acompanhamento e **aceita** ou **recusa** (com motivo opcional). No aceite, informa o **CPF** e confirma o celular. O aceite registra data, hora, IP, user agent e o hash do PDF. Vencido o prazo sem resposta, a proposta expira, e o RH pode reenviar.
- **RN-21-092** — **Aceite externo:** o sistema cria a **admissão** (D-251, spec 07) com o cadastro inicial preenchido (nome, CPF, contatos, cargo, unidade, departamento, tipo de vínculo, data de início) e o currículo na pasta. A candidatura vai para **Contratado**, e o RH segue o fluxo da spec 07 (liberar o convite) **[P-21-23]**.
- **RN-21-093** — Se o CPF já tem vínculo ativo na empresa, o RH vê o alerta da RN-07-014 antes de criar a admissão.

### 4.9 Recrutamento interno (D-533)

- **RN-21-100** — Vagas **internas** aparecem no portal do colaborador (Mais → Vagas internas, spec 16), para todos ou com filtro por unidade e tipo de vínculo. O colaborador se candidata com um clique, podendo anexar um currículo e uma mensagem.
- **RN-21-101** — **Sigilo:** o gestor atual do colaborador **não vê** a candidatura nas etapas anteriores à proposta. Na proposta, ele é avisado, conforme a configuração da empresa: **avisar na proposta** (padrão) ou **não avisar** **[P-21-24]**.
- **RN-21-102** — **Contratação interna:** no aceite, não há admissão. O sistema cria uma **revisão do vínculo** (D-207) com cargo, salário, unidade, departamento e gestor novos, com a data de início como vigência e o motivo "recrutamento interno". Se o tipo de vínculo mudar (por exemplo, de estágio para CLT), o RH é levado ao desligamento e à nova admissão **[P-21-25]**.

### 4.10 Banco de talentos e retenção (D-526, spec 05)

- **RN-21-110** — Com o consentimento do banco de talentos, o candidato pode ser **convidado** pelo RH para outras vagas da empresa por 12 meses. O convite chega por e-mail, e ele confirma o interesse com um clique, o que cria a candidatura.
- **RN-21-111** — **30 dias antes** do fim dos 12 meses, o candidato recebe um e-mail para renovar por mais 12 meses. Sem renovação, vale a retenção de 6 meses a partir do fim do último processo **[P-21-26]**.
- **RN-21-112** — **Sem consentimento:** os dados ficam **6 meses** depois do fim do último processo do candidato na empresa (spec 05) e são excluídos por um job, com o currículo e as fichas. Indicadores agregados continuam.
- **RN-21-113** — Candidatos de uma empresa nunca aparecem para outra empresa, nem do mesmo parceiro.

### 4.11 Indicadores

- **RN-21-120** — Painel do recrutamento (spec 17), por vaga e no total **[P-21-27]**:
  - vagas abertas, posições preenchidas e tempo médio para preencher;
  - candidatos por origem e conversão por etapa;
  - motivos de reprovação e de recusa de proposta;
  - diversidade agregada das candidaturas, só para o RH administrador e com a regra do "< 5" (D-448).

## 5. Estados

**Pedido de vaga:** `submitted` → `approved` (vira vaga) | `rejected` · `cancelled`

**Vaga:** `draft` → `open` ⇄ `paused` → `filled` | `cancelled`

**Candidatura:** `active` (numa etapa) → `hired` | `rejected` | `withdrawn`

**Proposta:** `draft` → `sent` → `accepted` | `declined` | `expired` · `cancelled`

**Entrevista:** `scheduled` → `done` | `cancelled` | `no_show`

## 6. Permissões

Spec 03, seção 4.9, com o detalhe:

| Ação | Quem |
|---|---|
| Pedir vaga | Gestor (equipe dele) |
| Aprovar pedido, abrir e editar vaga | RH administrador (T), RH analista com o módulo `recrutamento` (U) |
| Gerir candidatos e etapas | RH administrador (T), RH analista com o módulo (U), gestor (vagas da equipe dele) |
| Ver e avaliar candidatos atribuídos | Entrevistadores indicados (só os candidatos que vão entrevistar) |
| Ver diversidade agregada | RH administrador |
| Ver condição PcD em vaga afirmativa | RH administrador, RH analista da vaga |
| Funil padrão, textos de devolutiva, slug público, aviso ao gestor no recrutamento interno | RH administrador |
| Candidatar-se a vaga interna | Colaborador |

## 7. Modelo de dados

```
job_requisitions
  id, company_id, requested_by_id, position_id, unit_id, department_id, quantity,
  reason ('growth'|'replacement'), replaced_employment_id, salary_min, salary_max,
  desired_start_on, status, decided_by_id, decided_at, decision_note, job_opening_id

job_openings
  id, company_id, job_requisition_id, title, position_id, unit_id, department_id,
  employment_kind, work_mode, location, description, benefits,
  salary_min, salary_max, show_salary, quantity, applications_close_on,
  visibility ('external'|'internal'|'both'), internal_audience (jsonb),
  affirmative_pcd, recruiter_id, manager_id, status, rejection_message

job_requirements
  id, job_opening_id, text, required (bool), position

screening_questions
  id, job_opening_id, text, kind ('text'|'yes_no'|'choice'), options (jsonb),
  expected_answer

pipeline_stages
  id, company_id, job_opening_id (nullable = funil padrão), name, kind, position

evaluation_criteria
  id, job_opening_id, name, position

candidates                                          -- por empresa
  id, company_id, name, email (único na empresa), phone, city, state, linkedin_url,
  worker_profile_id (se for colaborador), tracking_token_digest,
  talent_pool_until, whatsapp_consent, consents (jsonb), deleted_at

candidate_diversity                                 -- separado, criptografado
  candidate_id, gender, race, disability, disability_needs

applications
  id, company_id, job_opening_id, candidate_id, stage_id, status, source,
  referred_by_id, screening_answers (jsonb), screening_flags (jsonb),
  rejection_reason, rejection_note, rejected_by_id, feedback_status
  ('pending'|'scheduled'|'sent'|'skipped'), feedback_send_at, internal (bool)

application_events
  id, application_id, kind, from_stage_id, to_stage_id, actor_id, note, created_at

resumes
  id, company_id, candidate_id, file (Active Storage), sha256, uploaded_at,
  ai_extraction_id (spec 14), ai_summary, ai_fit (jsonb: [{requirement_id,
  status, quote}]), ai_questions (jsonb), prompt_version

interviews
  id, application_id, stage_id, starts_at, duration_minutes, location, meeting_url,
  status, ics_uid, ics_sequence

interview_participants
  interview_id, user_id

scorecards
  id, application_id, stage_id, evaluator_id, ratings (jsonb), opinion,
  recommendation ('advance'|'hold'), submitted_at

offers
  id, application_id, document_template_id, pdf (Active Storage), sha256,
  status, expires_on, sent_at, responded_at, response_ip, response_user_agent,
  decline_reason, admission_id, employment_revision_id

candidate_messages                                  -- registro próprio (RN-21-073)
  id, company_id, candidate_id, kind, channel, status, provider_message_id, sent_at
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Recruiting::AnalyzeResumeJob` | Ao receber currículo | Extração, resumo e aderência pela IA (fila `ai`) |
| `Recruiting::SendCandidateMessageJob` | Por mensagem | E-mail (SES) ou WhatsApp (Twilio), com silêncio no WhatsApp |
| `Recruiting::ScheduledFeedbackJob` | A cada hora | Envia as devolutivas agendadas |
| `Recruiting::OfferExpirationJob` | Diário | Expira propostas sem resposta |
| `Recruiting::TalentPoolRenewalJob` | Diário | Pede renovação 30 dias antes do fim |
| `Recruiting::RetentionJob` | Diário | Exclui candidatos fora da retenção |

- **.ics** gerado pela gem `icalendar` **[P-21-28]**.
- **Avisos novos** no catálogo da spec 15 (usuários do sistema): `recruiting.requisition_submitted` e `recruiting.requisition_decided`, `recruiting.interview_assigned` (entrevistador), `recruiting.scorecard_pending`, `recruiting.offer_answered` e `recruiting.internal_offer` (gestor atual, RN-21-101). Nenhum é obrigatório; todos em S E P.

## 9. Critérios de aceite

- **CA-21-001** — Dado um pedido de vaga do gestor, quando o RH analista da unidade aprova, então a vaga é criada com os dados do pedido, e o gestor é avisado.
- **CA-21-002** — Dada a página de vagas de uma empresa de parceiro, quando um candidato abre pelo celular, então vê a marca configurada e só as vagas externas abertas daquela empresa.
- **CA-21-003** — Dada uma resposta "não" à pergunta "Tem CNH D?", quando o RH abre a triagem, então o candidato aparece com o destaque "não atende: CNH D" e continua em Inscritos.
- **CA-21-004** — Dado um currículo analisado, quando o RH abre o candidato, então vê cada requisito como evidenciado, não evidenciado ou pouco claro, com o trecho, e nenhuma nota ou ordenação.
- **CA-21-005** — Dado um candidato com autodeclaração de raça, quando o gestor entrevistador abre a ficha, então não vê esse dado.
- **CA-21-006** — Dados dois entrevistadores, quando o primeiro abre o candidato antes de enviar a ficha, então não vê a ficha do segundo.
- **CA-21-007** — Dado um candidato reprovado com o motivo "salário", quando a devolutiva é enviada, então o texto não menciona o motivo.
- **CA-21-008** — Dada uma entrevista remarcada, quando o RH salva, então o candidato recebe um .ics que atualiza o mesmo evento na agenda.
- **CA-21-009** — Dada uma proposta aceita por um candidato externo, quando ele confirma com o CPF, então a admissão é criada com o cadastro inicial preenchido e o currículo na pasta.
- **CA-21-010** — Dada uma colaboradora que se candidatou a uma vaga interna, quando ela está em entrevistas, então o gestor atual não vê a candidatura; na proposta, ele é avisado.
- **CA-21-011** — Dado um candidato sem consentimento de banco de talentos, quando passam 6 meses do fim do processo, então os dados, o currículo e as fichas são excluídos.
- **CA-21-012** — Dado um candidato que pede a exclusão pela página de acompanhamento, sem proposta aceita, quando confirma, então os dados são excluídos na hora.

## 10. Propostas aprovadas (D-534)

| # | Proposta |
|---|---|
| P-21-01 | Campos da vaga, com requisitos obrigatórios e desejáveis |
| P-21-02 | Endereço da página de vagas e slug público da empresa |
| P-21-03 | Origem pelo link e pergunta "Como soube da vaga?", com indicação |
| P-21-04 | Campos fixos da inscrição, sem CPF |
| P-21-05 | Diversidade separada da candidatura, só agregada |
| P-21-06 | Vaga afirmativa PcD: condição e adaptações visíveis ao RH; laudo só na admissão |
| P-21-07 | Honeypot, limites e varredura de vírus |
| P-21-08 | O e-mail identifica o candidato na empresa |
| P-21-09 | Cadastro manual com declaração do RH e aviso de privacidade ao candidato |
| P-21-10 | Funil padrão com Inscritos, Proposta e Contratado fixas |
| P-21-11 | Lista em ordem de inscrição, com filtros |
| P-21-12 | Proteção contra viés nas instruções da IA |
| P-21-13 | Créditos: 1 por currículo e 1 pelas perguntas |
| P-21-14 | Versão da análise guardada e revisão humana a pedido |
| P-21-15 | Remarcação atualiza o mesmo evento .ics |
| P-21-16 | Entrevistadores podem ser qualquer usuário indicado, vendo só os seus candidatos |
| P-21-17 | Ficha enviada não é editada |
| P-21-18 | Devolutiva agora, agendada ou não enviada |
| P-21-19 | Mensagens a candidatos num registro próprio, fora do catálogo |
| P-21-20 | Link de acompanhamento com token, reenviável por e-mail |
| P-21-21 | Ações do candidato na página, com exclusão na hora |
| P-21-22 | Carta-proposta pelo motor de modelos, com prazo de 5 dias úteis |
| P-21-23 | Admissão criada no aceite externo |
| P-21-24 | Aviso ao gestor atual na proposta, configurável |
| P-21-25 | Contratação interna vira revisão do vínculo |
| P-21-26 | Renovação do banco de talentos 30 dias antes |
| P-21-27 | Indicadores do recrutamento |
| P-21-28 | Gem `icalendar` |
