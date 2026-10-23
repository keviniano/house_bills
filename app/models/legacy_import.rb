require "csv"
require "open3"

# Copies the 2011–2020 Postgres database into this one (plan Phase 6), keeping every ID:
#
#   LegacyImport.new(LegacyImport::Psql.new("postgres://...")).run(replace: true)
#
# Money becomes integer cents in SQL, where Postgres's numeric arithmetic is exact. Rows
# are inserted directly, so no callbacks run and PaperTrail records nothing; the legacy
# `versions` are copied unchanged. Afterwards it checks foreign keys and backfills the
# creator_id/updater_id that went unset from 2015, from the PaperTrail versions.
class LegacyImport
  class Error < StandardError; end

  STAMPS = %w[lock_version created_at updated_at creator_id updater_id].freeze

  # In dependency order. "amount_cents" is computed from the legacy decimal `amount`.
  # users leaves out the Devise password, confirmation and lock columns (Google sign-in only).
  TABLES = {
    "roles"           => %w[id name created_at updated_at],
    "users"           => %w[id name email sign_in_count current_sign_in_at last_sign_in_at
                            current_sign_in_ip last_sign_in_ip created_at updated_at],
    "accounts"        => %w[id name owner_id lock_records_before] + STAMPS,
    "shareholders"    => %w[id account_id user_id role_id name email opened_on inactivated_on closed_on] + STAMPS,
    "bill_types"      => %w[id account_id name] + STAMPS,
    "payees"          => %w[id account_id name] + STAMPS,
    "bills"           => %w[id type bill_type_id shareholder_id account_id payee date amount_cents note] + STAMPS,
    "account_entries" => %w[id type bill_id shareholder_id account_id check_number date payee amount_cents note cleared] + STAMPS,
    "balance_entries" => %w[id type account_id bill_id account_entry_id shareholder_id share amount_cents date] + STAMPS,
    "balance_events"  => %w[id date account_id bill_id account_entry_id],
    "versions"        => %w[id item_type item_id event whodunnit object created_at]
  }.freeze

  # Each must be 0 in the legacy database before anything is copied.
  PRECHECKS = {
    "money that isn't whole cents" => %w[bills account_entries balance_entries].map { |t|
      "(SELECT COUNT(*) FROM #{t} WHERE amount * 100 <> ROUND(amount * 100))" }.join(" + "),
    "balance_entries with no amount (the new column is NOT NULL)" => "SELECT COUNT(*) FROM balance_entries WHERE amount IS NULL",
    "account_entries.balance_offset_id in use (column dropped)" => "SELECT COUNT(*) FROM account_entries WHERE balance_offset_id IS NOT NULL",
    "balance_entries.is_pot_entry in use (column dropped)" => "SELECT COUNT(*) FROM balance_entries WHERE is_pot_entry"
  }.freeze

  # Bills whose year was mistyped, entered 2017-11-01 among September 2017 bills. The fix is
  # applied to the bill and everything dated from it; amounts are untouched.
  DATE_FIXES = { 6112 => Date.new(2017, 9, 4), 6116 => Date.new(2017, 9, 30) }.freeze

  # PaperTrail item_type (the STI base class) for each userstamped table.
  USERSTAMPED = { "accounts" => "Account", "shareholders" => "Shareholder", "bill_types" => "BillType",
                  "payees" => "Payee", "bills" => "Bill", "account_entries" => "AccountEntry",
                  "balance_entries" => "BalanceEntry" }.freeze

  # Reads the legacy database through psql, one CSV result per query.
  class Psql
    def initialize(url)
      @url = url
    end

    def rows(sql)
      out, err, status = Open3.capture3("psql", @url, "-v", "ON_ERROR_STOP=1", "-X", "-q",
                                        "-c", "\\copy (#{sql}) TO STDOUT WITH CSV HEADER")
      raise Error, "psql failed: #{err.strip}" unless status.success?
      CSV.parse(out, headers: true).map(&:to_h)
    end
  end

  attr_reader :report

  def initialize(source)
    @source = source
    @report = []
  end

  def run(replace: false)
    precheck!
    refuse_to_overwrite! unless replace

    connection.disable_referential_integrity do
      connection.transaction do
        TABLES.keys.reverse_each { |table| connection.delete("DELETE FROM #{table}") }
        TABLES.each { |table, columns| copy(table, columns) }
        check_foreign_keys!
        backfill_userstamps
        fix_dates
      end
    end
    report_dates
    report
  end

  # Each member's balance and last activity at the end of the legacy data, for reconciling
  # with the spreadsheet that took over from it.
  def self.final_balances_csv
    CSV.generate do |csv|
      csv << %w[shareholder_id name opened_on closed_on last_activity balance]
      Shareholder.includes(:account).order(:account_id, :name).each do |sh|
        csv << [ sh.id, sh.name, sh.opened_on, sh.closed_on, sh.balance_entries.maximum(:date),
                 ActiveSupport::NumberHelper.number_to_rounded(sh.balance, precision: 2) ]
      end
    end
  end

  private

  def connection = ApplicationRecord.connection

  def precheck!
    problems = PRECHECKS.filter_map do |label, sql|
      count = @source.rows("SELECT (#{sql}) AS n").first["n"].to_i
      "#{label}: #{count}" if count.positive?
    end
    raise Error, "The legacy database needs attention first:\n  #{problems.join("\n  ")}" if problems.any?
  end

  def refuse_to_overwrite!
    filled = TABLES.keys.select { |table| connection.select_value("SELECT 1 FROM #{table} LIMIT 1") }
    raise Error, "#{filled.join(', ')} already have rows; rerun with REPLACE=1 to replace them" if filled.any?
  end

  def copy(table, columns)
    select = columns.map { |c| c == "amount_cents" ? "ROUND(amount * 100)::bigint AS amount_cents" : c }
    rows = @source.rows("SELECT #{select.join(', ')} FROM #{table} ORDER BY id")
    model = Class.new(ApplicationRecord) do
      self.table_name = table
      self.inheritance_column = nil
    end
    # Rails stored the legacy timestamps in UTC, without a zone; read them as UTC, not Pacific.
    Time.use_zone("UTC") { rows.each_slice(1_000) { |slice| model.insert_all!(slice, record_timestamps: false) } }
    @report << format("%-16s %7d rows", table, rows.size)
  end

  def check_foreign_keys!
    orphans = connection.select_all("PRAGMA foreign_key_check").to_a
    return @report << "Foreign keys: all references resolve" if orphans.empty?

    summary = orphans.group_by { |o| [ o["table"], o["parent"] ] }.map { |(t, p), rows| "#{t} → #{p}: #{rows.size}" }
    raise Error, "Rows referencing missing records:\n  #{summary.join("\n  ")}"
  end

  # creator = whoever the first `create` version names; updater = the last create/update version.
  def backfill_userstamps
    USERSTAMPED.each do |table, item_type|
      version = ->(order) {
        "(SELECT CAST(whodunnit AS INTEGER) FROM versions v WHERE v.item_type = '#{item_type}' " \
        "AND v.item_id = #{table}.id AND v.whodunnit IS NOT NULL AND v.event IN (%s) ORDER BY v.id #{order} LIMIT 1)"
      }
      creators = connection.update("UPDATE #{table} SET creator_id = #{format(version.("ASC"), "'create'")} " \
                                   "WHERE creator_id IS NULL AND #{format(version.("ASC"), "'create'")} IS NOT NULL")
      updaters = connection.update("UPDATE #{table} SET updater_id = #{format(version.("DESC"), "'create','update'")} " \
                                   "WHERE updater_id IS NULL AND #{format(version.("DESC"), "'create','update'")} IS NOT NULL")
      @report << format("%-16s creator backfilled on %d, updater on %d", table, creators, updaters) if creators + updaters > 0
    end
  end

  def fix_dates
    DATE_FIXES.each do |bill_id, date|
      was = Bill.where(id: bill_id).pick(:date) or next
      next if was == date

      Bill.where(id: bill_id).update_all(date: date)
      [ BalanceEntry, BalanceEvent, AccountEntry ].each { |model| model.where(bill_id: bill_id).update_all(date: date) }
      @report << "Bill##{bill_id} date corrected from #{was} to #{date}"
    end
  end

  def report_dates
    last = [ Bill.maximum(:date), AccountEntry.maximum(:date) ].compact.max
    @report << "Latest bill or entry date: #{last}"
    odd = Bill.where("date < ?", Date.new(2000, 1, 1)).order(:id).map { |b| "#{b.class.name}##{b.id} #{b.date}" }
    @report << "Bills dated before 2000 (probably typos): #{odd.join(', ')}" if odd.any?
  end
end
