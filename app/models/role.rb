class Role < ActiveRecord::Base
  def self.owner
    where( name: "Owner" ).first
  end
end
