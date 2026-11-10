# CatalystHR — Regras para conferência do especialista em DP

> Data: 2026-10-13 · Atualizado: 2026-11-10 · Áreas: departamento pessoal, folha, eSocial e contabilidade trabalhista

## Sobre o produto

O CatalystHR é uma plataforma de RH na nuvem para empresas de todos os portes. Ela é vendida por parceiros (consultorias e escritórios, com a marca deles) e também diretamente. O sistema calcula ponto, banco de horas, férias, rescisão e folha, e transmite os eventos ao eSocial.

Os padrões descritos aqui vieram do nosso conhecimento da legislação. **Precisam de conferência** antes da implementação. Tudo o que muda por convenção coletiva fica configurável por empresa. O que precisamos é que os **padrões** e as **regras fixas** estejam certos.

## Como responder

Para cada item: **correto**, **incorreto** (com a regra certa e o fundamento) ou **depende** (de quê). Os códigos entre parênteses são referências internas.

**Prioridade:**
- **A:** antes do primeiro cliente (solicitações, atestados e desligamento);
- **B:** antes do módulo de ponto;
- **C:** antes do módulo de folha (inclui as férias).

---

## 1. Entregas que precisamos de você

- [ ] **1.1 Anexo de rubricas e incidências (C).** O catálogo padrão de rubricas, com:
  - natureza do eSocial (tabela 03);
  - tipo (provento, desconto ou informativa);
  - incidências de INSS, IRRF e FGTS;
  - se entra nas médias de férias, de 13º e de rescisão.

  As empresas usam essas rubricas sem poder mudar as incidências.
- [ ] **1.2 Casos de teste da folha (C).** Uma planilha de cenários com o resultado esperado, para servir de teste automático:
  - mensal com horas extras e faltas;
  - adiantamento;
  - férias com abono e médias;
  - 13º (1ª e 2ª parcelas);
  - rescisões (sem justa causa, com justa causa, pedido de demissão, acordo, fim de contrato de experiência);
  - pró-labore, estágio e autônomo (RPA);
  - pensão alimentícia;
  - consignado acima da margem.
- [ ] **1.3 Tabela de prazos do eSocial (C).** O prazo de cada evento do MVP (item 6.2).

## 2. Férias e solicitações — férias com prioridade C, demais itens com prioridade A

- [ ] **2.1 (C) Validações do pedido de férias**, que o sistema bloqueia (o RH pode forçar com justificativa):
  - até 3 períodos, um com pelo menos 14 dias e os outros com pelo menos 5 (art. 134, § 1º);
  - não começar nos 2 dias anteriores a feriado ou ao DSR (art. 134, § 3º);
  - aviso ao colaborador com 30 dias de antecedência (art. 135);
  - abono pecuniário de até 1/3 (art. 143);
  - adiantamento da 1ª parcela do 13º, se pedido no prazo (Lei 4.749/65);
  - dias limitados ao saldo do período (art. 130);
  - estagiário: recesso de 30 dias ou proporcional (Lei 11.788/08, art. 13).
- [ ] **2.2 (C) Saldo e períodos aquisitivos:** um período a cada 12 meses; as faltas injustificadas reduzem os dias (art. 130); afastamentos longos podem zerar o período (art. 133).
- [ ] **2.3 (C) Férias vencidas:** aviso ao RH 60 dias antes do fim do período concessivo (pagamento em dobro, art. 137).
- [ ] **2.4 (C) Férias coletivas:** até 2 períodos por ano, nenhum com menos de 10 dias; comunicação ao sindicato e ao órgão do Ministério do Trabalho com 15 dias de antecedência, com dispensa da comunicação ao Ministério para ME e EPP (art. 139; LC 123/06, art. 51). Quem não completou o período aquisitivo tira férias proporcionais e começa um novo período (art. 140).
- [ ] **2.5 (A) Atestados:**
  - até 15 dias, somando os atestados pelo mesmo motivo dentro de 60 dias, é ausência justificada paga pela empresa;
  - acima disso, é afastamento previdenciário (S-2230), e o vínculo fica afastado a partir do 16º dia.

  Confirmar a regra de soma.
- [ ] **2.6 (A) Aviso prévio:**
  - 30 dias mais 3 por ano completo, até 90, quando o empregador dispensa (Lei 12.506/11);
  - 30 dias no pedido de demissão;
  - redução de 2 horas por dia ou 7 dias corridos no aviso trabalhado (art. 488);
  - cálculo da data projetada.
- [ ] **2.7 (A) Prazos da rescisão:** pagamento em 10 dias corridos do término (art. 477, § 6º).
- [ ] **2.8 (A) Exame demissional:** exigido conforme a NR-7, com dispensa se o último exame ocupacional for recente. Quais são os prazos por grau de risco?
- [ ] **2.9 (A) Contrato de experiência:** soma de até 90 dias e uma única prorrogação (arts. 445 e 451). Sem decisão até o fim, o contrato passa a prazo indeterminado. Se o RH já informou a prorrogação no cadastro (por exemplo, 45 + 45), o sistema entende que ela consta do contrato assinado e passa ao segundo período sozinho, com aviso ao RH (D-648). Está correto? Isso depende de o contrato prever a prorrogação automática?
- [ ] **2.9.1 (A) Exame admissional:** a admissão registra a data do exame e avisa quando ele é posterior ao início, sem bloquear. O vínculo ativa na data de início mesmo sem ASO, com alerta (art. 168 e NR-7, D-651). Isso basta? Existe dispensa de exame recente que devamos tratar? Com o ASO inapto, o vínculo não ativa até o RH cancelar ou reavaliar (D-653). Está correto?
- [ ] **2.9.2 (A) Experiência por categoria e contagem:** o sistema só aceita experiência em CLT da categoria padrão, e não em aprendiz, temporário ou intermitente, e conta o dia de início: 45 dias a partir de 01/11 terminam em 15/12 (D-653). Está correto? O afastamento durante a experiência suspende a contagem?
- [ ] **2.10 (A) Tipos de desligamento:** sem justa causa, justa causa, pedido de demissão, acordo (art. 484-A), término de contrato determinado ou de experiência, falecimento. Falta algum?

## 3. Jornada e banco de horas — prioridade B

- [ ] **3.1 Regra "CLT padrão"**, que vem pronta e pode ser ajustada por empresa:

  | Item | Padrão proposto |
  |---|---|
  | Tolerância | 5 minutos por marcação e 10 por dia (art. 58, § 1º) |
  | Hora extra | 50% em dia útil; 100% em domingo e feriado não compensados |
  | Limite diário | Alerta acima de 2 horas extras (art. 59) |
  | Noturno urbano | 22h às 5h, 20%, hora reduzida de 52min30s (art. 73), com prorrogação (Súmula 60, II, TST) |
  | DSR | Perde o DSR na semana com falta injustificada (Lei 605/49). Faltas abonadas, atestados e férias não tiram o DSR |
  | Interjornada | 11 horas (art. 66) |
  | Intrajornada | 1 hora acima de 6 horas de trabalho; 15 minutos entre 4 e 6 horas (art. 71) |
  | Intervalo suprimido | Pago com 50% sobre o tempo suprimido (art. 71, § 4º) |
  | 12x36 | Feriados e prorrogação noturna considerados compensados (art. 59-A e CCT) |

- [ ] **3.2 Noturno rural:** lavoura das 21h às 5h e pecuária das 20h às 4h, 25%, sem hora reduzida (Lei 5.889/73, art. 7º).
- [ ] **3.3 Jornada que passa da meia-noite** é apurada no dia em que começou.
- [ ] **3.4 Dia com número ímpar de marcações** (faltou uma) fica inconsistente e não gera falta nem extra até ser tratado.
- [ ] **3.5 Intervalo pré-assinalado:** descontado sem marcação, mas, se houver marcações de intervalo, valem elas.
- [ ] **3.6 Banco de horas:**
  - acordo individual (compensação em até 6 meses, art. 59, § 5º), coletivo (até 12 meses, § 2º) ou mensal (no próprio mês, § 6º);
  - créditos com vencimento, e débitos consumindo os créditos mais antigos;
  - no vencimento, o saldo positivo é pago como extra, e o negativo é descontado (se o acordo permitir) ou zerado.
- [ ] **3.7 Ponto facultativo** é dia normal, a menos que a empresa dispense o trabalho.
- [ ] **3.8 Feriados nacionais** usados nos prazos em dias úteis e no ponto: 1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11 (Lei 14.759/2023) e 25/12, mais a Sexta-feira da Paixão, que é feriado religioso municipal (Lei 9.093/1995), mas entra como nacional, e o RH pode desmarcá-la na unidade. Carnaval e Corpus Christi ficam fora, como ponto facultativo. Está correto? Falta algum?

## 4. Folha — prioridade C, salvo indicação no item

- [ ] **4.1 Tabelas legais**, mantidas pela plataforma com vigência: INSS do empregado e teto; IRRF mensal com deduções e desconto simplificado; IR exclusivo da PLR; salário mínimo; salário-família; dedução por dependente; alíquotas patronais; transição da desoneração (CPRB) até 2028. Qual data vale para cada tabela: a competência ou a data de pagamento (regime de caixa do IRRF)?
- [ ] **4.2 Tipos de folha:**

  | Folha | Regra proposta |
  |---|---|
  | Mensal | Salário proporcional, variáveis, benefícios, descontos, INSS, IRRF, FGTS, desconto do adiantamento |
  | Adiantamento quinzenal | 40% de padrão (configurável), sem INSS, IRRF pela regra vigente, descontado na mensal |
  | Complementar | Diferenças de competência já fechada (por exemplo, dissídio retroativo) |
  | 13º, 1ª parcela | Metade, até 30/11 ou junto das férias, sem descontos |
  | 13º, 2ª parcela | Até 20/12, INSS e IRRF sobre o total, médias de variáveis |
  | Férias | 1/3, abono, médias do período aquisitivo, adiantamento do 13º, pagamento até 2 dias antes (art. 145) |
  | Rescisão | Saldo de salário, aviso, férias vencidas e proporcionais com 1/3, 13º proporcional, médias, multa do FGTS (40% ou 20% no acordo), descontos, TRCT |
  | PLR | IR exclusivo, sem INSS e FGTS |

- [ ] **4.3 Médias de variáveis** (extras, noturno, comissões) para férias, 13º e rescisão: qual é o período e o método padrão da CLT (quantidade ou valor, corrigido ou não)?
- [ ] **4.4 Outros vínculos:**
  - pró-labore: 11% do contribuinte individual até o teto, patronal conforme o regime, IRRF, sem FGTS;
  - estágio: bolsa e auxílio-transporte, sem INSS e FGTS, com IRRF;
  - autônomo (RPA): 11% retido, 20% patronal, IRRF e ISS conforme o município.
- [ ] **4.5 VT:** desconto de até 6% do salário-base, limitado ao custo do benefício.
- [ ] **4.6 Pensão alimentícia:** percentual sobre o líquido ou o bruto, com ou sem 13º e férias, ou valor fixo; dedução no IRRF.
- [ ] **4.7 Consignado:** controle da margem consignável. Qual é o limite vigente? A parcela acima da margem não é descontada e gera alerta.
- [ ] **4.8 Crédito do Trabalhador:** como os contratos chegam à empresa e como os descontos são informados e repassados?
- [ ] **4.9 Pagamento:** padrão no 5º dia útil do mês seguinte (art. 459, § 1º).
- [ ] **4.10 Holerite:** empresa, competência, rubricas com referência e valor, bases de INSS, FGTS e IRRF, FGTS do mês, líquido. Falta algum campo obrigatório?
- [ ] **4.11 Informe de rendimentos:** até o último dia útil de fevereiro, para todos que receberam no ano anterior.
- [ ] **4.12 Relatórios contábeis:** resumo por rubrica e centro de custo; encargos (INSS patronal, RAT ajustado, terceiros, FGTS); provisões de férias e 13º; lançamentos contábeis por rubrica. Falta algo que a contabilidade costuma pedir?
- [ ] **4.13 NF de prestador PJ:** sem retenções nem EFD-Reinf (D-359). Isso vale para todos os casos?
- [ ] **4.14 Desoneração:** a plataforma gera a base e o valor da CPRB, e a contabilidade envia o R-2060 da EFD-Reinf (D-370). Está correto?
- [ ] **4.15 (A) Reajuste coletivo por percentual:** no reajuste em massa (por exemplo, um dissídio), o percentual incide sobre o salário em vigor na data da revisão, e o resultado é arredondado para o centavo mais próximo, com o meio para cima: R$ 2.345,67 com 5% dá R$ 2.462,95 (D-669). Está correto? Existe regra legal ou costume de convenção coletiva que mande arredondar de outro jeito, por exemplo sempre para cima ou para o real inteiro?

## 5. Indicadores — prioridade C

- [ ] **5.1 Turnover** = ((admissões + desligamentos) ÷ 2) ÷ quadro médio do mês × 100. **Turnover voluntário** = desligamentos voluntários ÷ quadro médio × 100.
- [ ] **5.2 Absenteísmo** = horas de ausência (faltas injustificadas, atestados e atrasos acima da tolerância) ÷ horas previstas × 100.
- [ ] **5.3 Custo de pessoal** = proventos, encargos (INSS da empresa, RAT, terceiros, FGTS) e benefícios pagos pela empresa, só com as folhas fechadas.

## 6. eSocial — prioridade C

- [ ] **6.1 Eventos do MVP:**
  - tabelas: S-1000, S-1005, S-1010, S-1020;
  - não periódicos: S-2190, S-2200, S-2205, S-2206, S-2230, S-2299, S-2300, S-2306, S-2399, S-3000;
  - periódicos: S-1200, S-1210, S-1280, S-1298, S-1299.

  Os eventos de SST (S-2210, S-2220, S-2240) ficam com a clínica ou o SESMT (D-371). Falta algum evento essencial?
- [ ] **6.2 Prazos:** confirmar o prazo de cada evento. Exemplos que temos: S-2200 até o dia anterior ao início; periódicos até o dia 15 do mês seguinte.
- [ ] **6.3 Autônomo:** entendemos que o S-2300 é facultativo para o contribuinte individual autônomo e que a remuneração vai no S-1200. Por isso, a plataforma não envia o S-2300. Está correto?
- [ ] **6.4 S-2190:** é oferecido quando a admissão está perto do prazo e os dados ainda estão incompletos. Está correto?
- [ ] **6.5 Migração:** a empresa importa os XMLs já transmitidos e escolhe a competência de corte. A partir dela, a plataforma transmite. Retificações de competências anteriores usam os recibos importados. Há algum risco?
- [ ] **6.6 Guias:** FGTS Digital e DCTFWeb são emitidas no portal oficial, e o sistema confere os valores com o esperado. Está correto?
- [ ] **6.7 Colaboradores alocados em clientes:** a empresa pode ser a empregadora e alocar colaboradores em clientes dela, e o vínculo indica o cliente (D-570). Essa alocação exige informar o tomador em algum evento do eSocial ou em outra obrigação, por exemplo no trabalho temporário ou na cessão de mão de obra? Em quais casos?

---

## Contato

Responsável pelo CatalystHR: _preencher_ · Prazo desejado para os itens de prioridade A: _preencher_
