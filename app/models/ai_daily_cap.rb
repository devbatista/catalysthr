# The company's day against its safety cap (spec 14, RN-14-114, D-395): the cap of the day, the
# credits used, and the pause when the cap is reached, until midnight in Brasília or until the
# superadmin or the support releases it. Paused, every function goes to the manual flow.
class AiDailyCap < ApplicationRecord
  audited ignore: %i[used_credits]

  belongs_to :company
  belongs_to :released_by, class_name: "User", optional: true

  def paused? = paused_at.present? && released_at.nil?
  def released? = released_at.present?
end
