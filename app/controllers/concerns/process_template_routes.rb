# The routes of the models of process in each area (D-639): the admin's library, the
# partner's panel and the company's, by the controller's route_prefix ("admin_",
# "partner_" or "").
module ProcessTemplateRoutes
  extend ActiveSupport::Concern

  ROUTES = {
    templates: "%sprocess_templates", template: "%sprocess_template", new_template: "new_%sprocess_template",
    edit_template: "edit_%sprocess_template", activate_template: "activate_%sprocess_template",
    archive_template: "archive_%sprocess_template", default_template: "default_%sprocess_template",
    adopt_templates: "adopt_%sprocess_templates", template_items: "%sprocess_template_items",
    template_item: "%sprocess_template_item", new_template_item: "new_%sprocess_template_item",
    edit_template_item: "edit_%sprocess_template_item", move_template_item: "move_%sprocess_template_item"
  }.freeze

  AREAS = { "admin_" => :library, "partner_" => :partner, "" => :company }.freeze

  included do
    helper_method :template_route, :template_area
  end

  def template_route(name, *, **)
    public_send("#{format(ROUTES.fetch(name), route_prefix)}_path", *, **)
  end

  # :library, :partner or :company, for the screens' texts and options.
  def template_area
    AREAS.fetch(route_prefix)
  end
end
