ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # An account with members Ann (share 1), Bob (share 1) and Cat (share 2), all open
    # since 2020, plus a bill type. Users aren't needed; members work without one.
    def create_household
      @role    = Role.find_or_create_by!(name: "Owner")
      @account = Account.create!(name: "House #{SecureRandom.hex(4)}")
      @ann, @bob, @cat = %w[Ann Bob Cat].map do |name|
        Shareholder.create!(account: @account, name: name, role: @role, opened_on: Date.new(2020, 1, 1))
      end
      @bill_type = BillType.create!(account_id: @account.id, name: "Utilities")
    end

    def create_bill(klass = ShareholderBill, amount: "100.00", entry_type: "Bill", shares: { @ann => 1, @bob => 1, @cat => 2 }, **attrs)
      klass.create!(
        account: @account, bill_type: @bill_type, date: Date.new(2024, 3, 15),
        entry_type: entry_type, entry_amount: amount,
        bill_share_balance_entries_attributes: shares.map { |sh, share|
          { shareholder_id: sh.id, share: share.to_s, account_id: @account.id }
        },
        **attrs
      )
    end
  end
end
