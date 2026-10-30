module Panel
  module PartnerPanel
    # The partner's models of process (spec 06, D-126): the administrator keeps them and
    # adopts the library's (D-232), the consultant reads them. Its client companies adopt
    # copies of the active ones (P-06-02).
    class ProcessTemplatesController < BaseController
      include ProcessTemplateEditing

      private

      def template_scope
        SharedProcessTemplate.where(partner: partner)
      end

      def build_template(attributes)
        SharedProcessTemplate.new(attributes.merge(partner: partner))
      end

      def adoptable_scope
        SharedProcessTemplate.library
      end

      def adopt_into
        partner
      end

      def route_prefix
        "partner_"
      end
    end
  end
end
