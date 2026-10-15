# Company isolation (spec 01, RN-01-010 and RN-01-012; P-01-05 and P-01-07).
#
# Queries on company-owned models (`acts_as_tenant :company`) without a current
# company raise ActsAsTenant::Errors::NoTenantSet instead of returning every
# company's data. Views without a current company (partner panel, admin area) lift
# the tenant in a single place, which also applies the authorized companies
# (RN-01-011, built with spec 03).
ActsAsTenant.configure do |config|
  config.require_tenant = true
end

# Sidekiq jobs carry the company that enqueued them. Active Job jobs carry it
# through the gem's Active Job extension, loaded automatically.
require "acts_as_tenant/sidekiq"
