class Role < ActiveRecord::Base
  def self.owner
    find_by_name("Owner")
  end
end
