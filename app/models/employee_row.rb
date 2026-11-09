# A line of the people list (spec 04, block 4c-1): the person, the employment that
# represents them (an open one first, then the latest) and the revision that counts for
# it today (RN-04-061). Open employments come first, then by name.
EmployeeRow = Data.define(:profile, :employment, :revision) do
  def self.build(profiles)
    rows = profiles.map do |profile|
      employment = profile.employments.min_by { |item| [ item.open? ? 0 : 1, -item.started_on.jd, -item.id ] }
      new(profile: profile, employment: employment, revision: employment&.effective_revision)
    end
    rows.sort_by { |row| [ row.open? ? 0 : 1, I18n.transliterate(row.profile.display_name).downcase ] }
  end

  # The list's filters, shared with the HR panel so the numbers match (RN-17-002): the unit,
  # the client, or "none" for people without one (RN-17-005), and the situation, where
  # "active" is the panel's "Colaboradores ativos", employments active or on leave
  # (RN-17-010).
  def self.filter(rows, unit_id: nil, client_id: nil, situation: nil)
    rows = rows.select { |row| row.employment&.status.in?(%w[active on_leave]) } if situation == "active"
    rows = rows.select { |row| row.unit&.id.to_s == unit_id.to_s } if unit_id.present?
    if client_id == Dashboards::Filter::NO_CLIENT
      rows = rows.select { |row| row.open? && row.revision&.allocation_client_id.nil? }
    elsif client_id.present?
      rows = rows.select { |row| row.revision&.allocation_client_id.to_s == client_id.to_s }
    end
    rows
  end

  def open?
    employment&.open? || false
  end

  def unit
    revision&.unit
  end

  def position
    revision&.position
  end

  def department
    revision&.department
  end

  # The department's own managers (RN-04-021).
  def managers
    department&.managers&.map(&:user) || []
  end
end
