# 11 — Jornada e banco de horas

> Status: aprovado (regras legais pendentes de conferência por especialista em DP) · Última atualização: 2026-10-12
> Decisões: D-065, D-207, D-236, D-242, D-279, D-291, D-317, D-318, D-330 a D-341, D-638 ([decisoes.md](decisoes.md))
> Os itens **[P-11-nn]** foram todos aprovados sem ajuste (D-341, seção 10).
> **Atenção:** as regras trabalhistas citadas (CLT, Lei 5.889/73, Lei 605/49, súmulas do TST) devem ser conferidas por especialista em DP. Convenções coletivas podem mudar os padrões, e é por isso que tudo fica em regras configuráveis.

## 1. Objetivo

Transformar as marcações do ponto ([spec 10](10-ponto-rep-p.md)) em **jornada apurada**:

- horas trabalhadas, extras, adicional noturno, faltas, atrasos e DSR;
- violações de intervalo;
- saldo do banco de horas.

O resultado aparece no espelho de ponto, passa pela ciência do colaborador e segue para a folha ([spec 12](12-folha-de-pagamento.md)).

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Regra de ponto | `TimeRule` | Como calcular: tolerâncias, faixas de hora extra, noturno, DSR, intervalos, banco de horas (D-332) |
| Jornada | `WorkSchedule` | O que é esperado: horários ou carga, de um dos 4 tipos (D-337). Aponta uma regra de ponto |
| Turno | `Shift` | Um bloco de horário (por exemplo, "06h–14h com 1h de intervalo"), usado nas escalas |
| Escala do gestor | `Roster` | A escala semanal montada pelo gestor para a equipe |
| Período de apuração | `TimePeriod` | O intervalo que fecha junto (D-330) |
| Dia apurado | `DailyTimesheet` | O cálculo de um dia para um vínculo |
| Espelho | `Timesheet` | O resumo do período de um vínculo, com ciência ou contestação (D-335, D-340) |
| Banco de horas | `HourBankEntry` | Lançamentos de crédito e débito, com vencimento (D-333) |

A jornada de cada vínculo vem da **revisão com vigência** (spec 04, D-207). Trocar de jornada é uma nova revisão.

## 3. Histórias de usuário

1. Como **RH**, quero criar a regra "CCT Metalúrgicos" com 60% nas 2 primeiras horas extras e 100% depois.
2. Como **RH**, quero cadastrar a escala 12x36 da portaria começando em 01/11.
3. Como **gestor de loja**, quero montar a escala da semana que vem e publicar para a equipe.
4. Como **colaborador**, quero ver meu saldo de banco de horas e os dias que geraram crédito.
5. Como **RH**, quero ver antes do fechamento quem tem marcações faltando ou ajustes pendentes.
6. Como **colaborador**, quero dar ciência no meu espelho ou contestar um dia errado.
7. Como **RH**, quero que as horas extras e faltas fechadas apareçam sozinhas na folha.

## 4. Regras de negócio

### 4.1 Regra de ponto (D-332)

- **RN-11-001** — A regra de ponto é criada pelo RH administrador. O sistema traz a regra "CLT padrão" pronta, que pode ser copiada e ajustada **[P-11-01]**. Conteúdo:

  | Grupo | Configuração | Padrão "CLT padrão" (a conferir) |
  |---|---|---|
  | **Tolerância** (D-331) | Minutos por marcação e por dia | 5 e 10 (art. 58, § 1º) |
  | **Hora extra** | Faixas por tipo de dia (útil, sábado, domingo, feriado), com percentual e limite | Útil: 50%. Domingo e feriado não compensados: 100% |
  | **Limite diário** | Alerta acima de N horas extras no dia | 2 horas (art. 59) |
  | **Noturno** (D-334) | Tipo (urbano, rural lavoura, rural pecuária), horário, percentual, hora reduzida, prorrogação | Urbano: 22h–5h, 20%, hora de 52min30s (art. 73); prorrogação ligada (Súmula 60, II, do TST) |
  | **DSR** | Perda do DSR por falta injustificada na semana; reflexo de atrasos | Perde o DSR com falta injustificada (Lei 605/49) |
  | **Intervalos** (D-338) | Interjornada mínima; intrajornada mínima por carga; forma de pagamento | 11h (art. 66); 1h acima de 6h e 15 min entre 4h e 6h (art. 71); suprimido pago com 50% sobre o tempo suprimido (art. 71, § 4º) |
  | **Banco de horas** (D-333) | Ver 4.6 | Desligado |
  | **Escala 12x36** | Feriados e prorrogação noturna já compensados | Conforme art. 59-A e a CCT |

- **RN-11-002** — Rural: lavoura das 21h às 5h e pecuária das 20h às 4h, 25%, **sem hora reduzida** (Lei 5.889/73, art. 7º).
- **RN-11-003** — Mudar uma regra vale para os dias **ainda não fechados**. Dias de períodos fechados não são recalculados, a menos que o período seja reaberto (D-339). A regra guarda o histórico de versões **[P-11-02]**.

### 4.2 Jornadas (D-337)

- **RN-11-010** — **Fixa semanal:** horários de entrada, intervalo e saída por dia da semana, e quais dias são folga ou DSR.
- **RN-11-011** — **Escala cíclica:** uma sequência de dias (turno ou folga) que se repete a partir de uma data de referência. Exemplos:
  - 12x36: turno de 12h, folga;
  - 6x1: 6 turnos, 1 folga;
  - revezamento: manhã ×2, tarde ×2, noite ×2, folga ×2.

  Cada vínculo informa o dia do ciclo em que começa **[P-11-03]**.
- **RN-11-012** — **Flexível por carga:** carga diária e/ou semanal, sem horário. A hora extra é o que passa da carga; a falta ou débito é o que fica abaixo, depois da tolerância. O intervalo mínimo continua valendo **[P-11-04]**.
- **RN-11-013** — **Escala do gestor:**
  - o gestor monta a escala da equipe semana a semana, escolhendo turnos de um catálogo da empresa;
  - a escala precisa ser **publicada** até N dias antes da semana (configurável, 7 de padrão);
  - depois de publicada, cada mudança avisa a pessoa afetada (spec 15);
  - dia sem turno publicado conta como folga **[P-11-05]**.
- **RN-11-014** — O intervalo de cada jornada é **marcado** ou **pré-assinalado** (D-317). No pré-assinalado, o intervalo previsto é descontado sem precisar de marcação. Se houver marcações de intervalo, valem elas.

### 4.3 Feriados (D-236, D-242, D-336)

- **RN-11-020** — Feriados:
  - **nacionais:** carregados pela equipe CatalystHR a partir da BrasilAPI (gratuita), com revisão manual **[P-11-06]**. Só valem depois de a equipe publicar: os de lei federal e a Sexta-feira da Paixão, que o RH pode desmarcar na unidade onde ela não for feriado; Carnaval e Corpus Christi ficam fora, como ponto facultativo (D-638);
  - **estaduais e municipais:** cadastrados à mão pela equipe CatalystHR para cada cidade com unidade de cliente (D-336);
  - **da unidade:** feriados e pontos facultativos acrescentados pelo RH (D-242).
- **RN-11-021** — Quando uma empresa cadastra uma unidade numa cidade ainda sem feriados cadastrados, a equipe CatalystHR recebe uma tarefa na área admin, e o RH vê o aviso "feriados municipais em cadastro" **[P-11-07]**.
- **RN-11-022** — Ponto facultativo é dia normal, a menos que a empresa marque que dispensa o trabalho naquele dia. Nesse caso, conta como feriado na apuração **[P-11-08]**.

### 4.4 Apuração diária

- **RN-11-030** — Para cada vínculo e dia, o sistema calcula:
  1. o **esperado**: jornada vigente (revisão), feriado, escala publicada, férias, afastamento, abono ou folga compensada (specs 09 e 12);
  2. as **marcações válidas**: originais mais inclusões, menos desconsiderações (spec 10);
  3. os **pares** entrada e saída, e as horas trabalhadas;
  4. a **tolerância**, as **extras** por faixa, o **noturno** (com hora reduzida, se urbano), as **faltas**, os **atrasos** e as **saídas antecipadas**;
  5. as **violações** de interjornada e intrajornada, e os valores devidos (D-338);
  6. o **banco de horas** do dia, se a regra usar.
- **RN-11-031** — Dias com marcações **ímpares** (faltou uma) ficam como **inconsistentes**. Não geram falta nem extra até serem tratados, e aparecem nas pendências do fechamento **[P-11-09]**.
- **RN-11-032** — Jornadas que passam da meia-noite são apuradas no **dia em que começaram** **[P-11-10]**.
- **RN-11-033** — O recálculo de um dia é disparado por qualquer mudança que o afete (marcação, tratamento, abono, férias, troca de jornada, feriado), roda em job e só alcança dias de períodos abertos **[P-11-11]**.
- **RN-11-034** — **Perda do DSR:** falta injustificada na semana tira o DSR daquela semana, conforme a regra. Faltas abonadas, atestados e férias não tiram.

### 4.5 Ausências justificadas

- **RN-11-040** — Vêm de outros módulos e zeram a expectativa do dia (ou de parte dele), sem gerar falta:
  - férias (spec 09);
  - atestado e afastamento (spec 09);
  - abono aprovado (spec 09);
  - folga por compensação de banco (spec 09);
  - licenças (spec 12).

### 4.6 Banco de horas (D-333)

- **RN-11-050** — Configuração na regra:

  | Item | Opções |
  |---|---|
  | Tipo de acordo | Individual (compensação em até 6 meses, art. 59, § 5º), coletivo (até 12 meses, art. 59, § 2º), mensal (compensação no próprio mês, art. 59, § 6º) |
  | O que vai para o banco | Todas as extras; só acima de N minutos por dia; por tipo de dia (por exemplo, útil vai para o banco, domingo é pago) |
  | Percentual no banco | 1 para 1, ou com fator (por exemplo, domingo vale 1h30 no banco) |
  | Débitos | Se atrasos e faltas descontam do banco ou viram desconto na folha |
  | Limite de saldo | Positivo e negativo máximos (alerta ao passar) |
  | Vencimento | Pagar o saldo positivo como hora extra; e o negativo: descontar (se o acordo permitir) ou zerar |

- **RN-11-051** — O banco funciona como um extrato: cada crédito tem data e **vencimento**. Débitos e folgas consomem os créditos mais antigos primeiro **[P-11-12]**.
- **RN-11-052** — No vencimento, um job aplica a regra e gera os lançamentos para a folha do período (D-335).
- **RN-11-053** — O RH pode lançar ajustes manuais no banco, com motivo (spec 03, 4.7). O colaborador e o gestor veem o saldo e o extrato.

### 4.7 Fechamento do período (D-330, D-335, D-339, D-340)

- **RN-11-060** — O período tem dia inicial configurável (D-330). Períodos são gerados automaticamente, um por vez.
- **RN-11-061** — **Pendências do fechamento:** antes de fechar, o RH vê a lista de:
  - dias inconsistentes (marcações ímpares);
  - dias sem marcação e sem justificativa;
  - pedidos de ajuste e abono em aberto;
  - escalas não publicadas;
  - contestações em aberto.

  É possível fechar com pendências, mas cada pendência precisa de confirmação explícita ("fechar mesmo assim") **[P-11-13]**.
- **RN-11-062** — Ao fechar, o sistema:
  1. trava a apuração do período;
  2. gera o **espelho** de cada vínculo (PDF, Prawn), com marcações originais, tratamentos identificados, ocorrências e totais;
  3. pede a **ciência** de cada colaborador (D-279), com prazo configurável (5 dias úteis de padrão) **[P-11-14]**;
  4. gera os **lançamentos para a folha** (D-335): extras por faixa, noturno, faltas, atrasos, DSR perdido, intervalo suprimido, banco pago ou descontado.
- **RN-11-063** — **Contestação** (D-340): em vez de dar ciência, o colaborador contesta escrevendo o que discorda. Isso abre uma solicitação do tipo "Contestação de espelho" (novo tipo do sistema, spec 09) para o RH. O RH corrige (reabrindo, se possível) ou responde. A contestação e a resposta ficam no espelho **[P-11-15]**.
- **RN-11-064** — **Reabertura** (D-339): o RH administrador reabre com motivo, só se a folha do mês ainda não fechou. Reabrir:
  - desfaz os lançamentos na folha;
  - invalida as ciências e contestações abertas;
  - permite recalcular.

  Um novo fechamento gera novos espelhos e pede ciência de novo.
- **RN-11-065** — Com a folha já fechada, correções do período entram como **lançamentos de diferença** no período aberto seguinte, com referência ao período original **[P-11-16]**.

## 5. Estados

**Período:** `open` → `closed` → (`reopened` → `closed`)

**Dia apurado:** `ok` · `inconsistent` · `pending_justification`

**Espelho:** `generated` → `acknowledged` | `contested` → (`resolved`)

**Escala do gestor:** `draft` → `published` → (`changed_after_publish`)

## 6. Permissões

Spec 03, seção 4.7, mais:

| Ação | Quem |
|---|---|
| Regras de ponto | RH administrador |
| Jornadas e turnos | RH administrador, RH analista (U, `ponto`) |
| Montar e publicar a escala da equipe | Gestor (E), RH |
| Fechar o período | RH administrador, RH analista (U, `ponto`) |
| Reabrir o período | RH administrador (D-339) |
| Ver espelho e banco | Colaborador (o próprio), gestor (E), RH |
| Ajuste manual no banco | RH administrador, RH analista (U, `ponto`) |

## 7. Modelo de dados

```
time_rules
  id, company_id, name, version, config (jsonb: tolerâncias, faixas, noturno,
  dsr, intervalos, banco, 12x36), status

work_schedules
  id, company_id, name, kind ('fixed_weekly'|'cyclic'|'flexible'|'roster'),
  time_rule_id, break_mode ('punched'|'pre_assigned'),
  config (jsonb: dias e horários | sequência do ciclo | cargas)

shifts
  id, company_id, name, starts_at, ends_at, break_minutes, break_starts_at

rosters / roster_entries
  id, company_id, department_id, week_start, status, published_at, published_by_id
  roster_id, employment_id, date, shift_id (nullable = folga)

employment_revisions (spec 04) + work_schedule_id, cycle_start_index

holidays e unit_holidays (spec 06, D-638) + o ponto facultativo dispensado pela empresa (RN-11-022), a desenhar com esta spec

time_periods
  id, company_id, starts_on, ends_on, status, closed_at, closed_by_id,
  reopened_at, reopened_by_id, reopen_reason

daily_timesheets
  id, company_id, employment_id, date, time_period_id, expected (jsonb),
  worked_minutes, overtime (jsonb por faixa), night_minutes, absence_minutes,
  late_minutes, early_leave_minutes, dsr_lost (bool), break_violations (jsonb),
  hour_bank_minutes, status, computed_at

timesheets
  id, company_id, employment_id, time_period_id, totals (jsonb), pdf (S3),
  acknowledgment_id (spec 08), contest_request_id (spec 09), status

hour_bank_entries
  id, company_id, employment_id, date, minutes (+/-), kind
  ('credit'|'debit'|'adjustment'|'expiration_paid'|'expiration_discounted'|'compensation'),
  expires_on, consumed_minutes, source_type, source_id, reason, created_by_id

payroll_time_items                                     -- entregue à folha (spec 12)
  id, company_id, employment_id, time_period_id, code (ocorrência), quantity_minutes,
  reference_period_id (diferença de período anterior), status
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Timesheets::RecomputeDayJob` | A cada mudança que afeta um dia | Recalcula o dia (RN-11-033) |
| `Timesheets::NightlyRecomputeJob` | Diário, de madrugada | Fecha o dia anterior para todos (faltas de quem não marcou) |
| `TimePeriods::CloseJob` | Ao fechar | Espelhos, pedidos de ciência, lançamentos para a folha |
| `HourBank::ExpireJob` | Diário | Aplica os vencimentos do banco |
| `Rosters::PublishDeadlineJob` | Diário | Avisa os gestores com escala não publicada perto do prazo |
| `Holidays::ImportNationalJob` | Anual (BrasilAPI) | Carrega os feriados nacionais para revisão |

## 9. Critérios de aceite

- **CA-11-001** — Dada a regra "CLT padrão" e jornada 08:00–17:00, quando o colaborador entra às 08:04 e sai às 17:03, então não há atraso nem extra (dentro de 5 por marcação e 10 no dia).
- **CA-11-002** — Dada a mesma jornada, quando ele sai às 18:30 num dia útil, então o dia registra 1h30 de extra a 50%.
- **CA-11-003** — Dado um trabalhador urbano das 22:00 às 05:00, quando o dia é apurado, então o noturno registra 8 horas noturnas (7h de relógio com hora reduzida) e 20%.
- **CA-11-004** — Dado um trabalhador rural da pecuária das 20:00 às 04:00, quando o dia é apurado, então o noturno registra 8 horas, com 25% e sem hora reduzida.
- **CA-11-005** — Dada uma falta injustificada na quarta, quando a semana é apurada, então o DSR daquela semana é perdido. Com um atestado na quarta, não é.
- **CA-11-006** — Dado alguém que saiu às 23:00 e voltou às 07:00, quando o dia é apurado, então aparece a violação de interjornada (8h, abaixo de 11h) e o valor devido conforme a regra.
- **CA-11-007** — Dado um banco individual com crédito de 3h em 10/03, quando chega 10/09 sem compensação, então o job paga as 3h como extra na folha do período.
- **CA-11-008** — Dada uma escala 12x36 começando em 01/11 no dia de turno, quando o RH consulta 04/11, então o dia esperado é de turno (01 turno, 02 folga, 03 turno, 04 folga…), conforme o ciclo cadastrado.
- **CA-11-009** — Dado um dia com 3 marcações, quando o RH abre o fechamento, então o dia aparece como inconsistente na lista de pendências.
- **CA-11-010** — Dado um período fechado e a folha do mês aberta, quando o RH administrador reabre com motivo, então os lançamentos saem da folha e os espelhos voltam a pedir ciência no novo fechamento.
- **CA-11-011** — Dado um colaborador que contesta o espelho, quando ele envia, então uma solicitação "Contestação de espelho" é aberta para o RH e o espelho mostra a contestação.

## 10. Propostas aprovadas (D-341)

| # | Proposta |
|---|---|
| P-11-01 | Regra "CLT padrão" pronta, que a empresa copia e ajusta |
| P-11-02 | Mudança de regra vale para dias não fechados, com histórico de versões |
| P-11-03 | Escala cíclica com dia inicial do ciclo por vínculo |
| P-11-04 | Jornada flexível: extra acima da carga, débito abaixo, intervalo mínimo mantido |
| P-11-05 | Escala do gestor publicada com antecedência (7 dias de padrão); dia sem turno é folga |
| P-11-06 | Feriados nacionais pela BrasilAPI, com revisão manual |
| P-11-07 | Tarefa para a equipe CatalystHR quando surge uma cidade sem feriados cadastrados |
| P-11-08 | Ponto facultativo só conta como feriado se a empresa dispensar o trabalho |
| P-11-09 | Dia com marcações ímpares fica inconsistente até ser tratado |
| P-11-10 | Jornada que passa da meia-noite é apurada no dia em que começou |
| P-11-11 | Recálculo por job, só em períodos abertos |
| P-11-12 | Banco consome os créditos mais antigos primeiro |
| P-11-13 | Fechar com pendências exige confirmação de cada uma |
| P-11-14 | Prazo de ciência do espelho de 5 dias úteis de padrão |
| P-11-15 | Novo tipo de solicitação do sistema: "Contestação de espelho" |
| P-11-16 | Com a folha fechada, correções viram lançamentos de diferença no período seguinte |
