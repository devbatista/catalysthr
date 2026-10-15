require "prism"

# Finds controller actions reached by a route that skip authorization (RN-03-003,
# P-03-10, CA-03-008). An action is covered when its method calls `authorize!`, when
# the controller declares load_and_authorize_resource or authorize_resource for it,
# or when it is declared public with `public_actions`. Devise's own actions (sign-in,
# recovery, unlock) are public by nature.
module AuthorizationCoverage
  module_function

  def missing(routes = Rails.application.routes.routes)
    routes.filter_map { |route| uncovered(route.defaults[:controller], route.defaults[:action]) }.uniq
  end

  def uncovered(controller_path, action)
    return if controller_path.nil? || action.nil?

    controller = "#{controller_path.camelize}Controller".safe_constantize
    return unless controller && controller < ApplicationController
    return if controller < DeviseController
    return if controller.public_action_names.include?(action)
    return if resource_authorized?(controller, action)
    return if calls_authorize?(controller, action)

    "#{controller_path}##{action}"
  end

  def resource_authorized?(controller, action)
    controller.resource_authorization_options.any? do |options|
      only = Array(options[:only]).map(&:to_s)
      except = Array(options[:except]).map(&:to_s)
      (only.empty? || only.include?(action)) && !except.include?(action)
    end
  end

  def calls_authorize?(controller, action)
    return false unless controller.method_defined?(action)

    file, line = controller.instance_method(action).source_location
    definition = find_definition(Prism.parse_file(file).value, action.to_sym, line)
    definition.present? && calls?(definition, :authorize!)
  end

  def find_definition(node, name, line)
    return node if node.is_a?(Prism::DefNode) && node.name == name && node.location.start_line == line

    node.compact_child_nodes.each do |child|
      found = find_definition(child, name, line)
      return found if found
    end
    nil
  end

  def calls?(node, method_name)
    return true if node.is_a?(Prism::CallNode) && node.name == method_name

    node.compact_child_nodes.any? { |child| calls?(child, method_name) }
  end
end
