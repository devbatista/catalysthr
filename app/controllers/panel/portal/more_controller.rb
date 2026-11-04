module Panel
  module Portal
    # "Mais" (spec 16, RN-16-011, D-645): "Minha equipe" for managers, the person's data,
    # the notices, security and leaving. Payslips, evaluations, the assistant, the board,
    # internal jobs, privacy and help come with their specs.
    class MoreController < BaseController
      def show
        authorize! :read, :portal
      end
    end
  end
end
