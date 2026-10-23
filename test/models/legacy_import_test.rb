require "test_helper"

class LegacyImportTest < ActiveSupport::TestCase
  # Stands in for psql: answers the prechecks with 0 (or the given counts) and each
  # table's SELECT with the given rows, already in the shape the SQL would return.
  class FakeSource
    def initialize(tables, precheck_counts = {})
      @tables = tables
      @precheck_counts = precheck_counts
    end

    def rows(sql)
      if (label = LegacyImport::PRECHECKS.find { |_, check| sql.include?(check) }&.first)
        [ { "n" => @precheck_counts.fetch(label, 0).to_s } ]
      else
        table = sql[/FROM (\w+) ORDER BY id\z/, 1] or raise "unexpected query: #{sql}"
        columns = LegacyImport::TABLES.fetch(table)
        @tables.fetch(table, []).map { |row| columns.index_with { |c| row[c]&.to_s } }
      end
    end
  end

  T = "2016-05-01 12:00:00"

  def legacy_tables
    {
      "roles" => [ { "id" => 3, "name" => "Owner", "created_at" => T, "updated_at" => T } ],
      "users" => [ { "id" => 7, "name" => "Ann", "email" => "ann@example.com", "sign_in_count" => 12, "created_at" => T, "updated_at" => T } ],
      "accounts" => [ { "id" => 1, "name" => "House", "lock_records_before" => "2018-01-01", "created_at" => T, "updated_at" => T } ],
      "shareholders" => [ { "id" => 4, "account_id" => 1, "user_id" => 7, "role_id" => 3, "name" => "Ann", "opened_on" => "2011-01-01" } ],
      "bill_types" => [ { "id" => 2, "account_id" => 1, "name" => "Utilities" } ],
      "bills" => [
        { "id" => 6112, "type" => "ShareholderBill", "bill_type_id" => 2, "shareholder_id" => 4, "account_id" => 1,
          "date" => "0017-09-04", "amount_cents" => 4423, "created_at" => T, "updated_at" => T },
        { "id" => 50, "type" => "AccountBill", "bill_type_id" => 2, "account_id" => 1, "payee" => "PG&E",
          "date" => "2016-04-30", "amount_cents" => -1, "creator_id" => 7 }
      ],
      "account_entries" => [ { "id" => 9, "type" => "BillAccountEntry", "bill_id" => 50, "account_id" => 1,
                               "date" => "2016-04-30", "amount_cents" => 1, "cleared" => "t" } ],
      "balance_entries" => [
        { "id" => 11, "type" => "BillOffsetBalanceEntry", "bill_id" => 6112, "account_id" => 1, "shareholder_id" => 4,
          "amount_cents" => 4423, "date" => "0017-09-04" },
        { "id" => 12, "type" => "PotBalanceEntry", "bill_id" => 50, "account_id" => 1, "amount_cents" => 0, "date" => "2016-04-30" }
      ],
      "balance_events" => [ { "id" => 5, "date" => "0017-09-04", "account_id" => 1, "bill_id" => 6112 } ],
      "versions" => [
        { "id" => 1, "item_type" => "BalanceEntry", "item_id" => 11, "event" => "create", "whodunnit" => "7", "object" => nil, "created_at" => T },
        { "id" => 2, "item_type" => "Bill", "item_id" => 50, "event" => "update", "whodunnit" => "7",
          "object" => "---\namount: !ruby/object:BigDecimal 18:0.1e1\n", "created_at" => T }
      ]
    }
  end

  def import(tables = legacy_tables, prechecks = {}, replace: true)
    LegacyImport.new(FakeSource.new(tables, prechecks)).run(replace: replace)
  end

  test "copies every table keeping IDs, with money in cents and booleans cast" do
    report = import

    assert_equal [ 7 ], User.pluck(:id)
    assert_equal 12, User.find(7).sign_in_count
    assert_equal Date.new(2018, 1, 1), Account.find(1).lock_records_before
    assert_instance_of AccountBill, Bill.find(50)
    assert_equal(-1, Bill.find(50).amount_cents)
    assert AccountEntry.find(9).cleared
    assert_equal Time.utc(2016, 5, 1, 12), Bill.find(6112).created_at
    assert_includes report, format("%-16s %7d rows", "bills", 2)
  end

  test "copies PaperTrail versions unchanged and records none of its own" do
    import
    assert_equal [ 1, 2 ], PaperTrail::Version.order(:id).pluck(:id)
    assert_equal legacy_tables["versions"][1]["object"], PaperTrail::Version.find(2).object
  end

  test "backfills missing creators and updaters from the versions, keeping ones already set" do
    import
    assert_equal [ 7, 7 ], BalanceEntry.find(11).values_at(:creator_id, :updater_id)
    assert_nil BalanceEntry.find(12).creator_id
    assert_equal [ 7, 7 ], Bill.find(50).values_at(:creator_id, :updater_id)
  end

  test "corrects the two mistyped 0017 dates on the bill and everything dated from it" do
    report = import
    assert_equal Date.new(2017, 9, 4), Bill.find(6112).date
    assert_equal Date.new(2017, 9, 4), BalanceEntry.find(11).date
    assert_equal Date.new(2017, 9, 4), BalanceEvent.find(5).date
    assert_includes report, "Bill#6112 date corrected from 0017-09-04 to 2017-09-04"
  end

  test "refuses to overwrite a database that has rows, unless asked to replace them" do
    error = assert_raises(LegacyImport::Error) { import(replace: false) }
    assert_match "users already have rows", error.message
    assert User.exists?(users(:one).id)

    import(replace: true)
    assert_not User.exists?(users(:one).id)
  end

  test "stops before copying anything when the legacy data needs attention" do
    error = assert_raises(LegacyImport::Error) { import(legacy_tables, { "money that isn't whole cents" => 2 }) }
    assert_match "money that isn't whole cents: 2", error.message
    assert User.exists?(users(:one).id)
  end

  test "reports rows that reference missing records and rolls everything back" do
    tables = legacy_tables
    tables["bills"].first["shareholder_id"] = 99

    error = assert_raises(LegacyImport::Error) { import(tables) }
    assert_match "bills → shareholders: 1", error.message
    assert User.exists?(users(:one).id)
    assert_equal 0, Bill.count
  end

  test "final balances list every member with their balance at the end of the data" do
    import
    rows = CSV.parse(LegacyImport.final_balances_csv, headers: true)
    assert_equal [ "4", "Ann", "44.23" ], rows.first.values_at("shareholder_id", "name", "balance")
  end
end
