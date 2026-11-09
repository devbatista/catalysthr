module Panel
  # "Tarefas atrasadas", opened by the HR panel's indicator (RN-17-010, D-658): the open items
  # past their date (RN-06-028) of the open processes the person runs, the oldest date first.
  class OverdueItemsController < BaseController
    include DashboardLists

    def index
      authorize! :adjust, ProcessInstance
      items = dashboard_panel.overdue_items
      @count = items.count
      @items = items.includes(instance: %i[unit subject]).order(:due_on, :id).limit(DashboardLists::LIMIT).to_a
      employments = @items.filter_map { |item| item.instance.employment }
      ActiveRecord::Associations::Preloader.new(records: employments, associations: { worker_profile: :user }).call
      @people = Membership.where(id: @items.flat_map(&:responsible_membership_ids)).includes(:user).index_by(&:id)
    end
  end
end
