module Companies
  # Moves a company to another partner, or to and from the direct modality (RN-01-050 to
  # RN-01-053, D-123, D-599). Only the owner changes: the company's data, its own
  # memberships and its accounting firm stay; the old partner's consultants stop reaching
  # it. The old address does not redirect (P-01-13), and the company's users are told the
  # new one. Only the superadmin transfers (spec 01, section 6).
  #
  # When the models of process, the assistant's materials and the Q&A exist (specs 06 and
  # 14), what the company used from the old partner is copied here (RN-01-053, D-599).
  class Transfer
    Result = Data.define(:transfer, :errors) do
      def success? = errors.empty?
    end
    Changed = Class.new(StandardError)

    def self.call(**)
      new(**).call
    end

    # to_partner: nil makes the company direct, with a subdomain at slug.
    def initialize(company:, to_partner:, performed_by:, authorized_by_text:, document: nil, slug: nil)
      @company = company
      @from_partner = company.partner
      @to_partner = to_partner
      @performed_by = performed_by
      @authorized_by_text = authorized_by_text.to_s.strip
      @document = document
      @slug = slug.to_s.strip.downcase
    end

    def call
      errors = check
      return Result.new(transfer: nil, errors: errors) if errors.any?

      # The brand stops owning a subdomain, so its e-mail domain goes too (D-599). Done
      # first, because SES may not answer and nothing has changed yet.
      return failure(:email_unavailable) if leaving_direct? && @company.brand && Brands::RemoveEmailDomain.call(brand: @company.brand) == false

      transfer = @company.with_lock do
        # Someone else transferred it meanwhile.
        raise Changed unless @company.partner_id == @from_partner&.id

        release_subdomain if leaving_direct?
        move
        record
      end
      @company.brand&.subdomains&.each(&:expire_host_lookup)
      Companies::TransferNotificationJob.perform_later(transfer)
      Result.new(transfer: transfer, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      Result.new(transfer: nil, errors: error.record.errors.full_messages)
    rescue Changed
      failure(:changed)
    end

    private

    def leaving_direct?
      @from_partner.nil?
    end

    def check
      errors = []
      errors << message(:same_owner) if @to_partner&.id == @from_partner&.id
      errors << message(:partner_without_subdomain) if @to_partner && !@to_partner.brand&.active_subdomain
      errors << message(:authorization_missing) if @authorized_by_text.blank?
      errors << message(:slug_missing) if @to_partner.nil? && @slug.blank?
      errors.concat(document_errors) if @document.present?
      errors
    end

    def document_errors
      io = @document.to_io
      content_type = Marcel::MimeType.for(io)
      io.rewind
      errors = []
      errors << message(:document_type) unless content_type.in?(CompanyTransfer::DOCUMENT_TYPES)
      errors << message(:document_size) if @document.size > CompanyTransfer::MAX_DOCUMENT_SIZE
      @document_type = content_type
      errors
    end

    # The old address answers the neutral 404 and the slug stays reserved for 90 days,
    # until the release job frees it (D-599).
    def release_subdomain
      @company.brand&.subdomains&.active&.each do |subdomain|
        subdomain.update!(status: "redirecting", redirect_until: BrandSubdomain::REDIRECT_PERIOD.from_now)
      end
    end

    def move
      # The old partner's consultants stop reaching the company (RN-01-051).
      PartnerMembershipCompany.where(company: @company).delete_all
      @company.update!(partner: @to_partner, brand_display_mode: @to_partner ? (@company.brand_display_mode || "alongside") : nil)
      become_direct if @to_partner.nil?
    end

    # The company's own brand becomes the direct company's; without one, a brand with its
    # name and CatalystHR's colors (P-01-02). A slug it had before comes back.
    def become_direct
      brand = @company.brand || @company.create_brand!(commercial_name: @company.name)
      Brands::ChangeSlug.call(brand: brand, slug: @slug)
    end

    def record
      transfer = CompanyTransfer.create!(company: @company, from_partner: @from_partner, to_partner: @to_partner,
        performed_by: @performed_by, authorized_by_text: @authorized_by_text, performed_at: Time.current)
      attach_document(transfer) if @document.present?
      transfer
    end

    # Under the company's prefix in the bucket (RN-01-014).
    def attach_document(transfer)
      transfer.authorization_document.attach(ActiveStorage::Blob.create_and_upload!(
        io: @document.to_io, filename: @document.original_filename, content_type: @document_type, identify: false,
        key: "companies/#{@company.id}/transfers/#{SecureRandom.base36(28)}"
      ))
    end

    def failure(key)
      Result.new(transfer: nil, errors: [ message(key) ])
    end

    def message(key)
      I18n.t("companies.transfer.errors.#{key}")
    end
  end
end
