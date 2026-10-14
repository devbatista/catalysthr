# 12 — Folha de pagamento

> Status: aprovado (cálculos pendentes de conferência por especialista em DP e contabilidade) · Última atualização: 2026-10-12
> Decisões: D-011, D-070 a D-075, D-111, D-122, D-175, D-176, D-189, D-207, D-212, D-335, D-350 a D-363 ([decisoes.md](decisoes.md))
> Os itens **[P-12-nn]** foram todos aprovados sem ajuste (D-362, seção 10).
> **Atenção:** os cálculos trabalhistas, previdenciários e tributários citados (percentuais, prazos, incidências, regras de média) **precisam ser conferidos por especialista em DP e pela contabilidade** antes da implementação, e acompanhados a cada mudança de lei. Esta spec descreve o **motor** e as regras gerais; a tabela detalhada de rubricas e incidências é um anexo a ser produzido com o especialista.

## 1. Objetivo

Permitir que o **RH da empresa processe a folha completa na plataforma** (D-011, D-070):

- todos os tipos de vínculo e de folha;
- benefícios e descontos;
- holerite, informe de rendimentos e lista de pagamentos;
- dados prontos para o eSocial e as guias ([spec 13](13-esocial-obrigacoes.md)).

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Dados fiscais da empresa | `CompanyTaxProfile` | CNAE, FPAS, RAT/FAP, terceiros, regime, desoneração (D-212) |
| Rubrica | `PayrollItem` | Provento, desconto ou informativa, com incidências (D-350) |
| Tabela legal | `LegalTable` | INSS, IRRF, salário mínimo etc., com vigência (D-351) |
| Competência | `PayrollPeriod` | O mês de referência da folha, com o ciclo de D-354 |
| Folha | `PayrollRun` | Um cálculo dentro da competência: mensal, adiantamento, complementar, 13º 1ª ou 2ª parcela, PLR, férias, rescisão (D-355) |
| Lançamento | `PayrollEntry` | Uma rubrica de um vínculo numa folha, com quantidade, base e valor |
| Variável | `PayrollInput` | Um lançamento informado antes do cálculo (ponto, benefícios, digitado pelo RH) |
| Benefício | `Benefit` / `BenefitEnrollment` | Benefício da empresa e a adesão de cada pessoa (D-357) |
| Desconto recorrente | `RecurringDeduction` | Pensão, consignado, mensalidades, com início, fim e regra |
| Período aquisitivo | `VacationAcquisitionPeriod` | Base das férias (spec 09) |

## 3. Histórias de usuário

1. Como **RH**, quero calcular a folha do mês, conferir as diferenças contra o mês anterior e fechar.
2. Como **RH**, quero que horas extras, noturno e faltas do ponto entrem sozinhas na folha.
3. Como **RH**, quero criar a rubrica "Gratificação de função" como 20% do salário, com incidência de INSS, IRRF e FGTS.
4. Como **RH**, quero calcular as férias de alguém com a média das horas extras dos últimos 12 meses.
5. Como **RH**, quero calcular a rescisão e gerar o TRCT.
6. Como **colaborador**, quero ver meu holerite no celular quando a folha fechar.
7. Como **RH**, quero a lista de pagamentos por PIX para pagar no banco.
8. Como **prestador PJ**, quero enviar minha nota fiscal e saber quando foi aprovada.
9. Como **RH**, quero o informe de rendimentos de todos em fevereiro.

## 4. Regras de negócio

### 4.1 Dados fiscais da empresa (D-074, D-212)

- **RN-12-001** — O RH administrador mantém, com vigência **[P-12-01]**:
  - classificação tributária (eSocial S-1000) e regime: Simples Nacional (com indicação do anexo IV), Lucro Presumido, Lucro Real;
  - indicação de ME ou EPP;
  - CNAE preponderante;
  - FPAS e código de terceiros;
  - RAT (1%, 2% ou 3%) e FAP (de 0,5 a 2,0);
  - desoneração da folha (CPRB): se a empresa está no regime e com qual alíquota;
  - por unidade, quando diferente da matriz: CNAE, RAT e lotação tributária (S-1020).
- **RN-12-002** — A **transição da desoneração** (reoneração gradual até 2028) fica numa tabela legal mantida pela equipe CatalystHR, com o percentual de cada ano (D-351) **[P-12-02]**.

### 4.2 Tabelas legais (D-351)

- **RN-12-010** — A equipe CatalystHR mantém, com vigência:
  - INSS do empregado (progressiva) e teto;
  - IRRF mensal, deduções e desconto simplificado;
  - IR exclusivo da PLR;
  - salário mínimo;
  - salário-família (cota e limite);
  - dedução por dependente;
  - alíquotas patronais;
  - transição da CPRB.
- **RN-12-011** — A folha usa a tabela **vigente na competência** (ou na data de pagamento, quando a lei manda, como no IRRF, que segue o regime de caixa). A regra de qual data vale fica em cada tabela **[P-12-03]**.
- **RN-12-012** — Toda mudança de tabela fica no histórico, avisa os RHs das empresas com folha contratada e mostra quais competências abertas serão afetadas.

### 4.3 Rubricas (D-350, D-352, D-353)

- **RN-12-020** — **Catálogo da plataforma:** rubricas padrão com natureza eSocial (tabela 03), tipo (provento, desconto, informativa) e incidências (INSS, IRRF, FGTS, e se entra nas médias de férias, 13º e rescisão). As empresas usam essas rubricas sem poder editar as incidências **[P-12-04]**.
- **RN-12-021** — **Rubricas da empresa:** o RH administrador cria rubricas com natureza eSocial, incidências e forma de cálculo. As exigências de cada convenção coletiva entram assim (D-352), por exemplo:
  - adicional por tempo de serviço;
  - piso salarial (alerta na revisão do vínculo, como a faixa do cargo, P-04-14);
  - contribuição assistencial;
  - percentuais de hora extra (na regra de ponto, spec 11).
- **RN-12-022** — Formas de cálculo (D-353):

  | Tipo | Exemplo |
  |---|---|
  | Valor fixo | R$ 150,00 |
  | Percentual sobre o salário | 20% do salário-base |
  | Percentual sobre outra rubrica ou base | 10% sobre a base de INSS |
  | Quantidade × valor | Horas × valor da hora × 1,5 |
  | Fórmula | Expressão segura (gem Dentaku) com variáveis permitidas: `salario_base`, `horas_mes`, `dias_trabalhados`, `dependentes_irrf`, `tempo_servico_anos`, valores de outras rubricas... |

- **RN-12-023** — Fórmulas são validadas ao salvar (sintaxe, variáveis existentes, sem dependência circular entre rubricas) e testadas com um vínculo de exemplo antes de ativar **[P-12-05]**.
- **RN-12-024** — Rubricas da empresa entram no S-1010 (spec 13) quando criadas ou alteradas.

### 4.4 Competência e ciclo (D-354)

```
aberta → calculada → conferida → fechada
            ↑   (recalcular quantas vezes quiser)
fechada → reaberta (RH administrador, com motivo) → calculada…
```

- **RN-12-030** — **Aberta:** o RH lança as variáveis. As do ponto chegam sozinhas no fechamento do ponto (D-335); as de benefícios, descontos recorrentes, férias e afastamentos são geradas pelo sistema.
- **RN-12-031** — **Calcular:** roda o cálculo de todos os vínculos ativos no período (ou dos selecionados), em job, com progresso. Pode ser repetido.
- **RN-12-032** — **Conferência:** relatórios antes de fechar **[P-12-06]**:
  - comparação com o mês anterior, por pessoa e rubrica, destacando variações acima de X%;
  - líquidos negativos ou zerados;
  - salários abaixo do mínimo ou do piso;
  - pessoas sem conta ou PIX;
  - resumo por rubrica e por centro de custo (unidade e departamento).

  O RH marca "conferida".
- **RN-12-033** — **Fechar:**
  1. trava a folha;
  2. publica os holerites (D-360);
  3. gera a lista de pagamentos (D-356) e os relatórios contábeis;
  4. dispara os eventos de remuneração e pagamento (S-1200, S-1210) e o fechamento (S-1299), conforme a spec 13.
- **RN-12-034** — **Reabrir** (D-354): só o RH administrador, com motivo, e conforme o que a spec 13 permitir (S-1298 para reabrir o movimento no eSocial). Holerites publicados ficam marcados como "em revisão" até o novo fechamento **[P-12-07]**.

### 4.5 Tipos de folha (D-072, D-355)

| Folha | Regra principal (a conferir) |
|---|---|
| **Mensal** | Salário proporcional aos dias, variáveis, benefícios, descontos, INSS, IRRF, FGTS, desconto do adiantamento |
| **Adiantamento quinzenal** | Percentual configurável por empresa (40% de padrão), pago na data definida e descontado na mensal. Sem INSS; IRRF conforme a regra vigente **[P-12-08]** |
| **Complementar** | Diferenças de competência já fechada (por exemplo, dissídio retroativo), com referência à competência original |
| **13º — 1ª parcela** | Metade do 13º, até 30/11, ou junto das férias se pedida (spec 09). Sem descontos |
| **13º — 2ª parcela** | Até 20/12, com INSS e IRRF sobre o total e as médias de variáveis |
| **Férias** | 1/3 constitucional, abono pecuniário, médias de variáveis do período aquisitivo, adiantamento do 13º. Pagamento até 2 dias antes do início (art. 145) |
| **Rescisão** | Saldo de salário, aviso prévio, férias vencidas e proporcionais com 1/3, 13º proporcional, médias, multa do FGTS (40% ou 20% no acordo), descontos. Gera o TRCT |
| **PLR** | Valor por pessoa, com IR exclusivo pela tabela própria e sem INSS e FGTS |

- **RN-12-040** — **Médias** de variáveis (horas extras, noturno, comissões) para férias, 13º e rescisão: período e método (quantidade ou valor, corrigido ou não) definidos por rubrica, com o padrão da CLT e espaço para a CCT **[P-12-09]**.
- **RN-12-041** — **Períodos aquisitivos de férias:** gerados a cada 12 meses de vínculo. As faltas injustificadas reduzem os dias (art. 130), e afastamentos longos podem zerar o período (art. 133). Os saldos alimentam o pedido de férias (spec 09).
- **RN-12-042** — **Rescisão:** usa os dados do desligamento (spec 09), calcula as verbas e gera o TRCT em PDF. O prazo de pagamento de 10 dias (D-298) e o S-2299 (spec 13) são acompanhados. A guia de multa do FGTS e o seguro-desemprego são tratados na spec 13 **[P-12-10]**.

### 4.6 Outros vínculos

| Vínculo | Cálculo (a conferir) |
|---|---|
| **Sócio (pró-labore)** | INSS do contribuinte individual retido (11%, até o teto), patronal conforme o regime, IRRF. Sem FGTS. Recibo de pró-labore |
| **Estágio** | Bolsa e auxílio-transporte, sem INSS e FGTS. IRRF sobre a bolsa. Recesso conforme a spec 09. Recibo de bolsa |
| **Autônomo** | RPA (recibo de pagamento a autônomo) com INSS retido (11%), patronal (20%), IRRF e ISS, quando aplicável (alíquota por município, informada pelo RH) **[P-12-11]** |
| **PJ** | Não entra na folha. Nota fiscal com conferência e aprovação (4.8) |

### 4.7 Benefícios e descontos (D-357, D-358)

- **RN-12-050** — **Benefícios da empresa:** o RH cadastra cada benefício com:
  - tipo: VT, VR, VA, plano de saúde, odontológico, seguro de vida, outro;
  - valor ou tabela por faixa ou dependente;
  - parte da empresa e desconto do colaborador;
  - coparticipação;
  - rubricas de provento e desconto.
- **RN-12-051** — **VT:** o colaborador opta ou recusa pela solicitação (spec 09) e informa o trajeto. O desconto é de até 6% do salário-base, limitado ao custo do benefício. O valor de compra vai para o relatório do pedido (D-358).
- **RN-12-052** — **Planos:** a adesão inclui os dependentes (spec 04), e a coparticipação do mês é lançada pelo RH (importação de planilha da operadora) **[P-12-12]**.
- **RN-12-053** — **Pensão alimentícia:** cadastro com:
  - número do processo;
  - beneficiário (nome, CPF, conta ou PIX);
  - fórmula: percentual sobre o líquido ou o bruto, com ou sem o 13º e as férias, ou valor fixo;
  - início e fim.

  O valor descontado entra na lista de pagamentos para o beneficiário e é deduzido no IRRF. A conta do beneficiário é dado sensível (spec 05) **[P-12-13]**.
- **RN-12-054** — **Consignado:** cadastro do contrato (instituição, parcelas, valor), com controle da **margem consignável** (limite configurável na tabela legal). Contratos do **Crédito do Trabalhador**, recebidos pelos canais oficiais, são lançados conforme as regras vigentes (a confirmar na spec 13). Parcela que passa da margem gera alerta e não é descontada além do limite **[P-12-14]**.
- **RN-12-055** — **Contribuição sindical:** só com autorização prévia e expressa do colaborador (art. 578), registrada como documento com ciência (spec 08). Filiação sindical é dado sensível (D-221).
- **RN-12-056** — **Relatórios para operadoras** (D-358): VT por pessoa e trajeto, VR e VA por pessoa, vidas do plano. Em CSV e PDF, para o RH fazer os pedidos.

### 4.8 Nota fiscal do PJ (D-175, D-189, D-359)

- **RN-12-060** — O PJ envia a NF pelo portal (PDF, e o XML se houver), informando competência e valor.
- **RN-12-061** — O sistema confere automaticamente:
  - o CNPJ do prestador (da NF, pela IA ou pelo XML) contra o do vínculo;
  - o valor contra o valor do contrato;
  - se a competência já tem NF.

  Divergências aparecem para o RH **[P-12-15]**.
- **RN-12-062** — O RH aprova ou devolve com motivo. Aprovada, a NF entra na lista de pagamentos da data configurada. Retenções de tributos e EFD-Reinf não são feitas (D-359).

### 4.9 Pagamentos (D-356)

- **RN-12-070** — A data de pagamento é configurável por empresa e tipo de folha, com o padrão do 5º dia útil do mês seguinte para a mensal (art. 459, § 1º). Dias úteis seguem o calendário da spec 11 **[P-12-16]**.
- **RN-12-071** — **Lista de pagamentos:** gerada por folha (e para NFs aprovadas e pensões), com nome, CPF, forma (PIX, que é o padrão, ou conta), chave PIX ou banco, agência e conta, e valor líquido. Exportada em CSV e PDF. O CSV segue um layout simples de importação de lote, que os bancos costumam aceitar ou adaptar **[P-12-17]**.
- **RN-12-072** — O RH marca cada linha, ou a lista toda, como **paga**, com a data. O sistema usa a data de pagamento para o S-1210 (spec 13) e para o IRRF.
- **RN-12-073** — Quem não tem PIX nem conta aparece na conferência (RN-12-032) como pendência.

### 4.10 Holerite e informe (D-360, D-361)

- **RN-12-080** — Ao fechar a folha:
  - o holerite de cada pessoa é gerado (PDF, Prawn) e publicado na pasta (categoria Folha) e na tela da folha;
  - o aviso sai por e-mail e WhatsApp (spec 15);
  - a primeira abertura fica registrada como confirmação de leitura.
- **RN-12-081** — O holerite mostra empresa, competência, rubricas (com referência e valor), bases de INSS, FGTS e IRRF, FGTS do mês e líquido. A data de pagamento aparece quando marcada **[P-12-18]**.
- **RN-12-082** — **Informe de rendimentos:** gerado até o último dia útil de fevereiro, para todos os que receberam no ano anterior, inclusive desligados ainda em período de leitura (D-090). Fica na pasta, com aviso **[P-12-19]**.
- **RN-12-083** — **Prévia do holerite** (D-363): quando a competência está **conferida** e ainda não fechada, o colaborador vê no portal a prévia do próximo holerite, com o aviso "valores sujeitos ao fechamento da folha". Se a competência voltar a ser calculada, a prévia some até a nova conferência.

### 4.11 Relatórios contábeis (D-073)

- **RN-12-090** — Ao fechar:
  - **resumo da folha** por rubrica, por unidade e departamento;
  - **encargos** (INSS patronal, RAT ajustado, terceiros, FGTS);
  - **provisões** de férias e 13º;
  - **lançamentos contábeis**, num layout de importação configurável (conta de débito e crédito por rubrica). A contabilidade lê em modo leitura (D-193) **[P-12-20]**.

## 5. Estados

**Competência:** `open` → `calculated` → `reviewed` → `closed` → (`reopened`)

**Folha (run):** `draft` → `calculating` → `calculated` | `failed` → `closed`

**Holerite:** `published` → `read`

**NF do PJ:** `submitted` → `approved` | `returned` → `paid`

**Linha de pagamento:** `pending` → `paid`

## 6. Permissões

Spec 03, seção 4.8:

| Ação | Quem |
|---|---|
| Dados fiscais, rubricas, fórmulas, benefícios | RH administrador (P-03-25) |
| Variáveis, cálculo, conferência, fechamento, lista de pagamentos | RH administrador (T), RH analista (U, `folha`) |
| Reabrir competência | RH administrador |
| Ver folha, holerites, guias e relatórios | Contabilidade em leitura (D-193) |
| Tabelas legais e catálogo de rubricas | Superadmin, suporte |
| Ver o próprio holerite e informe | Colaborador |
| Enviar NF | PJ |

## 7. Modelo de dados

```
company_tax_profiles                                   -- com vigência
  id, company_id, valid_from, tax_classification, regime, simples_annex_iv,
  me_epp, cnae, fpas, third_party_code, rat, fap, cprb, cprb_rate,
  per_unit_overrides (jsonb)

legal_tables                                           -- global, com vigência
  id, kind, valid_from, valid_to, applies_by ('competence'|'payment_date'),
  data (jsonb: faixas, valores)

payroll_items                                          -- catálogo + empresa
  id, company_id (nullable = plataforma), code, name, kind
  ('earning'|'deduction'|'informative'), esocial_nature, incidences (jsonb:
  inss, irrf, fgts, averages_vacation, averages_13th, averages_termination),
  calculation_type, calculation_config (jsonb), formula, status

payroll_periods
  id, company_id, competence (ano-mês), status, reviewed_by_id,
  closed_at, closed_by_id, reopened_at, reopened_by_id, reopen_reason

payroll_runs
  id, company_id, payroll_period_id, kind ('monthly'|'advance'|'complementary'|
  'thirteenth_1'|'thirteenth_2'|'plr'|'vacation'|'termination'),
  reference_period_id, payment_date, status, calculated_at

payroll_inputs                                         -- variáveis
  id, company_id, payroll_period_id, employment_id, payroll_item_id, quantity,
  amount, source ('time'|'benefit'|'deduction'|'manual'|'vacation'|'leave'),
  source_ref

payroll_entries                                        -- resultado
  id, company_id, payroll_run_id, employment_id, payroll_item_id, reference,
  base_amount (cript.), amount (cript.)

payroll_results                                        -- totais por pessoa e folha
  id, company_id, payroll_run_id, employment_id, gross (cript.), deductions
  (cript.), net (cript.), inss_base, fgts_base, irrf_base, fgts_amount, payslip_pdf

benefits / benefit_enrollments
recurring_deductions                                   -- pensão, consignado, mensalidades
  id, company_id, employment_id, kind, config (jsonb), beneficiary (jsonb, cript.),
  starts_on, ends_on, status

vacation_acquisition_periods
  id, company_id, employment_id, starts_on, ends_on, entitled_days, used_days,
  sold_days, concessive_ends_on, status

contractor_invoices                                    -- NF do PJ
  id, company_id, employment_id, competence, amount, file_pdf, file_xml,
  extracted (jsonb), checks (jsonb), status, reviewed_by_id, paid_on

payment_lists / payment_list_items
  id, company_id, payroll_run_id (nullable), kind, generated_at
  payment_list_id, payee_type, payee_id, method ('pix'|'bank_account'),
  destination (cript.), amount (cript.), status, paid_on

income_statements                                      -- informe anual
  id, company_id, employment_id, year, pdf, published_at
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Payroll::CalculateRunJob` | Sob demanda | Calcula a folha, em lotes por vínculo, com progresso |
| `Payroll::CloseRunJob` | Ao fechar | Holerites, lista de pagamentos, relatórios, eventos do eSocial |
| `Payroll::RecurringInputsJob` | Ao abrir a competência | Gera as variáveis de benefícios e descontos recorrentes |
| `Vacations::AcquisitionPeriodsJob` | Diário | Abre períodos aquisitivos e atualiza saldos |
| `Payroll::IncomeStatementsJob` | Fevereiro | Gera e publica os informes |
| `ContractorInvoices::CheckJob` | Ao enviar a NF | Extrai dados (IA ou XML) e confere |

O cálculo da folha é **determinístico e testável**: dado o mesmo conjunto de entradas e tabelas, o resultado é idêntico. Cada regra de cálculo tem testes com casos conferidos pelo especialista **[P-12-21]**.

## 9. Critérios de aceite

- **CA-12-001** — Dada uma tabela de INSS nova, com vigência em 01/01, quando a folha de janeiro é calculada, então usa a tabela nova, e a de dezembro (complementar) usa a anterior.
- **CA-12-002** — Dada a rubrica "Gratificação" com fórmula `salario_base * 0.2`, quando o RH salva, então a fórmula é validada e testada com um vínculo de exemplo.
- **CA-12-003** — Dada uma fórmula que referencia a si mesma, por outra rubrica, quando o RH salva, então o sistema recusa por dependência circular.
- **CA-12-004** — Dado o fechamento do ponto com 10h de extra a 50%, quando a competência abre, então a variável já está lançada para o vínculo.
- **CA-12-005** — Dada uma variação de mais de 30% no líquido de alguém, quando o RH abre a conferência, então a pessoa aparece destacada.
- **CA-12-006** — Dada uma folha fechada, quando o colaborador abre o holerite pela primeira vez, então a leitura fica registrada.
- **CA-12-007** — Dada uma pensão de 30% sobre o líquido, quando a folha é calculada, então o desconto aparece no holerite e o beneficiário entra na lista de pagamentos.
- **CA-12-008** — Dada uma parcela de consignado acima da margem, quando a folha é calculada, então o desconto respeita a margem e o RH recebe o alerta.
- **CA-12-009** — Dada uma NF do PJ com CNPJ diferente do vínculo, quando ela é enviada, então a conferência aponta a divergência ao RH.
- **CA-12-010** — Dada a lista de pagamentos, quando o RH marca tudo como pago em 05/11, então a data entra no S-1210 e no histórico de cada pessoa.
- **CA-12-011** — Dado um colaborador desligado em junho com leitura de 12 meses, quando o informe é gerado em fevereiro, então ele recebe o informe no portal.

## 10. Propostas aprovadas (D-362)

| # | Proposta |
|---|---|
| P-12-01 | Dados fiscais com vigência e exceções por unidade |
| P-12-02 | Transição da CPRB em tabela legal mantida pela plataforma |
| P-12-03 | Cada tabela indica se vale pela competência ou pela data de pagamento |
| P-12-04 | Rubricas do catálogo não têm incidências editáveis pela empresa |
| P-12-05 | Fórmulas validadas e testadas com vínculo de exemplo antes de ativar |
| P-12-06 | Relatórios de conferência (variação, líquido negativo, piso, sem conta, resumos) |
| P-12-07 | Holerites ficam "em revisão" na reabertura |
| P-12-08 | Adiantamento de 40% por padrão |
| P-12-09 | Médias configuráveis por rubrica, com o padrão da CLT |
| P-12-10 | Guia da multa do FGTS e seguro-desemprego tratados na spec 13 |
| P-12-11 | Autônomo com RPA, incluindo ISS por alíquota informada pelo RH |
| P-12-12 | Coparticipação lançada por importação da planilha da operadora |
| P-12-13 | Pensão com beneficiário na lista de pagamentos e dedução no IRRF |
| P-12-14 | Margem consignável com alerta e limite |
| P-12-15 | Conferência automática da NF (CNPJ, valor, duplicidade) |
| P-12-16 | Pagamento no 5º dia útil por padrão |
| P-12-17 | Lista de pagamentos em CSV e PDF, num layout simples de lote |
| P-12-18 | Conteúdo do holerite |
| P-12-19 | Informe publicado até o último dia útil de fevereiro |
| P-12-20 | Relatórios contábeis com layout de lançamentos configurável |
| P-12-21 | Cálculo determinístico, com testes conferidos pelo especialista |

## 11. Em aberto

- **Anexo de rubricas e incidências:** produzir com especialista em DP antes da implementação.
- **Crédito do Trabalhador:** como os contratos chegam e são informados (spec 13).
- **Layout CSV da lista de pagamentos:** validar com os bancos dos clientes do piloto.
