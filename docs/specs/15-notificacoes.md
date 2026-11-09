# 15 — Notificações

> Status: aprovado · Última atualização: 2026-11-06
> Decisões: D-012, D-026, D-034, D-040, D-041, D-092, D-160, D-161, D-177, D-179, D-181, D-182, D-186, D-314, D-386, D-400 a D-410, D-570, D-607 a D-609, D-643, D-654, D-655 ([decisoes.md](decisoes.md))
> Os itens **[P-15-01]** a **[P-15-34]** foram todos aprovados sem ajuste (D-410, seção 10). O item **[P-15-35]** (gestor do cliente, D-570) foi aprovado sem ajuste (D-572).

## 1. Objetivo

Fazer **cada aviso chegar à pessoa certa, pelo canal certo, na hora certa**, sem expor dados sensíveis e sem incomodar fora do expediente:

- notificações no sistema (sino), e-mail, WhatsApp e push do PWA (D-400);
- catálogo único de avisos, usado por todas as specs;
- preferências por empresa e por pessoa (D-401);
- horário de silêncio (D-402, D-403);
- resumo diário por e-mail para o RH e os gestores (D-404);
- lembrete de marcação de ponto (D-405);
- mural de comunicados (D-408);
- entrega, falhas e canal de reserva (D-409).

As outras specs dizem **quando** um aviso nasce. Esta spec diz **como** ele chega.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Tipo de aviso | `NotificationType` | Item do catálogo (seção 4.2): para quem vai, se é obrigatório ou urgente, canais padrão |
| Notificação | `Notification` | Um aviso para uma pessoa. Aparece no sino quando o tipo tem o canal S no catálogo (D-608) |
| Entrega | `NotificationDelivery` | O envio da notificação por um canal externo (e-mail, WhatsApp, push), com status |
| Preferência | `NotificationPreference` | Canais escolhidos pela empresa (padrão) ou pela pessoa (ajuste) para um tipo |
| Inscrição de push | `PushSubscription` | Um navegador ou PWA autorizado a receber push |
| Modelo de WhatsApp | `WhatsappTemplate` | Texto aprovado pela Meta, com variáveis (D-406) |
| Comunicado | `Announcement` | Publicação do RH no mural (D-408) |
| Resumo diário | `NotificationDigest` | O e-mail diário com os avisos do RH ou do gestor (D-404) |

## 3. Histórias de usuário

1. Como **colaborador**, quero receber no WhatsApp que meu holerite saiu, com o link para abrir no portal.
2. Como **colaborador**, não quero receber aviso de trabalho às 22h nem no domingo.
3. Como **vigilante em escala 12x36 noturna**, quero receber os avisos durante o meu turno, e não no meu dia de folga.
4. Como **RH**, quero um único e-mail de manhã com tudo o que chegou para mim, e não 40 e-mails soltos.
5. Como **RH**, quero ser avisado na hora quando um evento do eSocial é rejeitado.
6. Como **colaborador**, quero desligar o WhatsApp dos avisos de comunicados, mas continuar recebendo os de holerite.
7. Como **colaborador**, quero ser lembrado quando esquecer de marcar a saída.
8. Como **RH**, quero avisar a empresa toda que amanhã não haverá expediente.
9. Como **RH**, quero saber quando o e-mail de um colaborador está errado, porque os avisos voltam.

## 4. Regras de negócio

### 4.1 Canais (D-400)

| Canal | Requisito | Conteúdo | Custo |
|---|---|---|---|
| Sistema (sino) | Nenhum. Sempre ativo | Título, texto curto e link | Nenhum |
| E-mail | E-mail cadastrado e válido | Título, texto e botão, com a marca | Baixo (SES) |
| WhatsApp | Celular, consentimento (RN-02-015 e RN-02-016) e modelo aprovado | Modelo com variáveis e link | Por mensagem (cota, D-407) |
| Push | Permissão concedida no navegador ou PWA | Título e texto curto, abrindo o link | Nenhum |

- **RN-15-001** — **Sino:** fica no topo do painel e do portal, com o contador de não lidas. A lista mostra as notificações dos últimos 90 dias. Abrir uma notificação marca como lida e leva à tela de origem. O contador é atualizado a cada 60 segundos com `fetch` em JavaScript puro, sem WebSocket **[P-15-01]**.
- **RN-15-002** — **E-mail:** sai pelo domínio da marca (RN-01-040), com logo e cores da marca, e um rodapé que explica por que a pessoa recebeu e leva às preferências **[P-15-02]**.
- **RN-15-003** — **Push:** Web Push com chaves VAPID, pelo service worker do PWA (spec 16). A permissão é pedida **depois do primeiro acesso**, com uma tela explicando para que serve, e não logo ao abrir. No iPhone, só funciona com o PWA instalado na tela inicial (iOS 16.4 ou superior), e a tela explica como instalar **[P-15-03]**. O convite fica no Início do portal, a partir da segunda visita, e no painel a ativação fica em "Minhas notificações" (D-654).
- **RN-15-004** — Uma pessoa pode ter várias inscrições de push (celular e computador). Todas recebem. Sair da conta remove a inscrição daquele navegador; a sessão que só expira mantém (D-654).
- **RN-15-005** — **Nenhum dado sensível sai do sistema** nos canais externos: nada de salário, valores, CID, números de documentos, motivo de desligamento ou conteúdo de advertências. O aviso diz **o que aconteceu** e leva ao sistema, que pede login. Exemplo: "Seu holerite de outubro está disponível", e não o valor líquido **[P-15-04]**.
- **RN-15-006** — Tudo em português do Brasil, com o nome comercial da marca de quem recebe (spec 01).
- **RN-15-007** — No impersonate, nenhum aviso sai (D-186).

### 4.2 Catálogo de avisos

- **RN-15-010** — O catálogo fica **no código**, e cada tipo tem: código, para quem vai, se é obrigatório, se é urgente e os canais padrão. A empresa só ajusta os canais (RN-15-020) **[P-15-05]**.
- **RN-15-011** — **Avisos de acesso** (convite, código ou link de recuperação, código de desbloqueio) não passam pelo catálogo nem pelas preferências: vão pelo canal que a pessoa ou o RH escolheu no momento (spec 02), na hora, sem horário de silêncio e sem consumir a cota de WhatsApp **[P-15-06]**.
- **RN-15-012** — **Catálogo inicial** **[P-15-07]**. Legenda: **S** sistema, **E** e-mail, **W** WhatsApp, **P** push; **Obr.** obrigatório; **Urg.** urgente.

  **Colaborador**

  | Código | Quando | Obr. | Canais padrão |
  |---|---|---|---|
  | `security.account_locked` | Conta bloqueada por tentativas (D-181). Na fase 1, só no sino: o e-mail de desbloqueio já é um aviso de acesso (D-607) | Sim | S E W |
  | `security.mfa_reset` | MFA redefinido por quem administra o perfil | Sim | S E |
  | `security.passkey_added` | Nova passkey cadastrada na conta, com o nome dela (D-647) | Sim | S E |
  | `security.contact_changed` | E-mail ou celular alterado pelo RH (aviso ao contato antigo e ao novo) | Sim | E W |
  | `payroll.payslip_published` | Holerite publicado (D-360) | Sim | S E W P |
  | `payroll.income_statement` | Informe de rendimentos disponível (D-361) | Sim | S E W P |
  | `documents.acknowledgment_pending` | Documento pedindo ciência (D-279), inclusive aviso de férias | Sim | S E W P |
  | `documents.requested` | Documento pedido pelo RH ou pelo processo (D-278) | Não | S W P |
  | `documents.correction_requested` | Correção pedida, com o motivo (RN-08-022) | Não | S W P |
  | `documents.expiring` | Documento vencendo (D-276) | Não | S W P |
  | `processes.task_assigned` | Item de integração ou de processo para a pessoa | Não | S P |
  | `requests.status_changed` | Solicitação mudou de status | Não | S P |
  | `timesheet.ready_for_acknowledgment` | Espelho do período para ciência (spec 11) | Sim | S E W P |
  | `schedule.changed` | Escala publicada ou alterada (RN-11-013) | Não | S W P |
  | `time.punch_reminder` | Lembrete de marcação (seção 4.6) | Não | P |
  | `time.receipt_email` | Comprovante da marcação por e-mail (D-314, opção da pessoa) | Não | E |
  | `announcements.published` | Comunicado novo no mural (D-408) | Não | S E W P |
  | `admission.started` | Admissão liberada, com as pendências de envio | Sim | S E W |
  | `processes.form_correction_requested` | Formulário devolvido pelo RH (D-649) | Não | S |
  | `memberships.read_only_ending` | Acesso do desligado termina em 30 dias (spec 16, RN-16-052) | Sim | S E W P |

  **Gestor**

  | Código | Quando | Obr. | Urg. | Canais padrão |
  |---|---|---|---|---|
  | `requests.approval_pending` | Aprovação esperando o gestor | Não | Não | S E P |
  | `requests.escalated` | Etapa escalada para ele (RN-09-011) | Não | Sim | S E P |
  | `processes.task_overdue` | Item atribuído a ele está atrasado (RN-06-028) | Não | Não | S E P |
  | `documents.team_expiring` | Documento da equipe vencendo, só o texto (P-08-11) | Não | Não | S E |
  | `employments.probation_ending` | Fim de experiência (RN-07-101) | Sim | Não | S E P |
  | `schedule.publish_deadline` | Escala ainda não publicada perto do prazo | Não | Não | S E P |

  **Gestor do cliente** (D-570) **[P-15-35]**

  | Código | Quando | Obr. | Urg. | Canais padrão |
  |---|---|---|---|---|
  | `processes.task_assigned` | Item de processo atribuído a ele | Não | Não | S E |
  | `processes.task_overdue` | Item atribuído a ele está atrasado (RN-06-028) | Não | Não | S E |

  **RH (RH administrador, RH analista e consultor, conforme o escopo)**

  | Código | Quando | Obr. | Urg. | Canais padrão |
  |---|---|---|---|---|
  | `documents.review_pending` | Documento aguardando revisão | Não | Não | S E |
  | `documents.hr_expiring` | Documento vencendo na unidade (RN-08-031, D-643) | Não | Não | S E |
  | `documents.batch_ready` | Lote pronto para confirmar | Não | Não | S E |
  | `documents.batch_expiring` | Lote perto de expirar (RN-08-062) | Não | Não | S E |
  | `requests.created` | Solicitação nova para o RH | Não | Não | S E |
  | `requests.escalated` | Etapa escalada para o RH | Não | Sim | S E P |
  | `processes.task_overdue` | Item atrasado (RN-06-028) | Não | Não | S E |
  | `processes.form_submitted` | Formulário para revisar (D-649) | Não | Não | S E |
  | `admission.esocial_deadline` | S-2200 perto do prazo (RN-07-052) | Sim | Sim | S E P |
  | `admission.aso_unfit` | ASO inapto (RN-07-061). O texto diz só que a admissão precisa de atenção, sem o resultado (D-651) | Sim | Sim | S E P |
  | `admission.activated_with_pending` | Vínculo ativado sem eSocial aceito ou com pendências (RN-07-085) | Sim | Sim | S E P |
  | `employments.probation_ending` | Fim de experiência | Sim | Não | S E |
  | `employments.revisions_effective` | Revisões entrando em vigor no dia (P-04-29): um aviso por dia para cada pessoa, com as revisões do escopo dela, sem a de admissão (D-608) | Não | Não | S E |
  | `vacations.concessive_period` | Período concessivo vencendo em 60 dias (P-09-09) | Sim | Não | S E |
  | `terminations.deadline` | Prazos de rescisão, eSocial e exame demissional | Sim | Sim | S E P |
  | `esocial.rejected` | Evento rejeitado (D-376) | Sim | Sim | S E P |
  | `esocial.deadline` | Prazo do eSocial chegando (P-13-09) | Sim | Sim | S E P |
  | `certificates.expiring` | Certificado A1 vencendo (P-13-07) | Sim | Sim nos 5 dias | S E |
  | `payroll.legal_table_changed` | Tabela legal alterada (RN-12-012) | Não | Não | S E |
  | `payroll.consigned_margin` | Desconto limitado pela margem consignável | Não | Não | S E |
  | `time.holidays_missing` | Cidade da unidade sem feriados municipais (RN-11-021) | Não | Não | S E |
  | `contacts.email_invalid` | E-mail de alguém voltou (D-409) | Não | Não | S E |
  | `lgpd.subject_request` | Pedido de titular (spec 05) | Sim | Não | S E |
  | `lgpd.deletion_upcoming` | Exclusão de dados em 30, 7 e 1 dia (RN-05-082) | Sim | Sim no último | S E |
  | `lgpd.incident` | Incidente de segurança (RN-05-092) | Sim | Sim | S E |
  | `ai.daily_cap_reached` | IA pausada pelo teto diário (RN-14-114) | Não | Não | S E |
  | `reports.export_ready` | Exportação grande pronta (spec 17) | Não | Não | S E |
  | `reports.scheduled_ready` | Relatório agendado pronto (spec 17) | Não | Não | S E |
  | `exports.company_ready` | Exportação completa pronta (spec 18) | Sim | Não | S E |
  | `imports.assisted_completed` | Importação assistida confirmada pelo suporte (spec 18) | Não | Não | S E |

  **Contabilidade:** `accounting.admission_forwarded` (admissão encaminhada) e `accounting.payroll_closed` (folha fechada, relatórios disponíveis), ambos não obrigatórios, em S E.

  **Administrador do parceiro e RH administrador da empresa direta (contrato):** `billing.usage_threshold` (80% e 100% de colaboradores, IA ou WhatsApp, D-092, D-101, D-407), `billing.overdue` (pagamento em atraso, nos dias 1, 5, 10 e 15, D-116, D-624), `brand.email_domain_status` (domínio verificado ou com falha, RN-01-040), todos obrigatórios, em S E.

  **Recrutamento (spec 21):** `recruiting.requisition_submitted`, `recruiting.requisition_decided`, `recruiting.interview_assigned`, `recruiting.scorecard_pending`, `recruiting.offer_answered` e `recruiting.internal_offer`. Nenhum obrigatório, em S E P. As mensagens a candidatos ficam fora do catálogo (RN-21-073).

  **Avaliação (spec 22):** `performance.probation_review_open`, `performance.cycle_phase_started`, `performance.review_pending`, `performance.peer_nomination_pending`, `performance.calibration_invite`, `performance.result_released` (obrigatório) e `feedback.received`. Em S E P.

  **Cobrança (spec 19):** para o responsável financeiro, `billing.invoice_issued`, `billing.price_change` (aviso de 30 dias da migração de preço, D-620), `billing.payment_failed`, `billing.trial_ending`, `billing.trial_expired`, `billing.cancel_scheduled`, `billing.contract_closing` e `billing.nfse_issued`; para o financeiro e o superadmin, `platform.nfse_error`; para o RH administrador das empresas da carteira, `billing.partner_read_only` e `billing.partner_cancelled`. Todos obrigatórios, em S E.

  **Equipe CatalystHR:** `platform.adjustment_pending` (ajuste acima de 20% aguardando o superadmin, D-621), `platform.ai_circuit_open` (disjuntor da IA, RN-14-123), `platform.ai_daily_cap` (RN-14-114), `platform.holidays_task` (RN-11-021), em S E.

- **RN-15-013** — Novas specs (16 a 22) acrescentam tipos ao catálogo seguindo o mesmo formato. O catálogo no código e as telas de preferências têm só os tipos que o sistema já gera; cada spec acrescenta os seus quando é construída (D-607).

### 4.3 Preferências (D-401)

- **RN-15-020** — O **RH administrador** define, para cada tipo, os **canais padrão** da empresa. A empresa começa com os canais do catálogo.
- **RN-15-021** — Cada pessoa, em "Minhas notificações", liga ou desliga os canais externos dos **avisos opcionais**.
- **RN-15-022** — Nos **avisos obrigatórios**, a pessoa escolhe os canais, mas precisa manter **pelo menos um canal externo** disponível (e-mail, WhatsApp ou push), além do sino. Se a empresa deixar um obrigatório só no sino, o sistema não aceita a configuração **[P-15-08]**.
- **RN-15-023** — Canal indisponível para a pessoa (sem e-mail, sem consentimento de WhatsApp, sem push autorizado) é ignorado sem erro. Se um obrigatório ficar sem canal externo disponível, ele aparece só no sino e a pessoa vê, na tela de preferências, o aviso "Cadastre um e-mail ou autorize o WhatsApp para receber avisos importantes" **[P-15-09]**.
- **RN-15-024** — Revogar o consentimento de WhatsApp (RN-02-015) desliga o canal em todos os tipos, imediatamente.

### 4.4 Horário de silêncio (D-402, D-403)

- **RN-15-030** — Vale para **WhatsApp e push**. O sino e o e-mail não têm horário de silêncio.
- **RN-15-031** — **Regra fixa:** das 20h às 8h, sábados, domingos e feriados da unidade da pessoa (calendário da spec 11), no fuso da unidade (RN-04-013). O aviso fica retido e sai às 8h do próximo dia útil **[P-15-10]**. A unidade é a do vínculo atual; sem vínculo, a matriz da empresa; sem empresa, vale o fuso de Brasília com os feriados nacionais (D-654).
- **RN-15-032** — **Pela jornada** (D-403), a partir da spec 11 (fase 3, D-654), para quem tem jornada fixa semanal, escala cíclica ou escala do gestor (RN-11-010, 011, 013): o silêncio é **fora do turno**, com uma margem de **30 minutos** antes da entrada e depois da saída, e nos dias de folga, DSR, férias e afastamento. O aviso retido sai no início do próximo turno, menos a margem. A jornada flexível por carga (RN-11-012) usa a regra fixa **[P-15-11]**.
- **RN-15-033** — Saem **na hora**, mesmo no silêncio:
  - avisos de acesso (RN-15-011);
  - avisos de segurança (`security.*`) **[P-15-12]**.

  Os urgentes do RH também esperam o silêncio no WhatsApp e no push. Eles chegam na hora pelo sino e pelo e-mail.
- **RN-15-034** — Avisos retidos do mesmo tipo são **agrupados** na liberação: "Você tem 3 documentos pedidos", e não três mensagens **[P-15-13]**.
- **RN-15-035** — Se a pessoa já abriu a notificação no sistema antes da liberação, o WhatsApp e o push retidos são **cancelados** **[P-15-14]**.

### 4.5 Resumo diário por e-mail (D-404)

- **RN-15-040** — Para quem tem perfil de **RH, consultor, gestor ou contabilidade**, os avisos **de trabalho não urgentes** que iriam por e-mail entram num **resumo diário**, e não num e-mail por aviso. Ficam de fora os avisos `security.*` e `billing.*` e os que a pessoa recebe como colaboradora, que saem um a um. É um resumo por vínculo de acesso e marca (D-655). Até o resumo ser ligado, esses avisos vão por e-mail um a um (D-607).
- **RN-15-041** — O resumo sai às **7h30**, no fuso da unidade da pessoa (RN-15-031), de segunda a sexta. Ele traz os avisos das últimas 24 horas (ou desde sexta, na segunda) que **ainda não foram lidos** no sistema, agrupados por assunto, com links. Sem nada pendente, não sai e-mail **[P-15-15]**.
- **RN-15-042** — Os **urgentes** saem por e-mail na hora.
- **RN-15-043** — O resumo diário é uma lista dos avisos, gerada sem IA. Ele não substitui o resumo operacional, que fica só na tela inicial (D-386).
- **RN-15-044** — Colaboradores recebem os e-mails um a um, porque são poucos **[P-15-16]**.

### 4.6 Lembrete de marcação (D-405)

- **RN-15-050** — Configuração da empresa, que pode ser diferente por unidade **[P-15-17]**:
  - ligado ou desligado (padrão: **desligado**);
  - tolerância em minutos depois do horário previsto (padrão: **15**);
  - marcações lembradas: entrada, saída e intervalo (padrão: entrada e saída);
  - canais: push e, opcionalmente, WhatsApp, que consome a cota.
- **RN-15-051** — Só vale para jornadas com horário previsto (fixa semanal, escala cíclica e escala do gestor). Não há lembrete em folga, DSR, feriado, férias ou afastamento, nem para quem já marcou.
- **RN-15-052** — No máximo **um lembrete por marcação prevista**. O texto diz "Você ainda não marcou a saída de hoje (previsto 18h)" e abre a tela de marcação.
- **RN-15-053** — O lembrete **nunca marca o ponto** nem altera a apuração. Ele não segue o horário de silêncio, porque acontece dentro do turno.

### 4.7 WhatsApp (D-012, D-041, D-161, D-406, D-407)

- **RN-15-060** — Só avisos, sempre com o link para o sistema (D-012). Os modelos são da categoria **utilidade** da Meta, e os códigos de acesso usam a categoria **autenticação** **[P-15-18]**.
- **RN-15-061** — A equipe CatalystHR mantém os modelos na área admin: código, texto, variáveis e status de aprovação em cada número (da plataforma e de cada parceiro com número próprio). Um tipo de aviso sem modelo aprovado naquele número **não usa o WhatsApp** e cai para os outros canais.
- **RN-15-062** — Remetente: o número da plataforma por padrão, com o nome da marca no texto. Com número próprio (adicional do plano, D-161), as mensagens saem do número do parceiro. A empresa cliente em modo `replace` continua usando o número do parceiro (RN-01-034).
- **RN-15-063** — **Mensagens recebidas:** o número não atende conversas. Qualquer mensagem recebida ganha uma resposta automática com o canal de suporte da marca e o link do portal. A palavra **SAIR** revoga o consentimento de WhatsApp da pessoa em todas as empresas daquele número, com registro (RN-02-015) **[P-15-19]**.
- **RN-15-064** — **Cota (D-407):** conta cada mensagem enviada. A cota pertence ao contrato (parceiro ou empresa direta) e é dividida entre as empresas da carteira, como a de IA (P-14-25). As mensagens de acesso (RN-15-011) não consomem a cota **[P-15-20]**.
- **RN-15-065** — A Twilio confirma entrega e leitura por callback. A leitura no WhatsApp **não** marca a notificação como lida no sistema **[P-15-21]**.

### 4.8 Mural de comunicados (D-408)

- **RN-15-070** — Quem publica: o **RH administrador**, para a empresa toda, e o **RH analista**, para as unidades dele **[P-15-22]**.
- **RN-15-071** — O comunicado tem:
  - título e texto, com o botão "Escrever com IA" (D-391);
  - anexo opcional (PDF ou imagem, até 10 MB), que passa pela varredura de vírus antes de o comunicado ir ao ar (D-656);
  - público: todos, ou um filtro por unidade, departamento, cargo e tipo de vínculo. O filtro é aplicado na hora da leitura: quem entra depois vê o comunicado enquanto ele valer, e o aviso vai para quem estava no público na publicação (D-656);
  - publicação imediata ou agendada;
  - validade, obrigatória, sugerida em 30 dias, depois da qual sai do mural (D-656);
  - opção de **fixar no topo**.
- **RN-15-072** — O mural fica no portal do colaborador e no painel do RH. O RH vê quantas pessoas do público abriram o comunicado, contra o público de hoje com acesso ao portal (D-656). Publicado, o comunicado só muda a validade e o fixar no topo; para corrigir o texto, é retirado e publicado de novo (D-656).
- **RN-15-073** — O comunicado não tem valor de ciência. Para registrar ciência, o RH publica um documento com ciência (D-279). A tela de publicação lembra disso **[P-15-23]**.
- **RN-15-074** — O aviso usa o tipo `announcements.published`: sino, push e e-mail com o título e o texto (sem anexo, só o link). No WhatsApp, vai o modelo padrão "Você tem um novo comunicado de {{marca}}" com o link. Comunicados seguem o horário de silêncio como qualquer aviso.

### 4.9 Entrega, falhas e canal de reserva (D-409)

- **RN-15-080** — Cada entrega tem status próprio (seção 5). Os provedores informam o resultado:
  - SES: entrega, devolução (bounce) e reclamação (complaint), pelo SNS **[P-15-24]**;
  - Twilio: enviada, entregue, lida e falhou, por callback;
  - Web Push: resposta 404 ou 410 apaga a inscrição.
- **RN-15-081** — **Obrigatórios:** se a entrega falha, o sistema tenta o **próximo canal disponível**, na ordem **WhatsApp → e-mail → push**, pulando os já usados. O sino sempre tem o aviso **[P-15-25]**. Disponível é o canal que a pessoa consegue receber, mesmo fora das preferências ou do catálogo do tipo, e o push da reserva respeita o silêncio (D-654).
- **RN-15-082** — **Opcionais:** sem reserva. O aviso fica no sino.
- **RN-15-083** — **E-mail que volta** (bounce permanente): o endereço é marcado como **inválido**, deixa de receber e-mails, aparece em destaque no cadastro e gera `contacts.email_invalid` ao RH do escopo. A marca sai quando o e-mail é alterado. **Reclamação de spam** suspende os e-mails opcionais daquele endereço **[P-15-26]**. O e-mail inválido não recebe nenhum e-mail do sistema, nem convite nem recuperação de senha, e a tela que tentaria enviar avisa na hora. O mesmo endereço volta a receber quando o suporte o libera pelo admin, o que também o tira da lista de supressão do SES (D-609).
- **RN-15-084** — Falhas temporárias do provedor têm até 3 novas tentativas, com 1, 5 e 15 minutos de intervalo, antes de contar como falha (como RN-14-120) **[P-15-27]**.
- **RN-15-085** — **Duplicidade:** o mesmo tipo, para a mesma pessoa e o mesmo objeto de origem, não gera outra notificação em menos de 12 horas. Por exemplo, um alerta diário de prazo do eSocial gera uma notificação por dia, e não uma por execução do job **[P-15-28]**.

### 4.10 Retenção

- **RN-15-090** — Notificações ficam no sino por **90 dias** e são apagadas com **1 ano**, junto com as entregas (D-608). Os registros de entrega ficam **1 ano**, sem o texto da mensagem, só o tipo, o canal, o destino mascarado e os status **[P-15-29]**.
- **RN-15-091** — Os comunicados ficam no histórico do mural por **2 anos** depois da validade **[P-15-30]**.

## 5. Estados

**Notificação:** `unread` → `read` · `archived` (depois de 90 dias)

**Entrega:** `queued` → (`held`, no silêncio)? → `sending` → `sent` → `delivered` → (`read`, no WhatsApp)? | `failed` → (`fallback`, se obrigatório) · `cancelled` (lida no sistema antes de sair, RN-15-035)

**Modelo de WhatsApp (por número):** `draft` → `pending_approval` → `approved` | `rejected` · `paused` (pausado pela Meta)

**Comunicado:** `draft` → `scheduled` → `published` → `expired` · `withdrawn`

**E-mail do usuário:** `valid` → `bounced` | `complained` → `valid` (ao alterar)

## 6. Permissões

| Ação | Quem |
|---|---|
| Ver as próprias notificações e ajustar as próprias preferências | Todos |
| Canais padrão da empresa por tipo | RH administrador |
| Lembrete de marcação | RH administrador |
| Publicar comunicado | RH administrador (empresa toda), RH analista (unidades dele) **[P-15-22]** |
| Editar e retirar comunicado | Quem publicou, RH administrador (D-656) |
| Ver quantos abriram o comunicado | Quem publicou, RH administrador |
| Modelos de WhatsApp, números e catálogo | Superadmin, suporte |
| Consumo de WhatsApp | Como a linha "Consumo" da spec 03 |

## 7. Modelo de dados

```
company_notification_settings                        -- canais padrão da empresa por tipo
  company_id, notification_type, channels (text[])

notification_preferences                             -- ajuste da pessoa
  id, membership_id, notification_type, channels (text[])

notifications
  id, company_id (nullable: parceiro, escritório ou plataforma), recipient_user_id,
  recipient_membership_id, notification_type, title, body, url,
  subject_type, subject_id, mandatory, urgent, dedup_key, read_at, created_at

notification_deliveries
  id, notification_id, channel ('email'|'whatsapp'|'push'), status, held_until,
  attempts, sent_at, delivered_at, read_at, failed_reason, provider_message_id,
  destination_masked, fallback_from_id, digest_id

notification_digests
  id, recipient_membership_id, brand_id, sent_at, provider_message_id, notification_ids (uuid[])

push_subscriptions
  id, user_id, brand_id, endpoint, p256dh, auth, user_agent, last_success_at

whatsapp_senders
  id, owner_type, owner_id,                           -- plataforma (null) ou Partner
  phone, twilio_sender_sid, status

whatsapp_templates
  id, code, category ('utility'|'authentication'), body, variables (text[])

whatsapp_template_approvals
  id, whatsapp_template_id, whatsapp_sender_id, twilio_content_sid, status

messaging_usage_entries                               -- base da cota de WhatsApp (D-407)
  id, billing_account_type, billing_account_id, company_id,
  notification_delivery_id, period ('YYYY-MM'), messages

punch_reminder_settings
  id, company_id, unit_id (nullable = empresa toda), enabled, tolerance_minutes,
  marks (text[]), channels (text[])

announcements
  id, company_id, author_id, title, body, attachment (Active Storage),
  audience (jsonb), publish_at, expires_at, pinned, status,
  published_at, withdrawn_at, withdrawn_by_id

announcement_reads
  id, company_id, announcement_id, membership_id, read_at

users (acréscimo)
  email_status ('valid'|'bounced'|'complained'), email_status_at
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Notifications::DispatchJob` | Ao criar uma notificação | Aplica preferências, silêncio e resumo, e cria as entregas |
| `Notifications::DeliverEmailJob` | Por entrega | Envia pelo Action Mailer com o SES |
| `Notifications::DeliverWhatsappJob` | Por entrega | Envia o modelo pela Twilio e lança o consumo |
| `Notifications::DeliverPushJob` | Por entrega | Envia o Web Push |
| `Notifications::ReleaseHeldJob` | A cada 5 minutos | Libera as entregas retidas cujo silêncio acabou, agrupando por tipo |
| `Notifications::DigestJob` | A cada 30 minutos, das 6h às 12h30 de Brasília, de segunda a sexta | Monta e envia os resumos diários das 7h30 de cada fuso (D-655) |
| `Notifications::PunchRemindersJob` | A cada 5 minutos | Procura marcações previstas sem registro além da tolerância |
| `Notifications::FallbackJob` | Ao falhar uma entrega obrigatória | Cria a entrega no próximo canal |
| `Notifications::UsageAlertsJob` | A cada hora | Avisos de 80% e 100% da cota de WhatsApp |
| `Announcements::PublishScheduledJob` | A cada 5 minutos | Publica os comunicados agendados com o anexo limpo e encerra os vencidos (D-656) |
| `Announcements::NotifyJob` | Ao publicar um comunicado | Avisa o público daquele momento (D-656) |
| `Notifications::PurgeJob` | Diário | Arquiva notificações de 90 dias, apaga entregas de 1 ano e comunicados 2 anos depois da validade ou da retirada (RN-15-091) |

- **Fila:** os envios ficam na fila `notifications` do Sidekiq. O ponto continua prioritário (P-10-26) **[P-15-31]**.
- **E-mail:** Action Mailer com o SES pela gem `aws-sdk-rails`, com um *configuration set* que publica os eventos de entrega, devolução e reclamação no SNS, recebidos num endpoint com a assinatura conferida **[P-15-24]**.
- **WhatsApp:** gem oficial `twilio-ruby`, com os modelos pelo Content API da Twilio. Os callbacks de status e as mensagens recebidas chegam num endpoint que confere a assinatura da Twilio **[P-15-32]**.
- **Push:** gem `web-push`, com as chaves VAPID nas variáveis de ambiente **[P-15-33]**.
- **Desenvolvimento:** e-mails no letter_opener (D-026); WhatsApp e push gravados em log, sem envio real **[P-15-34]**.

## 9. Critérios de aceite

- **CA-15-001** — Dado um holerite publicado às 21h para um colaborador de jornada comercial, quando o aviso é criado, então aparece na hora no sino e no e-mail, e o WhatsApp e o push saem às 8h do próximo dia útil.
- **CA-15-002** — Dado um vigilante em 12x36 com turno das 19h às 7h, quando um documento é pedido às 22h de um dia de turno, então o WhatsApp sai na hora.
- **CA-15-003** — Dado o mesmo vigilante em dia de folga, quando um documento é pedido, então o WhatsApp fica retido até 18h30 do próximo turno.
- **CA-15-004** — Dado um colaborador que abriu o aviso no sistema às 7h, quando chega a liberação das 8h, então o WhatsApp retido é cancelado.
- **CA-15-005** — Dado um RH com 12 documentos para revisar ao longo do dia, quando chega 7h30 do dia seguinte, então ele recebe um único e-mail com os itens ainda não lidos.
- **CA-15-006** — Dado um evento do eSocial rejeitado às 15h, quando o retorno chega, então o RH recebe na hora o e-mail e a notificação no sino.
- **CA-15-007** — Dado um colaborador que tenta deixar o holerite só no sino, quando salva as preferências, então o sistema exige pelo menos um canal externo.
- **CA-15-008** — Dado um aviso obrigatório cujo WhatsApp falhou, quando a Twilio informa a falha, então o sistema envia por e-mail.
- **CA-15-009** — Dado um e-mail que volta com bounce permanente, quando o SES informa, então o endereço fica inválido e o RH da unidade recebe o aviso.
- **CA-15-010** — Dada uma jornada com saída às 18h e lembrete de 15 minutos ligado, quando são 18h15 sem marcação, então o colaborador recebe um único push, e nada muda no ponto.
- **CA-15-011** — Dado um comunicado para a unidade Centro, quando é publicado, então só as pessoas dessa unidade o veem no mural e recebem o aviso.
- **CA-15-012** — Dada uma resposta "SAIR" no WhatsApp, quando a mensagem chega, então o consentimento é revogado, registrado, e nenhum aviso sai mais por WhatsApp para essa pessoa.
- **CA-15-013** — Dado qualquer aviso de holerite, quando sai por e-mail, WhatsApp ou push, então o texto não traz valores.
- **CA-15-014** — Dado um tipo sem modelo aprovado no número do parceiro, quando o aviso é criado, então o WhatsApp é ignorado, e os outros canais funcionam.

## 10. Propostas aprovadas (D-410)

| # | Proposta |
|---|---|
| P-15-01 | Sino com 90 dias de lista e atualização a cada 60 segundos, sem WebSocket |
| P-15-02 | E-mail com a marca e rodapé com link para as preferências |
| P-15-03 | Permissão de push pedida depois do primeiro acesso, com explicação e orientação para iPhone |
| P-15-04 | Nenhum dado sensível nos canais externos |
| P-15-05 | Catálogo no código; a empresa só ajusta os canais |
| P-15-06 | Avisos de acesso fora do catálogo, sem silêncio e sem cota |
| P-15-07 | Catálogo inicial de avisos, com obrigatórios, urgentes e canais padrão |
| P-15-08 | Obrigatórios exigem pelo menos um canal externo, além do sino |
| P-15-09 | Aviso na tela de preferências quando falta canal para os obrigatórios |
| P-15-10 | Silêncio fixo inclui feriados da unidade, no fuso da unidade |
| P-15-11 | Silêncio pela jornada com margem de 30 minutos; jornada flexível usa a regra fixa |
| P-15-12 | Só acesso e segurança furam o silêncio |
| P-15-13 | Avisos retidos do mesmo tipo são agrupados |
| P-15-14 | Retido é cancelado se a pessoa já leu no sistema |
| P-15-15 | Resumo às 7h30 em dias úteis, só com o que não foi lido |
| P-15-16 | Colaboradores recebem e-mails um a um |
| P-15-17 | Configuração do lembrete de marcação, por empresa ou unidade, desligado por padrão |
| P-15-18 | Modelos de utilidade e de autenticação da Meta |
| P-15-19 | Resposta automática e "SAIR" revoga o consentimento |
| P-15-20 | Cota de WhatsApp do contrato, sem contar as mensagens de acesso |
| P-15-21 | Leitura no WhatsApp não marca como lida no sistema |
| P-15-22 | RH administrador publica para todos; RH analista para as unidades dele |
| P-15-23 | Comunicado não tem valor de ciência |
| P-15-24 | Eventos do SES pelo SNS, com assinatura conferida |
| P-15-25 | Ordem de reserva WhatsApp → e-mail → push |
| P-15-26 | Bounce marca o e-mail como inválido; reclamação suspende os opcionais |
| P-15-27 | Três novas tentativas em falhas temporárias |
| P-15-28 | Sem duplicidade em 12 horas |
| P-15-29 | Sino por 90 dias; entregas por 1 ano sem o texto |
| P-15-30 | Comunicados no histórico por 2 anos |
| P-15-31 | Fila `notifications` |
| P-15-32 | `twilio-ruby` com Content API e assinatura conferida |
| P-15-33 | Gem `web-push` com VAPID |
| P-15-34 | WhatsApp e push só em log no desenvolvimento |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-15-35 | Avisos do gestor do cliente: item atribuído e item atrasado, pelo sino e por e-mail |
