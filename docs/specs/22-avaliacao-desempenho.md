# 22 — Avaliação de experiência e desempenho

> Status: aprovado · Última atualização: 2026-10-13
> Decisões: D-126, D-146, D-190, D-279, D-390, D-540 a D-551 ([decisoes.md](decisoes.md))
> Os itens **[P-22-nn]** foram todos aprovados sem ajuste (D-551, seção 10).

## 1. Objetivo

Dar ao gestor e ao colaborador **conversas de desempenho com base em registros**, e não na memória:

- avaliação de experiência ligada ao fim de cada período (D-540), como no protótipo do portal;
- ciclos de desempenho com autoavaliação, gestor, pares e ascendente (D-541), competências e metas (D-542);
- calibração (D-543), devolutiva e PDI (D-547);
- feedbacks contínuos (D-548);
- apoio da IA só com texto, nunca com notas (D-549).

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Competência | `Competency` | Comportamento avaliado, com descrição e exemplos por nota. Da biblioteca da plataforma ou da empresa (D-550) |
| Modelo de avaliação | `EvaluationTemplate` | As competências, a escala e as perguntas abertas de um tipo de avaliação, por cargo ou grupo de cargos |
| Avaliação de experiência | `ProbationReview` | Autoavaliação e avaliação do gestor antes do fim de um período de experiência |
| Ciclo | `PerformanceCycle` | Um período de desempenho (por exemplo, "2º semestre 2026"), com fases e pesos |
| Participante | `CycleParticipant` | Uma pessoa avaliada no ciclo, com o gestor da época |
| Meta | `Goal` | Uma meta individual do ciclo, com peso e resultado |
| Avaliação | `Review` | Uma avaliação preenchida: autoavaliação, gestor, par ou ascendente |
| Calibração | `CalibrationSession` | A reunião de calibração de uma área (D-543) |
| PDI | `DevelopmentPlan` | O plano de desenvolvimento que fecha o ciclo |
| Feedback | `Feedback` | Um feedback contínuo de uma pessoa para outra (D-548) |

## 3. Histórias de usuário

1. Como **recém-admitido**, quero fazer minha autoavaliação de experiência pelo celular antes do fim dos 45 dias.
2. Como **gestor**, quero avaliar a experiência e decidir a prorrogação com a avaliação em mãos.
3. Como **RH**, quero abrir o ciclo do 2º semestre e acompanhar quantas autoavaliações e avaliações de gestor faltam.
4. Como **colaboradora**, quero indicar três colegas para me avaliar e saber que as respostas são anônimas.
5. Como **gestor**, quero ver o resumo do que a equipe disse sobre mim, sem saber quem disse.
6. Como **RH**, quero calibrar as notas da área de produção, porque um gestor avalia todos com 5.
7. Como **colaborador**, quero ver minha nota final e meu PDI depois da conversa com o gestor.
8. Como **colega**, quero reconhecer pelo portal a ajuda que recebi de alguém de outra equipe.

## 4. Regras de negócio

### 4.1 Competências e modelos (D-550)

- **RN-22-001** — A plataforma mantém uma **biblioteca de competências** (D-126), cada uma com descrição e exemplos de comportamento por nota. A empresa **adota** (cópia independente, D-232), **ajusta** ou **cria** as próprias.
- **RN-22-002** — **Escala de 1 a 5**, com rótulos **[P-22-01]**:

  | Nota | Rótulo |
  |---|---|
  | 1 | Muito abaixo do esperado |
  | 2 | Abaixo do esperado |
  | 3 | Dentro do esperado |
  | 4 | Acima do esperado |
  | 5 | Muito acima do esperado |

  Cada item também aceita **"Não pude observar"**, que não entra na média.
- **RN-22-003** — **Modelos de avaliação** por tipo (experiência, desempenho, pares, ascendente), com 3 a 8 competências e até 3 perguntas abertas. O modelo de desempenho pode variar por **cargo** ou **grupo de cargos**. A plataforma traz modelos prontos para os grupos operacional, administrativo e liderança, e um modelo de experiência com as competências do protótipo (qualidade do trabalho, segurança e normas, trabalho em equipe, aprendizado das rotinas) **[P-22-02]**.

### 4.2 Avaliação de experiência (D-540)

- **RN-22-010** — A avaliação **abre junto com o aviso** de fim de cada período de experiência (RN-07-101, 10 dias antes por padrão), para o colaborador e para o gestor. A empresa pode desligar a avaliação de experiência.
- **RN-22-011** — **Ordem**, como no protótipo **[P-22-03]**:
  1. o colaborador faz a **autoavaliação** (notas e comentário), até **3 dias antes** do fim do período;
  2. o gestor faz a avaliação dele, vendo a autoavaliação. Se o colaborador não responder no prazo, o gestor avalia assim mesmo.
- **RN-22-012** — A avaliação do gestor termina com uma **recomendação**: efetivar, prorrogar (se ainda for possível) ou desligar, com justificativa. A recomendação aparece na tela da decisão da admissão (RN-07-101), mas **não decide sozinha**: quem registra a decisão é o RH ou o gestor, como na spec 07.
- **RN-22-013** — O colaborador vê a avaliação do gestor **depois da conversa de feedback**, registrada pelo gestor, e dá ciência (como RN-22-061) **[P-22-04]**.
- **RN-22-014** — Se o período terminar sem a avaliação do gestor, o RH é avisado, e a avaliação fica marcada como "não realizada".

### 4.3 Ciclo de desempenho (D-541, D-542, D-546)

- **RN-22-020** — O RH administrador (ou o RH analista, nas unidades dele, com o módulo `avaliacao`) cria o ciclo com **[P-22-05]**:
  - nome, período avaliado e fases com datas (abaixo);
  - modelos de avaliação por cargo ou grupo;
  - tipos de avaliação ligados (autoavaliação, gestor, pares, ascendente);
  - **pesos** (D-546);
  - **elegibilidade**.
- **RN-22-021** — **Fases** **[P-22-06]**:

  | Fase | O que acontece |
  |---|---|
  | Metas | O colaborador propõe as metas, e o gestor ajusta e aprova |
  | Acompanhamento | As metas podem ter atualizações de progresso. Os feedbacks contínuos seguem |
  | Indicação de pares | O colaborador indica os pares, e o gestor aprova |
  | Avaliação | Autoavaliação, pares, ascendente e gestor, nessa ordem de prazo |
  | Calibração | RH e gestores ajustam as notas finais |
  | Devolutiva | Reuniões de feedback, PDI e ciência |
  | Encerrado | Tudo em leitura |

- **RN-22-022** — **Elegibilidade padrão:** vínculos CLT e de estágio ativos, com pelo menos **90 dias** de casa na data de início da fase de avaliação. Quem está em experiência fica fora, porque tem a avaliação própria. Afastados ficam fora, e quem é desligado durante o ciclo sai dele. O RH pode incluir ou excluir pessoas à mão, com motivo **[P-22-07]**.
- **RN-22-023** — O **gestor avaliador** é o gestor do departamento da pessoa no início da fase de avaliação (D-190). Se a pessoa mudou de equipe durante o ciclo, o gestor anterior pode deixar um comentário, que o novo gestor vê **[P-22-08]**.

**Metas**

- **RN-22-030** — De 1 a 5 metas por pessoa, cada uma com título, como será medida, peso (a soma dá 100%) e o valor esperado **[P-22-09]**.
- **RN-22-031** — No fim, o gestor registra o resultado e o **atingimento**, convertido para a escala 1–5 **[P-22-10]**:

  | Atingimento | Nota |
  |---|---|
  | Menos de 50% | 1 |
  | 50% a 79% | 2 |
  | 80% a 99% | 3 |
  | 100% a 119% | 4 |
  | 120% ou mais | 5 |

  Metas qualitativas recebem a nota direto do gestor.

**Nota final** (D-546)

- **RN-22-040** — Pesos padrão, ajustáveis em cada ciclo **[P-22-11]**:
  - **competências 60%** e **metas 40%**;
  - dentro das competências: **gestor 60%**, **autoavaliação 20%**, **pares 20%**.
- **RN-22-041** — Se uma fonte não existir (pares desligados no ciclo, menos de 3 respostas de pares, metas não definidas), o peso dela é **redistribuído** proporcionalmente entre as outras, e a ficha mostra isso.
- **RN-22-042** — A **ascendente não entra** na nota de ninguém (D-546).
- **RN-22-043** — A nota final é mostrada com **uma casa decimal** e o rótulo da faixa mais próxima.

### 4.4 Pares e ascendente (D-544, D-545)

- **RN-22-050** — **Pares:** o colaborador indica de 2 a 5 colegas da empresa. O gestor aprova ou troca. Cada pessoa pode receber no máximo **6 pedidos** de avaliação de pares por ciclo, para não sobrecarregar ninguém **[P-22-12]**.
- **RN-22-051** — **Anonimato** (pares e ascendente) **[P-22-13]**:
  - o avaliado, o gestor e o RH veem só o **agregado** (média por competência) e os **comentários sem autor**;
  - o resultado só aparece com **pelo menos 3 respostas**; com menos, aparece "respostas insuficientes";
  - o RH vê **quem respondeu e quem falta**, para cobrar, mas nunca a resposta de cada um;
  - tecnicamente, a resposta é gravada **sem a ligação com quem respondeu**. A ligação fica só na tabela de pedidos, para controlar quem já respondeu.
- **RN-22-052** — **Ascendente:** cada pessoa da equipe avalia o gestor com o modelo ascendente. O resultado agregado vai para o **gestor**, para o **gestor dele** e para o **RH**. Não entra em nota (RN-22-042) **[P-22-14]**.
- **RN-22-053** — Os textos dos comentários anônimos aparecem **em ordem aleatória** e sem data, para dificultar a identificação.

### 4.5 Calibração (D-543)

- **RN-22-055** — O RH abre uma sessão de calibração por **área** (departamento ou unidade) e convida os gestores dela. A tela mostra **[P-22-15]**:
  - a distribuição das notas finais da área (gráfico);
  - a média por gestor, para comparar quem avalia mais alto ou mais baixo;
  - a lista de pessoas com a nota calculada, a avaliação do gestor e o resumo dos pares.
- **RN-22-056** — O RH ajusta a nota final de cada pessoa, com uma **justificativa** obrigatória. A nota calculada e o ajuste ficam no histórico.
- **RN-22-057** — Não há distribuição forçada (cota de notas). A sessão é encerrada pelo RH, e as notas ficam **calibradas**.

### 4.6 Devolutiva e PDI (D-542, D-547)

- **RN-22-060** — Depois da calibração, o gestor faz a **reunião de feedback** com cada pessoa e registra: data, pontos conversados e o **PDI** combinado.
- **RN-22-061** — Registrada a reunião, o colaborador vê no portal: a nota final calibrada, a avaliação do gestor por competência, o agregado e o resumo dos pares, as metas com o atingimento e o PDI. Ele dá **ciência** (como D-279) e pode escrever um comentário, que fica no histórico. Ciência não é concordância.
- **RN-22-062** — A **justificativa da calibração** é interna: o colaborador vê só a nota final **[P-22-16]**.
- **RN-22-063** — **PDI simples:** de 1 a 3 pontos de desenvolvimento, cada um com uma ou mais ações (curso, mentoria, projeto, leitura) e um prazo. O PDI aparece no início do ciclo seguinte, para revisão **[P-22-17]**.
- **RN-22-064** — Se o gestor não registrar a reunião até o fim da fase de devolutiva, o RH é avisado. O RH pode liberar o resultado ao colaborador sem a reunião, com justificativa **[P-22-18]**.

### 4.7 Feedbacks contínuos (D-548)

- **RN-22-070** — Qualquer pessoa da empresa com acesso ao portal ou ao painel dá feedback a um colega: tipo (**reconhecimento** ou **ponto de melhoria**), texto e, se quiser, a competência relacionada.
- **RN-22-071** — **Quem vê:** quem deu, quem recebeu e o **gestor de quem recebeu**. O feedback é **identificado** (não anônimo). O RH vê só contagens, como no protótipo ("Feedbacks registrados"), e não o conteúdo **[P-22-19]**.
- **RN-22-072** — Quem recebe pode **denunciar** um feedback inadequado (ofensivo ou discriminatório). Só nesse caso o RH vê o conteúdo, para tratar **[P-22-20]**.
- **RN-22-073** — Na avaliação do ciclo, o gestor vê os feedbacks que a pessoa recebeu no período avaliado.
- **RN-22-074** — Feedbacks não podem ser editados depois de enviados. Quem enviou pode apagar em até 24 horas **[P-22-21]**.

### 4.8 IA (D-549, spec 14)

- **RN-22-080** — **Resumo dos comentários:** a IA junta os comentários de pares, ascendente e feedbacks do período num resumo por temas (pontos fortes, pontos de atenção).
  - Fontes anônimas só entram com **pelo menos 3 respostas**, e o resumo **parafraseia**, sem citar frases literais que possam identificar quem escreveu **[P-22-22]**.
  - O gestor vê o resumo durante a avaliação. O colaborador vê o resumo do que recebeu depois da devolutiva.
- **RN-22-081** — **Sugestão de PDI:** a partir das competências com notas mais baixas e do resumo, a IA sugere pontos de desenvolvimento e ações. O gestor edita antes de registrar.
- **RN-22-082** — **Ajuda a escrever:** em qualquer campo de comentário (avaliações e feedbacks), o botão "Melhorar com IA" sugere um texto mais claro e específico. Um alerta aponta linguagem vaga ou enviesada, por exemplo referências a idade, gênero, aparência, gravidez ou vida pessoal. A pessoa decide o que fazer **[P-22-23]**.
- **RN-22-083** — A IA **nunca sugere, calcula ou comenta notas** (D-549). As notas também não são enviadas à IA, salvo a indicação das competências mais baixas para a sugestão de PDI **[P-22-24]**.
- **RN-22-084** — **Créditos** (spec 14): 1 por resumo, 1 por sugestão de PDI e 1 por texto melhorado **[P-22-25]**.

### 4.9 Indicadores

- **RN-22-090** — Painel do ciclo para o RH, como no protótipo: andamento da autoavaliação, da avaliação do gestor, dos pares, da ascendente, da calibração e da devolutiva, com cobrança em um clique para quem está atrasado. Depois do encerramento: distribuição das notas por área e a evolução em relação ao ciclo anterior **[P-22-26]**.

### 4.10 Retenção e uso

- **RN-22-095** — Avaliações, PDIs e feedbacks são dados da relação de trabalho. Seguem a retenção do vínculo (spec 05) e entram na exportação completa (spec 18).
- **RN-22-096** — O sistema não liga a nota a salário nem a promoção. O RH usa os resultados nas próprias decisões, fora do módulo **[P-22-27]**.

## 5. Estados

**Avaliação de experiência:** `open` → `self_done` → `manager_done` → `feedback_given` → `acknowledged` · `not_done`

**Ciclo:** `draft` → `goals` → `tracking` → `nominations` → `reviews` → `calibration` → `feedback` → `closed`

**Avaliação (`Review`):** `pending` → `draft` → `submitted`

**Pedido de par:** `proposed` → `approved` | `replaced` → `answered` | `declined`

**Feedback:** `sent` → (`deleted` em até 24 h) · `reported` → `resolved`

## 6. Permissões

Spec 03, seção 4.9, com o detalhe:

| Ação | Quem |
|---|---|
| Biblioteca de competências da plataforma | Superadmin, suporte |
| Competências e modelos da empresa, ciclos | RH administrador (T), RH analista com o módulo `avaliacao` (U) |
| Autoavaliação, indicar pares, metas próprias | Colaborador |
| Avaliar a equipe, aprovar metas e pares, devolutiva e PDI | Gestor (E) |
| Avaliar pares e o próprio gestor | Colaborador indicado ou da equipe |
| Ver resultados de pares e ascendente | Só agregados, com 3 ou mais respostas: avaliado, gestor dele e RH |
| Calibrar | RH administrador, RH analista (U); gestores convidados veem a área e opinam |
| Ver resultados da equipe | Gestor (E), RH (T/U) |
| Ver o próprio resultado | Colaborador, depois da devolutiva |
| Dar feedback contínuo | Qualquer usuário da empresa |
| Ver conteúdo de feedback | Quem deu, quem recebeu e o gestor de quem recebeu; o RH só se denunciado |

## 7. Modelo de dados

```
competencies
  id, company_id (nullable = biblioteca), name, description,
  level_examples (jsonb: 1..5), adopted_from_id, status

evaluation_templates
  id, company_id (nullable = biblioteca), kind ('probation'|'performance'|'peer'|'upward'),
  name, position_ids (bigint[]), position_group, open_questions (jsonb)

evaluation_template_items
  evaluation_template_id, competency_id, position

probation_reviews
  id, company_id, employment_id, period_number (1|2), due_on, status,
  manager_id, recommendation ('confirm'|'extend'|'terminate'),
  recommendation_note, feedback_given_at, acknowledged_at, ack_comment

performance_cycles
  id, company_id, name, period_start, period_end, phases (jsonb: datas por fase),
  weights (jsonb), enabled_kinds (text[]), eligibility (jsonb), status

cycle_participants
  id, performance_cycle_id, employment_id, manager_id, template_id,
  calculated_score, final_score, calibration_note, calibrated_by_id,
  feedback_meeting_at, feedback_notes, acknowledged_at, ack_comment,
  released_without_meeting_note

goals
  id, cycle_participant_id, title, measure, weight, target, result,
  achievement_pct, score, status

reviews                                              -- autoavaliação e gestor
  id, company_id, subject_type ('ProbationReview'|'CycleParticipant'), subject_id,
  kind ('self'|'manager'), reviewer_id, ratings (jsonb), comments (jsonb),
  status, submitted_at

anonymous_review_requests                            -- quem foi chamado e se respondeu
  id, cycle_participant_id, kind ('peer'|'upward'), reviewer_id, status,
  nominated_by_id, approved_by_id

anonymous_review_answers                             -- respostas sem o avaliador
  id, cycle_participant_id, kind, ratings (jsonb), comments (jsonb), submitted_on

calibration_sessions
  id, performance_cycle_id, scope_type ('Department'|'Unit'), scope_id,
  participant_manager_ids (bigint[]), status, closed_at

development_plans
  id, cycle_participant_id (ou probation_review_id), items (jsonb: [{area, actions, due_on}])

feedbacks
  id, company_id, from_user_id, to_employment_id, kind ('recognition'|'improvement'),
  competency_id, text, created_at, deleted_at, reported_at, report_reason,
  resolved_by_id, resolution_note
```

A tabela `anonymous_review_answers` não tem coluna de avaliador e guarda só a data (sem hora) do envio. O status do pedido é atualizado na mesma transação, sem gravar qual resposta veio de qual pedido (RN-22-051).

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Probation::OpenReviewsJob` | Junto do aviso da RN-07-101 | Abre as avaliações de experiência |
| `Performance::PhaseJob` | Diário | Avança as fases do ciclo e manda os avisos |
| `Performance::RemindersJob` | Diário | Cobra pendências perto do prazo |
| `Performance::ScoresJob` | Ao fechar a fase de avaliação | Calcula as notas com os pesos e as redistribuições |
| `Performance::SummarizeJob` | Sob demanda | Resumo dos comentários pela IA (fila `ai`) |

- **Avisos novos** no catálogo da spec 15: `performance.probation_review_open` (colaborador e gestor), `performance.cycle_phase_started`, `performance.review_pending`, `performance.peer_nomination_pending` (gestor), `performance.calibration_invite`, `performance.result_released` (colaborador, obrigatório) e `feedback.received`. Exceto o resultado, nenhum é obrigatório; todos em S E P.

## 9. Critérios de aceite

- **CA-22-001** — Dado um contrato de experiência de 45 + 45 dias com aviso de 10 dias, quando faltam 10 dias para o fim do primeiro período, então o colaborador e o gestor recebem a avaliação de experiência.
- **CA-22-002** — Dada a avaliação de experiência com a recomendação "prorrogar", quando o RH abre a decisão da admissão, então vê a recomendação e a justificativa, e a decisão continua manual.
- **CA-22-003** — Dados pesos de gestor 60%, autoavaliação 20% e pares 20%, e só 2 respostas de pares, quando a nota é calculada, então o peso dos pares é redistribuído para gestor e autoavaliação, e a ficha mostra isso.
- **CA-22-004** — Dadas 2 respostas na avaliação ascendente de um gestor, quando ele abre o resultado, então vê "respostas insuficientes".
- **CA-22-005** — Dadas 4 respostas de pares, quando o RH abre o acompanhamento, então vê quem respondeu, mas não consegue ver a resposta de cada um.
- **CA-22-006** — Dada uma nota calibrada de 4,2 para 3,8, quando o colaborador vê o resultado, então vê 3,8, sem a justificativa da calibração.
- **CA-22-007** — Dado um gestor que ainda não registrou a reunião de feedback, quando o colaborador abre o portal, então não vê o resultado do ciclo.
- **CA-22-008** — Dado um feedback de melhoria para uma colega, quando o RH abre o painel, então vê só a contagem de feedbacks, sem o texto.
- **CA-22-009** — Dado um comentário "ele é velho demais para aprender", quando o avaliador usa "Melhorar com IA", então aparece o alerta de linguagem enviesada.
- **CA-22-010** — Dado o resumo de comentários de pares, quando a IA gera o texto, então ele não traz frases literais dos comentários anônimos e não menciona notas.

## 10. Propostas aprovadas (D-551)

| # | Proposta |
|---|---|
| P-22-01 | Escala 1–5 com rótulos e "Não pude observar" |
| P-22-02 | Modelos prontos (operacional, administrativo, liderança e experiência) |
| P-22-03 | Experiência: autoavaliação até 3 dias antes; o gestor avalia mesmo sem ela |
| P-22-04 | O colaborador vê a avaliação de experiência depois da conversa |
| P-22-05 | Configuração do ciclo |
| P-22-06 | Fases do ciclo |
| P-22-07 | Elegibilidade padrão (90 dias de casa, sem experiência e afastados) |
| P-22-08 | Gestor avaliador é o do início da avaliação; o anterior pode comentar |
| P-22-09 | De 1 a 5 metas com pesos |
| P-22-10 | Conversão do atingimento das metas para a escala |
| P-22-11 | Pesos padrão (60/40; gestor 60, auto 20, pares 20) |
| P-22-12 | Limite de 6 pedidos de pares por pessoa no ciclo |
| P-22-13 | Regras técnicas do anonimato |
| P-22-14 | Ascendente visível ao gestor, ao gestor dele e ao RH |
| P-22-15 | Tela de calibração (distribuição, média por gestor) |
| P-22-16 | Justificativa da calibração é interna |
| P-22-17 | PDI com 1 a 3 pontos, revisado no ciclo seguinte |
| P-22-18 | RH libera o resultado sem reunião, com justificativa |
| P-22-19 | Feedback identificado; RH vê só contagens |
| P-22-20 | Denúncia de feedback inadequado |
| P-22-21 | Feedback apagável em até 24 horas |
| P-22-22 | Resumo da IA sem frases literais de fontes anônimas |
| P-22-23 | "Melhorar com IA" com alerta de linguagem enviesada |
| P-22-24 | Notas não vão à IA, salvo as competências mais baixas para o PDI |
| P-22-25 | Créditos de IA da avaliação |
| P-22-26 | Painel do ciclo com cobrança em um clique |
| P-22-27 | Sem ligação automática com salário e promoção |
