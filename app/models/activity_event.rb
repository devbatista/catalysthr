# A happening of the company for the HR panel's "Atividade recente" (spec 17, RN-17-011,
# P-17-03, D-658): a document sent, an admission forwarded to the accounting firm. The text
# is written when it happens, without sensitive data: a document of a sensitive type goes
# without the type's name (D-658). The unit, the client and the module say who sees it
# (RN-17-001, RN-17-005, RN-17-014). Kept 90 days (D-657).
class ActivityEvent < ApplicationRecord
  KINDS = %w[document_sent admission_forwarded].freeze
  RETENTION = 90.days
  SHOWN = 20

  acts_as_tenant :company

  belongs_to :unit, optional: true
  belongs_to :department, optional: true
  belongs_to :allocation_client, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :module_code, inclusion: { in: Membership::RELEASABLE_MODULES }
  validates :text, :occurred_at, presence: true

  # Records the happening where the person works today: their unit, department and client.
  # Nothing is written during an impersonate simulation (RN-02-085), and a failure never
  # stops what happened: the panel just misses a line.
  def self.record(kind, employment:, module_code:, text:, actor: nil, url: nil)
    return if Simulation.active?

    revision = employment&.effective_revision
    create!(kind: kind, module_code: module_code, text: text, actor_name: actor&.name, url: url, occurred_at: Time.current,
      unit_id: revision&.unit_id, department_id: revision&.department_id, allocation_client_id: revision&.allocation_client_id)
  rescue StandardError => error
    Rails.error.report(error, handled: true, context: { kind: kind })
    nil
  end
end
