require "open3"
require "zlib"

# The scheduled backups and the restore test (plan Phase 9). Each run records a BackupCheck,
# whether it passed or not, so the admin footer shows a failure instead of going quiet.
#
#   daily         consistent copy, integrity_check, gzipped → daily/2026-11-08.sqlite3.gz (kept 30 days)
#   monthly       plain SQL .dump, gzipped → monthly/2026-11.sql.gz (kept forever)
#   restore_test  restore the Litestream replica to a temporary file, integrity_check, compare
#                 its figures with the live database, and run LedgerVerifier
#
# The live database is read through its own read-only SQLite connection, never Active Record's.
class DatabaseBackup
  class Error < StandardError; end

  # Row counts and money totals, compared between the restored copy and the live database.
  FIGURES_SQL = {
    "bills"                 => "SELECT COUNT(*) FROM bills",
    "account_entries"       => "SELECT COUNT(*) FROM account_entries",
    "balance_entries"       => "SELECT COUNT(*) FROM balance_entries",
    "balance_events"        => "SELECT COUNT(*) FROM balance_events",
    "shareholders"          => "SELECT COUNT(*) FROM shareholders",
    "versions"              => "SELECT COUNT(*) FROM versions",
    "account_entries_cents" => "SELECT COALESCE(SUM(amount_cents), 0) FROM account_entries",
    "balance_entries_cents" => "SELECT COALESCE(SUM(amount_cents), 0) FROM balance_entries",
    "bills_cents"           => "SELECT COALESCE(SUM(amount_cents), 0) FROM bills",
    "member_balances"       => "SELECT group_concat(shareholder_id || ':' || cents, ',') FROM " \
                               "(SELECT shareholder_id, SUM(amount_cents) AS cents FROM balance_entries " \
                               "WHERE shareholder_id IS NOT NULL GROUP BY shareholder_id ORDER BY shareholder_id)"
  }.freeze

  def self.live_database_path
    File.expand_path(ActiveRecord::Base.connection_db_config.database, Rails.root)
  end

  def initialize(db_path: self.class.live_database_path, storage: CloudStorage.new,
                 restorer: method(:litestream_restore), ledger: -> { LedgerVerifier.new.run.unexpected.size },
                 now: Time.current)
    @db_path = db_path
    @storage = storage
    @restorer = restorer
    @ledger = ledger
    @now = now
  end

  def run(kind)
    case kind.to_s
    when "daily"        then daily
    when "monthly"      then monthly
    when "restore_test" then restore_test
    else raise ArgumentError, "unknown backup kind #{kind.inspect}"
    end
  rescue StandardError => e
    BackupCheck.create!(kind: kind.to_s, ok: false, details: { "error" => "#{e.class}: #{e.message}" })
  end

  private

  def daily
    in_tmpdir do |dir|
      copy = snapshot(dir)
      gz = gzip_file(copy, "#{copy}.gz")
      name = @storage.upload(gz, "daily/#{@now.to_date.iso8601}.sqlite3.gz", content_type: "application/gzip")
      BackupCheck.create!(kind: "daily", ok: true, object_name: name, bytes: File.size(gz))
    end
  end

  def monthly
    in_tmpdir do |dir|
      copy = snapshot(dir)
      sql, err, status = Open3.capture3("sqlite3", copy, ".dump")
      raise Error, "sqlite3 .dump failed: #{err.strip}" unless status.success?

      gz = File.join(dir, "dump.sql.gz")
      Zlib::GzipWriter.open(gz) { |out| out.write(sql) }
      name = @storage.upload(gz, "monthly/#{@now.strftime('%Y-%m')}.sql.gz", content_type: "application/gzip")
      BackupCheck.create!(kind: "monthly", ok: true, object_name: name, bytes: File.size(gz))
    end
  end

  def restore_test
    in_tmpdir do |dir|
      restored = File.join(dir, "restored.sqlite3")
      @restorer.call(restored)
      check_integrity!(restored)
      differences = compare(figures(restored), figures(@db_path))
      ledger_unexpected = @ledger.call
      BackupCheck.create!(kind: "restore_test", ok: differences.empty?, bytes: File.size(restored),
                          details: { "differences" => differences, "ledger_unexpected" => ledger_unexpected })
    end
  end

  # A consistent copy of the live database through SQLite's online backup API, checked.
  def snapshot(dir)
    copy = File.join(dir, "production.sqlite3")
    source = SQLite3::Database.new(@db_path, readonly: true)
    target = SQLite3::Database.new(copy)
    backup = SQLite3::Backup.new(target, "main", source, "main")
    backup.step(-1)
    backup.finish
    target.close
    source.close
    check_integrity!(copy)
    copy
  end

  def check_integrity!(path)
    result = read(path) { |db| db.get_first_value("PRAGMA integrity_check") }
    raise Error, "integrity_check of #{File.basename(path)}: #{result}" unless result == "ok"
  end

  def figures(path)
    read(path) { |db| FIGURES_SQL.transform_values { |sql| db.get_first_value(sql) } }
  end

  def compare(restored, live)
    live.filter_map { |key, value| "#{key}: restored #{restored[key].inspect}, live #{value.inspect}" unless restored[key] == value }
  end

  def litestream_restore(output)
    _, err, status = Open3.capture3("litestream", "restore", "-config", Rails.root.join("config/litestream.yml").to_s,
                                    "-o", output, @db_path)
    raise Error, "litestream restore failed: #{err.strip.lines.last}" unless status.success?
  end

  # Opens a read-only connection for the block and returns the block's value.
  def read(path)
    db = SQLite3::Database.new(path, readonly: true)
    yield db
  ensure
    db&.close
  end

  def gzip_file(path, gz)
    Zlib::GzipWriter.open(gz) { |out| File.open(path, "rb") { |f| IO.copy_stream(f, out) } }
    gz
  end

  def in_tmpdir(&)
    Dir.mktmpdir("backup", &)
  end
end
