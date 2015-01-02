# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)

# u = User.find_or_initialize_by_name('KC')
# if u.new_record?
#   u.email = "kc@kevinchambers.com"
#   u.encrypted_password = "$2a$10$HU0K/fky2Xo8nOG.jpTFgeIobMgf9NdCNGmd8kGpkMRotIdvRNkJO"
#   u.save!
# end

# BillType.find_or_create_by_name('Utility')
# BillType.find_or_create_by_name('Internet')
# BillType.find_or_create_by_name('Food')
# BillType.find_or_create_by_name('Misc')
# BillType.find_or_create_by_name('Supplies')

# Role.find_or_create_by_name 'User'
# Role.find_or_create_by_name 'Power User'
# Role.find_or_create_by_name 'Owner'

# role_id = Role.find_by_name('User').id
#
# Account.find_or_create_by_name :name => 'My Account', :owner_id => 1
# Account.find_or_create_by_name :name => 'The Other Account', :owner_id => 1
#
# account_id = Account.find_by_name('My Account').id
#
# Shareholder.find_or_create_by_name(:name => 'Kevin', :opened_on => Date.today, :account_id => account_id, :role_id => role_id,
#     :status => "Account Holder", :status_on => Date.today, :user_id => 1)
# Shareholder.find_or_create_by_name(:name => 'Steve', :opened_on => Date.today, :account_id => account_id, :role_id => role_id,
#     :status => "Owner-created", :status_on => Date.today)
# Shareholder.find_or_create_by_name(:name => 'Virgil', :opened_on => Date.today, :account_id => account_id, :role_id => role_id,
#     :status => "Owner-created", :status_on => Date.today)
# Shareholder.find_or_create_by_name(:name => 'Aaron', :opened_on => Date.today, :account_id => account_id, :role_id => role_id,
#     :status => "Owner-created", :status_on => Date.today)
# Shareholder.find_or_create_by_name(:name => 'Jim', :opened_on => Date.today, :account_id => account_id, :role_id => role_id,
#     :status => "Owner-created", :status_on => Date.today)
# Shareholder.find_or_create_by_name(:name => 'The Pot', :opened_on => Date.today, :account_id => account_id,
#     :status => "System-created", :status_on => Date.today, :is_pot => true)
