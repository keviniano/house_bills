class Payee < ActiveRecord::Base
  stampable
  belongs_to :account
end
