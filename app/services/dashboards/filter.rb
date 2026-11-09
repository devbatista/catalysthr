module Dashboards
  # The HR panel's filters (RN-17-004, RN-17-005): the unit, within the person's scope, and
  # the allocation client, with "sem cliente", when the company uses them (D-570). The lists
  # each indicator opens get the same filter, so the numbers match (RN-17-002, P-17-01). A
  # unit or client outside the options is ignored.
  class Filter
    NO_CLIENT = "none".freeze

    attr_reader :ability, :company, :unit_id, :client_id

    def initialize(ability, company, unit_id: nil, client_id: nil)
      @ability = ability
      @company = company
      @unit_id = unit_id.presence_in(units.map { |unit| unit.id.to_s })
      @client_id = clients? ? client_id.presence_in(clients.map { |client| client.id.to_s } + [ NO_CLIENT ]) : nil
    end

    # The units the person's numbers cover (RN-17-014).
    def units
      @units ||= begin
        scope = ability.hr_unit_ids
        units = Unit.ordered
        units = units.where(id: scope) unless scope == :all
        units.to_a
      end
    end

    def clients?
      company.uses_allocation_clients
    end

    def clients
      @clients ||= clients? ? AllocationClient.where(status: "active").ordered.to_a : []
    end

    def unit
      units.find { |item| item.id.to_s == unit_id } if unit_id
    end

    def client
      clients.find { |item| item.id.to_s == client_id } if client_id && client_id != NO_CLIENT
    end

    def no_client?
      client_id == NO_CLIENT
    end

    def any?
      unit_id.present? || client_id.present?
    end

    # For the links: the lists open with the same filter.
    def params
      { unit_id: unit_id, client_id: client_id }.compact
    end

    # Today at the company's headquarters, for the panel's dates (as D-656).
    def today
      @today ||= Time.find_zone(company.headquarters&.time_zone || "America/Sao_Paulo").today
    end

    # The people of the filter, among the given ones: in the unit, as the U scope counts it
    # (D-142), and allocated in the client, or in none.
    # Subqueries, never merge: a merge would replace the scope's own condition on the id.
    def people(profiles = WorkerProfile.all)
      profiles = profiles.where(id: WorkerProfile.in_units(unit_id).select(:id)) if unit_id
      if client
        profiles = profiles.where(id: WorkerProfile.in_allocation_clients(client.id).select(:id))
      elsif no_client?
        profiles = profiles.where(id: WorkerProfile.without_allocation_client.select(:id))
      end
      profiles
    end

    # The processes of the filter: started in the unit, and of people of the client.
    def instances(relation)
      relation = relation.where(process_instances: { unit_id: unit_id }) if unit_id
      if client_id
        employments = Employment.where(worker_profile_id: people.select(:id)).select(:id)
        relation = relation.where(process_instances: { subject_type: "Employment", subject_id: employments })
      end
      relation
    end

    # The cache's key (RN-17-091): the company, the person, whose units and released modules
    # make the scope, and the filter.
    def cache_key(user)
      [ company.id, user.id, unit_id || "-", client_id || "-" ]
    end
  end
end
