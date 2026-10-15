# 03 — Permissões

> Status: aprovado · Última atualização: 2026-10-14
> Decisões: D-030, D-051, D-052, D-086, D-090, D-111, D-116, D-122, D-127, D-142, D-143, D-162, D-166, D-171, D-172, D-185 a D-187, D-190 a D-194, D-570, D-581 ([decisoes.md](decisoes.md))
> Base: a matriz de acesso da apresentação (página 6). Os itens **[P-03-01]** a **[P-03-37]** foram aprovados, alguns com ajuste (D-194, seção 9). Os itens **[P-03-38]** a **[P-03-41]** (gestor do cliente, D-570) foram aprovados sem ajuste (D-572).

## 1. Objetivo

Definir, para cada módulo, **quem pode fazer o quê e sobre quais registros**. A spec 02 define quem é o usuário e quais perfis ele tem. Esta spec define o que cada perfil permite. As specs de cada módulo detalham as ações e remetem para esta matriz.

## 2. Como o acesso é calculado

O que um usuário pode fazer resulta de cinco filtros, aplicados em sequência:

```
perfil(is) da membership  →  escopo  →  módulos liberados  →  módulos contratados  →  modo de restrição
```

### 2.1 Perfis (spec 02)

| Sigla | Perfil | Organização |
|---|---|---|
| SA | Superadmin | Plataforma |
| SUP | Suporte | Plataforma |
| FIN | Financeiro | Plataforma |
| PA | Administrador do parceiro | Parceiro |
| CON | Consultor | Parceiro |
| RHA | RH administrador | Empresa |
| RHN | RH analista | Empresa |
| GES | Gestor | Empresa |
| COL | Colaborador | Empresa |
| GCL | Gestor do cliente (D-570) | Empresa |
| ECA | Administrador do escritório contábil | Escritório |
| ECC | Contador | Escritório |

Quando uma membership tem vários perfis (D-051), as permissões se **somam**. Exemplo: um gestor que também é colaborador vê os dados da equipe dele e os próprios.

### 2.2 Escopos

| Código | Escopo | Quem |
|---|---|---|
| **T** | Toda a empresa | RHA |
| **U** | As unidades atribuídas à membership | RHN (D-142) |
| **E** | A equipe: colaboradores dos departamentos que ele gerencia | GES (D-190) |
| **P** | Só os próprios dados | COL |
| **C** | As empresas da carteira autorizadas | PA (todas do parceiro), CON (atribuídas, D-052) |
| **F** | As empresas ligadas ao escritório | ECA, ECC (D-171) |
| **K** | Os colaboradores alocados nos clientes atribuídos a ele (RN-04-095) | GCL (D-570) **[P-03-38]** |

- **Consultor (D-192):** dentro de cada empresa atribuída, age como **RHN com escopo T**, ou seja, analista de todas as unidades.
- **Administrador do parceiro:** **não opera dentro das empresas**. Ele tem só a visão consolidada da carteira e as ações de carteira da seção 4.1: cadastrar a empresa, convidar o primeiro RHA e alterar ou remover RHAs. Para operar dentro de uma empresa, a membership dele precisa ter também o perfil de consultor, com a empresa atribuída (D-051) **[P-03-01]**.
- **Suporte CatalystHR:**
  - nas **empresas diretas**, age como consultor (RHN com escopo T), para fazer implantação e atendimento (D-127) **[P-03-02]**. Entra pela área administrativa, com um token de uso único que abre o subdomínio da empresa (D-581);
  - nas **empresas de parceiros**, só acessa por impersonate, que é somente leitura com simulação (D-185, D-186) **[P-03-02]**.
- **Superadmin:** nas empresas, acessa só por impersonate. Fora delas, tem acesso total à área administrativa **[P-03-03]**.

### 2.3 Módulos liberados por membership (D-191)

Para **RHN** e **CON**, o administrador escolhe quais módulos a pessoa opera. Lista de módulos liberáveis **[P-03-04]**:

`admissao` · `documentos` · `solicitacoes` · `ponto` · `folha` · `esocial` · `recrutamento` · `avaliacao`

- **Sempre liberados** para RHN e CON: cadastros de colaboradores (em leitura, se nenhum módulo exigir edição), painéis e assistente **[P-03-05]**.
- **Quem libera:** o RHA libera os módulos do RHN; o PA libera os módulos do CON (por consultor, valendo em todas as empresas atribuídas a ele) **[P-03-06]**.
- **RHA, PA e GES** não têm essa restrição. O GES, por definição, só tem as ações de gestor listadas na matriz.

### 2.4 Módulos contratados

Ponto e folha (com eSocial) só aparecem se tiverem sido contratados (D-111 para parceiros, D-122 para empresas diretas). Um módulo não contratado some para todos os perfis, sem mensagem de erro **[P-03-07]**.

### 2.5 Modos de restrição

Os modos se sobrepõem às permissões acima:

| Modo | Efeito |
|---|---|
| **Membership `read_only`** (desligado, D-090) | Só leitura de holerites, informe de rendimentos, espelhos de ponto, documentos e TRCT próprios |
| **Inadimplência** (D-116) | Parceiro e empresas em somente leitura. **Exceção:** o ponto continua funcionando, inclusive a marcação e os comprovantes |
| **Impersonate** (D-186, D-187) | Leitura normal, escrita simulada, sensíveis mascarados |
| **Dados sensíveis** (D-086) | Exigem confirmar a senha por 5 minutos (D-183) e geram evento de acesso (D-085) |

## 3. Implementação com CanCanCan

- **RN-03-001** — A `Ability` é montada pela soma de abilities parciais **[P-03-08]**:
  - `PlatformAbility`: equipe CatalystHR, na área admin;
  - `PartnerAbility`: painel do parceiro;
  - `CompanyAbility`: na empresa atual, por perfil;
  - `AccountingFirmAbility`: contabilidade.

  Cada uma é uma classe pequena, e a soma usa `merge`.
- **RN-03-002** — Listagens usam `accessible_by(current_ability)` sobre o tenant atual (acts_as_tenant). Os escopos U, E e K viram condições de banco (hash conditions), nunca blocos Ruby, para que o `accessible_by` funcione **[P-03-09]**.
- **RN-03-003** — Todo controller usa `load_and_authorize_resource` ou `authorize!` explícito. Um teste de rotas falha se alguma ação de controller não tiver autorização **[P-03-10]**.
- **RN-03-004** — O modo somente leitura (por desligamento ou inadimplência) é aplicado na `Ability`, com `cannot` para as ações de escrita, e não só escondendo botões **[P-03-11]**.
- **RN-03-005** — Os módulos liberados e contratados também entram na `Ability`. Um módulo não liberado gera `cannot :manage` nos models dele **[P-03-12]**.
- **RN-03-006** — Uma ação negada para um registro **fora do escopo** devolve 404 (RN-01-013). Uma ação negada para um registro **dentro do escopo** devolve 403, com a mensagem "Você não tem permissão para esta ação" **[P-03-13]**.

## 4. Matriz por módulo

**Legenda:** ✓ pode · **T/U/E/P/C/F** pode, dentro do escopo · **L** só leitura · **—** não pode · **M** só se o módulo estiver liberado na membership (RHN, CON)

O consultor (CON) segue a coluna RHN com escopo T. O administrador do parceiro (PA) não aparece nas tabelas de dentro da empresa, porque não opera nelas **[P-03-01]**.

### 4.1 Plataforma e parceiro

| Ação | SA | SUP | FIN | PA | CON |
|---|---|---|---|---|---|
| Criar parceiro ou empresa direta | ✓ | — | ✓ | — | — |
| Trocar slug, transferir empresa | ✓ | — | — | — | — |
| Planos, módulos, preços (D-115) | ✓ | — | ✓ | — | — |
| Cobrança, faturas, inadimplência | ✓ | L | ✓ | L (as próprias) | — |
| Consumo (IA, armazenamento, colaboradores) | ✓ | L | ✓ | L (o próprio) | — |
| Biblioteca de modelos padrão (D-126) | ✓ | ✓ | — | L | L |
| Base de conhecimento do sistema (D-106) | ✓ | ✓ | — | L | L |
| Marca do parceiro e das empresas clientes (spec 01) | ✓ | ✓ | — | ✓ | — |
| Marca da empresa direta (D-162) | ✓ | ✓ | — | — | — |
| Equipe do parceiro (convidar administradores e consultores, remover, atribuir empresas; nunca a própria membership nem o último administrador ativo, D-584) | — | — | — | ✓ | — |
| Liberar módulos do consultor | — | — | — | ✓ | — |
| Cadastrar empresa cliente na carteira e convidar o primeiro RHA | — | — | — | ✓ **[P-03-14]** | — |
| Alterar perfis ou remover RHA de empresa cliente, e convidar um RHA novo para uma empresa que já existe (D-585) | — | — | — | ✓ **[P-03-35]** | — |
| Modelos de processo do parceiro | — | — | — | ✓ | L |
| Painel consolidado da carteira | — | — | — | C | C |
| Impersonate | ✓ | ✓ | — | — | — |

### 4.2 Configuração da empresa e usuários

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Configurações da empresa (dados, regras, retenção, período de leitura D-090) | ✓ | — | — | — | — |
| Unidades, departamentos, cargos | ✓ | L | L (os próprios) | — | — |
| Convidar e remover RH, gestores | ✓ | — | — | — | — |
| Convidar colaboradores | ✓ | U · M(`admissao`) **[P-03-15]** | — | — | — |
| Liberar módulos e unidades do RHN | ✓ | — | — | — | — |
| Ligar e desligar escritório contábil (D-171) | ✓ | — | — | — | — |
| Equipe do escritório (D-172) | — | — | — | — | ECA |
| Redefinir MFA de outro usuário (P-02-22) | ✓ (o RH) | — | — | — | ECA (os contadores) |
| Corrigir e-mail ou celular de usuário (P-02-17) | ✓ | U | — | — | — |

### 4.3 Colaboradores e cadastro

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Listar colaboradores | T | U | E | — | F (L) |
| Dados básicos (nome, cargo, unidade, departamento, contato de trabalho) | T | U | E (L) | P (L) | F (L) |
| Dados pessoais completos (documentos, endereço, dependentes) | T | U | — | P | F (L) |
| Salário e dados bancários (sensível) | T | U · M(`folha`) **[P-03-16]** | — | P (L) | F (L) |
| Dados de saúde (sensível) | T | U **[P-03-17]** | — | P (L) | — **[P-03-18]** |
| Editar cadastro | T | U | — | — | — |
| Pedir alteração dos próprios dados (validada pelo RH) | — | — | — | P | — |
| Histórico de movimentações | T | U | — | P (L) | F (L) |
| Notas internas | T | U | E | **nunca** | — |

### 4.4 Admissão (spec 07)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Criar admissão, aplicar modelo | T | U · M | — | — | — |
| Revisar documentos, pedir correção | T | U · M | — | — | — |
| Itens do checklist sob responsabilidade do gestor (por exemplo, integração) | T | U · M | E | — | — |
| Ver e enviar os próprios itens | — | — | — | P | — |
| Registrar envio à contabilidade | T | U · M | — | — | — |
| Ver encaminhamentos e confirmar recebimento (D-143) | L | L | — | — | F |

### 4.5 Documentos (spec 08)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Ver a pasta do colaborador | T | U · M | — (apresentação, p. 6) | P | F (L) (D-193) |
| Enviar documento | T | U · M | — | P | — |
| Revisar, aprovar, pedir substituição | T | U · M | — | — | — |
| Documentos de saúde (ASO, atestados) | T | U · M **[P-03-17]** | — | P (L) | — **[P-03-18]** |
| Excluir documento | T **[P-03-19]** | — | — | — | — |

### 4.6 Solicitações (spec 09)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Abrir solicitação | T (em nome de alguém) | U · M | E (em nome da equipe) **[P-03-20]** | P | — |
| Ver solicitações | T | U · M | E | P | — |
| Comentar | T | U · M | E | P (as próprias) | — |
| Notas internas | T | U · M | E | **nunca** | — |
| Aprovar ou reprovar etapa do gestor | — | — | E | — | — |
| Aprovar ou reprovar etapa do RH, concluir | T | U · M | — | — | — |
| Abrir desligamento | T | U · M | — | — | — |
| Responder solicitação LGPD (D-087) | T | — **[P-03-21]** | — | — | — |

### 4.7 Ponto e jornada (specs 10 e 11)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Marcar ponto (PWA, navegador, totem) | — | — | — | P | — |
| Ver marcações e espelho | T | U · M | E | P | — **[P-03-22]** |
| Solicitar ajuste de marcação | — | — | — | P | — |
| Aprovar ajuste de marcação | T | U · M | E **[P-03-23]** | — | — |
| Ver marcações fora da cerca e selfies | T | U · M | E **[P-03-24]** | P | — |
| Configurar escalas, jornadas, cercas, totens | T | U · M | — | — | — |
| Fechar o período e gerar AFD e AEJ | T | U · M | — | — | — |
| Banco de horas: ver | T | U · M | E | P | — |
| Banco de horas: lançar ajuste manual | T | U · M | — | — | — |

### 4.8 Folha, eSocial e obrigações (specs 12 e 13)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Rubricas, tabelas, regras (CCT) | T | — **[P-03-25]** | — | — | — |
| Calcular, conferir, fechar folha | T | U · M(`folha`) | — | — | F (L) (D-193) |
| Ver holerites | T | U · M(`folha`) | — | P | F (L) |
| Ver e emitir guias (FGTS, DCTFWeb) | T | U · M(`folha`) | — | — | F (L) |
| Gerar a lista de pagamentos e marcar como pago (D-356) | T | U · M(`folha`) **[P-03-26]** | — | — | — |
| Relatórios contábeis | T | U · M(`folha`) | — | — | F (L) |
| Transmitir eventos ao eSocial | T | U · M(`esocial`) | — | — | — |
| Ver eventos e retornos do eSocial | T | U · M(`esocial`) | — | — | F (L) (D-193) |
| Certificado A1 (enviar, trocar) | T | — | — | — | — |
| Enviar nota fiscal (PJ, D-175) | — | — | — | P (vínculo PJ) | — |
| Conferir e aprovar nota fiscal do PJ | T | U · M(`folha`) | — | — | — |

### 4.9 Recrutamento e avaliação (specs 21 e 22)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Abrir vaga | T | U · M | E (pedir vaga) **[P-03-27]** | — | — |
| Gerir candidatos e etapas | T | U · M | E (as vagas da equipe) | — | — |
| Configurar ciclos e modelos de avaliação | T | U · M | — | — | — |
| Avaliar a equipe | — | — | E | — | — |
| Autoavaliação | — | — | — | P | — |
| Ver resultados | T | U · M | E | P (os próprios) **[P-03-28]** | — |

### 4.10 IA, painéis e importação (specs 14, 17 e 18)

| Ação | RHA | RHN | GES | COL | ECA/ECC |
|---|---|---|---|---|---|
| Resumo operacional | T | U | E **[P-03-29]** | — | — |
| Assistente de políticas | ✓ | ✓ | ✓ | ✓ | — |
| Base de conhecimento do sistema (D-110) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Materiais do assistente da empresa (enviar, editar) | T | — **[P-03-30]** | — | — | — |
| Painel da empresa | T | U | E | — | — |
| Importar dados | T | U **[P-03-31]** | — | — | — |
| Exportar relatórios | T | U | E (da equipe) | — | F (relatórios contábeis) |

### 4.11 LGPD e auditoria (spec 05)

| Ação | SA | SUP | RHA | RHN | Demais |
|---|---|---|---|---|---|
| Ver trilha de auditoria da empresa | ✓ | ✓ | T | — | — |
| Ver eventos de acesso a dados sensíveis | ✓ | ✓ | T | — | — |
| Ver acessos de impersonate na empresa | ✓ | ✓ | T **[P-03-32]** | — | — |
| Exportar os próprios dados (portabilidade) | — | — | — | — | P (COL, via solicitação, D-087) |

### 4.12 Gestor do cliente (D-570)

O GCL não aparece nas tabelas anteriores: em tudo o que não está nesta tabela, ele não tem acesso (—) **[P-03-39]**.

| Ação | GCL |
|---|---|
| Listar os colaboradores alocados e ver os dados básicos (nome, cargo, unidade, cliente, data de início, contato de trabalho) | K (L) |
| Ver a admissão: etapa atual, status, data prevista de início e os itens atribuídos a ele | K (L) |
| Concluir os itens atribuídos ao papel `client_manager` (tarefa, aprovação, leitura e aceite, spec 06) | K |

- **RN-03-014** — O GCL **não** vê: a pasta de documentos, os dados pessoais completos, salário, dados bancários, dados de saúde, notas internas, painéis, relatórios e o assistente da empresa. Também não envia documentos nem edita o cadastro **[P-03-40]**.
- **RN-03-015** — Nesta versão, o GCL não participa das solicitações (spec 09) nem do ponto (specs 10 e 11). Esse ponto está em aberto em `decisoes.md` **[P-03-41]**.

## 5. Regras gerais

- **RN-03-010** — Ninguém aprova a própria solicitação, nem a do próprio ajuste de ponto ou da própria nota fiscal. Um gestor que também é colaborador tem as solicitações dele aprovadas pelo gestor do departamento acima dele ou pelo RH **[P-03-33]**.
- **RN-03-011** — Ninguém do RH vê notas internas sobre si mesmo. Se um RH analista também é colaborador, as notas internas sobre ele não aparecem para ele **[P-03-34]**.
- **RN-03-012** — Os perfis de um usuário dentro de uma empresa só podem ser alterados por quem está acima dele: o RHA altera RHN, GES e COL; o RHA de outro RHA só pode ser alterado por outro RHA ou pelo PA (empresa de parceiro) ou pelo SUP (empresa direta) **[P-03-35]**.
- **RN-03-013** — Toda empresa deve ter pelo menos um RHA ativo, ou ser atendida por um parceiro (com PA). O sistema impede remover o último RHA de uma empresa direta **[P-03-36]**.

## 6. Modelo de dados

```
memberships (spec 02)
  ...
  unit_ids (array, só para hr_analyst; vazio = nenhuma unidade)      [P-03-37]
  enabled_modules (array de strings, para hr_analyst e consultant)

department_managers (spec 04)
  department_id, membership_id   -- vários gestores por departamento (D-190, D-203)

allocation_client_managers (spec 04)
  allocation_client_id, membership_id   -- clientes do gestor do cliente (D-570)
```

## 7. Critérios de aceite

- **CA-03-001** — Dado um RH analista com a unidade Caxias e o módulo `documentos`, quando ele lista os colaboradores, então só vê os de Caxias, e o menu não mostra folha nem ponto.
- **CA-03-002** — Dado um gestor do departamento Produção, quando ele abre a ficha de um colaborador da Produção, então vê os dados básicos, mas não os documentos nem o salário.
- **CA-03-003** — Dado um colaborador, quando ele abre uma solicitação dele que tem nota interna, então não vê a nota.
- **CA-03-004** — Dado um consultor atribuído às empresas A e B com os módulos `admissao` e `solicitacoes`, quando ele entra na empresa A, então opera admissões de todas as unidades, mas não acessa a folha.
- **CA-03-005** — Dado um contador ligado à empresa A, quando ele abre a folha de outubro, então vê os valores em leitura, sem botões de recálculo ou fechamento.
- **CA-03-006** — Dado um parceiro inadimplente há 16 dias, quando um colaborador marca o ponto, então a marcação é aceita. Quando o RH tenta criar uma admissão, então recebe "Empresa em modo somente leitura".
- **CA-03-007** — Dada uma empresa sem o módulo de folha contratado, quando o RHA abre o menu, então não vê folha nem eSocial.
- **CA-03-008** — Dada uma ação de controller nova sem `authorize!`, quando a suíte de testes roda, então o teste de cobertura de autorização falha.
- **CA-03-009** — Dado um gestor que também é colaborador, quando ele abre a solicitação de férias dele, então não vê o botão de aprovar.
- **CA-03-010** — Dado um gestor do cliente X, quando ele abre a admissão de um colaborador alocado no cliente Y, então recebe 404.
- **CA-03-011** — Dado um gestor do cliente X, quando ele abre a admissão de um colaborador de X, então vê a etapa e os itens dele, mas não vê documentos, salário nem notas internas.

## 8. Fora do escopo

- Perfis personalizáveis pelo cliente (D-191 definiu perfis fixos).
- Permissão por campo além dos grupos de dados acima.

## 9. Propostas aprovadas (D-194)

Todas aprovadas. Quatro tiveram ajuste:

- **P-03-01:** o administrador do parceiro não opera dentro das empresas. Ele tem só a visão consolidada; para operar, precisa ter também o perfil de consultor.
- **P-03-14:** o administrador do parceiro cadastra a empresa cliente e convida o primeiro RHA.
- **P-03-31:** o RH analista também importa dados, nas unidades dele.
- **P-03-35:** em empresa de parceiro, o administrador do parceiro altera ou remove RHAs.

| # | Proposta |
|---|---|
| P-03-01 | O administrador do parceiro tem só a visão consolidada; para operar dentro de uma empresa, precisa ter o perfil de consultor |
| P-03-02 | O suporte age como consultor nas empresas diretas e só por impersonate nas de parceiros |
| P-03-03 | O superadmin acessa empresas só por impersonate |
| P-03-04 | Lista de módulos liberáveis por membership |
| P-03-05 | Cadastros (leitura), painéis e assistente sempre liberados para RHN e CON |
| P-03-06 | O RHA libera os módulos do RHN; o PA libera os do CON, valendo em todas as empresas atribuídas |
| P-03-07 | Módulo não contratado some do menu, sem mensagem |
| P-03-08 | Ability montada pela soma de abilities parciais |
| P-03-09 | Escopos U e E como condições de banco |
| P-03-10 | Teste que falha se alguma ação não tiver autorização |
| P-03-11 | Somente leitura aplicado na Ability |
| P-03-12 | Módulos liberados e contratados aplicados na Ability |
| P-03-13 | 404 fora do escopo; 403 dentro do escopo |
| P-03-14 | O PA cadastra empresas clientes na carteira e convida o primeiro RHA |
| P-03-15 | O RHN convida colaboradores das unidades dele, se tiver o módulo `admissao` |
| P-03-16 | O RHN só vê salário e dados bancários se tiver o módulo `folha` |
| P-03-17 | O RHN vê dados e documentos de saúde das unidades dele |
| P-03-18 | A contabilidade não vê dados nem documentos de saúde, mesmo com acesso à pasta |
| P-03-19 | Só o RHA exclui documentos |
| P-03-20 | O gestor pode abrir solicitações em nome da equipe |
| P-03-21 | Só o RHA responde solicitações de LGPD |
| P-03-22 | A contabilidade não vê ponto |
| P-03-23 | O gestor aprova ajustes de marcação da equipe |
| P-03-24 | O gestor vê marcações fora da cerca e selfies da equipe |
| P-03-25 | Só o RHA configura rubricas e regras da folha |
| P-03-26 | O RHN com o módulo `folha` gera a lista de pagamentos (antes era o CNAB, que saiu do MVP por D-356) |
| P-03-27 | O gestor pede abertura de vaga para a equipe |
| P-03-28 | O colaborador vê os próprios resultados de avaliação |
| P-03-29 | O gestor recebe o resumo operacional da equipe |
| P-03-30 | Só o RHA envia e edita materiais do assistente |
| P-03-31 | O RHA importa dados de toda a empresa; o RHN, das unidades dele |
| P-03-32 | O RHA vê os acessos de impersonate na empresa dele |
| P-03-33 | Ninguém aprova o que é próprio. O gestor tem as solicitações dele aprovadas pelo nível acima ou pelo RH |
| P-03-34 | O RH que também é colaborador não vê as notas internas sobre si mesmo |
| P-03-35 | Quem pode alterar os perfis de quem. Em empresa de parceiro, o PA altera ou remove RHAs |
| P-03-36 | Empresa direta precisa ter pelo menos um RHA ativo |
| P-03-37 | Unidades e módulos liberados guardados em arrays na membership |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-03-38 | Perfil GCL com o escopo K (clientes atribuídos), como condição de banco |
| P-03-39 | Ações do GCL: dados básicos e admissão em leitura, e conclusão dos itens atribuídos a ele |
| P-03-40 | O GCL não vê pasta, dados pessoais completos, salário, saúde, notas internas, painéis nem o assistente |
| P-03-41 | O GCL fica fora das solicitações e do ponto na primeira versão |

## 10. Em aberto

- Resolvido: os departamentos formam uma árvore (D-202), e o "gestor acima" está definido em RN-04-024.
