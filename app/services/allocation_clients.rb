# The company's allocation clients and their managers (RN-04-090 to RN-04-096, D-570).
module AllocationClients
  module_function

  # A client manager left without an active client, or in a company that turned the
  # clients off, loses the client_manager role, the only one they hold, and so the
  # access; the sessions end (RN-02-064, RN-02-063).
  def release_managers!(company, by:)
    ActsAsTenant.with_tenant(company) do
      Membership.where(organization: company).with_role("client_manager").where.not(status: "revoked").find_each do |membership|
        next if company.uses_allocation_clients &&
          AllocationClientManager.joins(:allocation_client).where(membership: membership, allocation_clients: { status: "active" }).exists?

        Memberships::Revoke.call(membership: membership, by: by)
      end
    end
  end

  # The client's managers: active client managers of the company (RN-04-094). Removing the
  # last client of a manager takes the access away.
  def assign_managers!(client, membership_ids:, by:)
    wanted = Membership.where(organization: client.company, id: Array(membership_ids).compact_blank)
      .with_role("client_manager").where.not(status: "revoked").pluck(:id)
    current = client.allocation_client_managers.pluck(:membership_id)
    return if wanted.sort == current.sort

    AllocationClientManager.transaction do
      client.allocation_client_managers.where(membership_id: current - wanted).destroy_all
      (wanted - current).each { |membership_id| client.allocation_client_managers.create!(membership_id: membership_id) }
    end
    AccessEvent.record!(kind: "admin", action: "client_managers_assigned", user: by, subject: client,
      metadata: { from: current.sort, to: wanted.sort })
    release_managers!(client.company, by: by)
  end
end
