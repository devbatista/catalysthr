module Admin
  # The items of the library's models of process (spec 06, RN-06-010 to RN-06-042, D-639).
  class ProcessTemplateItemsController < BaseController
    include ProcessTemplateItemEditing

    private

    def template_scope
      SharedProcessTemplate.library
    end

    def route_prefix
      "admin_"
    end
  end
end
