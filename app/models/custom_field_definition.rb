# An extra field of the person's record, created by the company (RN-04-080, D-213): text,
# number, date, a choice among options, or yes/no. The key is fixed at creation, so the
# values in the records keep pointing to it. Removing a field inactivates it: it is
# hidden and the values stay (RN-04-081, P-04-26). The visibility and the edition by the
# employee take effect with the portal (spec 16), through the HR's approval (RN-04-071).
# Sensitive data has its own place in the record and never goes here (D-086, D-605).
class CustomFieldDefinition < ApplicationRecord
  FIELD_TYPES = %w[text number date select boolean].freeze
  STATUSES = %w[active inactive].freeze

  audited

  acts_as_tenant :company

  enum :field_type, FIELD_TYPES.index_by(&:itself), validate: true, prefix: :type
  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :label, with: ->(label) { label.to_s.squish.presence }
  normalizes :options, with: ->(options) { Array(options).map { |option| option.to_s.squish }.compact_blank.uniq }

  scope :ordered, -> { order(:label) }

  before_validation :assign_key, on: :create
  before_validation :clear_options, unless: :type_select?

  validates :label, presence: true, length: { maximum: 80 }
  validates :key, presence: true, uniqueness: { scope: :company_id }, format: { with: /\A[a-z][a-z0-9_]{0,59}\z/ }
  validates :options, presence: true, if: :type_select?
  validate :key_and_type_fixed, on: :update
  validate :editable_only_when_visible

  def audit_company_id
    company_id
  end

  # The value typed in a form, kept in the record's JSONB: text, a number as text, an ISO
  # date, an option or true/false. Blank is nil; :invalid when it does not fit the type.
  def cast(value)
    return value if [ true, false ].include?(value) && type_boolean?
    return if value.to_s.strip.empty?

    text = value.to_s.strip
    case field_type
    when "text" then text.first(500)
    when "number" then text.tr(",", ".").match?(/\A-?\d+(\.\d+)?\z/) ? text.tr(",", ".") : :invalid
    when "date" then Date.iso8601(text).iso8601
    when "select" then options.include?(text) ? text : :invalid
    when "boolean" then ActiveModel::Type::Boolean.new.cast(text)
    end
  rescue Date::Error
    :invalid
  end

  private

  def assign_key
    return if key.present? || label.blank?

    base = I18n.transliterate(label).downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").first(50)
    base = "campo_#{base}" unless base.match?(/\A[a-z]/)
    candidate = base
    number = 1
    candidate = "#{base}_#{number += 1}" while self.class.exists?(key: candidate)
    self.key = candidate
  end

  def clear_options
    self.options = []
  end

  def key_and_type_fixed
    errors.add(:key, :fixed) if key_changed?
    errors.add(:field_type, :fixed) if field_type_changed?
  end

  def editable_only_when_visible
    errors.add(:editable_by_employee, :not_visible) if editable_by_employee && !visible_to_employee
  end
end
