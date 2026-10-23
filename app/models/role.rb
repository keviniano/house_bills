class Role < ApplicationRecord
  def self.owner
    where( name: "Owner" ).first
  end
end
