module Imports
  # Tells the company's HR administrators that the support finished an import on its behalf
  # (RN-18-062, D-666): the kind and the counts, no data of the people (RN-15-005), with the
  # company's brand. Once per import (RN-15-085).
  module AssistedNotice
    module_function

    def call(import)
      return unless import.assisted? && import.status.in?(%w[completed completed_with_errors])

      Membership.active.with_role("hr_admin").where(organization: import.company).includes(:user).find_each do |membership|
        Notifications.notify!("imports.assisted_completed", user: membership.user, membership: membership, subject: import,
          path: "/imports/#{import.id}", kind: I18n.t("imports.kinds.#{import.kind}.title"), created: import.created_count,
          updated: import.updated_count, errors: import.error_count + import.failed_count)
      end
    end
  end
end
