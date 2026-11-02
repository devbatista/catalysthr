# 06 — Modelos de processo

> Status: aprovado · Última atualização: 2026-10-14
> Decisões: D-091, D-126, D-143, D-171, D-203, D-204, D-213, D-230 a D-242, D-570, D-638 a D-641 ([decisoes.md](decisoes.md))
> Os itens **[P-06-01]** a **[P-06-20]** foram todos aprovados sem ajuste (D-241, seção 10). Os itens **[P-06-21]** e **[P-06-22]** (clientes de alocação, D-570) foram aprovados sem ajuste (D-572).

## 1. Objetivo

Oferecer um motor único de **modelos de processo**, usado por admissão, integração, desligamento e fluxos de solicitação (D-230). Com ele:

- a equipe CatalystHR, os parceiros e as empresas montam checklists reutilizáveis;
- cada processo nasce como cópia do modelo (D-091), com responsáveis, prazos e dependências já calculados.

As specs de cada processo (07 admissão, 09 solicitações) usam este motor e definem as regras próprias.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Modelo | `ProcessTemplate` | Checklist reutilizável de um tipo (admissão, integração, desligamento, fluxo de solicitação) |
| Item do modelo | `ProcessTemplateItem` | Uma tarefa do modelo, com tipo, responsável, prazo, condições e dependências |
| Processo | `ProcessInstance` | Um processo em andamento, criado como cópia do modelo |
| Item do processo | `ProcessItem` | A cópia de um item no processo, já com pessoa responsável e data de prazo |

### Níveis de modelo (D-126, D-232)

```
Biblioteca CatalystHR ──adotar (cópia)──► Modelos do parceiro ──adotar (cópia)──► Modelos da empresa
        └─────────────────────────adotar (cópia)───────────────────────────────►┘ (empresa direta)
```

- Adotar sempre cria uma **cópia independente** (D-232). A cópia guarda de onde veio (`source_template_id`) só para informação. Mudanças no original não chegam à cópia.
- **Processos só usam modelos da empresa.** Para usar um modelo do parceiro ou da biblioteca, a empresa adota antes, e com isso cria a cópia dela **[P-06-01]**.
- **O que cada empresa vê para adotar** **[P-06-02]**:
  - empresa de parceiro: os modelos do parceiro e a biblioteca;
  - empresa direta: a biblioteca.

### Quem edita

| Nível | Quem edita |
|---|---|
| Biblioteca | Superadmin e suporte (spec 03, 4.1) |
| Parceiro | Administrador do parceiro (spec 03, 4.1) |
| Empresa | RH administrador (D-240) |

## 3. Histórias de usuário

1. Como **suporte CatalystHR**, quero manter um modelo "Admissão CLT padrão" na biblioteca, para que empresas diretas comecem rápido.
2. Como **administrador do parceiro**, quero adaptar o modelo da biblioteca com o jeito da minha consultoria e oferecer aos meus clientes.
3. Como **RH administrador**, quero adotar o modelo do parceiro e incluir o item "Integração de segurança" só para a unidade da fábrica.
4. Como **RH**, quero que os prazos se calculem sozinhos a partir da data de início do colaborador.
5. Como **RH**, quero que "Encaminhar à contabilidade" só seja liberado depois que todos os documentos estiverem validados.
6. Como **colaborador**, quero ler o código de conduta e confirmar a leitura pelo portal.

## 4. Regras de negócio

### Modelo

- **RN-06-001** — O modelo tem:
  - nome, descrição e tipo (`admission`, `onboarding`, `offboarding`, `request_flow`);
  - dono: biblioteca, parceiro ou empresa;
  - status: `draft`, `active` ou `archived`;
  - origem: o modelo de onde foi copiado.
- **RN-06-002** — Só modelos `active` podem ser adotados ou iniciar processos. Arquivar um modelo não afeta os processos já iniciados (D-091).
- **RN-06-003** — Cada empresa marca um modelo padrão por tipo. O cargo pode apontar um modelo de admissão específico (D-204), que tem prioridade sobre o padrão **[P-06-03]**.
- **RN-06-004** — Um modelo de admissão pode indicar um modelo de integração, que começa automaticamente quando a admissão é concluída **[P-06-04]**.

### Itens

- **RN-06-010** — Tipos de item (D-231):

  | Tipo | Código | O responsável... | Concluído quando |
  |---|---|---|---|
  | Tarefa | `task` | faz algo fora do sistema | marca como feito, com comentário opcional |
  | Envio de documento | `document` | envia um arquivo de um tipo de documento (spec 08) | o RH valida o documento |
  | Formulário | `form` | preenche campos | o RH revisa e aplica (RN-06-030) |
  | Leitura e aceite | `acknowledgement` | lê um material e confirma | confirma a leitura (data, hora e IP registrados) |
  | Encaminhamento | `forward` | envia arquivos e dados a alguém de fora | o destinatário confirma o recebimento |
  | Aprovação | `approval` | aprova ou reprova, com justificativa na reprovação | aprova; se reprovar, o processo segue a regra da spec que o usa |

- **RN-06-011** — Cada item tem:
  - título e instruções;
  - obrigatório ou opcional;
  - responsável (por papel), prazo, condições e dependências;
  - configuração própria do tipo (por exemplo, o tipo de documento ou os campos do formulário).

### Responsáveis (D-234)

- **RN-06-020** — Papéis disponíveis no modelo **[P-06-05]**:

  | Papel | Vira, quando o processo começa |
  |---|---|
  | `employee` | A pessoa do processo |
  | `hr` | O RH responsável pelo processo (quem iniciou, se for RH; senão, o RH da unidade) |
  | `manager` | Os gestores do departamento da pessoa. Qualquer um conclui (D-203) |
  | `upper_manager` | O gestor acima (RN-04-024) |
  | `accountant` | O escritório contábil ligado à empresa (D-171) |
  | `client_manager` | Os gestores do cliente de alocação da pessoa (RN-04-095). Qualquer um conclui. Só aparece em empresa que usa clientes de alocação (D-570) **[P-06-21]** |
  | `initiator` | Quem iniciou o processo |

- **RN-06-021** — Depois de iniciado o processo, o RH pode trocar o responsável de qualquer item (D-091).
- **RN-06-022** — Se um papel não tem ninguém (por exemplo, o departamento não tem gestor, a empresa não tem escritório contábil, ou a pessoa está "sem cliente" ou num cliente sem gestor), o item vai para o RH e o processo mostra um alerta **[P-06-06]**.

### Prazos (D-235, D-236)

- **RN-06-025** — O prazo é "N dias antes ou depois de uma data do processo", em dias corridos ou úteis, escolhido por item. As datas de referência dependem do tipo **[P-06-07]**:

  | Tipo | Datas de referência |
  |---|---|
  | Admissão | Início do processo, data prevista de início do trabalho |
  | Integração | Data de início do trabalho |
  | Desligamento | Início do processo, data do desligamento |
  | Fluxo de solicitação | Abertura da solicitação, data do pedido (por exemplo, início das férias) |

- **RN-06-026** — Dias úteis excluem sábados, domingos, feriados nacionais e os feriados da unidade da pessoa (D-236). O calendário de feriados é o mesmo do ponto ([spec 11](11-jornada-banco-de-horas.md)).
- **RN-06-029** — Origem dos feriados (D-242):
  - a equipe CatalystHR carrega os feriados nacionais, os estaduais e os municipais das cidades onde há unidades de clientes;
  - o RH complementa com feriados e pontos facultativos de cada unidade;
  - os nacionais vêm da BrasilAPI e só valem depois da revisão da equipe (RN-11-020, D-638).
- **RN-06-027** — Se a data de referência mudar (por exemplo, o início foi adiado), os prazos dos itens ainda não concluídos são recalculados. Prazos editados à mão pelo RH não mudam **[P-06-08]**.
- **RN-06-028** — Item vencido aparece como **atrasado** nas telas e nos painéis, e o responsável e o RH são avisados (spec 15). O atraso não bloqueia nada **[P-06-09]**.

### Formulários (D-238)

- **RN-06-030** — O formulário é montado com:
  - campos da ficha e do vínculo (spec 04), inclusive campos personalizados (D-213);
  - campos livres, que ficam só no processo.
- **RN-06-031** — Respostas em campos da ficha ou do vínculo só vão para o cadastro quando o RH revisa e aplica. O RH pode corrigir antes de aplicar. Campos sensíveis seguem a spec 05 (criptografia, confirmação de senha) **[P-06-10]**.

### Condições (D-233)

- **RN-06-035** — O item pode ter condições por tipo de vínculo, cargo, unidade e, na empresa que usa clientes de alocação, cliente **[P-06-22]**. Dentro de uma condição vale qualquer valor da lista; condições diferentes precisam ser verdadeiras ao mesmo tempo. Exemplo: "vínculo CLT **e** unidade Caxias ou Bento" **[P-06-11]**.
- **RN-06-036** — As condições são avaliadas **quando o processo começa**. Se o cargo, a unidade ou o cliente mudar depois, os itens não são reavaliados sozinhos. O sistema avisa o RH, que ajusta à mão **[P-06-12]**. Exceção: se o cliente mudar, os itens ainda não concluídos do papel `client_manager` passam para os gestores do cliente novo, porque os do anterior perdem o acesso (RN-04-095) **[P-06-21]**.
- **RN-06-037** — Os documentos exigidos pelo cargo (D-204) entram no processo de admissão como itens de envio de documento, mesmo sem estar no modelo **[P-06-13]**.

### Dependências (D-237)

- **RN-06-040** — Um item pode depender de um ou mais itens do mesmo modelo. Ele fica **bloqueado** até todos estarem concluídos ou dispensados. Sem dependência, o item nasce liberado.
- **RN-06-041** — O editor do modelo recusa dependências em ciclo.
- **RN-06-042** — Se um item do qual outros dependem não entrar no processo (por causa de uma condição), a dependência é ignorada para quem dependia dele **[P-06-14]**.

### Processo (instância)

- **RN-06-050** — Iniciar um processo:
  1. copia o modelo da empresa;
  2. avalia as condições;
  3. resolve os responsáveis;
  4. calcula os prazos;
  5. define quais itens nascem bloqueados (D-091).
- **RN-06-051** — No processo, o RH pode incluir, remover, editar e reordenar itens, e trocar responsáveis e prazos. Cada mudança fica no histórico do processo.
- **RN-06-052** — **Dispensar** um item obrigatório exige justificativa. O item dispensado conta como resolvido para as dependências **[P-06-15]**.
- **RN-06-053** — O processo é concluído quando todos os itens obrigatórios estão concluídos ou dispensados. A conclusão pode ser automática ou exigir a confirmação do RH, conforme a spec do processo **[P-06-16]**.

### Leitura e aceite

- **RN-06-060** — O material é um PDF enviado no modelo, que passa pela varredura de vírus antes de ficar disponível (P-05-30, D-638), ou um material do assistente (spec 14). O aceite guarda a versão do material, a data, a hora e o IP. Se o material mudar, aceites antigos continuam válidos para a versão que foi lida **[P-06-17]**.

### Encaminhamento

- **RN-06-065** — Com escritório contábil ligado (D-171), o encaminhamento:
  - reúne os arquivos e dados escolhidos no item (por exemplo, todos os documentos validados e a ficha);
  - fica disponível para os contadores do escritório;
  - é concluído quando um contador confirma o recebimento (D-143).
- **RN-06-066** — Sem escritório ligado, o RH registra o envio à mão (anexo e data), como no protótipo, e o item é concluído com esse registro **[P-06-18]**.

## 5. Estados

**Modelo:** `draft` → `active` → `archived`

**Processo:** `open` → `completed` · `open` → `cancelled` (com motivo)

**Item:**

```
blocked → pending → submitted → done
                  ↘ correction_requested → submitted
pending/blocked → skipped (dispensado, com justificativa)
approval: pending → approved | rejected
forward:  pending → sent → received
```

## 6. Permissões

| Ação | Quem |
|---|---|
| Biblioteca | Superadmin, suporte |
| Modelos do parceiro | Administrador do parceiro; consultor lê |
| Modelos da empresa: criar, editar, adotar, marcar padrão | RH administrador (D-240) |
| Iniciar e ajustar processos | Conforme a spec de cada processo (07, 09) e a spec 03 |
| Concluir item | O responsável do item, ou o RH |

## 7. Modelo de dados

```
process_templates                            -- ProcessTemplate (empresa) e SharedProcessTemplate (D-639)
  id, company_id (só nos da empresa, para acts_as_tenant), partner_id (só nos do
  parceiro; os dois vazios = biblioteca), kind, name, description, status,
  source_template_id, is_default, onboarding_template_id (só para admissão)   [P-06-04]

process_template_items                       -- ProcessTemplateItem e SharedProcessTemplateItem (D-639)
  id, company_id (só nos da empresa), process_template_id, position, kind, title,
  instructions, required, responsible_role, due_anchor, due_offset_days (negativo =
  antes), due_business_days (bool),
  conditions (jsonb: {employment_kinds: [], position_ids: [], unit_ids: [],
              allocation_client_ids: []}),                        [P-06-22]
  config (jsonb por tipo), depends_on_item_ids (uuid[])

process_template_materials                   -- ProcessTemplateMaterial e SharedProcessTemplateMaterial (D-640)
  id, company_id (só nos da empresa), process_template_item_id (fica vazio se o item
  for removido), version, uploaded_by_id, file (Active Storage, PDF)        [P-06-17]

file_scans                                   -- varredura de vírus por arquivo, sem empresa (P-05-30, D-640)
  id, blob_id, status ('scanning'|'clean'|'infected'), signature, attempted_at, scanned_at

positions + admission_template_id                                 (D-204)

process_instances
  id, company_id, process_template_id (origem), kind, subject_type, subject_id
  (Employment, Request...), status, anchor_dates (jsonb), started_by_id,
  subject_snapshot (jsonb: vínculo, cargo, unidade e cliente no início, RN-06-036),
  completion_mode ('confirm'|'automatic', D-641), completed_at, completed_by_id,
  cancelled_at, cancelled_by_id, cancel_reason

process_items
  id, company_id, process_instance_id, source_template_item_id, position, kind,
  title, instructions, required, status, responsible_role,
  responsible_membership_ids (array), responsible_fallback (bool, RN-06-022),
  due_anchor, due_offset_days, due_business_days (para o recálculo, RN-06-027),
  due_on, due_manually_set (bool), overdue_notified_on,
  config (jsonb), result (jsonb), completed_by_id, completed_at,
  skipped_reason

process_item_dependencies
  id, company_id, item_id, depends_on_item_id

process_events                               -- histórico do processo (RN-06-051, D-641)
  id, company_id, process_instance_id, process_item_id, action, actor_id,
  details (jsonb), created_at

holidays                                     -- compartilhado com a spec 11; sem empresa (D-638)
  id, level ('national'|'state'|'city'), state, ibge_city_code, city_name, date, name,
  status ('pending'|'published'|'rejected'), source ('manual'|'brasil_api'),
  unit_opt_out (bool, só nacional), reviewed_by_id, reviewed_at

unit_holidays                                -- da empresa, com acts_as_tenant (D-638)
  id, company_id, unit_id, kind ('holiday'|'optional_day'|'opt_out'), date, name,
  holiday_id (só no opt_out), created_by_id
```

Modelos da biblioteca e do parceiro não têm `company_id` e ficam fora do acts_as_tenant, com acesso pelo ponto único de consultas entre organizações (P-01-06) **[P-06-19]**.

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Processes::OverdueItemsJob` | Diário | Marca os itens atrasados e dispara os avisos (spec 15) |
| `Processes::UnblockItemsJob` | Ao concluir ou dispensar um item | Libera os itens dependentes e avisa os responsáveis |
| `Holidays::ImportNationalJob` | Anual | Carrega os feriados nacionais do ano seguinte **[P-06-20]** |

## 9. Critérios de aceite

- **CA-06-001** — Dado um modelo do parceiro adotado pela empresa, quando o parceiro edita o original, então a cópia da empresa não muda.
- **CA-06-002** — Dado um item "Integração de segurança" com a condição "unidade = Caxias", quando uma admissão começa para a unidade Bento, então o item não entra no processo.
- **CA-06-003** — Dado um item com prazo "3 dias úteis antes do início" e início em 15/11 (feriado nacional), quando o processo começa, então o prazo considera o feriado e cai no dia útil correto.
- **CA-06-004** — Dado que "Encaminhar à contabilidade" depende de "RG validado" e "Comprovante validado", quando só o RG está validado, então o encaminhamento continua bloqueado.
- **CA-06-005** — Dado um formulário com o campo "Conta bancária", quando o colaborador preenche, então a ficha só muda depois que o RH aplica.
- **CA-06-006** — Dado um departamento sem gestor, quando um processo com item do papel `manager` começa, então o item vai para o RH e o processo mostra um alerta.
- **CA-06-007** — Dada uma data de início adiada em 7 dias, quando o RH salva, então os prazos não concluídos e não editados à mão se deslocam junto.
- **CA-06-008** — Dado um modelo com A dependendo de B e B dependendo de A, quando o RH salva, então o editor recusa por ciclo.
- **CA-06-009** — Dado um item de aprovação do papel `client_manager` e uma admissão alocada no cliente X, que tem dois gestores, quando o processo começa, então os dois recebem o item, e qualquer um deles conclui.
- **CA-06-010** — Dada uma admissão que muda do cliente X para o Y, quando o RH salva, então o item pendente do papel `client_manager` passa aos gestores de Y, e os de X deixam de vê-lo.

## 10. Propostas aprovadas (D-241)

| # | Proposta |
|---|---|
| P-06-01 | Processos só usam modelos da empresa; modelos de fora são adotados antes |
| P-06-02 | Empresa de parceiro vê modelos do parceiro e a biblioteca; empresa direta vê a biblioteca |
| P-06-03 | Modelo padrão por tipo na empresa, com prioridade para o modelo do cargo |
| P-06-04 | Modelo de admissão pode iniciar um modelo de integração na conclusão |
| P-06-05 | Lista de papéis de responsável |
| P-06-06 | Papel sem ninguém vai para o RH, com alerta |
| P-06-07 | Datas de referência por tipo de processo |
| P-06-08 | Prazos se recalculam quando a data de referência muda, menos os editados à mão |
| P-06-09 | Atraso avisa, mas não bloqueia |
| P-06-10 | Respostas do formulário só vão à ficha depois de o RH aplicar |
| P-06-11 | Condições: qualquer valor dentro da condição, todas as condições ao mesmo tempo |
| P-06-12 | Condições avaliadas só no início, com aviso ao RH quando cargo ou unidade mudam |
| P-06-13 | Documentos exigidos pelo cargo entram sozinhos na admissão |
| P-06-14 | Dependência de item que não entrou no processo é ignorada |
| P-06-15 | Dispensar item obrigatório exige justificativa e libera os dependentes |
| P-06-16 | Conclusão automática ou com confirmação, conforme o processo |
| P-06-17 | Aceite de leitura guarda a versão do material |
| P-06-18 | Sem escritório ligado, o RH registra o envio à mão |
| P-06-19 | Modelos de biblioteca e parceiro fora do acts_as_tenant, pelo ponto único |
| P-06-20 | Carga anual dos feriados nacionais |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-06-21 | Papel `client_manager`; os itens pendentes acompanham a troca de cliente |
| P-06-22 | Condição de item por cliente de alocação |

## 11. Em aberto

- **Fonte dos feriados estaduais e municipais** que a equipe CatalystHR carrega (D-242). Será tratada na spec 11.
