# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)

Role.create! name: 'User'
Role.create! name: 'Power User'
Role.create! name: 'Owner'

u = User.new(
    name:                   'Test User',
    email:                  'test@tester.com',
    password:               '123456',
    password_confirmation:  '123456'
    )
u.skip_confirmation!
u.save!

a = Account.create!(
    name:                   'Seed Account',
    owner_id:               u.id
    )

Shareholder.create!(
    name:                   'Kevin Chambers',
    email:                  'test@tester.com',
    account_id:             a.id,
    user_id:                u.id,
    role_id:                Role.owner.id,
    opened_on:              Date.today
    )

BillType.create!(
    name:                   'Seed Bill Type',
    account_id:             a.id
    )

Payee.create!(
    name:                   'Seed Payee',
    account_id:             a.id
    )
