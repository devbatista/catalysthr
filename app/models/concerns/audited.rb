# Change trail with PaperTrail (spec 05, RN-05-010, RN-05-011). Each version records who
# changed it, the IP, the request id and the company. Sensitive fields (D-086, D-221)
# never enter the version: only their names, in sensitive_fields. Secrets (password,
# tokens, MFA) stay out entirely, and their changes become access events.
#
#   audited sensitive: %i[cpf], secret: %i[encrypted_password], ignore: %i[sign_in_count]
module Audited
  extend ActiveSupport::Concern

  included do
    class_attribute :audited_sensitive_fields, instance_writer: false, default: [].freeze
    class_attribute :audited_ignored_fields, instance_writer: false, default: [].freeze
  end

  class_methods do
    def audited(sensitive: [], secret: [], ignore: [])
      self.audited_sensitive_fields = sensitive.map(&:to_s).freeze
      self.audited_ignored_fields = (ignore.map(&:to_s) + %w[updated_at]).freeze

      # The version accessor gets another name: legal_documents has a version column.
      has_paper_trail skip: audited_sensitive_fields + secret.map(&:to_s), ignore: audited_ignored_fields,
        version: :paper_trail_version,
        meta: { company_id: :audit_company_id, sensitive_fields: :changed_sensitive_fields }

      # A change only to sensitive fields does not create a version in PaperTrail, so
      # it is recorded here, with the field names and without the values.
      after_update :record_sensitive_change, if: :sensitive_only_change?
    end
  end

  # The company the record belongs to, if any, so the trail can be read per company.
  def audit_company_id
    respond_to?(:company_id) ? company_id : nil
  end

  def changed_sensitive_fields
    saved_changes.keys & audited_sensitive_fields
  end

  private

  def sensitive_only_change?
    return false unless PaperTrail.request.enabled? && PaperTrail.request.enabled_for_model?(self.class)

    changed = saved_changes.keys - audited_ignored_fields
    changed.any? && (changed - audited_sensitive_fields).empty?
  end

  def record_sensitive_change
    PaperTrail::Version.create!(
      item: self, event: "update", whodunnit: PaperTrail.request.whodunnit, object_changes: {},
      sensitive_fields: changed_sensitive_fields, company_id: audit_company_id,
      **PaperTrail.request.controller_info.to_h.symbolize_keys.slice(:ip, :request_id, :impersonator_id)
    )
  end
end
