module UnitsHelper
  # "CNPJ 12.ABC.345/0001-35", or the headquarters' when the unit has none (D-201).
  def unit_registration(unit)
    return t("units.uses_headquarters") if unit.registration_number.blank?

    number = unit.cnpj? ? Cnpj.format(unit.registration_number) : unit.registration_number
    "#{t("units.registration_types.#{unit.registration_type}")} #{number}"
  end

  def unit_address(unit)
    street = [ unit.street, unit.street_number ].compact_blank.join(", ")
    city = [ unit.city, unit.state ].compact_blank.join(" / ")
    [ street, unit.complement, unit.district, city, unit.postal_code&.sub(/\A(\d{5})(\d{3})\z/, '\1-\2') ].compact_blank.join(" · ")
  end
end
