class BillType < ActiveRecord::Base
  has_many :bills
end
