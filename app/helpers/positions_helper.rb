module PositionsHelper
  # "R$ 2.000,00 a R$ 3.500,00", "a partir de R$ 2.000,00", "até R$ 3.500,00" or "—".
  def salary_range(position)
    min, max = [ position.salary_min_cents, position.salary_max_cents ].map { |cents| cents && "R$ #{MoneyCents.format(cents)}" }
    return t("positions.range.between", min: min, max: max) if min && max
    return t("positions.range.from", min: min) if min
    return t("positions.range.up_to", max: max) if max

    "—"
  end
end
