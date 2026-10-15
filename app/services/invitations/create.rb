module Invitations
  # Invites a person to a company, partner or accounting firm (RN-02-010 to RN-02-013).
  # A CPF already on the platform keeps the same person, whose data stays as it is;
  # only the membership is new. Whoever calls this has already checked, with the
  # Ability, that the inviter may give these roles (spec 03).
  class Create
    def self.call(**)
      new(**).call
    end

    def initialize(organization:, roles:, channels:, invited_by:, name:, cpf:, email: nil, mobile_phone: nil,
      enabled_modules: [])
      @organization = organization
      @roles = roles
      @enabled_modules = Array(enabled_modules).compact_blank
      @channels = Array(channels).map(&:to_s)
      @invited_by = invited_by
      @person = { name: name, cpf: cpf, email: email, mobile_phone: mobile_phone }
    end

    # Returns the invitation, whose link the inviter can hand over (RN-02-011).
    def call
      invitation = ActiveRecord::Base.transaction do
        user = User.find_by(cpf: @person[:cpf]) || User.create!(@person)
        membership = Membership.find_or_initialize_by(user: user, organization: @organization)
        if membership.persisted? && !membership.invited? && !membership.revoked?
          Invitations.refuse(membership, :base, :already_member)
        end

        modules = (Array(@roles) & Membership::ROLES_WITH_MODULES).any? ? @enabled_modules : []
        membership.assign_attributes(roles: @roles, enabled_modules: modules, status: "invited")
        Invitations.issue(membership, channels: @channels, invited_by: @invited_by)
      end

      Invitations.deliver(invitation)
      invitation
    end
  end
end
