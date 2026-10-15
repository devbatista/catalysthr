module Panel
  module FirmPanel
    # The firm's administrator accepts or refuses a company's request (P-02-29, D-590).
    class LinksController < BaseController
      before_action :load_link

      def accept
        authorize! :accept, @link
        AccountingFirms::Respond.call(link: @link, accept: true, by: current_user)
        redirect_to firm_root_path, notice: t(".accepted", company: @link.company.name)
      end

      def refuse
        authorize! :refuse, @link
        AccountingFirms::Respond.call(link: @link, accept: false, by: current_user)
        redirect_to firm_root_path, notice: t(".refused", company: @link.company.name)
      end

      private

      def load_link
        @link = brand_links.pending.find(params[:id])
      end
    end
  end
end
