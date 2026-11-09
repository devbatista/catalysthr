class ApplicationRecord < ActiveRecord::Base
  include Audited
  include ImportTracking

  primary_abstract_class
end
