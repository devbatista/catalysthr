class ApplicationRecord < ActiveRecord::Base
  include Audited

  primary_abstract_class
end
