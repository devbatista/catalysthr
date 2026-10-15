module Panel
  module FirmPanel
    # The companies this brand has linked to the firm, and the requests waiting for an
    # answer (P-02-29, D-590).
    class HomeController < BaseController
      def index
        authorize! :read, :firm_panel
        @links = brand_links.open.includes(:company).order(:status, "companies.name").references(:companies)
      end
    end
  end
end
