# 19 — Administração e cobrança

> Status: aprovado (habilitação de pagamentos automáticos no Mercado Pago a confirmar); NFS-e pelo Asaas com configuração fiscal a definir com o contador · Última atualização: 2026-10-13
> Decisões: D-092, D-101, D-111 a D-116, D-120 a D-127, D-161, D-222, D-312, D-384, D-407, D-447, D-480 a D-498, D-560 a D-566, D-610 a D-613, D-616, D-618 a D-625 ([decisoes.md](decisoes.md))
> Os itens **[P-19-01]** a **[P-19-29]** foram aprovados (D-498). O modelo de cobrança foi ajustado pelo usuário: gestão da plataforma, cobrança executada pelo Mercado Pago (D-496, D-497). Os itens **[P-19-30]** a **[P-19-38]**, da NFS-e pelo Asaas, foram aprovados sem ajuste (D-566).

## 1. Objetivo

Definir **como o CatalystHR é vendido, cobrado e administrado**:

- contratos de parceiros e empresas diretas;
- planos, módulos e adicionais;
- cotas, consumo e excedente;
- teste grátis;
- cobrança mensal pelo Mercado Pago;
- nota fiscal de serviço (NFS-e) emitida pelo Asaas (D-560);
- inadimplência;
- cancelamento;
- área admin e painel da equipe CatalystHR (D-447, D-490).

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Contrato | `BillingAccount` | Quem paga: um parceiro (com a carteira toda) ou uma empresa direta |
| Plano | `Plan` | Pacote com preço, limites e cotas. Do tipo parceiro ou empresa direta |
| Módulo | `PlanModule` | Ponto ou folha (com eSocial), com preço próprio no plano (D-111, D-122) |
| Adicional | `AddOn` | Itens extras, como o número próprio de WhatsApp (D-161) |
| Assinatura | `Subscription` | O plano, os módulos e os adicionais ativos de um contrato, com o status |
| Consumo do mês | `UsagePeriod` | Pico de colaboradores, créditos de IA e mensagens de WhatsApp do mês, por contrato e por empresa |
| Fatura | `Invoice` | A cobrança mensal, com as linhas |
| Ajuste | `BillingAdjustment` | Desconto, crédito ou isenção lançado à mão (D-491) |
| Pagamento | `Payment` | Tentativa de pagamento no Mercado Pago |
| Nota fiscal | `ServiceInvoice` | A NFS-e de uma fatura paga, emitida pelo Asaas (D-560) |

## 3. Histórias de usuário

1. Como **financeiro CatalystHR**, quero cadastrar um plano de parceiro "Até 500 colaboradores" com cotas de IA e WhatsApp e o preço do excedente.
2. Como **comercial CatalystHR**, quero criar uma empresa direta em teste de 14 dias e convidar o RH administrador.
3. Como **administrador do parceiro**, quero ver quanto da faixa e das cotas a carteira já usou neste mês.
4. Como **administrador do parceiro**, quero baixar o consumo de cada empresa para cobrar meus clientes.
5. Como **RH administrador de empresa direta**, quero pagar por PIX e ver as faturas e notas fiscais.
6. Como **administrador do parceiro**, quero contratar o módulo de ponto hoje e começar a usar em uma empresa da carteira.
7. Como **financeiro CatalystHR**, quero conceder um crédito a um parceiro por uma falha nossa, com o motivo registrado.
8. Como **superadmin**, quero ver a margem de IA e WhatsApp de cada cliente.
9. Como **financeiro CatalystHR**, quero que a nota fiscal saia sozinha quando o cliente paga, sem emitir uma a uma no site da prefeitura.

## 4. Regras de negócio

### 4.1 Contratos

- **RN-19-001** — Cada **parceiro** é um contrato, que cobre todas as empresas da carteira. Cada **empresa direta** é um contrato. A empresa de parceiro não tem contrato próprio.
- **RN-19-002** — Status da assinatura:

  ```
  trialing → active ⇄ past_due → read_only → closing → closed
  trialing → trial_expired → (active | closed)
  active → cancel_scheduled → closing
  ```

- **RN-19-003** — **Transferência** de empresa (D-123): o consumo do mês é dividido pelos dias. O pico de colaboradores da empresa conta no contrato de origem até a data da transferência, e no de destino a partir dela **[P-19-01]**.

### 4.2 Planos, módulos e adicionais (D-115, D-480, D-122)

- **RN-19-010** — Cadastrados pelo superadmin e pelo financeiro. Campos do plano **[P-19-02]**:

  | Campo | Parceiro (D-480) | Empresa direta (D-122) |
  |---|---|---|
  | Mensalidade | Fixa, pela faixa | Valor por colaborador ativo, com mínimo mensal |
  | Limite de colaboradores | Faixa (ex.: até 500) | Não tem |
  | Excedente por colaborador | Preço acima da faixa | Não se aplica |
  | Créditos de IA no mês | Cota | Cota por colaborador (ex.: 3 créditos × colaboradores ativos) |
  | Mensagens de WhatsApp no mês | Cota | Cota por colaborador |
  | Preço do crédito de IA e da mensagem excedentes | Sim | Sim |
  | Módulos ponto e folha | Valor fixo somado à mensalidade | Valor por colaborador somado |

- **RN-19-011** — O núcleo está sempre incluído: cadastros, admissão, documentos, solicitações, processos, IA, portal, mural, painéis e relatórios. Ponto e folha (com eSocial) são módulos (D-111, D-122).
- **RN-19-012** — O parceiro com o módulo contratado liga e desliga o módulo **por empresa da carteira**. O preço do módulo não muda com o número de empresas que usam **[P-19-03]**.
- **RN-19-013** — **Adicionais:** número próprio de WhatsApp (D-161) e, quando existir, reconhecimento facial (D-312). Cada um tem preço mensal fixo.
- **RN-19-014** — **Versões de preço:** mudar o preço de um plano vale para contratos novos. Os contratos existentes continuam com o preço antigo até o financeiro migrá-los, com aviso de **30 dias** ao cliente **[P-19-04]**. Os preços ficam em versões do plano, que nunca são alteradas; o preço dos adicionais segue a mesma regra (D-611).
- **RN-19-015** — Planos podem ser **privados**, criados para um cliente específico, com condições negociadas **[P-19-05]**.

### 4.3 Consumo, cotas e excedente (D-092, D-101, D-407, D-483)

- **RN-19-020** — **Colaborador ativo** (D-483): o pico diário de vínculos ativos ou afastados no mês. Desligados em período de leitura não contam. O parceiro soma todas as empresas da carteira. Empresas em `closing` não contam (RN-05-084).
- **RN-19-021** — **Créditos de IA** (spec 14) e **mensagens de WhatsApp** (spec 15) somam no mês, por contrato. A cota **não acumula** para o mês seguinte **[P-19-06]**.
- **RN-19-022** — Avisos com 80% e 100% de cada limite, sem bloqueio (D-092). O excedente vai para a fatura seguinte.
- **RN-19-023** — Um job grava, todo dia, o pico de colaboradores de cada empresa e de cada contrato. No dia 1, fecha o mês anterior (`UsagePeriod`) **[P-19-07]**.
- **RN-19-024** — **Relatório de consumo do parceiro** (D-482): CSV com uma linha por empresa (CNPJ, nome, pico de colaboradores, módulos ligados, créditos de IA, mensagens de WhatsApp). O mês fechado fica disponível no dia 1, e o mês corrente pode ser baixado parcial a qualquer momento **[P-19-08]**.

### 4.4 Teste grátis (D-485 a D-487)

- **RN-19-030** — Criado pela equipe comercial (D-484): 14 dias, sem cartão, para parceiros e empresas diretas. As empresas cadastradas pelo parceiro em teste também ficam em teste.
- **RN-19-031** — No teste, os módulos **ponto e eSocial não funcionam** (D-486). A folha pode ser configurada e calculada, mas não fecha competência. As cotas de IA e WhatsApp do teste são reduzidas: **100 créditos** e **100 mensagens** **[P-19-09]**.
- **RN-19-032** — Avisos ao responsável 3 dias e 1 dia antes do fim, com o botão **Contratar**.
- **RN-19-033** — Contratar durante o teste: escolhe o plano e os módulos, cadastra o pagamento, e a primeira mensalidade é cobrada na hora. O ciclo começa nesse dia **[P-19-10]**. O parceiro sem colaborador ativo na carteira paga a mensalidade de pré-ativação (RN-19-035).
- **RN-19-034** — Fim do teste sem contratação (D-487): `trial_expired`, em somente leitura por 30 dias, com a exportação completa (spec 18). Contratando, tudo volta. Depois, exclusão total, como no encerramento. Na fase 1, só os status e a somente leitura; a exportação e a exclusão entram na fase 2 (D-610).
- **RN-19-035** — **Pré-ativação do parceiro** (D-612): enquanto a carteira não tem nenhum colaborador ativo (a mesma medida da RN-19-020), o parceiro contratado paga só um **valor simbólico**, único para todos os planos de parceiro e com versões como os preços (D-611), mais os adicionais. A faixa e os módulos não são cobrados, e as cotas de IA e WhatsApp são as do teste (RN-19-031), com o excedente pelos preços do plano. No primeiro dia com um colaborador ativo, a faixa e os módulos passam a valer, e a diferença proporcional aos dias até o fim do ciclo entra na próxima fatura (RN-19-060). A ativação é única: a cobrança não volta ao valor simbólico. Não vale para a empresa direta.

### 4.5 Fatura e pagamento (D-112, D-113, D-481, D-488)

- **RN-19-040** — **Ciclo mensal**, no dia do mês em que o contrato começou (dias 29 a 31 viram dia 28) **[P-19-11]**. A fatura do ciclo tem:
  - a mensalidade do plano e dos módulos do mês que começa (ou o valor de pré-ativação do parceiro, RN-19-035);
  - os adicionais;
  - o excedente do ciclo anterior (colaboradores, IA, WhatsApp);
  - as cobranças proporcionais de aumentos feitos no ciclo anterior (RN-19-060);
  - os ajustes manuais (RN-19-070).
- **RN-19-041** — A fatura é gerada **3 dias antes** do vencimento, com o detalhamento de cada linha, e avisada ao responsável (`billing.invoice_issued`) **[P-19-12]**.
- **RN-19-042** — **Gestão e cobrança** (D-496): a assinatura, o ciclo, as faturas, a régua e o status ficam **na plataforma**. O Mercado Pago **executa** cada cobrança:
  - **cartão de crédito:** o cliente informa o cartão ao contratar, e a primeira cobrança é feita com o cartão presente (com o CVV). O cartão fica salvo no Mercado Pago, e as faturas seguintes são cobradas no vencimento, no valor da fatura, como **pagamento automático** sem pedir o CVV de novo;
  - **PIX:** a fatura traz o QR code e o código copia e cola, gerados pela API de Orders do Mercado Pago, com vencimento no fim do dia do vencimento da fatura. Vencido, um PIX novo é gerado quando o cliente abre a fatura, válido até o fim daquele dia (D-622).

  As assinaturas do próprio Mercado Pago (preapproval) não são usadas.
- **RN-19-043** — Cartão recusado (D-497): a plataforma pede uma nova cobrança ao Mercado Pago **1, 3 e 5 dias** depois. A cada recusa, o cliente recebe `billing.payment_failed`, com o link para pagar por PIX ou trocar o cartão. Se nada der certo, segue a régua de inadimplência (RN-19-050) **[P-19-13]**.
- **RN-19-044** — **Responsável financeiro:** o administrador do parceiro ou o RH administrador da empresa direta, que pode cadastrar um e-mail de cobrança adicional **[P-19-14]**.
- **RN-19-045** — **NFS-e:** emitida pela plataforma, pelo Asaas, quando o pagamento é confirmado (seção 4.11). Revisa a D-114 e a P-19-15, que previam a emissão fora da plataforma e o registro manual.
- **RN-19-046** — A confirmação do pagamento vem pelo **webhook** do Mercado Pago, com a assinatura conferida. Um job diário confere as faturas em aberto direto na API, para o caso de um webhook se perder **[P-19-16]**.

### 4.6 Inadimplência (D-116, D-493 a D-495)

- **RN-19-050** — Régua, contada do vencimento **[P-19-17]**:

  | Dia | O que acontece |
  |---|---|
  | +1 | Aviso de fatura vencida ao responsável (`billing.overdue`) |
  | +5 | Novo aviso |
  | +10 | Aviso de que a conta entra em somente leitura em 5 dias |
  | +15 | `read_only` (D-116) |
  | +25 | Aviso de que o contrato será encerrado em 5 dias |
  | +30 | `closing` (D-493): começa o encerramento da spec 05 |

- **RN-19-051** — Em `read_only`, para o contrato e todas as suas empresas:
  - o **ponto** continua funcionando (D-116);
  - o RH transmite ao eSocial os **eventos já gerados** e consulta os retornos (D-494);
  - nada novo é criado ou alterado;
  - o portal do colaborador continua em leitura;
  - no painel, toda escrita é recusada com mensagem e uma faixa no topo, também em `closing` e no teste vencido; a conta da própria pessoa, o pagamento e a contratação continuam liberados (D-613, D-624).
- **RN-19-052** — Empresas de parceiro em `read_only`: o RH administrador vê a faixa **"Acesso limitado por pendência com [parceiro]"**, sem valores (D-495).
- **RN-19-053** — O pagamento confirmado volta a conta para `active` na hora, em qualquer etapa antes de `closing`. Em `closing`, só o superadmin pode reativar, nos 90 dias, com motivo e sem fatura vencida (D-624) **[P-19-18]**.

### 4.7 Troca de plano e cancelamento (D-489, D-492)

- **RN-19-060** — **Aumento** de plano, contratação de módulo ou de adicional: vale na hora. A diferença proporcional aos dias até o fim do ciclo entra na próxima fatura (RN-19-040) **[P-19-19]**.
- **RN-19-061** — **Redução** ou retirada de módulo ou adicional: vale no início do próximo ciclo. Retirar o módulo de ponto ou folha avisa que os dados continuam guardados e em leitura, e que o AFD e os XMLs do eSocial ficam na exportação **[P-19-20]**.
- **RN-19-062** — **Cancelamento** pelo cliente (D-489): pedido pelo responsável financeiro, com confirmação de senha ou passkey e um motivo (lista simples, mais texto). Vale no fim do ciclo pago, sem multa. Até lá, pode ser desfeito, pelo cliente ou pela equipe. Depois, começa o encerramento (D-222). A fatura do próximo ciclo já emitida e não paga é cancelada (D-625) **[P-19-21]**.
- **RN-19-063** — Parceiro que cancela: todas as empresas da carteira entram no encerramento junto. Antes disso, o superadmin pode **transferir** empresas para outro parceiro ou para contratação direta (D-123), com a autorização de cada uma. O aviso de cancelamento ao RH administrador de cada empresa da carteira sai **30 dias antes** do fim do ciclo, ou no pedido, se faltar menos **[P-19-22]**.

### 4.8 Ajustes manuais (D-491)

- **RN-19-070** — O financeiro e o superadmin lançam, para a próxima fatura: desconto (valor ou percentual, num ciclo ou em vários), crédito ou isenção de excedente. O motivo é obrigatório, e tudo fica na auditoria.
- **RN-19-071** — Ajustes acima de **20%** da fatura, lançados pelo financeiro, precisam da aprovação do superadmin **[P-19-23]**.

### 4.9 Área admin

- **RN-19-080** — Em `admin.catalysthr.com.br`, a equipe CatalystHR tem **[P-19-24]**:

  | Seção | Conteúdo | Spec |
  |---|---|---|
  | Painel | Seção 4.10 | 19 |
  | Clientes | Parceiros e empresas diretas: cadastro, plano, teste, status, transferência, impersonate | 01, 02, 19 |
  | Planos e preços | Planos, módulos, adicionais, versões de preço | 19 |
  | Cobrança | Faturas, pagamentos, ajustes, NFS-e, inadimplência | 19 |
  | Conteúdo | Biblioteca de modelos (D-126), base de conhecimento (D-106), tipos de documento da plataforma, rubricas e tabelas legais, feriados | 06, 08, 11, 12, 14 |
  | Comunicação | Modelos de WhatsApp e números | 15 |
  | IA | Pesos de créditos, tetos por empresa, liberação de pausas | 14 |
  | Implantação | Importação assistida | 18 |
  | Equipe | Usuários CatalystHR (superadmin, suporte, financeiro), com MFA obrigatório | 02 |

- **RN-19-081** — O **cadastro** de parceiro ou empresa direta pede: razão social, CNPJ, nome comercial, slug (spec 01), plano, módulos, teste ou contrato, data de início, e o e-mail e o CPF do primeiro administrador. O sistema cria o subdomínio, a marca e o convite (D-484).

### 4.10 Painel da equipe CatalystHR (D-447, D-490)

- **RN-19-090** — **Blocos** **[P-19-25]**:

  | Bloco | Conteúdo |
  |---|---|
  | **Receita** | Receita recorrente mensal (mensalidades e adicionais), excedentes do mês, inadimplência (valor e contratos por etapa da régua), cancelamentos agendados, testes em andamento e conversão de testes |
  | **Custos contra o cobrado** | Por contrato: custo real de IA (tokens, em reais) e WhatsApp contra o valor cobrado (cota proporcional mais excedente), com a margem. Destaque para margens negativas |
  | **Operação** | Filas do Sidekiq (tamanho e atraso), falhas de IA e disjuntor, entregas com falha por canal, rejeições do eSocial fora do comum, certificados vencendo, tarefas de feriados |
  | **Clientes** | Plano, colaboradores, uso das cotas, adoção (spec 17), última atividade e **risco de cancelamento** |

  Na fase 1, só os blocos Receita e Clientes, sem a adoção. Custos contra o cobrado e Operação entram quando as fontes existirem (D-610).

- **RN-19-091** — **Risco de cancelamento:** alto quando há pelo menos dois sinais entre queda de 30% nos acessos em 30 dias, atraso de pagamento, cancelamento de módulo, ou nenhum acesso do RH administrador em 14 dias **[P-19-26]**.
- **RN-19-092** — O custo da IA em dólares (spec 14) é convertido pela cotação do dia, guardada junto do custo **[P-19-27]**.

### 4.11 Nota fiscal de serviço (NFS-e) pelo Asaas (D-560 a D-565)

- **RN-19-100** — A plataforma emite pelo **Asaas** as NFS-e do **CatalystHR** para os **parceiros e as empresas diretas**, uma por fatura paga (D-560). Notas de parceiros para os clientes deles continuam fora da plataforma (D-482).
- **RN-19-101** — O Asaas é usado **só para notas**. A cobrança continua no Mercado Pago (D-561). A nota é emitida como **nota avulsa ligada ao cliente** no Asaas, sem cobrança no Asaas.
- **RN-19-102** — **Configuração fiscal**, na área admin (Cobrança), mantida pelo superadmin e pelo financeiro **[P-19-30]**:
  - a conta do Asaas do CatalystHR, com os dados fiscais e a configuração da prefeitura (ou do Portal Nacional), conforme as exigências do município (`fiscalInfo/municipalOptions`);
  - o código do serviço municipal e a alíquota de ISS;
  - o texto padrão da descrição;
  - as retenções, se houver.

  Os valores fiscais são definidos com o **contador da CatalystHR** (item em aberto).
- **RN-19-103** — **Cliente no Asaas:** na primeira nota, a plataforma cadastra o contrato como cliente no Asaas (CNPJ, razão social, endereço, e-mail de cobrança) e guarda o identificador. Mudanças nesses dados são enviadas ao Asaas antes da nota seguinte **[P-19-31]**.
- **RN-19-104** — **Momento** (D-562): quando o pagamento da fatura é confirmado pelo Mercado Pago (RN-19-046), a plataforma agenda a nota no Asaas, com emissão imediata. O momento do fato gerador do ISS deve ser confirmado pelo contador da CatalystHR, porque depende da prefeitura (item em aberto).
- **RN-19-105** — **Conteúdo da nota** **[P-19-32]**:
  - valor: o **total pago** da fatura, com os descontos e créditos já aplicados;
  - descrição: o texto padrão, o período do ciclo e as linhas da fatura (plano, módulos, adicionais, excedentes);
  - faturas de **valor zero** (100% de desconto ou crédito) não geram nota **[P-19-36]**.
- **RN-19-106** — **Status da nota** na fatura: agendada, autorizada, com erro ou cancelada. A nota só conta como emitida quando o Asaas avisa que a prefeitura autorizou, pelo webhook de nota autorizada. O webhook é recebido num endpoint que confere o token do Asaas, e um job diário confere as notas sem retorno direto na API **[P-19-33]**.
- **RN-19-107** — **Entrega** (D-564): autorizada a nota, o PDF e o XML ficam na fatura, e o responsável financeiro recebe o aviso `billing.nfse_issued` com o link. O envio de e-mail pelo próprio Asaas fica **desligado**, para a comunicação sair com a marca da plataforma.
- **RN-19-108** — **Erro da prefeitura** (D-563): a fatura mostra "nota com erro" e a mensagem recebida. O financeiro e o superadmin recebem `platform.nfse_error`. Depois de corrigir (dados do cliente, configuração fiscal), o financeiro clica em **Emitir de novo**.
- **RN-19-109** — **Falhas temporárias** (Asaas fora do ar, tempo esgotado): até 3 novas tentativas, com 1, 5 e 15 minutos de intervalo (como RN-14-120). Esgotadas as tentativas, vale a RN-19-108 **[P-19-34]**.
- **RN-19-110** — **Cancelamento** (D-565): o **estorno** do pagamento no Mercado Pago, informado pelo webhook, cancela a nota no Asaas **automaticamente**, com o motivo "estorno da fatura <número>". Se a prefeitura não aceitar o cancelamento (por exemplo, fora do prazo), a fatura mostra o erro, e o financeiro e o superadmin são avisados para tratar com o contador **[P-19-35]**.
- **RN-19-111** — Cada passo (agendamento, autorização, erro, cancelamento) fica no histórico da fatura e na auditoria.

## 5. Estados

**Assinatura:** `trialing` → `active` ⇄ `past_due` → `read_only` → `closing` → `closed` · `trial_expired` · `cancel_scheduled`

**Fatura:** `draft` → `open` → `paid` | `overdue` → `paid` | `void` (cancelada pelo financeiro, com motivo; a da contratação também é cancelada quando é substituída ou não é paga no dia, D-623)

**Pagamento:** `pending` → `approved` | `rejected` | `refunded` | `cancelled` (PIX que expirou ou foi trocado, D-622)

**Nota fiscal:** `scheduled` → `authorized` | `error` → (`scheduled`, ao emitir de novo) · `authorized` → `cancelling` → `cancelled` | `cancel_error`

## 6. Permissões

Spec 03, seção 4.1, com o detalhe:

| Ação | Quem |
|---|---|
| Criar parceiro ou empresa direta, teste ou contrato | Superadmin, financeiro |
| Planos, módulos, adicionais, preços | Superadmin, financeiro |
| Faturas, NFS-e (configuração fiscal, emitir de novo), ajustes até 20% | Superadmin, financeiro |
| Aprovar ajustes acima de 20% | Superadmin **[P-19-23]** |
| Reativar contrato em `closing` | Superadmin **[P-19-18]** |
| Ver cobrança (leitura) | Suporte |
| Painel CatalystHR | Superadmin e financeiro (todos os blocos); suporte (Operação e Clientes) **[P-19-28]** |
| Contratar, trocar plano, pagar, cancelar | Responsável financeiro: administrador do parceiro ou RH administrador da empresa direta |
| Ligar módulo por empresa da carteira | Administrador do parceiro |
| Relatório de consumo por empresa | Administrador do parceiro |

## 7. Modelo de dados

```
plans
  id, kind ('partner'|'direct'), name, private (bool), billing_account_id (se privado),
  status

plan_versions                                        -- preços e cotas (D-611)
  id, plan_id, version, valid_from, created_by_id,
  monthly_price_cents, price_per_employee_cents, minimum_monthly_cents,
  employee_limit, overage_per_employee_cents,
  ai_credits (ou ai_credits_per_employee), whatsapp_messages (ou por colaborador),
  ai_credit_overage_cents, whatsapp_overage_cents

plan_modules
  id, plan_version_id, module ('ponto'|'folha'), price_cents (ou por colaborador)

add_ons
  id, code ('whatsapp_sender'|'face_recognition'), status

add_on_prices                                        -- versões do preço (D-611)
  id, add_on_id, version, valid_from, monthly_price_cents, created_by_id

billing_accounts
  id, owner_type ('Partner'|'Company'), owner_id, billing_email, responsible_user_id,
  mercado_pago_customer_id, mercado_pago_card_id, payment_method ('card'|'pix'),
  card_brand, card_last4, card_expires_on, cycle_day, asaas_customer_id

subscriptions
  id, billing_account_id, plan_version_id, status, trial_ends_at,
  started_at, current_period_start, current_period_end, cancel_at, cancel_reason,
  read_only_at, closing_at

subscription_items                                   -- módulos e adicionais
  id, subscription_id, item_type, item_id, starts_at, ends_at

company_module_settings                              -- parceiro liga o módulo por empresa
  company_id, module, enabled, changed_by_id, changed_at

daily_usage
  id, billing_account_id, company_id, date, active_employees

usage_periods
  id, billing_account_id, company_id (nullable = total), period ('YYYY-MM'),
  peak_employees, ai_credits, whatsapp_messages, closed_at

invoices                                             -- o PIX fica em payments (D-622)
  id, billing_account_id, number, period_start, period_end, due_on, status,
  total_cents, usage_period, issued_at, paid_at,
  checkout, void_reason, voided_at                   -- a fatura da contratação (D-623)

invoice_lines
  id, invoice_id, kind ('plan'|'module'|'add_on'|'overage_employees'|'overage_ai'|
  'overage_whatsapp'|'proration'|'adjustment'), description, quantity,
  unit_cents, total_cents

billing_adjustments
  id, billing_account_id, kind ('discount'|'credit'|'overage_waiver'), value_cents,
  percent, cycles, reason, created_by_id, approved_by_id, applied_invoice_id

payments                                             -- D-622; attempt e next_retry_on entram com o cartão (19h)
  id, invoice_id, payment_method ('pix'|'card'), status, amount_cents, idempotency_key,
  provider_order_id, provider_payment_id, raw_status, qr_code, qr_code_base64,
  ticket_url, expires_at, paid_at, attempt, next_retry_on, created_at

fx_rates
  date, currency ('USD'), brl_rate

service_invoices                                     -- NFS-e pelo Asaas
  id, invoice_id, asaas_invoice_id, status, amount_cents, service_description,
  municipal_service_code, iss_rate, number, verification_code, authorized_at,
  pdf (Active Storage), xml (Active Storage), error_message, attempts,
  cancel_reason, cancelled_at

fiscal_settings                                      -- configuração fiscal (P-19-30)
  id, municipal_service_code, municipal_service_id, iss_rate, description_template,
  retentions (jsonb), updated_by_id
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Billing::DailyUsageJob` | Diário, 1h | Grava o pico de colaboradores do dia por empresa e contrato |
| `Billing::ClosePeriodJob` | Dia 1 | Fecha o consumo do mês anterior e gera o relatório do parceiro |
| `Billing::GenerateInvoicesJob` | Diário | Gera as faturas que vencem em 3 dias |
| `Billing::ChargeJob` | No vencimento e nas novas tentativas (1, 3 e 5 dias) | Pede ao Mercado Pago a cobrança do cartão salvo |
| `Billing::DunningJob` | Diário, às 3h | Aplica a régua de inadimplência (D-624) |
| `Billing::ReconcileJob` | Diário, às 2h30 | Confere na API do Mercado Pago os PIX pendentes (D-622) |
| `Billing::TrialJob` | Diário | Avisos e fim dos testes |
| `Billing::CancellationJob` | Diário, às 2h50 | Aplica os cancelamentos agendados no fim do ciclo e avisa a carteira 30 dias antes (D-625) |
| `Billing::FxRateJob` | Diário | Busca a cotação do dólar **[P-19-27]** |
| `Billing::IssueServiceInvoiceJob` | Ao confirmar o pagamento | Cadastra ou atualiza o cliente no Asaas e agenda a nota |
| `Billing::CancelServiceInvoiceJob` | Ao receber o estorno | Pede o cancelamento da nota ao Asaas |
| `Billing::ServiceInvoiceReconcileJob` | Diário | Confere na API do Asaas as notas sem retorno |

- **Mercado Pago** (D-496, D-622): API de Orders (`/v1/orders`) por cliente HTTP próprio, sem a gem oficial, com chave de idempotência por pedido. PIX criado com `payment_method` `pix`/`bank_transfer` e `expiration_time`. Webhook em `POST /webhooks/mercado-pago`, no host do admin, com a assinatura `x-signature` conferida com a assinatura secreta da conta (tópico Order); o aviso só diz qual pedido mudou, e o pedido é lido na API. Cartão: cliente e cartão salvos, cobrados no valor de cada fatura como pagamento automático; o desenho na API de Orders é definido no 19h. **Pré-requisito:** confirmar com o Mercado Pago a habilitação da conta para cobrar o cartão salvo sem o CVV (item em aberto). O Pix Automático pode entrar numa fase seguinte **[P-19-29]**.
- **Cotação do dólar:** API pública do Banco Central (PTAX) **[P-19-27]**.
- **Asaas** (D-560): API REST v3 por cliente HTTP próprio (Faraday), com a chave de API nas variáveis de ambiente. Endpoints de clientes, notas fiscais (agendar, emitir, cancelar) e webhooks de notas. Em desenvolvimento, o sandbox do Asaas; nos testes, WebMock **[P-19-37]**.
- **Avisos novos** no catálogo da spec 15, para o responsável financeiro: `billing.invoice_issued`, `billing.price_change` (D-620), `billing.payment_failed`, `billing.trial_ending`, `billing.trial_expired`, `billing.cancel_scheduled`, `billing.contract_closing` e `billing.nfse_issued` (obrigatórios, sino e e-mail). Para o financeiro e o superadmin: `platform.nfse_error` (S E) **[P-19-38]**. Para o superadmin: `platform.adjustment_pending` (S E, D-621). Para o RH administrador das empresas da carteira: `billing.partner_read_only` e `billing.partner_cancelled` (obrigatórios, sino e e-mail).

## 9. Critérios de aceite

- **CA-19-001** — Dado um parceiro com faixa de 500 e pico de 530 colaboradores em outubro, quando a fatura de novembro é gerada, então ela traz 30 colaboradores excedentes.
- **CA-19-002** — Dado um colaborador desligado em 10/10 em período de leitura, quando o pico de novembro é calculado, então ele não conta.
- **CA-19-003** — Dada uma empresa direta em teste, quando o RH tenta configurar o ponto, então o módulo aparece como "disponível após a contratação".
- **CA-19-004** — Dado um teste que termina sem contratação, quando passam 14 dias, então a conta fica em leitura com a exportação disponível, e é excluída 30 dias depois.
- **CA-19-005** — Dado um parceiro que contrata o módulo de ponto no dia 10 de um ciclo que começa no dia 1, quando a próxima fatura é gerada, então ela traz o valor proporcional aos dias restantes do ciclo anterior, contados a partir do dia 10, mais o mês cheio do novo ciclo.
- **CA-19-006** — Dado um parceiro em atraso há 15 dias, quando o RH de uma empresa da carteira entra, então vê a faixa de acesso limitado, consegue transmitir os eventos do eSocial já gerados, mas não cria uma admissão, e os colaboradores continuam marcando o ponto.
- **CA-19-007** — Dado um pagamento por PIX confirmado no dia 20 de atraso, quando o webhook chega, então a conta volta a `active` na hora.
- **CA-19-008** — Dado um webhook perdido, quando o job de conferência roda, então a fatura paga é encontrada na API e marcada como paga.
- **CA-19-009** — Dado um ajuste de 25% lançado pelo financeiro, quando ele salva, então o ajuste fica aguardando a aprovação do superadmin.
- **CA-19-010** — Dado o parceiro, quando baixa o relatório de outubro, então o CSV tem uma linha por empresa com o pico de colaboradores, os módulos, os créditos de IA e as mensagens.
- **CA-19-011** — Dado um contrato com custo de IA maior que o cobrado, quando o superadmin abre o painel, então o contrato aparece destacado com margem negativa.
- **CA-19-012** — Dada uma fatura paga por PIX, quando o webhook do Mercado Pago confirma o pagamento, então a nota é agendada no Asaas e, ao chegar a autorização, o PDF e o XML aparecem na fatura, e o responsável recebe o aviso.
- **CA-19-013** — Dada uma nota recusada pela prefeitura, quando o webhook de erro chega, então a fatura mostra a mensagem, o financeiro é avisado e pode emitir de novo depois de corrigir.
- **CA-19-014** — Dado um estorno no Mercado Pago de uma fatura com nota autorizada, quando o webhook chega, então a plataforma pede o cancelamento da nota ao Asaas e registra o resultado.
- **CA-19-015** — Dada uma fatura de valor zero por crédito, quando é marcada como paga, então nenhuma nota é emitida.

## 10. Propostas aprovadas (D-498)

| # | Proposta |
|---|---|
| P-19-01 | Consumo dividido pelos dias na transferência |
| P-19-02 | Campos do plano de parceiro e de empresa direta (mínimo mensal; cotas por colaborador na direta) |
| P-19-03 | Parceiro liga o módulo por empresa, com preço fixo |
| P-19-04 | Mudança de preço só para novos; migração com aviso de 30 dias |
| P-19-05 | Planos privados para um cliente |
| P-19-06 | Cota não acumula para o mês seguinte |
| P-19-07 | Pico gravado por dia e mês fechado no dia 1 |
| P-19-08 | Formato e disponibilidade do relatório de consumo do parceiro |
| P-19-09 | No teste, a folha não fecha competência; cotas de 100 créditos e 100 mensagens |
| P-19-10 | Contratar no teste cobra na hora e começa o ciclo |
| P-19-11 | Ciclo no dia de início do contrato (29 a 31 viram 28) |
| P-19-12 | Fatura gerada 3 dias antes, com detalhamento |
| P-19-13 | Novas tentativas do cartão em 1, 3 e 5 dias, pedidas pela plataforma, com aviso (confirmada por D-497) |
| P-19-14 | Responsável financeiro e e-mail de cobrança adicional |
| P-19-15 | ~~NFS-e registrada na fatura pelo financeiro~~ (revisada por D-560: a NFS-e é emitida pelo Asaas) |
| P-19-16 | Webhook com assinatura e conferência diária na API |
| P-19-17 | Régua de inadimplência (+1, +5, +10, +15, +25, +30) |
| P-19-18 | Pagamento reativa na hora; em `closing`, só o superadmin reativa |
| P-19-19 | Aumento proporcional cobrado na próxima fatura |
| P-19-20 | Retirar módulo mantém os dados em leitura |
| P-19-21 | Cancelamento com confirmação e motivo, desfazível até o fim do ciclo |
| P-19-22 | Cancelamento do parceiro: transferências possíveis e aviso de 30 dias às empresas |
| P-19-23 | Ajustes acima de 20% pelo financeiro precisam do superadmin |
| P-19-24 | Seções da área admin |
| P-19-25 | Conteúdo dos 4 blocos do painel CatalystHR |
| P-19-26 | Sinais de risco de cancelamento |
| P-19-27 | Cotação do dólar pela PTAX, guardada junto do custo |
| P-19-28 | Suporte vê só Operação e Clientes no painel |
| P-19-29 | Detalhes técnicos do Mercado Pago: gem oficial, Customers e Cards, idempotência, webhooks (modelo definido por D-496) |

### Propostas aprovadas da NFS-e pelo Asaas (D-566)

| # | Proposta |
|---|---|
| P-19-30 | Configuração fiscal na área admin (código do serviço, ISS, descrição, retenções), definida com o contador |
| P-19-31 | Cliente cadastrado no Asaas na primeira nota e atualizado antes das seguintes |
| P-19-32 | Valor da nota igual ao total pago; descrição com o período e as linhas da fatura |
| P-19-33 | Status da nota pelos webhooks do Asaas, com token conferido e conferência diária |
| P-19-34 | Três novas tentativas em falhas temporárias (1, 5 e 15 minutos) |
| P-19-35 | Erro no cancelamento automático avisa o financeiro e o superadmin |
| P-19-36 | Fatura de valor zero não gera nota |
| P-19-37 | Integração por HTTP próprio (Faraday), sandbox em desenvolvimento e WebMock nos testes |
| P-19-38 | Avisos `billing.nfse_issued` e `platform.nfse_error` |
