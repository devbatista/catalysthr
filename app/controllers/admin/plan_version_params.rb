module Admin
  # The price version's fields that the form sends, by the plan's kind (D-480, D-122).
  module PlanVersionParams
    module_function

    def permit(params, plan)
      fields = %i[valid_from] + PlanVersion::SHARED_AMOUNTS +
        (plan.partner? ? PlanVersion::PARTNER_AMOUNTS + PlanVersion::PARTNER_QUANTITIES : PlanVersion::DIRECT_AMOUNTS + PlanVersion::DIRECT_QUANTITIES)
      params.expect(plan_version: [ *fields, { module_prices: PlanModule::MODULES } ])
    end
  end
end
