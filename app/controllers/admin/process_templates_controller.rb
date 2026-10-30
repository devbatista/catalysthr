module Admin
  # The CatalystHR library of models of process (spec 06, D-126), kept by the superadmin
  # and the support in the admin's content (RN-19-080, D-639). Partners and companies adopt
  # copies of its active models (D-232).
  class ProcessTemplatesController < BaseController
    include ProcessTemplateEditing

    private

    def template_scope
      SharedProcessTemplate.library
    end

    def build_template(attributes)
      SharedProcessTemplate.new(attributes)
    end

    # The library adopts from nobody.
    def adoptable_scope
      SharedProcessTemplate.none
    end

    def route_prefix
      "admin_"
    end
  end
end
