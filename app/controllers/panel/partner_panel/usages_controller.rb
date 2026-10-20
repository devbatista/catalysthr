module Panel
  module PartnerPanel
    # The portfolio's usage (RN-19-020 to RN-19-024, D-618): how much of the band and of the
    # quotas the month used, each company's usage, and the CSV for the partner to bill its
    # clients (D-482). Only the partner's administrator (spec 19, section 6).
    class UsagesController < BaseController
      before_action :require_billing_feature

      def show
        authorize! :read_usage, partner
        @account = partner.billing_account
        return head(:not_found) if @account.nil? && request.format.csv?
        return if @account.nil?

        @periods = Billing::UsageReport.periods(@account)
        @period = params[:period].presence_in(@periods) || @periods.first
        @current = @period == @periods.first
        @report = Billing::UsageReport.new(@account, @period)
        @subscription = @account.subscription

        respond_to do |format|
          format.html
          format.csv { send_data @report.to_csv, filename: @report.filename, type: "text/csv; charset=utf-8" }
        end
      end
    end
  end
end
