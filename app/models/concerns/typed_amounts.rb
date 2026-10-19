# Amounts typed in reais and kept in integer cents (AGENTS.md, section 4). For each field,
# `field=` takes the text and fills `field_cents`; `field` gives back what was typed, or the
# stored amount formatted. A text that is not an amount is an error on `field_cents`.
#
#   typed_amounts :monthly_price, :overage_per_employee
module TypedAmounts
  extend ActiveSupport::Concern

  included do
    validate :typed_amounts_are_amounts
  end

  class_methods do
    def typed_amounts(*fields)
      fields.each do |field|
        define_method(field) { typed_amount_texts.fetch(field) { MoneyCents.format(public_send(:"#{field}_cents")) } }
        define_method(:"#{field}=") do |text|
          typed_amount_texts[field] = text
          cents = MoneyCents.parse(text)
          public_send(:"#{field}_cents=", cents == :invalid ? nil : cents)
        end
        validates :"#{field}_cents", numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
      end
    end
  end

  def invalid_amount?(field)
    typed_amount_texts.key?(field) && MoneyCents.parse(typed_amount_texts[field]) == :invalid
  end

  private

  def typed_amount_texts
    @typed_amount_texts ||= {}
  end

  def typed_amounts_are_amounts
    typed_amount_texts.each_key { |field| errors.add(:"#{field}_cents", :invalid_amount) if invalid_amount?(field) }
  end
end
