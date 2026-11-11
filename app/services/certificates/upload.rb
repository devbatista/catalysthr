module Certificates
  # The HR administrator sends the company's A1 (spec 13, RN-13-020, RN-13-021, D-673): the .pfx
  # or .p12 and its password, saying whether it is the employer's own or a proxy's. The file is
  # read and checked (Reader), its holder compared with the employer (the CNPJ's root, or the
  # CPF of an employer person), sealed (Vault) and kept as the company's only active one; the
  # previous one is erased (D-673). Each sending is an access event; the password never goes to
  # a log.
  class Upload
    include ActiveModel::Model

    EXTENSIONS = %w[.pfx .p12].freeze

    attr_accessor :company, :file, :password, :owner_kind, :by
    attr_reader :certificate

    validates :owner_kind, inclusion: { in: EmployerCertificate::OWNER_KINDS }
    validate :file_present
    validate :readable, if: -> { errors.none? }
    validate :holder_matches, if: -> { errors.none? }

    def save
      return false unless valid?
      return true if Simulation.active?

      sealed = Vault.seal(company, pfx: content, password: password)
      company.with_lock do
        EmployerCertificate.active.find_each { |previous| previous.retire!("replaced") }
        @certificate = EmployerCertificate.create!(owner_kind: owner_kind, holder_name: @read.holder_name,
          holder_document: @read.holder_document, valid_from: @read.valid_from, valid_to: @read.valid_to,
          uploaded_by: by, **sealed.to_h, alerted_days: already_due)
        AccessEvent.record!(kind: "certificate", action: "certificate_uploaded", user: by, subject: @certificate, company: company)
      end
      true
    rescue Vault::NotConfigured
      errors.add(:base, :not_configured)
      false
    end

    def content
      @content ||= file.respond_to?(:read) ? file.read.tap { file.rewind if file.respond_to?(:rewind) } : file.to_s
    end

    private

    def file_present
      return errors.add(:file, :blank) if file.blank?

      name = file.respond_to?(:original_filename) ? file.original_filename.to_s : ""
      errors.add(:file, :format) unless File.extname(name).downcase.in?(EXTENSIONS)
    end

    def readable
      @read = Reader.call(content, password)
    rescue Reader::Invalid => error
      errors.add(:file, error.key)
    end

    # RN-13-021: the employer's own holds the employer's document; a proxy's, another one.
    def holder_matches
      employer = employer_holder?
      if owner_kind == "employer" && !employer
        errors.add(:owner_kind, :not_employer, document: formatted_holder)
      elsif owner_kind == "proxy" && employer
        errors.add(:owner_kind, :is_employer)
      end
    end

    def employer_holder?
      document = @read.holder_document
      company.person? ? document == company.document : document.length == 14 && document[0, 8] == company.document
    end

    def formatted_holder = EmployerCertificate.new(holder_document: @read.holder_document).formatted_holder_document

    # The notices already passed for a certificate that arrives close to its end: only the
    # next ones are sent.
    def already_due
      days = (@read.valid_to.to_date - Date.current).to_i
      EmployerCertificate::ALERT_DAYS.select { |limit| days < limit }.min
    end
  end
end
