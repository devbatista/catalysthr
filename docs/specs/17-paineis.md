# 17 — Painéis e relatórios gerenciais

> Status: aprovado (fórmulas na conferência do especialista em DP) · Última atualização: 2026-10-13
> Decisões: D-085, D-086, D-107, D-190, D-221, D-386, D-440 a D-451 ([decisoes.md](decisoes.md))
> Os itens **[P-17-nn]** foram todos aprovados sem ajuste (D-451, seção 10).

## 1. Objetivo

Mostrar **o que precisa de atenção agora** e **como a empresa está evoluindo**, sempre dentro do escopo de quem olha:

- painel do RH, como no protótipo, com os blocos dos módulos contratados (D-440);
- painel do gestor;
- visão consolidada do parceiro, com comparação entre empresas (D-442, D-450);
- relatórios gerenciais com histórico: quadro e movimentação, absenteísmo e jornada, custo de pessoal, diversidade (D-441);
- exportação e agendamento (D-446, D-449).

O painel da equipe CatalystHR fica na spec 19 (D-447). O resumo da IA vem da spec 14.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Painel | `Dashboard` | A tela inicial de cada perfil, com indicadores e blocos |
| Indicador | `Indicator` | Um número com definição fixa (seção 4.2), que abre a lista de origem |
| Relatório gerencial | `Report` | Indicadores com histórico mensal, gráfico, filtros e exportação |
| Foto diária | `CompanyDailyMetric` | Os números do dia, já agregados, gravados de madrugada (D-443) |
| Exportação | `ReportExport` | Arquivo gerado (CSV, XLSX ou PDF) |
| Agendamento | `ReportSchedule` | Geração periódica de um relatório, com aviso aos usuários escolhidos (D-449) |
| Atividade | `ActivityEvent` | Um acontecimento da empresa para o bloco "Atividade recente" |

## 3. Histórias de usuário

1. Como **RH**, quero abrir o sistema e ver quantas admissões estão paradas e clicar no número para ver quais são.
2. Como **RH analista**, quero que o painel mostre só as minhas unidades.
3. Como **gestor**, quero ver quem da equipe está ausente hoje e o banco de horas de cada um.
4. Como **RH administrador**, quero o turnover dos últimos 12 meses por unidade, para levar à diretoria em PDF.
5. Como **RH administrador**, quero saber o custo de pessoal por departamento.
6. Como **administrador do parceiro**, quero ver quais empresas da carteira estão com folha atrasada ou eventos rejeitados.
7. Como **administrador do parceiro**, quero comparar o absenteísmo das empresas da carteira para oferecer consultoria.
8. Como **RH administrador**, quero que o diretor financeiro receba todo dia 5 o aviso de que o relatório de custo do mês está pronto.

## 4. Regras de negócio

### 4.1 Princípios

- **RN-17-001** — Todo número respeita o **escopo** de quem olha (spec 03): empresa toda, unidades, equipe ou carteira.
- **RN-17-002** — Todo indicador do painel **abre a lista de origem** com o mesmo filtro, e o número da lista é igual ao do indicador, porque os dois usam a mesma consulta **[P-17-01]**.
- **RN-17-003** — Indicadores com dado sensível (salário, raça, deficiência, saúde) só aparecem para quem tem acesso a eles. Nenhum painel mostra CID.
- **RN-17-004** — O topo de cada painel tem o filtro de **unidade** (dentro do escopo). Os relatórios também filtram por departamento, cargo, tipo de vínculo e período.

### 4.2 Painel do RH (D-440)

- **RN-17-010** — **Indicadores do protótipo**, com a definição de cada um **[P-17-02]**:

  | Indicador | O que conta | Linha de apoio |
  |---|---|---|
  | Admissões em andamento | Admissões não concluídas nem canceladas | Quantas têm correção pendente |
  | Documentos pendentes | Versões aguardando revisão mais pedidos ainda não atendidos | Quantos estão vencidos |
  | Aprovações aguardando | Solicitações paradas em etapa de gestor | Desde quando está a mais antiga |
  | Tarefas atrasadas | Itens de processo vencidos (RN-06-028) | Unidade com mais atrasos |
  | Vencimentos em 30 dias | Documentos, contratos de experiência e certificado A1 vencendo | Tipos mais comuns |
  | Colaboradores ativos | Vínculos ativos e afastados | Por unidade |

- **RN-17-011** — **Blocos do protótipo:**
  - **Resumo operacional** (spec 14);
  - **Pendências por unidade:** documentos, aprovações e atrasos por unidade;
  - **Próximos vencimentos:** os 10 mais próximos;
  - **Atividade recente:** os últimos 20 acontecimentos do escopo (envios, aprovações, admissões encaminhadas, materiais publicados), sem dado sensível **[P-17-03]**.
- **RN-17-012** — **Blocos dos módulos** (D-440), se o módulo está contratado e a pessoa tem acesso a ele **[P-17-04]**:

  | Módulo | Bloco |
  |---|---|
  | Ponto | Ausentes hoje, marcações fora da cerca de ontem, dias com inconsistência, ajustes pendentes, espelhos contestados |
  | Folha | Competência atual e o status dela (aberta, calculada, conferida, fechada), prazo de fechamento, divergências de conferência |
  | eSocial | Eventos rejeitados, eventos esperando envio, prazos dos próximos 7 dias, certificado vencendo |

- **RN-17-013** — Os botões do topo, como no protótipo: **Exportar** (seção 4.8) e **Nova admissão**.
- **RN-17-014** — Escopo: o RH administrador vê a empresa toda. O RH analista e o consultor veem as unidades deles, e os blocos de módulos só aparecem se o módulo estiver liberado para eles (spec 03).

### 4.3 Painel do gestor

- **RN-17-020** — No painel, o gestor vê **só a equipe** (D-190) **[P-17-05]**:
  - pessoas da equipe, ativas e afastadas;
  - ausências de hoje e da semana (férias, afastamentos e folgas; atestado aparece como "ausência", D-301);
  - aprovações esperando por ele;
  - banco de horas e horas extras do mês, por pessoa (com o módulo ponto);
  - vencimentos da equipe, só o texto (P-08-11);
  - fins de experiência;
  - o resumo operacional da equipe (spec 14).
- **RN-17-021** — A área "Minha equipe" do portal (spec 16) é a versão para celular deste painel.

### 4.4 Empresa e contrato

- **RN-17-030** — Na **empresa direta**, o RH administrador vê também o bloco **Contrato**: consumo de colaboradores, créditos de IA e mensagens de WhatsApp contra o plano, e a situação da cobrança (spec 19).
- **RN-17-031** — Na empresa de um parceiro, o RH administrador vê o consumo **da própria empresa** (colaboradores, IA, WhatsApp), mas não o do contrato do parceiro nem a cobrança **[P-17-06]**.

### 4.5 Visão consolidada do parceiro (D-442, D-450)

- **RN-17-040** — Quem vê: o **administrador do parceiro**, com a carteira toda, e o **consultor**, com as empresas atribuídas a ele (spec 03). A visão mostra **números por empresa**, nunca dados de pessoas. O administrador do parceiro não entra nas empresas (P-03-01). O consultor tem o link "Abrir empresa".
- **RN-17-041** — **Blocos** **[P-17-07]**:

  | Bloco | Por empresa |
  |---|---|
  | **Carteira e consumo** | Colaboradores ativos, módulos contratados, consumo de IA e WhatsApp, e os totais do contrato contra a cota (D-092, D-101, D-407). Situação da cobrança do parceiro (spec 19) |
  | **Saúde operacional** | Admissões paradas há mais de 3 dias, documentos e aprovações pendentes, itens atrasados, com sinal verde, amarelo ou vermelho |
  | **Folha e eSocial** | Status da competência, eventos rejeitados, prazos dos próximos 7 dias, certificado vencendo |
  | **Adoção** | % de colaboradores que entraram no portal nos últimos 30 dias, % com o app instalado ou push ativo, perguntas ao assistente no mês, % de documentos lidos pela IA |

- **RN-17-042** — **Sinais da saúde operacional:** verde sem atrasos; amarelo com qualquer item atrasado; vermelho com admissão parada há mais de 7 dias, evento do eSocial rejeitado há mais de 2 dias ou competência fora do prazo **[P-17-08]**.
- **RN-17-043** — **Comparação entre empresas** (D-450): turnover, absenteísmo, horas extras por colaborador e tempo médio de admissão, lado a lado e em ranking, do mês ou dos últimos 12 meses. Custo de pessoal e diversidade **não** entram. Empresas com menos de **5 colaboradores ativos** ficam fora da comparação de absenteísmo e turnover, para não expor pessoas **[P-17-09]**.

### 4.6 Relatórios gerenciais (D-441)

- **RN-17-050** — Cada relatório tem um gráfico (Chart.js, D-445) e uma tabela, e mostra até **24 meses**. Filtros: período, unidade, departamento, cargo e tipo de vínculo. Por padrão, entram CLT e estágio; PJ, autônomos e sócios aparecem no filtro de tipo de vínculo **[P-17-10]**.
- **RN-17-051** — **Quadro e movimentação** **[P-17-11]**:

  | Indicador | Fórmula |
  |---|---|
  | Quadro | Vínculos ativos e afastados no último dia do mês |
  | Admissões e desligamentos | Quantidade no mês. Os desligamentos são separados em voluntários e involuntários pelo motivo |
  | Turnover | ((admissões + desligamentos) ÷ 2) ÷ quadro médio do mês × 100 |
  | Turnover voluntário | Desligamentos voluntários ÷ quadro médio × 100 |
  | Tempo médio de admissão | Dias entre o cadastro inicial e a conclusão |
  | Tempo médio de casa | Do quadro do fim do mês |

- **RN-17-052** — **Absenteísmo e jornada** (com o módulo ponto; sem ele, só os atestados das solicitações) **[P-17-12]**:

  | Indicador | Fórmula |
  |---|---|
  | Absenteísmo | Horas de ausência (faltas não justificadas, atestados e atrasos além da tolerância) ÷ horas previstas × 100 |
  | Atestados | Dias e quantidade de atestados, **sem CID** |
  | Horas extras | Horas a 50% e a 100%, total e por colaborador |
  | Adicional noturno | Horas noturnas |
  | Banco de horas | Saldo total, positivo e negativo, e horas vencendo nos próximos 60 dias |

- **RN-17-053** — **Custo de pessoal** (D-444), só com as **folhas fechadas** **[P-17-13]**:
  - proventos, encargos (INSS da empresa, RAT, terceiros, FGTS) e benefícios pagos pela empresa;
  - por unidade, departamento e cargo (centro de custo, spec 12);
  - custo médio por colaborador e média salarial por cargo;
  - comparação com o mesmo mês do ano anterior.
- **RN-17-054** — **Diversidade** (D-448), só para o RH administrador **[P-17-14]**:
  - gênero, faixa etária (até 24, 25–34, 35–44, 45–54, 55 ou mais), raça/cor e PcD;
  - por unidade, departamento e nível de cargo;
  - qualquer grupo com menos de 5 pessoas aparece como **"< 5"**, inclusive nos totais que permitiriam descobrir o número;
  - "Não informado" aparece como categoria, porque raça/cor e deficiência são autodeclaradas;
  - não abre lista de pessoas.
- **RN-17-055** — Nos demais relatórios, clicar num número abre a lista de pessoas só se quem olha tiver acesso a esses dados (por exemplo, o gestor vê a lista das horas extras da equipe).

### 4.7 Foto diária (D-443)

- **RN-17-060** — Um job grava às **2h** (fuso da unidade) os números do dia anterior por empresa, unidade, departamento, cargo e tipo de vínculo, já agregados. Os relatórios leem só essas fotos **[P-17-15]**.
- **RN-17-061** — Toda noite, o job **recalcula os últimos 2 meses**, para absorver mudanças com data retroativa (revisões de vínculo, ajustes de ponto, desligamentos lançados depois). Meses mais antigos só são recalculados por pedido do suporte **[P-17-16]**.
- **RN-17-062** — O histórico começa no primeiro dia da empresa na plataforma. Na implantação, o quadro e a movimentação dos meses anteriores podem ser montados a partir dos dados importados (spec 18) **[P-17-17]**.
- **RN-17-063** — Os relatórios mostram "Dados até ontem, atualizados às 2h". O painel mostra os números na hora (D-443).
- **RN-17-064** — A foto de diversidade guarda **só contagens agregadas**, sem ligação com as pessoas **[P-17-18]**.

### 4.8 Exportação (D-446)

- **RN-17-070** — Formatos **[P-17-19]**:
  - **CSV:** UTF-8 com BOM e separador ponto e vírgula, que abre direto no Excel em português;
  - **XLSX:** gem `caxlsx`, com uma aba por tabela e os totais;
  - **PDF:** Prawn, com a marca, os filtros aplicados, as tabelas e gráficos de barras e linhas desenhados pelo próprio Prawn.
- **RN-17-071** — Exportações com até 5.000 linhas saem na hora. Acima disso, um job gera o arquivo, e a pessoa recebe o aviso `reports.export_ready` (spec 15). O link vale **24 horas** **[P-17-20]**.
- **RN-17-072** — Toda exportação gera um **evento de acesso** (D-085), com o relatório, os filtros e o formato. Exportações com dado sensível pedem a confirmação de senha ou passkey (RN-02-052).

### 4.9 Agendamento (D-449)

- **RN-17-080** — O RH administrador e o RH analista agendam os relatórios que eles mesmos podem ver, escolhendo **[P-17-21]**:
  - o relatório, os filtros e o formato;
  - a frequência: semanal (dia da semana) ou mensal (dia do mês);
  - os destinatários, **só usuários do sistema** que tenham permissão para aquele relatório.
- **RN-17-081** — Na data, o sistema gera o arquivo e manda o aviso `reports.scheduled_ready` (sino e e-mail), **sem anexo**, com o link. Ao abrir, a permissão é conferida de novo. Quem perdeu a permissão deixa de receber, e o dono do agendamento é avisado.
- **RN-17-082** — Agendamentos de quem perdeu o acesso ficam **pausados** até o RH administrador assumir ou excluir.

### 4.10 Desempenho

- **RN-17-090** — O painel abre em até **2 segundos** com 5.000 colaboradores. Os blocos carregam em paralelo, cada um numa requisição própria (`fetch`, JS puro), para que um bloco lento não segure os outros **[P-17-22]**.
- **RN-17-091** — Os números do painel ficam em cache por **60 segundos** por empresa e escopo, com a indicação "atualizado há X segundos" e o botão de atualizar **[P-17-23]**.

## 5. Estados

**Exportação:** `queued` → `ready` → `expired` | `failed`

**Agendamento:** `active` ⇄ `paused` → `deleted`

## 6. Permissões

| Ação | Quem |
|---|---|
| Painel do RH | RH administrador (T), RH analista e consultor (U) |
| Painel do gestor | Gestor (E) |
| Bloco Contrato (empresa direta) | RH administrador |
| Consumo da própria empresa (empresa de parceiro) | RH administrador **[P-17-06]** |
| Visão consolidada e comparação | Administrador do parceiro (carteira), consultor (empresas atribuídas) |
| Quadro e movimentação, absenteísmo e jornada | RH administrador (T), RH analista (U), gestor (E, da equipe) |
| Custo de pessoal | RH administrador (T), RH analista com o módulo folha (U) (D-444) |
| Diversidade | RH administrador (D-448) |
| Exportar | Quem vê o relatório (spec 03, "Exportar relatórios") |
| Agendar | RH administrador, RH analista |

## 7. Modelo de dados

```
company_daily_metrics                                 -- foto diária (D-443)
  id, company_id, date, unit_id, department_id, position_id, employment_kind,
  active_count, on_leave_count, admissions, terminations_voluntary,
  terminations_involuntary, admission_days_sum, admission_count_closed,
  tenure_days_sum, expected_hours, absence_hours, late_hours,
  medical_leave_days, medical_leave_count, overtime_50_hours, overtime_100_hours,
  night_hours, hour_bank_positive, hour_bank_negative
  -- único por (company_id, date, unit_id, department_id, position_id, employment_kind)

company_monthly_costs                                 -- das folhas fechadas
  id, company_id, period ('YYYY-MM'), unit_id, department_id, position_id,
  employment_kind, headcount, gross, employer_inss, rat, third_parties, fgts,
  benefits_cost, total_cost

company_diversity_snapshots                           -- só contagens (P-17-18)
  id, company_id, period, unit_id, department_id, position_level,
  dimension ('gender'|'age_band'|'race'|'disability'), value, count

activity_events
  id, company_id, unit_id, department_id, kind, actor_name, text, url, occurred_at

report_exports
  id, company_id (nullable = parceiro), requested_by_id, report, filters (jsonb),
  format ('csv'|'xlsx'|'pdf'), status, file (Active Storage), expires_at

report_schedules
  id, company_id, owner_id, report, filters (jsonb), format,
  frequency ('weekly'|'monthly'), day, recipient_ids (bigint[]), status, last_run_at
```

As tabelas de métricas não guardam o identificador de pessoas. As listas que um número abre são consultadas na hora nas tabelas de origem.

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Metrics::DailySnapshotJob` | 2h, diário, por fuso | Grava a foto do dia anterior e recalcula os últimos 2 meses |
| `Metrics::MonthlyCostJob` | Ao fechar uma folha | Grava o custo da competência |
| `Metrics::DiversitySnapshotJob` | Mensal, no 1º dia | Grava as contagens de diversidade do mês anterior |
| `Reports::ExportJob` | Sob demanda | Gera exportações grandes |
| `Reports::ScheduleJob` | A cada hora | Roda os agendamentos do horário |
| `Reports::PurgeExportsJob` | Diário | Apaga exportações vencidas |

- **Chart.js** pelo importmap, com os dados em JSON na página. Cores da marca (RN-16-083) **[P-17-24]**.
- **Avisos novos** no catálogo da spec 15: `reports.export_ready` e `reports.scheduled_ready` (não obrigatórios, sino e e-mail).

## 9. Critérios de aceite

- **CA-17-001** — Dado o indicador "Documentos pendentes" com 7, quando o RH clica nele, então a lista abre com os mesmos 7 documentos.
- **CA-17-002** — Dado um RH analista da unidade Caxias, quando abre o painel, então nenhum número inclui a unidade Bento Gonçalves.
- **CA-17-003** — Dada uma empresa sem o módulo folha, quando o RH abre o painel, então o bloco Folha não aparece.
- **CA-17-004** — Dado um gestor, quando abre o painel, então vê o banco de horas de cada pessoa da equipe, e um atestado aparece como "ausência".
- **CA-17-005** — Dado o administrador do parceiro, quando abre a visão consolidada, então vê os números de cada empresa, sem nenhum nome de colaborador, e não consegue abrir as listas.
- **CA-17-006** — Dada uma empresa com 3 colaboradores na carteira, quando o parceiro compara o absenteísmo, então essa empresa não aparece no ranking.
- **CA-17-007** — Dado um departamento com 2 pessoas PcD, quando o RH administrador abre a diversidade, então o número aparece como "< 5".
- **CA-17-008** — Dado um RH analista sem o módulo folha, quando procura o relatório de custo, então ele não aparece.
- **CA-17-009** — Dado um desligamento lançado hoje com data do mês passado, quando roda a foto da madrugada, então o turnover do mês passado é atualizado.
- **CA-17-010** — Dada uma exportação de 12.000 linhas, quando o RH pede o XLSX, então o arquivo é gerado em segundo plano, o aviso chega com o link, e o link expira em 24 horas.
- **CA-17-011** — Dado um agendamento mensal para um usuário que perdeu o perfil de RH, quando chega a data, então ele não recebe o aviso, e o dono do agendamento é avisado.
- **CA-17-012** — Dado o bloco de eSocial lento, quando o painel abre, então os outros blocos aparecem sem esperar por ele.

## 10. Propostas aprovadas (D-451)

| # | Proposta |
|---|---|
| P-17-01 | O indicador e a lista usam a mesma consulta |
| P-17-02 | Definição dos 6 indicadores do protótipo |
| P-17-03 | Atividade recente: últimos 20 acontecimentos, sem dado sensível |
| P-17-04 | Conteúdo dos blocos de ponto, folha e eSocial |
| P-17-05 | Conteúdo do painel do gestor |
| P-17-06 | Na empresa de parceiro, o RH administrador vê só o consumo da própria empresa |
| P-17-07 | Conteúdo dos 4 blocos da visão consolidada |
| P-17-08 | Regras dos sinais verde, amarelo e vermelho |
| P-17-09 | Comparação sem custo e diversidade; empresas com menos de 5 colaboradores ficam fora |
| P-17-10 | 24 meses de histórico; CLT e estágio por padrão |
| P-17-11 | Fórmulas de quadro, turnover e tempos |
| P-17-12 | Fórmulas de absenteísmo e jornada |
| P-17-13 | Custo de pessoal só com folhas fechadas, por centro de custo |
| P-17-14 | Faixas etárias, "< 5" também nos totais, "Não informado" e sem lista |
| P-17-15 | Foto às 2h, por fuso, já agregada |
| P-17-16 | Recalcular os últimos 2 meses toda noite |
| P-17-17 | Histórico anterior a partir dos dados importados |
| P-17-18 | Diversidade só com contagens, sem ligação com as pessoas |
| P-17-19 | Detalhes dos formatos CSV, XLSX e PDF |
| P-17-20 | Exportações grandes em segundo plano, link de 24 horas |
| P-17-21 | Regras do agendamento |
| P-17-22 | Painel em até 2 segundos, com blocos carregados em paralelo |
| P-17-23 | Cache de 60 segundos com botão de atualizar |
| P-17-24 | Chart.js com as cores da marca |
