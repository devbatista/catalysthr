# What a person may do in the partner's panel (spec 03, section 4.1), by the roles of
# the active membership in the partner that owns the subdomain. The panel has no
# current company: companies are reached only through the portfolio (RN-01-011).
class PartnerAbility
  include CanCan::Ability

  # Roles the partner's administrator gives to the team (D-584).
  INVITABLE_ROLES = %w[partner_admin consultant].freeze

  def initialize(user, partner)
    membership = Membership.active.find_by(user: user, organization: partner)
    return if membership.nil?

    can :read, :partner_panel
    admin(user, partner) if membership.roles.include?("partner_admin")
  end

  private

  def admin(user, partner)
    team(user, partner)

    # The HR administrators of the client companies: see, invite, change or remove them
    # (P-03-35, D-585). Never one's own membership (RN-03-012).
    can %i[read_hr_admin invite_hr_admin], Membership do |membership|
      client_hr_admin?(membership, partner)
    end
    can :change_hr_admin, Membership do |membership|
      client_hr_admin?(membership, partner) && membership.user_id != user.id
    end
  end

  def client_hr_admin?(membership, partner)
    membership.organization.is_a?(Company) && membership.organization.partner_id == partner.id &&
      membership.roles.include?("hr_admin")
  end

  # The partner's team: invite administrators and consultants, their roles, modules and
  # companies, and removal (D-052, P-03-06, D-584). Nobody changes their own access.
  def team(user, partner)
    can %i[read invite], Membership, organization_type: "Partner", organization_id: partner.id

    can %i[update revoke resend_invitation cancel_invitation], Membership do |membership|
      team_member?(membership, partner, user)
    end
    # Contact and MFA only for who has no access anywhere else (RN-02-044, P-02-17, D-582).
    can %i[correct_contact reset_mfa], Membership do |membership|
      team_member?(membership, partner, user) && membership.exclusive_access?
    end
  end

  def team_member?(membership, partner, user)
    membership.organization_type == "Partner" && membership.organization_id == partner.id && membership.user_id != user.id
  end
end
