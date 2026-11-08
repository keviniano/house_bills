require "test_helper"

class DatabaseBackupTest < ActiveSupport::TestCase
  # Records uploads instead of sending them, keeping a copy of each file.
  class FakeStorage
    attr_reader :uploads

    def initialize(dir)
      @dir = dir
      @uploads = {}
    end

    def upload(path, name, content_type:)
      copy = File.join(@dir, name.tr("/", "_"))
      FileUtils.cp(path, copy)
      @uploads[name] = copy
      "gs://test-bucket/#{name}"
    end
  end

  setup do
    @dir = Dir.mktmpdir
    @live = File.join(@dir, "live.sqlite3")
    build_database(@live)
    @storage = FakeStorage.new(@dir)
    @now = Time.zone.local(2026, 11, 8, 3, 15)
  end

  teardown { FileUtils.rm_rf(@dir) }

  def build_database(path, member_cents: 500)
    SQLite3::Database.new(path) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE bills (id INTEGER PRIMARY KEY, amount_cents INTEGER);
        CREATE TABLE account_entries (id INTEGER PRIMARY KEY, amount_cents INTEGER);
        CREATE TABLE balance_entries (id INTEGER PRIMARY KEY, shareholder_id INTEGER, amount_cents INTEGER);
        CREATE TABLE balance_events (id INTEGER PRIMARY KEY);
        CREATE TABLE shareholders (id INTEGER PRIMARY KEY);
        CREATE TABLE versions (id INTEGER PRIMARY KEY);
        INSERT INTO bills VALUES (1, 1000);
        INSERT INTO account_entries VALUES (1, -1000);
        INSERT INTO balance_entries VALUES (1, 6, #{member_cents}), (2, 7, -500);
      SQL
    end
  end

  def backup(**options)
    DatabaseBackup.new(db_path: @live, storage: @storage, now: @now, ledger: -> { 0 }, **options)
  end

  test "daily uploads a gzipped copy of the database and records it" do
    check = backup.run(:daily)

    assert check.ok?
    assert_equal "gs://test-bucket/daily/2026-11-08.sqlite3.gz", check.object_name
    copy = File.join(@dir, "unzipped.sqlite3")
    File.binwrite(copy, Zlib.gunzip(File.binread(@storage.uploads["daily/2026-11-08.sqlite3.gz"])))
    assert_equal 1000, SQLite3::Database.new(copy).get_first_value("SELECT amount_cents FROM bills")
  end

  test "monthly uploads a gzipped SQL dump" do
    check = backup.run(:monthly)

    assert check.ok?
    sql = Zlib.gunzip(File.binread(@storage.uploads["monthly/2026-11.sql.gz"]))
    assert_includes sql, "INSERT INTO bills VALUES(1,1000);"
  end

  test "the restore test passes when the restored copy matches the live database" do
    check = backup(restorer: ->(output) { FileUtils.cp(@live, output) }).run(:restore_test)

    assert check.ok?
    assert_equal({ "differences" => [], "ledger_unexpected" => 0 }, check.details)
  end

  test "the restore test fails on any difference, listing it" do
    restorer = ->(output) { build_database(output, member_cents: 499) }
    check = backup(restorer: restorer, ledger: -> { 2 }).run(:restore_test)

    assert_not check.ok?
    assert_includes check.details["differences"], "balance_entries_cents: restored -1, live 0"
    assert_includes check.details["differences"], "member_balances: restored \"6:499,7:-500\", live \"6:500,7:-500\""
    assert_equal 2, check.ledger_unexpected
  end

  test "a failure is recorded, not raised" do
    check = backup(restorer: ->(_) { raise DatabaseBackup::Error, "no replica" }).run(:restore_test)

    assert_not check.ok?
    assert_equal "DatabaseBackup::Error: no replica", check.details["error"]
  end

  test "a corrupt copy fails the integrity check" do
    check = backup(restorer: ->(output) { File.write(output, "not a database") }).run(:restore_test)

    assert_not check.ok?
    assert_match(/SQLite3::|integrity_check/, check.details["error"])
  end
end
