# Critérios de aceite das specs 01 a 05 e 19 (checklist)

> Última atualização: 2026-10-28
> Para o item "os critérios de aceite das specs 01 a 05 e 19 passam" da fase 1 (`plano-de-fases.md`). Uma CA marcada tem um exemplo do RSpec que a cita e testa o comportamento. A suíte roda no CI a cada PR.

Resumo: **70** CAs. **59** com teste e **11** que dependem de módulos de fases seguintes.


## Spec 01 — Multiempresa e white label

- [x] **CA-01-001** Dado um parceiro com o slug `aurora`, quando alguém acessa `aurora.painel.catalysthr.com.br`, então a tela de… Teste: `spec/requests/host_resolution_spec.rb`, `spec/requests/sign_in_spec.rb`
- [x] **CA-01-002** Dado um usuário com membership só na empresa direta `serraazul`, quando ele tenta logar em… Teste: `spec/requests/sign_in_spec.rb`
- [x] **CA-01-003** Dado um consultor atribuído às empresas A e B do parceiro, quando ele abre o seletor de empresas, então vê só… Teste: `spec/requests/partner_panel_spec.rb`
- [x] **CA-01-004** Dado um usuário com a empresa A como atual, quando ele acessa a URL de um colaborador da empresa B, então… Teste: `spec/requests/employees_spec.rb`
- [x] **CA-01-005** Dado um job enfileirado para a empresa A, quando ele roda, então só lê e grava dados da empresa A, e… Teste: `spec/models/tenancy_spec.rb`
- [x] **CA-01-006** Dado que o slug `aurora` foi trocado para `auroragp` há 10 dias, quando alguém acessa… Teste: `spec/requests/brands_spec.rb`, `spec/requests/host_resolution_spec.rb`
- [x] **CA-01-007** Dado que já se passaram 91 dias da troca, quando alguém acessa o slug antigo, então recebe a 404 neutra. Teste: `spec/requests/host_resolution_spec.rb`
- [x] **CA-01-008** Dado um domínio de e-mail ainda pendente, quando um convite é enviado, então ele sai de… Teste: `spec/services/invitations_spec.rb`
- [x] **CA-01-009** Dado um domínio verificado no SES, quando um convite é enviado, então ele sai de `no-reply@<domínio da… Teste: `spec/services/invitations_spec.rb`
- [x] **CA-01-010** Dada uma cor primária com contraste menor que 4.5:1 com branco, quando o admin do parceiro tenta salvar,… Teste: `spec/models/brand_spec.rb`, `spec/requests/brands_spec.rb`
- [x] **CA-01-011** Dado um colaborador no subdomínio da marca, quando ele instala o PWA, então o app aparece com o nome curto e… Teste: `spec/requests/host_resolution_spec.rb`
- [x] **CA-01-012** Dada uma empresa transferida do parceiro X para o Y, quando um consultor de X tenta acessá-la, então não a… Teste: `spec/requests/company_transfer_spec.rb`
- [x] **CA-01-013** Dado o slug `admin`, quando o admin tenta usá-lo para um parceiro, então o sistema recusa por ser um nome… Teste: `spec/models/brand_subdomain_spec.rb`, `spec/requests/brands_spec.rb`

## Spec 02 — Identidade e acesso

- [x] **CA-02-001** Dado um colaborador sem e-mail, com CPF e celular, quando o RH o convida por WhatsApp e link impresso, então… Teste: `spec/requests/invitations_spec.rb`, `spec/services/invitations_spec.rb`
- [x] **CA-02-002** Dado um convite reenviado, quando a pessoa usa o link antigo, então vê "convite expirado". Teste: `spec/requests/invitations_spec.rb`, `spec/requests/memberships_spec.rb`
- [x] **CA-02-003** Dado um usuário que digita `123.456.789-09` ou `12345678909`, quando a senha está certa, então ele entra nos… Teste: `spec/requests/sign_in_spec.rb`
- [x] **CA-02-004** Dada a senha `catalyst1`, quando o usuário tenta salvá-la, então o sistema recusa por faltar maiúscula e… Teste: `spec/models/user_spec.rb`, `spec/requests/sign_in_spec.rb`
- [x] **CA-02-005** Dadas 5 tentativas erradas, quando o usuário tenta de novo com a senha certa, então a conta continua… Teste: `spec/requests/sign_in_spec.rb`
- [x] **CA-02-006** Dado um RH analista no primeiro acesso, quando ele termina de criar a senha e aceitar os termos, então não… Teste: `spec/requests/mfa_spec.rb`
- [x] **CA-02-007** Dado um usuário que marcou "lembrar este dispositivo", quando ele entra de novo no mesmo navegador em até 30… Teste: `spec/requests/mfa_spec.rb`
- [x] **CA-02-008** Dado um gestor que também é colaborador, quando fica 31 minutos sem usar o sistema, então precisa entrar de… Teste: `spec/requests/user_sessions_spec.rb`
- [ ] **CA-02-009** Dado um colaborador logado no PWA há 10 dias, quando ele abre o holerite, então o sistema pede a senha. Se… Fica para: Fase 2: holerite no portal (specs 12 e 16)
- [ ] **CA-02-010** Dado um colaborador desligado com 90 dias de leitura configurados, quando ele entra no dia 30, então vê… Fica para: Fase 4: desligamento e período de leitura (specs 12 e 13)
- [x] **CA-02-011** Dado um escritório já cadastrado (mesmo CNPJ), quando outro RH administrador o liga à empresa dele, então a… Teste: `spec/requests/accounting_firm_spec.rb`
- [x] **CA-02-012** Dado um suporte em impersonate de um RH, quando ele salva a edição de um colaborador, então vê o resultado… Teste: `spec/requests/impersonation_spec.rb`
- [x] **CA-02-013** Dado um suporte em impersonate, quando ele abre a ficha de um colaborador, então o salário aparece como `R$… Teste: `spec/requests/impersonation_spec.rb` Ressalva: o atestado de saúde entra com os documentos (spec 08); o teste cobre o salário.
- [x] **CA-02-014** Dado um impersonate iniciado há 30 minutos, quando o suporte faz a próxima requisição, então a sessão é… Teste: `spec/requests/impersonation_spec.rb`
- [x] **CA-02-015** Dado um suporte, quando ele tenta iniciar o impersonate sem motivo, então o sistema não permite. Teste: `spec/requests/impersonation_spec.rb`
- [x] **CA-02-016** Dada a recuperação de senha com um CPF inexistente, quando a pessoa envia o formulário, então vê a mesma… Teste: `spec/requests/sign_in_spec.rb`
- [x] **CA-02-017** Dado um gestor do cliente no primeiro acesso, quando ele termina de criar a senha e aceitar os termos, então… Teste: `spec/requests/mfa_spec.rb`
- [x] **CA-02-018** Dado um gestor do cliente com um único cliente, quando o RH inativa esse cliente, então o perfil dele é… Teste: `spec/requests/allocation_clients_and_custom_fields_spec.rb`

## Spec 03 — Permissões

- [x] **CA-03-001** Dado um RH analista com a unidade Caxias e o módulo `documentos`, quando ele lista os colaboradores, então só… Teste: `spec/requests/employees_spec.rb`, `spec/requests/navigation_spec.rb`
- [x] **CA-03-002** Dado um gestor do departamento Produção, quando ele abre a ficha de um colaborador da Produção, então vê os… Teste: `spec/requests/employees_spec.rb`
- [ ] **CA-03-003** Dado um colaborador, quando ele abre uma solicitação dele que tem nota interna, então não vê a nota. Fica para: Fase 2: solicitações (spec 09)
- [ ] **CA-03-004** Dado um consultor atribuído às empresas A e B com os módulos `admissao` e `solicitacoes`, quando ele entra na… Fica para: Fase 2: admissão (spec 07). O consultor como RHN de todas as unidades já tem teste (D-192)
- [ ] **CA-03-005** Dado um contador ligado à empresa A, quando ele abre a folha de outubro, então vê os valores em leitura, sem… Fica para: Fase 4: folha (spec 12)
- [x] **CA-03-006** Dado um parceiro inadimplente há 16 dias, quando um colaborador marca o ponto, então a marcação é aceita.… Teste: `spec/requests/contract_lock_spec.rb` Ressalva: a marcação de ponto aceita em somente leitura entra com o ponto (spec 10); o teste cobre a escrita recusada.
- [x] **CA-03-007** Dada uma empresa sem o módulo de folha contratado, quando o RHA abre o menu, então não vê folha nem eSocial. Teste: `spec/requests/navigation_spec.rb` O eSocial não tem item de menu até a spec 13.
- [x] **CA-03-008** Dada uma ação de controller nova sem `authorize!`, quando a suíte de testes roda, então o teste de cobertura… Teste: `spec/requests/authorization_coverage_spec.rb`, `spec/support/authorization_coverage.rb`
- [ ] **CA-03-009** Dado um gestor que também é colaborador, quando ele abre a solicitação de férias dele, então não vê o botão… Fica para: Fase 4: férias (spec 09)
- [ ] **CA-03-010** Dado um gestor do cliente X, quando ele abre a admissão de um colaborador alocado no cliente Y, então recebe… Fica para: Fase 2: admissão (spec 07)
- [ ] **CA-03-011** Dado um gestor do cliente X, quando ele abre a admissão de um colaborador de X, então vê a etapa e os itens… Fica para: Fase 2: admissão (spec 07)

## Spec 04 — Cadastros

- [x] **CA-04-001** Dada uma empresa com CNPJ raiz 12.345.678, quando o RH cadastra uma filial com CNPJ 98.765.432/0002-xx, então… Teste: `spec/models/unit_spec.rb`, `spec/requests/units_spec.rb`
- [x] **CA-04-002** Dado o departamento Usinagem dentro de Produção, com Carlos como gestor de Produção, quando um colaborador da… Teste: `spec/models/department_spec.rb`
- [x] **CA-04-003** Dado que Usinagem não tem gestor e Produção tem dois, quando o gestor de Usinagem pediria férias para si… Teste: `spec/models/department_spec.rb`
- [x] **CA-04-004** Dado um vínculo com salário de R$ 2.000 vigente desde 01/03, quando o RH registra R$ 2.300 a partir de 01/12,… Teste: `spec/models/employment_revision_spec.rb`, `spec/requests/employees_spec.rb`
- [x] **CA-04-005** Dado um salário abaixo do mínimo da faixa do cargo, quando o RH salva, então o sistema pede uma justificativa… Teste: `spec/models/employee_registration_spec.rb`, `spec/models/employment_revision_spec.rb`, `spec/requests/employees_spec.rb`
- [x] **CA-04-006** Dado um estagiário, quando o RH registra a efetivação, então o vínculo de estágio fica `terminated`, um… Teste: `spec/models/employment_registration_spec.rb`, `spec/requests/employee_records_spec.rb`
- [x] **CA-04-007** Dado o colaborador João nas empresas A e B, quando a empresa A altera o endereço dele, então a ficha na… Teste: `spec/models/employee_registration_spec.rb`
- [x] **CA-04-008** Dado um colaborador que pede a troca de conta bancária com comprovante, quando o RH aprova, então a conta… Teste: `spec/models/bank_account_spec.rb`, `spec/requests/employee_records_spec.rb`
- [ ] **CA-04-009** Dado um campo personalizado "Tamanho do uniforme", editável pelo colaborador, quando o colaborador preenche,… Fica para: Fase 2: atualização pelo colaborador (specs 09 e 16)
- [x] **CA-04-010** Dada uma matrícula 1050 já usada por um vínculo encerrado, quando o RH tenta usá-la num vínculo novo, então o… Teste: `spec/models/employee_registration_spec.rb`, `spec/requests/employees_spec.rb`
- [x] **CA-04-011** Dada uma empresa com clientes de alocação desligados, quando o RH abre a revisão de um vínculo, então não vê… Teste: `spec/requests/allocation_clients_and_custom_fields_spec.rb`
- [x] **CA-04-012** Dada Ana alocada no cliente X e trocada para o cliente Y a partir de 01/12, quando chega 01/12, então os… Teste: `spec/models/allocation_client_spec.rb`
- [x] **CA-04-013** Dado um cliente com um vínculo `pending`, quando o RH tenta inativá-lo, então o sistema recusa. Teste: `spec/models/allocation_client_spec.rb`, `spec/requests/allocation_clients_and_custom_fields_spec.rb`

## Spec 19 — Administração e cobrança

- [x] **CA-19-001** Dado um parceiro com faixa de 500 e pico de 530 colaboradores em outubro, quando a fatura de novembro é… Teste: `spec/models/billing/invoicing_spec.rb`
- [x] **CA-19-002** Dado um colaborador desligado em 10/10 em período de leitura, quando o pico de novembro é calculado, então… Teste: `spec/jobs/billing/daily_usage_job_spec.rb`
- [x] **CA-19-003** Dada uma empresa direta em teste, quando o RH tenta configurar o ponto, então o módulo aparece como… Teste: `spec/models/company_modules_spec.rb`, `spec/requests/navigation_spec.rb`
- [ ] **CA-19-004** Dado um teste que termina sem contratação, quando passam 14 dias, então a conta fica em leitura com a… Fica para: Fase 2: exportação e exclusão do encerramento (D-610)
- [x] **CA-19-005** Dado um parceiro que contrata o módulo de ponto no dia 10 de um ciclo que começa no dia 1, quando a próxima… Teste: `spec/models/billing/contract_changes_spec.rb`, `spec/requests/admin/contract_changes_spec.rb`
- [x] **CA-19-006** Dado um parceiro em atraso há 15 dias, quando o RH de uma empresa da carteira entra, então vê a faixa de… Teste: `spec/requests/contract_lock_spec.rb`
- [x] **CA-19-007** Dado um pagamento por PIX confirmado no dia 20 de atraso, quando o webhook chega, então a conta volta a… Teste: `spec/models/billing/pix_spec.rb`, `spec/requests/mercado_pago_webhooks_spec.rb`
- [x] **CA-19-008** Dado um webhook perdido, quando o job de conferência roda, então a fatura paga é encontrada na API e marcada… Teste: `spec/models/billing/pix_spec.rb`
- [x] **CA-19-009** Dado um ajuste de 25% lançado pelo financeiro, quando ele salva, então o ajuste fica aguardando a aprovação… Teste: `spec/models/billing/adjustments_spec.rb`, `spec/requests/admin/billing_adjustments_spec.rb`
- [x] **CA-19-010** Dado o parceiro, quando baixa o relatório de outubro, então o CSV tem uma linha por empresa com o pico de… Teste: `spec/requests/partner_usage_spec.rb`
- [ ] **CA-19-011** Dado um contrato com custo de IA maior que o cobrado, quando o superadmin abre o painel, então o contrato… Fica para: Fase 2: bloco Custos do painel (D-610)
- [x] **CA-19-012** Dada uma fatura paga por PIX, quando o webhook do Mercado Pago confirma o pagamento, então a nota é agendada… Teste: `spec/requests/service_invoice_end_to_end_spec.rb`, `spec/requests/service_invoice_files_spec.rb`
- [x] **CA-19-013** Dada uma nota recusada pela prefeitura, quando o webhook de erro chega, então a fatura mostra a mensagem, o… Teste: `spec/models/billing/service_invoices_spec.rb`, `spec/requests/service_invoices_spec.rb`
- [x] **CA-19-014** Dado um estorno no Mercado Pago de uma fatura com nota autorizada, quando o webhook chega, então a plataforma… Teste: `spec/models/billing/service_invoices_spec.rb`, `spec/requests/service_invoice_files_spec.rb`
- [x] **CA-19-015** Dada uma fatura de valor zero por crédito, quando é marcada como paga, então nenhuma nota é emitida. Teste: `spec/models/billing/service_invoices_spec.rb`
