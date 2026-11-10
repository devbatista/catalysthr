module Ai
  # Whether a function may call the AI now for the company, and why not (spec 14). Anything but
  # :available sends the item to the manual flow (RN-14-010), except :breaker, which only waits
  # for the pause to end (RN-14-123).
  #
  # - :unavailable: the `ai` flag is off or there is no key (D-670);
  # - :simulation: impersonation never calls the AI (RN-14-132);
  # - :disabled: the HR administrator turned the function off (RN-14-010);
  # - :paused: the company reached its daily cap (RN-14-114);
  # - :breaker: the AI queue is paused (RN-14-123).
  module Availability
    module_function

    def check(company, feature)
      return :unavailable unless platform_on?
      return :simulation if Simulation.active?
      return :disabled unless enabled?(company, feature)
      return :paused if DailyCap.paused?(company)
      return :breaker if Breaker.open?

      :available
    end

    def available?(company, feature) = check(company, feature) == :available

    def platform_on? = FeatureFlags.enabled?(FeatureFlags::AI) && Client.configured?

    def enabled?(company, feature)
      ActsAsTenant.with_tenant(company) { CompanyAiSetting.find_by(feature: feature.to_s)&.enabled != false }
    end
  end
end
