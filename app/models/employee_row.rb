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
