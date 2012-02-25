class BillType < ActiveRecord::Base
  stampable
  has_many :bills
end
