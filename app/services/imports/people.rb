module Imports
  # The company's people by the CPF, for the imports that point to them (spec 18, kinds 2 to
  # 4, D-663): only the records of the company, never another company's (D-209). The CPF
  # is encrypted deterministically, so the search is one query for the whole file.
  module People
    module_function

    # { "12345678909" => WorkerProfile } for the CPFs that have a record in the company.
    def profiles_by_cpf(cpfs)
      cpfs = cpfs.compact.uniq
      return {} if cpfs.empty?

      users = User.where(cpf: cpfs).to_a
      memberships = Membership.where(user: users, organization: ActsAsTenant.current_tenant)
      WorkerProfile.where(membership: memberships).includes(membership: :user).to_h { |profile| [ profile.user.cpf, profile ] }
    end

    def cpf(value)
      Cpf.normalize(value.to_s).presence
    end
  end
end
