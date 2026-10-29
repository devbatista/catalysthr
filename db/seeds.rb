# Local sample data only, with fictional CNPJs. Production records are created through the admin area,
# never by seeds. Idempotent: run `bin/rails db:seed` as often as needed.
return unless Rails.env.development?

# A partner with two client companies: http://aurora.painel.localhost:3300
aurora = Partner.find_or_create_by!(cnpj: "98765432000198") do |partner|
  partner.name = "Aurora Gestão de Pessoas"
  partner.legal_name = "Aurora Gestão de Pessoas Ltda"
end
aurora_brand = Brand.find_or_create_by!(owner: aurora) do |brand|
  brand.commercial_name = "Aurora RH"
  brand.short_name = "Aurora"
  brand.primary_color = "#6B2FA3"
  brand.login_welcome_text = "Bem-vindo ao portal de RH da Aurora."
  brand.support_email = "suporte@aurora.example"
end
aurora_brand.subdomains.find_or_create_by!(slug: "aurora")

# The employer is found by the CNPJ root, and the full CNPJ goes to the headquarters
# (RN-04-001, RN-04-010, D-600).
def seed_company(cnpj, **attributes)
  company = Company.find_or_create_by!(document: cnpj[0, 8]) do |new_company|
    new_company.assign_attributes(employer_type: "company", **attributes)
  end
  headquarters = company.headquarters
  ActsAsTenant.with_tenant(company) { headquarters.update!(registration_type: "cnpj", registration_number: cnpj) } if headquarters.registration_number.blank?
  company
end

[
  [ "Padaria Pão Quente", "Padaria Pão Quente Ltda", "12ABC34501DE35" ],
  [ "Transportes Rápidos", "Transportes Rápidos S.A.", "13579246000101" ]
].each do |name, legal_name, cnpj|
  seed_company(cnpj, name: name, legal_name: legal_name, partner: aurora)
end

# A direct company without a configured brand: http://serraazul.painel.localhost:3300
serra_azul = seed_company("24681357000140", name: "Metalúrgica Serra Azul", legal_name: "Metalúrgica Serra Azul Ltda")
serra_azul_brand = Brand.find_or_create_by!(owner: serra_azul) do |brand|
  brand.commercial_name = serra_azul.name
end
serra_azul_brand.subdomains.find_or_create_by!(slug: "serraazul")

# An accounting firm serving the Padaria (D-170, D-171).
exata = AccountingFirm.find_or_create_by!(cnpj: "11222333000181") { |firm| firm.name = "Contábil Exata" }
AccountingFirmCompany.find_or_create_by!(accounting_firm: exata, company: Company.find_by!(document: "12ABC345")) do |link|
  link.status = "active"
  link.accepted_at = Time.current
end

# Fictional people, all with the password "Catalyst#2026". Sign in with the CPF or the e-mail.
FeatureFlags.declare
Flipper.enable(FeatureFlags::SIGN_IN)

[
  # CatalystHR team, at http://admin.localhost:3300
  [ "Rafael Batista", "39932899860", "rafael@catalysthr.example", { platform_role: "superadmin" }, nil, nil ],
  # Partner's administrator and consultant, and a client company's HR, at http://aurora.painel.localhost:3300
  [ "Beatriz Nunes", "39053344705", "beatriz@aurora.example", {}, aurora, %w[partner_admin] ],
  [ "Ana Ribeiro", "11144477735", "ana@aurora.example", {}, aurora, %w[consultant] ],
  [ "Maria Souza", "12345678909", "maria@padaria.example", {}, Company.find_by!(document: "12ABC345"), %w[hr_admin] ],
  # The accounting firm's administrator, at http://aurora.painel.localhost:3300 (MFA optional)
  [ "Eva Martins", "71460238001", "eva@exata.example", {}, exata, %w[firm_admin] ],
  # Direct company's HR, at http://serraazul.painel.localhost:3300
  [ "Carlos Mendes", "98765432100", "carlos@serraazul.example", {}, serra_azul, %w[hr_admin] ]
].each do |name, cpf, email, attributes, organization, roles|
  user = User.find_by(cpf: cpf) || User.create!(name: name, cpf: cpf, email: email, password: "Catalyst#2026", **attributes)
  next if organization.nil?

  Membership.find_or_create_by!(user: user, organization: organization) do |membership|
    membership.roles = roles
    membership.status = "active"
  end
end

# The consultant serves the Padaria (D-052).
Membership.find_by!(user: User.find_by!(cpf: "11144477735"), organization: aurora).partner_membership_companies
  .find_or_create_by!(company: Company.find_by!(document: "12ABC345"))

# Contracts (spec 19): the Aurora under contract, with both modules on for its companies;
# the Serra Azul in the free trial, where time tracking waits for the contract (D-616).
author = User.find_by!(cpf: "52998224725")
seed_plan = lambda do |kind, name, **prices|
  plan = Plan.find_or_create_by!(kind: kind, name: name)
  plan.latest_version || PlanVersion.create!(plan: plan, valid_from: Date.current, created_by: author,
    ai_credit_overage_cents: 50, whatsapp_overage_cents: 35, module_prices: { "ponto" => "400,00", "folha" => "600,00" }, **prices)
end
partner_plan = seed_plan.call("partner", "Até 500 colaboradores", monthly_price_cents: 150_000, employee_limit: 500,
  overage_per_employee_cents: 300, ai_credits: 1_000, whatsapp_messages: 2_000)
direct_plan = seed_plan.call("direct", "Empresa direta", price_per_employee_cents: 1_200, minimum_monthly_cents: 30_000,
  ai_credits_per_employee: 3, whatsapp_messages_per_employee: 5)
[
  [ aurora, partner_plan, "39053344705", { status: "active", activated_on: Date.current } ],
  [ serra_azul, direct_plan, "98765432100", { status: "trialing", trial_ends_on: Date.current + Subscription::TRIAL_DAYS } ]
].each do |owner, version, responsible_cpf, status|
  next if owner.billing_account

  account = BillingAccount.create!(owner: owner, responsible_user: User.find_by!(cpf: responsible_cpf),
    cycle_day: BillingAccount.cycle_day_for(Date.current), postal_code: "01310100", street: "Avenida Paulista",
    street_number: "1000", district: "Bela Vista", city: "São Paulo", state: "SP")
  subscription = Subscription.create!(billing_account: account, plan_version: version, created_by: author,
    started_on: Date.current, **status)
  PlanModule::MODULES.each { |code| subscription.items.create!(kind: "module", module: code, starts_on: Date.current) }
end
aurora.companies.each do |company|
  CompanyModuleSetting.apply(company, PlanModule::MODULES, by: author) if company.module_settings.empty?
end

# Fictional CatalystHR legal texts, so the first access can be completed (D-578, D-579).
LegalDocument::KINDS.each do |kind|
  next if LegalDocument.platform.exists?(kind: kind)

  LegalDocument.create!(kind: kind, published_by: author,
    body: "Texto fictício de desenvolvimento. Os textos reais são publicados pelo superadmin em /legal-documents.")
end

# Fictional employees with an employment, a dependent and a bank account, to see the
# records with data (spec 04). Valid fictional CPFs; found by CPF on later runs.
[
  [ serra_azul, "98765432100", "Operador de máquinas", "784105", [
    [ "Bruno Reis", "39813716070", "3.200,00", Date.new(2025, 8, 4) ],
    [ "Lúcia Andrade", "61839152036", "4.850,00", Date.new(2024, 2, 19) ]
  ] ],
  [ Company.find_by!(document: "12ABC345"), "12345678909", "Padeiro", "848305", [
    [ "Tiago Moura", "07217628083", "2.400,00", Date.new(2026, 1, 12) ],
    [ "Renata Prado", "84730531094", "2.650,00", Date.new(2025, 11, 3) ]
  ] ]
].each do |company, hr_cpf, position_name, cbo_code, people|
  hr = User.find_by!(cpf: hr_cpf)
  CboOccupation.find_or_create_by!(code: cbo_code) { |occupation| occupation.title = position_name }
  ActsAsTenant.with_tenant(company) do
    position = Position.find_or_create_by!(name: position_name) { |new_position| new_position.cbo_code = cbo_code }
    people.each do |name, cpf, salary, started_on|
      next if WorkerProfile.joins(:user).exists?(users: { cpf: cpf })

      registration = EmployeeRegistration.new(name: name, cpf: cpf, email: "#{cpf}@example.com", started_on: started_on,
        registration_number: company.reload.suggested_registration_number, position_id: position.id,
        unit_id: company.headquarters.id, salary: salary)
      raise registration.errors.full_messages.to_sentence unless registration.save(company: company, by: hr)

      profile = registration.profile
      profile.dependents.create!(name: "Filha de #{name.split.first}", birth_date: Date.new(2018, 5, 10), relationship_type: "child")
      BankAccounts::Register.call(profile: profile, primary: true, by: hr,
        attributes: { bank_code: "341", branch: "0001", account_number: "12345-6", account_type: "checking" })
    end
  end
end
