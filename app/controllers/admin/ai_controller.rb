module Admin
  # The AI for the CatalystHR team (spec 14, section 6, P-14-36, D-670): the credits' weights by
  # function with the date they start (RN-14-110), the use and the real cost of the last 30 days
  # to review the weights, the companies' day against the safety cap, the cap of a company and the
  # release of a pause (RN-14-114). Behind the `ai` flag.
  class AiController < BaseController
    USE_DAYS = 30

    before_action :require_ai_feature
    before_action :load_company, only: %i[company update_cap release]

    def index
      authorize! :read, :ai_admin
      @weights = AiCreditWeight.order(:feature, :valid_from).group_by(&:feature)
      @weight = AiCreditWeight.new(valid_from: Date.current.tomorrow)
      @use = use_by_feature(AiRequest.all)
      @today = AiDailyCap.where(date: Ai::DailyCap.today).includes(:company).order(used_credits: :desc).limit(50)
      @query = params[:q].to_s.strip
      @companies = @query.length >= 2 ? Company.where("name ILIKE ?", "%#{Company.sanitize_sql_like(@query)}%").order(:name).limit(20) : []
      @breaker_until = Ai::Breaker.open_until
    end

    def create_weight
      authorize! :update_weights, :ai_admin
      feature = Ai::Features.find(params.dig(:ai_credit_weight, :feature).presence || raise(ActiveRecord::RecordNotFound))
      @weight = AiCreditWeight.new(params.expect(ai_credit_weight: %i[feature credits valid_from]).merge(unit: feature.unit,
        created_by: current_user))
      if @weight.save
        redirect_to admin_ai_path, notice: t(".created")
      else
        redirect_to admin_ai_path, alert: @weight.errors.full_messages.to_sentence
      end
    rescue KeyError
      raise ActiveRecord::RecordNotFound
    end

    def company
      authorize! :read, :ai_admin
      @cap = AiDailyCap.find_by(company: @company, date: Ai::DailyCap.today)
      @cap_credits = @cap&.cap_credits || Ai::DailyCap.computed(@company)
      @computed = Ai::DailyCap.computed(@company, override: false)
      @use = use_by_feature(AiRequest.where(company: @company))
    end

    def update_cap
      authorize! :update_caps, :ai_admin
      credits = params[:ai_daily_cap_credits].presence
      if credits && !credits.to_s.match?(/\A\d{1,6}\z/)
        return redirect_to admin_ai_company_path(@company), alert: t(".invalid")
      end

      Ai::DailyCap.set!(@company, credits&.to_i)
      redirect_to admin_ai_company_path(@company), notice: t(credits ? ".updated" : ".reset")
    end

    def release
      cap = AiDailyCap.find_by!(company: @company, date: Ai::DailyCap.today)
      authorize! :release, cap
      Ai::DailyCap.release!(cap, by: current_user)
      redirect_to admin_ai_company_path(@company), notice: t(".released")
    end

    private

    def require_ai_feature
      head :not_found unless FeatureFlags.enabled?(FeatureFlags::AI)
    end

    def load_company
      @company = Company.find(params[:id])
    end

    # The calls, failures, credits and cost of each function in the last 30 days.
    def use_by_feature(scope)
      scope.where(created_at: USE_DAYS.days.ago..).group(:feature)
        .pluck(:feature, Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE status = 'failed')"),
          Arel.sql("SUM(credits)"), Arel.sql("SUM(cost_usd_micros)"))
        .map { |feature, calls, failed, credits, cost| { feature: feature, calls: calls, failed: failed, credits: credits.to_i, cost: cost.to_i } }
        .sort_by { |row| -row[:calls] }
    end
  end
end
