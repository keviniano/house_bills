class Payee < ActiveRecord::Base
  belongs_to :account
end
