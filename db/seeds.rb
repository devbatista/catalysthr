# Local sample data only, with fictional CNPJs. Production records are created through the admin area,
# never by seeds. Idempotent: run `bin/rails db:seed` as often as needed.
return unless Rails.env.development?

# A partner with two client companies: http://aurora.painel.localhost:3000
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

[
  [ "Padaria Pão Quente", "Padaria Pão Quente Ltda", "12ABC34501DE35" ],
  [ "Transportes Rápidos", "Transportes Rápidos S.A.", "13579246000101" ]
].each do |name, legal_name, cnpj|
  Company.find_or_create_by!(cnpj: cnpj) do |company|
    company.partner = aurora
    company.name = name
    company.legal_name = legal_name
  end
end

# A direct company without a configured brand: http://serraazul.painel.localhost:3000
serra_azul = Company.find_or_create_by!(cnpj: "24681357000140") do |company|
  company.name = "Metalúrgica Serra Azul"
  company.legal_name = "Metalúrgica Serra Azul Ltda"
end
serra_azul_brand = Brand.find_or_create_by!(owner: serra_azul) do |brand|
  brand.commercial_name = serra_azul.name
end
serra_azul_brand.subdomains.find_or_create_by!(slug: "serraazul")

# Fictional people, all with the password "Catalyst#2026". Sign in with the CPF or the e-mail.
FeatureFlags.declare
Flipper.enable(FeatureFlags::SIGN_IN)

[
  # CatalystHR team, at http://admin.localhost:3000
  [ "Paulo Lima", "52998224725", "paulo@catalysthr.example", { platform_role: "superadmin" }, nil, nil ],
  # Partner's consultant and a client company's HR, at http://aurora.painel.localhost:3000
  [ "Ana Ribeiro", "11144477735", "ana@aurora.example", {}, aurora, %w[consultant] ],
  [ "Maria Souza", "12345678909", "maria@padaria.example", {}, Company.find_by!(cnpj: "12ABC34501DE35"), %w[hr_admin] ],
  # Direct company's HR, at http://serraazul.painel.localhost:3000
  [ "Carlos Mendes", "98765432100", "carlos@serraazul.example", {}, serra_azul, %w[hr_admin] ]
].each do |name, cpf, email, attributes, organization, roles|
  user = User.find_by(cpf: cpf) || User.create!(name: name, cpf: cpf, email: email, password: "Catalyst#2026", **attributes)
  next if organization.nil?

  Membership.find_or_create_by!(user: user, organization: organization) do |membership|
    membership.roles = roles
    membership.status = "active"
  end
end
