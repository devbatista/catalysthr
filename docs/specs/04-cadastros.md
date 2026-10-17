# 04 — Cadastros

> Status: aprovado · Última atualização: 2026-10-14
> Decisões: D-053, D-086, D-090, D-151, D-176, D-190, D-200 a D-216, D-570, D-600 ([decisoes.md](decisoes.md))
> Os itens **[P-04-01]** a **[P-04-29]** foram todos aprovados sem ajuste (D-214, seção 10). Os itens **[P-04-30]** a **[P-04-36]** (clientes de alocação, D-570) foram aprovados sem ajuste (D-572).

## 1. Objetivo

Definir os cadastros que o resto da plataforma usa:

- a empresa e a estrutura dela (unidades, departamentos, cargos);
- a ficha de cada pessoa na empresa;
- os vínculos de trabalho, com o histórico de mudanças com data de vigência.

Admissão, documentos, ponto, folha e eSocial dependem destes dados.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Empresa | `Company` | O empregador: um CNPJ raiz, ou CPF para empregador pessoa física (D-200) |
| Unidade | `Unit` | Um estabelecimento (matriz, filial, obra), com CNPJ, CNO ou CAEPF próprio opcional (D-201) |
| Departamento | `Department` | Área dentro de uma unidade, em árvore (D-202), com um ou mais gestores (D-203) |
| Cargo | `Position` | Cargo com CBO, faixa salarial, requisitos e modelo de admissão (D-204) |
| Ficha da pessoa | `WorkerProfile` | Os dados pessoais da pessoa **naquela empresa** (D-209), um por membership de empresa **[P-04-01]** |
| Vínculo | `Employment` | Um contrato de trabalho. Uma ficha pode ter vários, simultâneos ou sucessivos (D-205) |
| Revisão do vínculo | `EmploymentRevision` | As condições do vínculo a partir de uma data: cargo, salário, unidade, departamento, jornada (D-207) **[P-04-02]** |
| Dependente | `Dependent` | Dependente da pessoa naquela empresa |
| Conta bancária | `BankAccount` | Conta ou chave PIX para pagamento |
| Campo personalizado | `CustomFieldDefinition` | Campo extra criado pela empresa (D-213) |
| Cliente de alocação | `AllocationClient` | Cliente da empresa onde o colaborador trabalha alocado. Só existe se a empresa usar clientes de alocação (D-570) |

### Onde fica cada dado da pessoa [P-04-03]

| Dado | Onde | Por quê |
|---|---|---|
| Nome civil, CPF, data de nascimento, e-mail e celular de login | `User` (spec 02) | Identidade e acesso, iguais em todas as empresas |
| Todo o resto: nome social, endereço, documentos, dependentes, banco, escolaridade, deficiência, campos extras | `WorkerProfile` (por empresa) | Cada empresa é controladora dos dados dela (D-080) e é o tenant (D-151) |

```
User ──< Membership (empresa) ──1 WorkerProfile ──< Employment ──< EmploymentRevision
                                      ├──< Dependent
                                      ├──< BankAccount
                                      └──< EmergencyContact
```

## 3. Histórias de usuário

1. Como **RH administrador**, quero cadastrar as unidades com o CNPJ de cada filial, para que ponto, folha e eSocial usem o estabelecimento certo.
2. Como **RH administrador**, quero montar os departamentos de cada unidade com seus gestores, para que as aprovações cheguem às pessoas certas.
3. Como **RH**, quero cadastrar cargos com CBO, faixa salarial e documentos exigidos, para que a admissão já saiba o que pedir.
4. Como **RH**, quero registrar uma promoção com vigência no próximo mês, para que a folha e o eSocial apliquem a mudança na data certa.
5. Como **RH**, quero efetivar um estagiário como CLT sem perder o histórico do estágio.
6. Como **colaborador**, quero pedir a troca da minha conta bancária pelo portal, enviando o comprovante.
7. Como **RH administrador**, quero criar um campo "Tamanho do uniforme" que o colaborador preenche.
8. Como **RH de uma consultoria**, quero indicar em qual cliente cada colaborador está alocado, para filtrar por cliente e envolver os gestores desse cliente (D-570).

## 4. Regras de negócio

### Empresa

- **RN-04-001** — A empresa é identificada por um CNPJ raiz (8 dígitos) ou por CPF, se o empregador for pessoa física (D-200). O documento é único na plataforma **[P-04-04]**.
- **RN-04-002** — Dados cadastrais da empresa nesta spec:
  - razão social e nome fantasia;
  - tipo de empregador (pessoa jurídica ou física) e documento;
  - endereço da matriz;
  - parceiro (opcional, D-120);
  - status;
  - configurações gerais: período de leitura do desligado (D-090), próxima matrícula, campos personalizados, uso de clientes de alocação (D-570).

  Os dados fiscais e previdenciários ficam na [spec 12](12-folha-de-pagamento.md) (D-212).

### Unidades

- **RN-04-010** — Toda empresa tem pelo menos uma unidade, a matriz, criada junto com ela **[P-04-05]**.
- **RN-04-011** — A unidade tem:
  - nome;
  - tipo de inscrição (CNPJ, CNO ou CAEPF) e número, ambos opcionais. Sem número próprio, usa o CNPJ da matriz (D-201);
  - endereço completo;
  - fuso horário;
  - status.

  O CNPJ de uma filial precisa ter a mesma raiz da empresa.
- **RN-04-012** — O endereço da unidade guarda latitude e longitude, que servem de base para a cerca virtual do ponto ([spec 10](10-ponto-rep-p.md)) **[P-04-06]**. A posição é sempre confirmada pelo RH no mapa (D-216).
- **RN-04-013** — O fuso horário da unidade define a hora local das marcações de ponto e dos prazos daquela unidade. O padrão é `America/Sao_Paulo` **[P-04-07]**.
- **RN-04-014** — Uma unidade com vínculos ativos não pode ser excluída, só inativada. Inativar uma unidade exige que nenhum vínculo ativo esteja nela **[P-04-08]**.

### Departamentos

- **RN-04-020** — O departamento pertence a uma unidade e pode ter um departamento pai na mesma unidade (D-202). A árvore não pode ter ciclos.
- **RN-04-021** — O departamento tem zero ou mais gestores (D-203). O gestor precisa ter uma membership ativa na empresa com o perfil `manager` **[P-04-09]**.
- **RN-04-022** — A **equipe** de um gestor é formada pelos colaboradores com vínculo ativo nos departamentos que ele gerencia **e nos subdepartamentos deles** (D-190) **[P-04-10]**.
- **RN-04-023** — Uma aprovação que cabe ao gestor do departamento pode ser feita por qualquer um dos gestores dele (D-203).
- **RN-04-024** — O **gestor acima** de alguém é o gestor do departamento pai mais próximo que tenha gestor. Se nenhum ancestral tiver gestor, a aprovação vai para o RH. Esse é o caminho usado quando um gestor pede algo para si (P-03-33) **[P-04-11]**.
- **RN-04-025** — Um departamento com vínculos ativos ou subdepartamentos ativos não pode ser excluído, só inativado depois de esvaziado **[P-04-12]**.

### Cargos

- **RN-04-030** — O cargo é da empresa (vale para todas as unidades) e tem (D-204):
  - nome e CBO de 6 dígitos;
  - faixa salarial (mínimo e máximo, opcionais);
  - descrição e requisitos;
  - modelo de admissão (spec 06);
  - tipos de documento exigidos (spec 08).
- **RN-04-031** — O CBO é validado contra a tabela oficial da CBO, carregada no sistema e atualizada pela equipe CatalystHR **[P-04-13]**.
- **RN-04-032** — Um salário fora da faixa do cargo não é bloqueado. O sistema mostra um alerta e pede uma justificativa, que fica registrada na revisão do vínculo **[P-04-14]**.

### Ficha da pessoa (WorkerProfile)

- **RN-04-040** — A ficha é criada junto com a primeira membership de empresa que tenha ou venha a ter vínculo, por exemplo na admissão. Cada empresa tem a própria ficha (D-209). A ficha de uma empresa nunca é lida por outra **[P-04-01]**. Na fase 1, antes da admissão e da importação, o RH cadastra à mão quem já trabalha na empresa: a tela "Novo colaborador" cria a pessoa, a membership de colaborador sem enviar convite, a ficha e o vínculo (D-600).
- **RN-04-041** — A ficha segue os grupos de dados do trabalhador do eSocial (D-206) **[P-04-15]**:

  | Grupo | Campos |
  |---|---|
  | Identificação | Nome social, sexo, raça/cor, estado civil, grau de instrução |
  | Nascimento | Município, UF e país de nascimento, nacionalidade |
  | Documentos | RG (número, órgão, UF, emissão), CTPS (número, série, UF), PIS/NIS, título de eleitor, CNH (número, categoria, validade), registro de classe, RNE/RNM para estrangeiro |
  | Endereço | CEP, logradouro, número, complemento, bairro, município (código IBGE), UF; ou endereço no exterior |
  | Estrangeiro | Data de chegada, condição de ingresso, casado(a) com brasileiro(a), filhos brasileiros |
  | Deficiência | Física, visual, auditiva, mental, intelectual; reabilitado ou readaptado; observação |
  | Contato | Telefone e e-mail pessoais |
  | Emergência | Nome, parentesco, telefone (um ou mais) |
  | Campos personalizados | Os definidos pela empresa (D-213) |

- **RN-04-042** — Dados sensíveis da ficha (D-086) ficam criptografados no banco: RG e demais documentos, dados bancários, deficiência e dados de saúde. CPF e RG usam criptografia determinística quando precisam de busca **[P-04-16]**.
- **RN-04-043** — **Dependentes** (D-208): nome, CPF, data de nascimento, sexo, parentesco (tipos do eSocial), se é dependente para IRRF, se é para salário-família, se é incapaz para o trabalho, e a certidão anexa (spec 08).
- **RN-04-044** — **Dados bancários** (D-208): banco, agência, conta, tipo (corrente, poupança, salário) ou chave PIX com o tipo da chave. Uma conta é marcada como principal para o pagamento. A conta precisa ter o CPF do titular igual ao do colaborador, o que é verificado por declaração e comprovante, não por consulta ao banco **[P-04-17]**.

### Vínculos (Employment)

- **RN-04-050** — O vínculo tem um tipo (D-176):

  | Tipo | Código | Evento eSocial (spec 13) |
  |---|---|---|
  | CLT (inclui aprendiz, temporário e intermitente como subtipos) | `clt` | S-2200 |
  | Estágio | `intern` | S-2300 |
  | Autônomo | `autonomous` | S-2300 (obrigatoriedade a confirmar na spec 13) |
  | Sócio com pró-labore | `owner` | S-2300 |
  | Prestador PJ | `contractor` | Não vai ao eSocial |

- **RN-04-051** — Uma ficha pode ter vários vínculos, simultâneos ou sucessivos (D-205). Cada vínculo tem a própria matrícula.
- **RN-04-052** — **Matrícula** (D-211): o sistema sugere o próximo número sequencial da empresa, e o RH pode trocar. A matrícula é única entre todos os vínculos da empresa, inclusive os encerrados, porque o eSocial não aceita matrícula repetida para o mesmo empregador **[P-04-18]**.
- **RN-04-053** — Campos do vínculo por tipo (D-206). A lista final por campo é revisada na spec 13 contra o leiaute vigente do eSocial **[P-04-15]**:

  | Grupo | CLT | Estágio | Autônomo / Sócio | PJ |
  |---|---|---|---|---|
  | Início e categoria | Data de admissão, tipo e indicativo de admissão, categoria eSocial | Data de início, categoria | Data de início, categoria | Início e fim do contrato |
  | Regime | Regime trabalhista e previdenciário, natureza da atividade, opção FGTS | — | — | — |
  | Contrato | Tipo (indeterminado, determinado), data de término, cláusula assecuratória | Natureza e nível do estágio, área, apólice de seguro, previsão de término | — | Objeto do contrato, contrato anexo |
  | Sindicato | CNPJ do sindicato da categoria, data-base | — | — | — |
  | Estágio | — | Instituição de ensino, agente de integração, supervisor (CPF) | — | — |
  | PJ | — | — | — | CNPJ e razão social do prestador, valor mensal, forma de pagamento |

- **RN-04-054** — Status do vínculo **[P-04-19]**:
  - `pending`: em admissão (spec 07);
  - `active`;
  - `on_leave`: afastado;
  - `terminated`: desligado, com data e motivo.

  Efetivar um estagiário encerra o vínculo de estágio e cria um vínculo CLT novo. Os dois ficam no histórico.
- **RN-04-055** — O perfil `employee` da membership existe enquanto houver ao menos um vínculo `pending`, `active` ou `on_leave`, ou enquanto durar o período de leitura depois do último desligamento (P-02-03, D-090).

### Revisões com vigência (EmploymentRevision)

- **RN-04-060** — As condições do vínculo são guardadas em revisões, cada uma com "vigente a partir de" (D-207). Cada revisão tem:
  - cargo (e CBO);
  - salário (valor e unidade: hora, dia, mês etc., ou descrição do salário variável);
  - unidade e departamento;
  - cliente de alocação, se a empresa usa (RN-04-092);
  - jornada (horas semanais, tipo de jornada, escala, definida na spec 11);
  - motivo da mudança;
  - justificativa (RN-04-032) **[P-04-02]**.
- **RN-04-061** — A revisão vigente numa data é a de maior "vigente a partir de" que não passe dessa data. A folha calcula cada período com a revisão vigente em cada dia **[P-04-20]**.
- **RN-04-062** — É permitido registrar uma revisão **futura**, por exemplo um aumento a partir de 01/12, e uma revisão **retroativa**. A retroativa avisa que pode exigir recálculo de folhas já fechadas e retificação no eSocial. Esse tratamento fica nas specs 12 e 13 **[P-04-21]**.
- **RN-04-063** — Toda revisão que muda cargo, salário ou jornada gera uma pendência de eSocial (S-2206) para a spec 13 **[P-04-22]**.
- **RN-04-064** — O departamento da revisão precisa pertencer à unidade da revisão.

### Atualização pelo colaborador

- **RN-04-070** — Pelo portal, o colaborador pede alteração de (D-210):
  - endereço e contatos;
  - dados bancários e PIX;
  - dependentes;
  - estado civil, escolaridade e nome social.
- **RN-04-071** — O pedido é uma solicitação do tipo "Atualização cadastral" ([spec 09](09-solicitacoes-aprovacoes.md)). Ela guarda os valores novos e o comprovante exigido, e só altera a ficha quando o RH aprova. O comprovante segue para a pasta de documentos (spec 08) **[P-04-23]**.
- **RN-04-072** — Comprovantes exigidos **[P-04-24]**:

  | Alteração | Comprovante |
  |---|---|
  | Endereço | Comprovante de residência |
  | Banco ou PIX | Comprovante da conta |
  | Dependente | Certidão ou documento do dependente |
  | Estado civil | Certidão |
  | Escolaridade | Diploma ou declaração |
  | Nome social | Nenhum (direito do colaborador) |
  | Contatos | Nenhum |

- **RN-04-073** — Alterações aprovadas que o eSocial exige comunicar geram pendência de S-2205 para a spec 13.

### Campos personalizados

- **RN-04-080** — O RH administrador cria campos com (D-213):
  - nome;
  - tipo: texto, número, data, seleção ou sim/não;
  - opções, se for seleção;
  - obrigatório ou não;
  - visível ao colaborador;
  - editável pelo colaborador. Se for, a edição passa pela validação do RH (RN-04-071) **[P-04-25]**.
- **RN-04-081** — Os valores ficam em uma coluna JSONB na ficha. Remover um campo esconde o valor, mas não apaga os dados já gravados **[P-04-26]**.

### Clientes de alocação (D-570)

- **RN-04-090** — O RH administrador liga ou desliga o uso de clientes de alocação nas configurações da empresa. Vem desligado. Desligado, nada desta seção aparece. Só é possível desligar quando nenhum vínculo `pending`, `active` ou `on_leave` tem cliente na revisão vigente **[P-04-30]**.
- **RN-04-091** — O cliente tem nome, documento (CNPJ ou CPF, opcional, único na empresa quando informado) e status. Ele pertence à empresa e fica no tenant dela **[P-04-31]**.
- **RN-04-092** — A revisão do vínculo indica o cliente de alocação. O campo é **opcional**: "sem cliente" representa quem trabalha na própria empresa, como a equipe interna **[P-04-32]**.
- **RN-04-093** — Trocar de cliente é uma revisão nova, com vigência, como trocar de unidade. A troca sozinha não gera pendência de eSocial (RN-04-063). A conferência de efeitos no eSocial está em aberto (seção 11) **[P-04-33]**.
- **RN-04-094** — O cliente tem zero ou mais **gestores do cliente**: pessoas com membership na empresa e o perfil `client_manager` (spec 02). Uma mesma pessoa pode gerir vários clientes **[P-04-34]**.
- **RN-04-095** — A **equipe** de um gestor do cliente são os vínculos `pending`, `active` ou `on_leave` cuja revisão vigente aponta para um dos clientes dele. No vínculo `pending`, vale a primeira revisão, para que o gestor participe da admissão. Quando o colaborador muda de cliente, ele sai da equipe na data da vigência **[P-04-35]**.
- **RN-04-096** — Um cliente com vínculos `pending`, `active` ou `on_leave` não pode ser inativado. Inativar tira o acesso dos gestores daquele cliente (RN-02-064) **[P-04-36]**.

## 5. Estados

**Vínculo:** `pending` → `active` ⇄ `on_leave` → `terminated` (`pending` → `cancelled` se a admissão for desistida)

**Unidade, departamento e cliente de alocação:** `active` ⇄ `inactive`

## 6. Permissões

Seguem a [spec 03](03-permissoes.md), seções 4.2 e 4.3. Resumo:

| Ação | Quem |
|---|---|
| Empresa, unidades, departamentos, cargos, campos personalizados | RH administrador |
| Ficha, vínculos e revisões | RH administrador (T), RH analista (U) |
| Ver salário e dados bancários | RH administrador, RH analista com módulo `folha` (P-03-16) |
| Pedir atualização dos próprios dados | Colaborador |
| Ligar clientes de alocação, cadastrar clientes e atribuir os gestores deles | RH administrador **[P-04-30]** |
| Indicar o cliente na revisão do vínculo | RH administrador (T), RH analista (U) |

## 7. Modelo de dados

```
companies (spec 01) + employer_type ('company'|'person'), document (CNPJ raiz ou CPF),
  legal_name, trade_name, address..., next_registration_number, read_only_period_days (padrão 365, D-423),
  uses_allocation_clients (bool, padrão false, D-570)

allocation_clients                                     -- D-570  [P-04-31]
  id, company_id, name, document_type ('cnpj'|'cpf'|null), document (nullable,
  único na empresa), status

allocation_client_managers                             -- D-570  [P-04-34]
  id, company_id, allocation_client_id, membership_id

units
  id, company_id, name, registration_type ('cnpj'|'cno'|'caepf'|null),
  registration_number, address..., ibge_city_code, latitude, longitude,
  time_zone, is_headquarters, status

departments
  id, company_id, unit_id, parent_id (nullable), name, status

department_managers                                    -- D-203
  id, company_id, department_id, membership_id

positions
  id, company_id, name, cbo_code, salary_min, salary_max, description,
  requirements, process_template_id, status

position_required_document_types
  position_id, document_type_id

cbo_occupations                                        -- tabela global, sem tenant  [P-04-13]
  code, title

worker_profiles                                        -- [P-04-01]
  id, company_id, membership_id (único), social_name, sex, race, marital_status,
  education_level, birth_city_code, birth_country, nationality,
  rg_number (cript.), rg_issuer, rg_state, rg_issued_on, ctps_number (cript.),
  ctps_series, ctps_state, pis_nis (cript.), voter_id (cript.), cnh_number (cript.),
  cnh_category, cnh_expires_on, foreign_* ..., disability_* (cript.),
  address..., personal_phone, personal_email, custom_fields (jsonb)

emergency_contacts
  id, company_id, worker_profile_id, name, relationship, phone

dependents
  id, company_id, worker_profile_id, name, cpf (cript.), birth_date, sex,
  relationship_type, irrf, family_allowance, incapable, status

bank_accounts
  id, company_id, worker_profile_id, bank_code, branch, account_number (cript.),
  account_type, pix_key_type, pix_key (cript.), primary

employments
  id, company_id, worker_profile_id, kind ('clt'|'intern'|'autonomous'|'owner'|'contractor'),
  registration_number (único por empresa), status, started_on, ended_on,
  termination_reason, esocial_category, details (jsonb por tipo)   [P-04-27]

employment_revisions                                   -- [P-04-02]
  id, company_id, employment_id, effective_on, position_id, cbo_code,
  salary_amount (cript.), salary_unit, variable_salary_description,
  unit_id, department_id, allocation_client_id (nullable, D-570), work_schedule_id (spec 11),
  weekly_hours, reason, justification, created_by_id

custom_field_definitions
  id, company_id, key, label, field_type, options (jsonb), required,
  visible_to_employee, editable_by_employee, status
```

Todas as tabelas com `company_id` usam acts_as_tenant (D-150) e PaperTrail (D-084).

## 8. Jobs e integrações

| Item | Detalhe |
|---|---|
| Consulta de CEP | Preenche o endereço pelo CEP. Consulta o ViaCEP e, se falhar, a BrasilAPI. O preenchimento manual é sempre possível (D-215) **[P-04-28]** |
| Coordenadas da unidade | Ao salvar ou alterar o endereço, o Nominatim (OpenStreetMap) sugere a posição, respeitando o limite de 1 requisição por segundo e com o app identificado. O RH confirma ou arrasta o pino num mapa Leaflet com o OpenStreetMap. Se o endereço não for encontrado, o RH marca direto no mapa (D-216) |
| Tabela CBO | Carga e atualização da tabela oficial pela equipe CatalystHR |
| `Employments::ApplyScheduledRevisionsJob` | Diário: avisa o RH sobre as revisões que entram em vigor no dia e gera as pendências de eSocial **[P-04-29]** |

## 9. Critérios de aceite

- **CA-04-001** — Dada uma empresa com CNPJ raiz 12.345.678, quando o RH cadastra uma filial com CNPJ 98.765.432/0002-xx, então o sistema recusa por ter outra raiz.
- **CA-04-002** — Dado o departamento Usinagem dentro de Produção, com Carlos como gestor de Produção, quando um colaborador da Usinagem pede férias, então Carlos pode aprovar.
- **CA-04-003** — Dado que Usinagem não tem gestor e Produção tem dois, quando o gestor de Usinagem pediria férias para si (RN-04-024), então a aprovação vai para os dois gestores de Produção, e qualquer um deles pode aprovar.
- **CA-04-004** — Dado um vínculo com salário de R$ 2.000 vigente desde 01/03, quando o RH registra R$ 2.300 a partir de 01/12, então a ficha mostra R$ 2.000 até 30/11, R$ 2.300 a partir de 01/12 e a revisão futura agendada.
- **CA-04-005** — Dado um salário abaixo do mínimo da faixa do cargo, quando o RH salva, então o sistema pede uma justificativa e só salva com ela preenchida.
- **CA-04-006** — Dado um estagiário, quando o RH registra a efetivação, então o vínculo de estágio fica `terminated`, um vínculo CLT novo é criado com outra matrícula, e os dois aparecem no histórico da pessoa.
- **CA-04-007** — Dado o colaborador João nas empresas A e B, quando a empresa A altera o endereço dele, então a ficha na empresa B não muda.
- **CA-04-008** — Dado um colaborador que pede a troca de conta bancária com comprovante, quando o RH aprova, então a conta nova vira a principal, e a anterior fica no histórico.
- **CA-04-009** — Dado um campo personalizado "Tamanho do uniforme", editável pelo colaborador, quando o colaborador preenche, então o valor só entra na ficha depois da aprovação do RH.
- **CA-04-010** — Dada uma matrícula 1050 já usada por um vínculo encerrado, quando o RH tenta usá-la num vínculo novo, então o sistema recusa.
- **CA-04-011** — Dada uma empresa com clientes de alocação desligados, quando o RH abre a revisão de um vínculo, então não vê o campo de cliente.
- **CA-04-012** — Dada Ana alocada no cliente X e trocada para o cliente Y a partir de 01/12, quando chega 01/12, então os gestores de X deixam de ver Ana, e os de Y passam a ver.
- **CA-04-013** — Dado um cliente com um vínculo `pending`, quando o RH tenta inativá-lo, então o sistema recusa.

## 10. Propostas aprovadas (D-214)

| # | Proposta |
|---|---|
| P-04-01 | Entidade `WorkerProfile` com a ficha da pessoa, uma por membership de empresa |
| P-04-02 | Entidade `EmploymentRevision` com as condições vigentes a partir de uma data |
| P-04-03 | Nome civil, CPF, nascimento e contatos de login ficam no `User`; o resto fica na ficha |
| P-04-04 | O documento do empregador (CNPJ raiz ou CPF) é único na plataforma |
| P-04-05 | Toda empresa nasce com a unidade matriz |
| P-04-06 | Latitude e longitude da unidade para a cerca virtual |
| P-04-07 | Fuso horário por unidade, com padrão America/Sao_Paulo |
| P-04-08 | Unidade com vínculos ativos só pode ser inativada, depois de esvaziada |
| P-04-09 | O gestor de departamento precisa ter o perfil `manager` na empresa |
| P-04-10 | A equipe do gestor inclui os subdepartamentos |
| P-04-11 | "Gestor acima" é o do departamento ancestral mais próximo com gestor; sem nenhum, vai ao RH |
| P-04-12 | Departamento com vínculos ou filhos ativos só é inativado depois de esvaziado |
| P-04-13 | Tabela oficial da CBO carregada no sistema para validar o código |
| P-04-14 | Salário fora da faixa gera alerta e exige justificativa, sem bloquear |
| P-04-15 | Campos da ficha e do vínculo pelos grupos do eSocial, revisados na spec 13 |
| P-04-16 | Criptografia dos dados sensíveis da ficha, determinística quando há busca |
| P-04-17 | A titularidade da conta é verificada por declaração e comprovante |
| P-04-18 | Matrícula única entre todos os vínculos da empresa, inclusive os encerrados |
| P-04-19 | Status do vínculo, e efetivação de estagiário como vínculo novo |
| P-04-20 | A folha usa a revisão vigente em cada dia do período |
| P-04-21 | Revisões futuras e retroativas permitidas, com aviso para as retroativas |
| P-04-22 | Revisão de cargo, salário ou jornada gera pendência de S-2206 |
| P-04-23 | A atualização pelo colaborador é uma solicitação do tipo "Atualização cadastral" |
| P-04-24 | Tabela de comprovantes exigidos por alteração |
| P-04-25 | Tipos e opções dos campos personalizados |
| P-04-26 | Campos personalizados em JSONB; remover um campo não apaga os valores |
| P-04-27 | Campos específicos de cada tipo de vínculo em JSONB (`details`) |
| P-04-28 | Consulta de CEP para preencher o endereço |
| P-04-29 | Job diário que avisa sobre revisões entrando em vigor |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-04-30 | Clientes de alocação ligados pelo RH administrador, desligados por padrão; só desliga sem vínculos alocados |
| P-04-31 | Cliente com nome, documento opcional e status, dentro do tenant da empresa |
| P-04-32 | Cliente na revisão do vínculo, opcional ("sem cliente" para a equipe interna) |
| P-04-33 | Troca de cliente como revisão com vigência, sem pendência de eSocial por si |
| P-04-34 | Gestores do cliente com o perfil `client_manager`, podendo gerir vários clientes |
| P-04-35 | A equipe do gestor do cliente inclui os vínculos em admissão |
| P-04-36 | Cliente com vínculos não é inativado; inativar tira o acesso dos gestores dele |

## 11. Em aberto

- **Clientes de alocação e eSocial (D-570):** verificar se a alocação exige informar o tomador em algum evento (spec 13).

- **Obrigatoriedade do S-2300 para autônomos:** confirmar na spec 13.
- **Leiaute do eSocial:** a lista de campos será conferida contra a versão vigente na spec 13.
