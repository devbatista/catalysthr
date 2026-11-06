module Documents
  # The variables of contracts and terms (RN-07-041, D-650): a fixed catalog, whose values
  # come from the record, the employment and the company. Sensitive ones are in it, so the
  # PDF is protected as a whole (D-650).
  class TemplateVariables
    CATALOG = %w[colaborador.nome colaborador.cpf colaborador.rg colaborador.ctps colaborador.pis colaborador.nascimento
      colaborador.endereco cargo.nome cargo.cbo vinculo.salario vinculo.inicio vinculo.matricula vinculo.jornada
      vinculo.experiencia_dias vinculo.experiencia_prorrogacao vinculo.experiencia_fim
      empresa.razao_social empresa.documento empresa.endereco unidade.nome unidade.endereco unidade.cidade hoje].freeze
    PATTERN = /\{\{\s*([^{}]*?)\s*\}\}/

    def self.used_in(text)
      text.to_s.scan(PATTERN).flatten.uniq & CATALOG
    end

    def self.unknown_in(text)
      text.to_s.scan(PATTERN).flatten.uniq - CATALOG
    end

    # The value of each name; blank is "".
    def initialize(employment)
      @employment = employment
      @profile = employment.worker_profile
      @user = @profile.user
      @revision = employment.effective_revision
      @company = employment.company
    end

    def values(names = CATALOG)
      names.to_h { |name| [ name, value(name).to_s ] }
    end

    private

    def value(name)
      case name
      when "colaborador.nome" then @user.name
      when "colaborador.cpf" then Cpf.format(@user.cpf)
      when "colaborador.rg" then @profile.rg_number
      when "colaborador.ctps" then [ @profile.ctps_number, @profile.ctps_series ].compact_blank.join(" / ")
      when "colaborador.pis" then @profile.pis_nis
      when "colaborador.nascimento" then @user.birth_date && I18n.l(@user.birth_date)
      when "colaborador.endereco" then address(@profile)
      when "cargo.nome" then @revision&.position&.name
      when "cargo.cbo" then @revision&.cbo_code
      when "vinculo.salario" then @revision&.salary_cents && "R$ #{MoneyCents.format(@revision.salary_cents)}"
      when "vinculo.inicio" then I18n.l(@employment.started_on)
      when "vinculo.matricula" then @employment.registration_number
      when "vinculo.jornada" then @revision&.weekly_hours && "#{@revision.weekly_hours.to_s("F").delete_suffix(".0")} horas semanais"
      when "vinculo.experiencia_dias" then @employment.experience_first_days
      when "vinculo.experiencia_prorrogacao" then @employment.experience_extension_days
      when "vinculo.experiencia_fim" then @employment.experience_first_ends_on && I18n.l(@employment.experience_first_ends_on)
      when "empresa.razao_social" then @company.legal_name
      when "empresa.documento" then @company.formatted_document
      when "empresa.endereco" then @company.headquarters && address(@company.headquarters)
      when "unidade.nome" then @revision&.unit&.name
      when "unidade.endereco" then @revision&.unit && address(@revision.unit)
      when "unidade.cidade" then [ @revision&.unit&.city, @revision&.unit&.state ].compact_blank.join(" / ")
      when "hoje" then I18n.l(Time.find_zone(@revision&.unit&.time_zone || "America/Sao_Paulo").today, format: :long)
      end
    end

    def address(record)
      ApplicationController.helpers.unit_address(record)
    end
  end
end
