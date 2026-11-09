# The code of a unit, a department or a position (spec 18, D-662): optional, unique in the
# company, in capitals, without spaces. It is the structure import's key and what the other
# imports point to (P-18-08).
module StructureCode
  extend ActiveSupport::Concern

  FORMAT = /\A[A-Z0-9][A-Z0-9._-]*\z/
  MAX_LENGTH = 30

  included do
    normalizes :code, with: ->(code) { code.to_s.strip.upcase.presence }

    validates :code, length: { maximum: MAX_LENGTH }, format: { with: FORMAT }, allow_nil: true
    validates :code, uniqueness: { scope: :company_id }, allow_nil: true

    scope :with_code, ->(code) { where(code: code.to_s.strip.upcase) }
  end
end
