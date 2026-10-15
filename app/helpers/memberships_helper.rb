module MembershipsHelper
  # Texts of the screens that manage people: the company's users, the partner's team and
  # the HR of the partner's client companies share the views. Each screen has its own
  # text where it differs; otherwise, the company's users' text.
  def membership_t(key, **options)
    t(:"#{controller_path.tr("/", ".")}.#{key}", default: :"panel.memberships.#{key}", **options)
  end

  # Whether this screen offers the action and the person may do it on the record.
  def may_manage_membership?(action, membership)
    permission = membership_permission(action)
    permission.present? && can?(permission, membership)
  end
end
