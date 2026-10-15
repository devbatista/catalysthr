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
