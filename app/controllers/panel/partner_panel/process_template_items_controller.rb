module Panel
  module PartnerPanel
    # The items of the partner's models of process (spec 06, RN-06-010 to RN-06-042, D-639).
    class ProcessTemplateItemsController < BaseController
      include ProcessTemplateItemEditing

      private

      def template_scope
        SharedProcessTemplate.where(partner: partner)
      end

      def route_prefix
        "partner_"
      end
    end
  end
end
