# 09 — Solicitações e aprovações

> Status: aprovado · Última atualização: 2026-10-12
> Decisões: D-087, D-230 a D-241, D-253, D-279, D-290 a D-302 ([decisoes.md](decisoes.md))
> Os itens **[P-09-nn]** foram todos aprovados sem ajuste (D-302, seção 10).
> Regras legais citadas (CLT, NR-7) devem ser conferidas pelo jurídico ou pelo especialista em DP antes da implementação.

## 1. Objetivo

Garantir que **toda solicitação tenha responsável, status e histórico** (apresentação, página 9). Os pedidos do dia a dia (férias, declarações, atestados, ajustes) e os fluxos administrativos (desligamento, LGPD) passam por um mesmo módulo:

- sequência de status padrão;
- aprovações por etapas;
- prazos com escalada;
- comentários, notas internas e anexos.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Tipo de solicitação | `RequestType` | Do sistema (D-291) ou da empresa (D-292) |
| Solicitação | `Request` | Um pedido aberto por alguém, sobre uma pessoa |
| Fluxo | `ProcessInstance` (`request_flow`) | As etapas de aprovação e execução, pelo motor da spec 06 (D-239) |
| Comentário | `RequestComment` | Mensagem visível às partes, ou nota interna (nunca vista pelo colaborador) |

### Status (D-290)

```
Aberta → Em análise → Aguardando informação ⇄ Em análise
                    → Aguardando aprovação → Em execução → Concluída
Qualquer status aberto → Reprovada (com justificativa) | Cancelada (com justificativa)
```

| Status | Código | Significado |
|---|---|---|
| Aberta | `open` | Criada, ainda sem ninguém tratando |
| Em análise | `in_review` | O responsável está avaliando |
| Aguardando informação | `awaiting_info` | Voltou para quem pediu, com uma pergunta |
| Aguardando aprovação | `awaiting_approval` | Numa etapa de aprovação |
| Em execução | `in_progress` | Aprovada, sendo executada (por exemplo, gerar a declaração ou programar as férias) |
| Concluída | `completed` | Terminada |
| Reprovada | `rejected` | Negada, com justificativa visível a quem pediu |
| Cancelada | `cancelled` | Encerrada sem decisão, com justificativa |

O status da solicitação é derivado da etapa atual do fluxo. Cada tipo define por quais status passa **[P-09-01]**.

## 3. Histórias de usuário

1. Como **colaborador**, quero pedir férias e ver na hora meu saldo e se as datas são válidas.
2. Como **gestor**, quero aprovar as férias da minha equipe vendo quem mais estará fora no período.
3. Como **colaborador**, quero mandar a foto do atestado e não ter que levar o papel ao RH.
4. Como **gestor**, quero saber que alguém vai faltar até sexta, sem ver o motivo médico.
5. Como **colaborador**, quero pedir uma declaração de vínculo e recebê-la em PDF na minha pasta.
6. Como **RH**, quero ser avisado quando uma aprovação de gestor está parada há dias.
7. Como **RH**, quero programar as férias coletivas de dezembro da fábrica.
8. Como **gestor**, quero pedir ao RH o desligamento de alguém da minha equipe.
9. Como **colaborador**, quero formalizar meu pedido de demissão pelo portal.
10. Como **RH administrador**, quero criar o tipo "Reembolso de curso", com os campos e o fluxo que a empresa usa.

## 4. Regras de negócio

### Regras comuns

- **RN-09-001** — Quem pode abrir:
  - o colaborador, para si;
  - o gestor, em nome de alguém da equipe (P-03-20);
  - o RH, em nome de qualquer pessoa no escopo dele.

  Cada tipo pode restringir quem abre. O desligamento, por exemplo, segue a RN-09-080.
- **RN-09-002** — Toda solicitação tem:
  - tipo, quem pediu, sobre quem é, campos do tipo e anexos;
  - status, etapa atual, responsável atual e prazo;
  - histórico completo (apresentação, página 9).
- **RN-09-003** — Comentários são visíveis a quem participa. **Notas internas** nunca aparecem para o colaborador (spec 03), e ninguém do RH vê notas internas sobre si mesmo (P-03-34).
- **RN-09-004** — Reprovar ou cancelar exige justificativa, que aparece para quem pediu (D-290).
- **RN-09-005** — Quem pediu pode **cancelar** enquanto a solicitação não estiver `in_progress` ou concluída **[P-09-02]**.
- **RN-09-006** — Ninguém aprova o que é próprio (P-03-33). A etapa de aprovação do gestor vai para o gestor acima (RN-04-024) quando quem pede é o próprio gestor.
- **RN-09-007** — **Aguardando informação:** o responsável faz uma pergunta, a solicitação volta para quem pediu e o prazo da etapa fica parado até a resposta **[P-09-03]**.

### Prazos e escalada (D-293, D-294)

- **RN-09-010** — Cada tipo define o **prazo de resposta por etapa** (em dias úteis) e o **tempo até escalar**, com 2 dias úteis de padrão (D-294).
- **RN-09-011** — Ao vencer o prazo, o responsável e o RH recebem um aviso (spec 15). Se a etapa continuar parada pelo tempo de escalada, ela é **escalada** **[P-09-04]**:
  - etapa do gestor → gestores acima (RN-04-024) → RH da unidade;
  - etapa do RH analista → RH administrador.

  Quem estava antes continua podendo decidir. A escalada só acrescenta quem pode decidir.
- **RN-09-012** — A escalada fica no histórico e entra no resumo operacional da IA (spec 14).

### Tipos do sistema (D-291)

Os tipos do sistema têm **regras fixas**. O **fluxo de aprovação** (quem aprova e em que ordem) é ajustável pelo RH administrador (D-292).

| Tipo | Quem abre | Fluxo padrão **[P-09-05]** | Resultado |
|---|---|---|---|
| Férias | Colaborador, gestor, RH | Gestor → RH | Programação das férias, aviso com ciência, recibo e pagamento (spec 12) |
| Atualização cadastral | Colaborador | RH | Aplica na ficha (spec 04) |
| Declarações e documentos | Colaborador, gestor, RH | RH | PDF gerado pelo modelo e salvo na pasta (D-299) |
| Envio de comprovantes | Colaborador | RH | Documento revisado e salvo na pasta (spec 08) |
| Geral | Colaborador, gestor | RH | Resposta do RH |
| Atestado e afastamento | Colaborador, RH | RH | Ausência registrada no ponto; afastamento e eSocial, se for o caso |
| Ajuste de marcação | Colaborador | Gestor (P-03-23) | Tratamento da marcação (spec 10) |
| Abono e compensação | Colaborador, gestor | Gestor → RH | Abono ou folga lançada no ponto e no banco de horas (spec 11) |
| Adiantamento e benefícios | Colaborador | RH | Lançamento na folha ou mudança de benefício (spec 12) |
| Privacidade/LGPD | Colaborador | RH administrador (P-03-21) | Conforme a spec 05 |
| Desligamento | RH, gestor, colaborador | Ver RN-09-080 | Processo de desligamento |
| Contestação de espelho | Colaborador (a partir do espelho) | RH | Correção do ponto ou resposta (spec 11, D-341) |

### Férias (D-295)

- **RN-09-020** — Ao pedir, o colaborador vê **os períodos aquisitivos**, **o saldo de cada um** e **o limite do período concessivo**. Os cálculos vêm da spec 12, considerando as faltas que reduzem os dias (CLT art. 130).
- **RN-09-021** — Validações (CLT, a conferir com especialista):

  | Regra | Base |
  |---|---|
  | Até 3 períodos; um com pelo menos 14 dias e os outros com pelo menos 5 | Art. 134, § 1º |
  | Não começar nos 2 dias anteriores a feriado ou ao DSR | Art. 134, § 3º |
  | Pedido com antecedência mínima configurável, já que o aviso ao colaborador precisa sair com 30 dias de antecedência | Art. 135 |
  | Abono pecuniário (venda) de até 1/3 dos dias | Art. 143 |
  | Adiantamento da 1ª parcela do 13º, se pedido no prazo | Lei 4.749/65 |
  | Dias pedidos não podem passar do saldo do período | Art. 130 |
  | Estagiário: recesso de 30 dias (ou proporcional), com regra própria | Lei 11.788/08, art. 13 |

  O sistema **bloqueia** o que viola a regra. O RH pode **forçar**, com justificativa registrada (D-295).
- **RN-09-022** — Na aprovação, o gestor vê um **mapa da equipe** com as férias e ausências já aprovadas no mesmo período **[P-09-06]**.
- **RN-09-023** — Depois da última aprovação, a solicitação vai para `in_progress`, e o RH:
  1. gera o **aviso de férias** (modelo de documento) com **ciência eletrônica** (D-279);
  2. a programação vai para a folha, para o recibo e o pagamento até 2 dias antes do início (art. 145, spec 12).

  A solicitação é concluída quando o aviso tem ciência e a programação está registrada na folha **[P-09-07]**.
- **RN-09-024** — Férias aprovadas podem ser **remarcadas** ou **canceladas** pelo RH antes do início, com justificativa. Isso gera uma nova versão da programação e um novo aviso **[P-09-08]**.

### Férias coletivas e calendário (D-300)

- **RN-09-030** — O RH programa **férias coletivas** para unidades ou departamentos inteiros. Regras (a conferir):
  - até 2 períodos por ano, nenhum com menos de 10 dias (art. 139, § 1º);
  - comunicação ao sindicato e ao órgão do Ministério do Trabalho com 15 dias de antecedência (art. 139, §§ 2º e 3º). Microempresas e empresas de pequeno porte são dispensadas da comunicação ao Ministério (LC 123/06, art. 51).
- **RN-09-031** — Quem ainda não completou o período aquisitivo entra em férias proporcionais e começa um novo período aquisitivo (art. 140). O cálculo fica na spec 12.
- **RN-09-032** — O sistema gera os comunicados com base nos modelos de documento, e o aviso a cada colaborador com ciência.
- **RN-09-033** — O **calendário anual** mostra, por unidade e departamento:
  - férias programadas e gozadas;
  - períodos concessivos que vencem.

  O RH recebe um aviso **60 dias antes** do fim de cada período concessivo sem férias programadas, porque férias vencidas são pagas em dobro (art. 137) **[P-09-09]**.

### Atestado e afastamento (D-301)

- **RN-09-040** — O colaborador envia a foto do atestado (spec 08, tipo "Atestado médico", categoria Saúde), as datas e, se quiser, o CID. A IA extrai as datas e o CID (spec 14).
- **RN-09-041** — O RH valida e registra:
  - **até 15 dias** (somando atestados do mesmo motivo em 60 dias): ausência justificada no ponto (spec 11), paga pela empresa;
  - **mais de 15 dias:** afastamento previdenciário, que gera o S-2230 (spec 13). O vínculo fica `on_leave` a partir do 16º dia.

  A regra exata de soma e os códigos de afastamento ficam na spec 13 **[P-09-10]**.
- **RN-09-042** — O gestor vê só "ausente de dd/mm a dd/mm". Arquivo, CID e motivo ficam com o RH (D-301, spec 03). Na lista de solicitações do gestor, o tipo aparece como "Ausência justificada" **[P-09-11]**.

### Declarações (D-299)

- **RN-09-050** — Tipos de declaração disponíveis são os modelos de documento da empresa marcados como "declaração" (vínculo, renda, férias, outras), com variáveis (D-253).
- **RN-09-051** — Depois da aprovação do RH, o PDF é gerado, salvo na pasta (categoria Declarações) e avisado a quem pediu. O RH pode editar o texto antes de gerar **[P-09-12]**.

### Abono, compensação, adiantamento e benefícios

- **RN-09-060** — **Abono:** falta ou atraso com justificativa e anexo opcional. Aprovado, o ponto trata o dia como abonado (spec 11).
- **RN-09-061** — **Compensação:** folga usando o banco de horas. O sistema mostra o saldo e não deixa pedir mais do que ele (spec 11).
- **RN-09-062** — **Adiantamento salarial:** valor dentro do limite configurado pela empresa (spec 12). Aprovado, entra como lançamento na folha do mês.
- **RN-09-063** — **Benefícios:** opção ou recusa do vale-transporte (com declaração de trajeto) e mudança de benefícios. Aprovado, altera o cadastro de benefícios (spec 12).

### Desligamento (D-296 a D-298)

- **RN-09-080** — Três formas de começar:

  | Quem | Como |
  |---|---|
  | **RH** | Abre o desligamento já preenchido, sem etapa de aprovação, e segue para o processo |
  | **Gestor** | Abre o pedido de desligamento de alguém da equipe, com motivo. O RH avalia e aprova (e completa os dados) ou reprova |
  | **Colaborador** | Pede demissão pelo portal. O sistema gera a **carta de pedido de demissão** com os dados informados, e o colaborador dá ciência eletrônica (D-279). O RH aceita e completa os dados |

- **RN-09-081** — O colaborador pode desistir do pedido de demissão enquanto o RH não aceitar **[P-09-13]**.
- **RN-09-082** — Dados do desligamento:
  - tipo: sem justa causa, justa causa, pedido de demissão, acordo (art. 484-A), término de contrato determinado ou de experiência, falecimento, outros;
  - data da comunicação;
  - aviso prévio: trabalhado, indenizado ou dispensado;
  - redução de jornada no aviso trabalhado: 2 horas por dia ou 7 dias corridos (art. 488);
  - último dia trabalhado e motivo.
- **RN-09-083** — **Aviso prévio** (D-298): 30 dias mais 3 por ano completo de serviço, até 90 dias, quando o empregador dispensa (Lei 12.506/11); 30 dias no pedido de demissão. O sistema calcula os dias e a data projetada do término. Os efeitos financeiros ficam na spec 12.
- **RN-09-084** — Ao aprovar, o sistema inicia o **processo de desligamento** (modelo `offboarding`, spec 06), com itens como devolução de EPI e equipamentos, exame demissional, entrevista de saída e encaminhamento à contabilidade (se a empresa usa).
- **RN-09-085** — **Prazos controlados** (D-298):

  | Prazo | Regra | Alerta |
  |---|---|---|
  | Pagamento das verbas | 10 dias corridos do término do contrato (art. 477, § 6º) | Diário a partir de 3 dias antes **[P-09-14]** |
  | eSocial S-2299 (ou S-2399) | Prazo legal definido na spec 13 | Conforme a spec 13 |
  | Exame demissional | Exigido conforme a NR-7, com possível dispensa se o último exame ocupacional for recente (prazos por grau de risco, a confirmar) | Item obrigatório no processo, salvo dispensa registrada |

- **RN-09-086** — Ao concluir o desligamento:
  - o vínculo vira `terminated`;
  - a membership passa a `read_only` pelo período da empresa (D-090, P-02-26);
  - a rescisão (TRCT) vem da spec 12 e fica na pasta (categoria Folha).

### Tipos da empresa (D-292)

- **RN-09-090** — O RH administrador cria tipos próprios com:
  - nome, descrição e ícone;
  - quem pode abrir (colaborador, gestor, RH);
  - campos (os campos livres do formulário da spec 06);
  - anexo obrigatório ou não;
  - fluxo de etapas (modelo `request_flow`);
  - prazos e tempo até escalar.
- **RN-09-091** — Tipos próprios não alteram dados do sistema sozinhos. A execução é uma tarefa do RH, por exemplo "registrar o reembolso" **[P-09-15]**.

## 5. Estados

Ver seção 2. Desligamento, além disso:

**Pedido de demissão:** `draft` → `acknowledged` (ciência do colaborador) → `accepted` (RH) | `withdrawn` (desistência)

**Desligamento:** `requested` → `approved` → `offboarding` → `completed` | `rejected` | `cancelled`

## 6. Permissões

Spec 03, seção 4.6, mais:

| Ação | Quem |
|---|---|
| Ajustar fluxo dos tipos do sistema, criar tipos próprios | RH administrador |
| Férias coletivas e calendário | RH administrador (T), RH analista (U, módulo `solicitacoes`) |
| Forçar férias fora da regra | RH administrador, RH analista (U), com justificativa **[P-09-16]** |
| Ver atestado (arquivo e CID) | RH administrador, RH analista (U). Gestor só vê as datas |

## 7. Modelo de dados

```
request_types
  id, company_id (nullable = sistema), code, name, description, icon,
  system_kind (nullable para tipos próprios), openers (array: employee|manager|hr),
  fields (jsonb), attachment_required, process_template_id (fluxo),
  step_due_business_days (jsonb por etapa), escalation_business_days (padrão 2),
  status

requests
  id, company_id, request_type_id, requester_membership_id,
  subject_worker_profile_id, subject_employment_id, status,
  process_instance_id, current_step_item_id, current_due_on, escalated_at,
  payload (jsonb com os campos do tipo), resolution_note, resolved_at

request_comments
  id, company_id, request_id, author_membership_id, body, internal (bool),
  attachments (Active Storage)

vacation_schedules                                     -- programação das férias
  id, company_id, employment_id, request_id (nullable), collective_vacation_id
  (nullable), acquisition_period_id (spec 12), starts_on, days, sold_days,
  thirteenth_advance, status, version, forced_by_id, force_justification

collective_vacations
  id, company_id, scope (unidades/departamentos), starts_on, days,
  union_notified_on, ministry_notified_on, status

leave_records                                          -- atestados e afastamentos
  id, company_id, employment_id, request_id, document_id, starts_on, ends_on,
  cid (cript.), kind ('justified_absence'|'social_security_leave'|...),
  esocial_event_id

terminations
  id, company_id, employment_id, request_id, kind, communicated_on,
  notice_type ('worked'|'indemnified'|'waived'), notice_days, notice_reduction
  ('two_hours'|'seven_days'|null), last_worked_on, projected_end_on, reason,
  payment_due_on, resignation_letter_document_id, offboarding_process_id,
  esocial_event_id, status
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Requests::DueAndEscalationJob` | A cada hora | Avisa sobre prazos vencidos e escala (RN-09-011) |
| `Vacations::ConcessivePeriodAlertJob` | Diário | Aviso de 60 dias antes do fim do período concessivo |
| `Terminations::DeadlinesJob` | Diário | Alertas de pagamento, eSocial e exame demissional |
| `Requests::GenerateDeclarationJob` | Na aprovação | Gera o PDF da declaração (Prawn) |

## 9. Critérios de aceite

- **CA-09-001** — Dado um colaborador com 30 dias de saldo, quando ele pede 3 períodos de 10 dias, então o sistema recusa por nenhum ter 14 dias ou mais.
- **CA-09-002** — Dado um pedido de férias começando numa quinta antes de um feriado na sexta, quando o colaborador envia, então o sistema recusa pela regra dos 2 dias. Se o RH forçar com justificativa, o pedido segue e a justificativa fica no histórico.
- **CA-09-003** — Dado um gestor que não decide há 2 dias úteis depois do prazo, quando o job roda, então os gestores acima e o RH passam a poder decidir, e a escalada aparece no histórico.
- **CA-09-004** — Dado um atestado de 3 dias com CID, quando o gestor abre a lista da equipe, então vê "Ausência justificada · 12/10 a 14/10", sem CID nem arquivo.
- **CA-09-005** — Dado um atestado que leva a soma a 20 dias pelo mesmo motivo, quando o RH valida, então o sistema indica o afastamento previdenciário a partir do 16º dia e gera a pendência de S-2230.
- **CA-09-006** — Dado um pedido de declaração de vínculo aprovado, quando o RH confirma, então o PDF aparece na pasta do colaborador e ele recebe o aviso.
- **CA-09-007** — Dado um colaborador com 4 anos completos dispensado sem justa causa, quando o RH registra o desligamento, então o aviso prévio calculado é de 42 dias.
- **CA-09-008** — Dado um pedido de demissão com ciência, quando o colaborador desiste antes do aceite do RH, então o pedido fica `withdrawn` e nenhum processo começa.
- **CA-09-009** — Dado um término de contrato em 10/11, quando chega 17/11 sem pagamento registrado, então o RH recebe o alerta de prazo.
- **CA-09-010** — Dado um colaborador, quando ele abre uma solicitação com nota interna, então não vê a nota.
- **CA-09-011** — Dado um tipo próprio "Reembolso de curso" com fluxo Gestor → RH, quando o colaborador abre, então a primeira etapa vai para os gestores do departamento dele.

## 10. Propostas aprovadas (D-302)

| # | Proposta |
|---|---|
| P-09-01 | Status derivado da etapa do fluxo; cada tipo define por quais passa |
| P-09-02 | Quem pediu cancela enquanto não estiver em execução |
| P-09-03 | "Aguardando informação" para o prazo da etapa |
| P-09-04 | Caminho da escalada: gestor → gestor acima → RH; RH analista → RH administrador. Quem estava antes continua podendo decidir |
| P-09-05 | Fluxos padrão de cada tipo do sistema (tabela) |
| P-09-06 | Mapa da equipe na aprovação de férias |
| P-09-07 | Férias concluídas quando o aviso tem ciência e a programação está na folha |
| P-09-08 | Remarcar ou cancelar férias antes do início, com nova versão e novo aviso |
| P-09-09 | Aviso 60 dias antes do fim do período concessivo |
| P-09-10 | Regra de 15 dias para afastamento, com detalhes na spec 13 |
| P-09-11 | O gestor vê o atestado como "Ausência justificada" |
| P-09-12 | O RH pode editar o texto da declaração antes de gerar |
| P-09-13 | O colaborador desiste do pedido de demissão até o aceite do RH |
| P-09-14 | Alerta diário a partir de 3 dias antes do prazo de pagamento |
| P-09-15 | Tipos próprios não alteram dados sozinhos; a execução é tarefa do RH |
| P-09-16 | RH administrador e RH analista podem forçar férias fora da regra, com justificativa |
