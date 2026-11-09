module Panel
  module PartnerPanel
    # One block of the partner's consolidated view (spec 17, section 4.5, D-657, D-660), each in
    # its own request (RN-17-090), 60 seconds in the cache by partner and person (RN-17-091).
    # Numbers by company only: nothing here opens a list of people (CA-17-005).
    class OverviewBlocksController < BaseController
      BLOCKS = %w[portfolio health adoption].freeze

      before_action -> { head :not_found unless FeatureFlags.enabled?(FeatureFlags::DASHBOARDS) }

      def show
        authorize! :read, :partner_overview
        block = params[:block].presence_in(BLOCKS) or return head(:not_found)

        key = [ "dashboards/partner", block, partner.id, current_user.id ]
        cached = Rails.cache.fetch(key, expires_in: Panel::DashboardBlocksController::CACHE_FOR, force: params[:refresh].present?) do
          overview = Dashboards::PartnerOverview.new(partner, partner_membership.portfolio_companies.includes(:module_settings).order(:name))
          { "html" => render_to_string(partial: "panel/partner_panel/overview/#{block}", locals: { overview: overview }),
            "at" => Time.current.to_i }
        end
        response.headers["X-Generated-At"] = cached.fetch("at").to_s
        response.headers["Cache-Control"] = "no-store"
        # The HTML was rendered by the block's own partial, already escaped.
        render html: cached.fetch("html").html_safe, layout: false
      end
    end
  end
end
