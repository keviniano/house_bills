# Recalculates the rows each bill and member account entry should have generated
# (shares, pot, offsets, the bill's account entry and the balance event) and reports
# where the stored rows differ. It only reads: stored rows are the record of what
# members were charged and are never rewritten (plan D5).
#
# Reviewed differences, such as cents where 2011-era Float rounding differs from
# integer cents, live in config/ledger_known_differences.yml and aren't reported as drift.
class LedgerVerifier
  KNOWN_DIFFERENCES_PATH = Rails.root.join("config/ledger_known_differences.yml")

  Difference = Data.define(:check, :record, :shareholder_id, :stored, :expected) do
    def key
      [ check, record, shareholder_id, stored, expected ].map(&:to_s)
    end

    def to_s
      line = "#{record} #{check}"
      line += " shareholder=#{shareholder_id}" if shareholder_id
      line += ": stored #{format(stored)}, expected #{format(expected)}"
      line += " (off by #{format(stored - expected)})" if stored.is_a?(Integer) && expected.is_a?(Integer)
      line
    end

    private

    def format(value)
      case value
      when Integer then "%.2f" % (value / 100r)
      when nil then "nothing"
      else value.to_s
      end
    end
  end

  Result = Data.define(:checked_bills, :checked_entries, :differences, :known_keys) do
    def unexpected
      differences.reject { |d| known_keys.include?(d.key) }
    end

    def known
      differences.select { |d| known_keys.include?(d.key) }
    end

    def as_json(*)
      {
        checked_bills: checked_bills,
        checked_entries: checked_entries,
        known_differences: known.size,
        unexpected_differences: unexpected.map(&:to_h)
      }
    end

    def report
      lines = unexpected.map(&:to_s)
      lines << "Checked #{checked_bills} bills and #{checked_entries} member account entries: " \
               "#{unexpected.size} unexpected differences, #{known.size} known."
      lines.join("\n")
    end
  end

  def self.known_difference_keys(path = KNOWN_DIFFERENCES_PATH)
    return Set.new unless File.exist?(path)

    entries = YAML.safe_load_file(path, permitted_classes: [ Date ]) || []
    entries.to_set do |e|
      [ e["check"], e["record"], e["shareholder_id"], e["stored"], e["expected"] ].map(&:to_s)
    end
  end

  def initialize(account_id: nil, known_keys: self.class.known_difference_keys)
    @account_id = account_id.presence
    @known_keys = known_keys
  end

  def run
    @differences = []
    checked_bills = check_bills
    checked_entries = check_member_account_entries
    check_orphans

    Result.new(checked_bills:, checked_entries:, differences: @differences, known_keys: @known_keys)
  end

  private

  def scoped(relation)
    @account_id ? relation.where(account_id: @account_id) : relation
  end

  def check_bills
    count = 0
    bills = scoped(Bill.all).includes(:bill_share_balance_entries, :pot_balance_entry,
                                      :bill_offset_balance_entry, :bill_account_entry, :balance_event)
    bills.find_each do |bill|
      count += 1
      check_shares_and_pot(bill)
      check_bill_offset(bill)
      check_balance_event(bill)
    end
    count
  end

  def check_shares_and_pot(bill)
    record = "#{bill.type}##{bill.id}"
    shares = bill.bill_share_balance_entries.to_a
    if shares.empty?
      differ("shares", record, nil, 0, "at least one")
      return
    end

    base_cents, gcd, remainder_cents = Bill.calc_shares(shares.map(&:share), bill.amount_cents)
    shares.each do |entry|
      expected = entry.share == 0 ? 0 : -(entry.share / gcd) * base_cents
      differ("share", record, entry.shareholder_id, entry.amount_cents, expected)
      check_generated_row("share", record, entry, bill)
    end

    pot = bill.pot_balance_entry
    differ("pot", record, nil, pot&.amount_cents, remainder_cents)
    check_generated_row("pot", record, pot, bill) if pot
  end

  def check_bill_offset(bill)
    record = "#{bill.type}##{bill.id}"
    case bill
    when ShareholderBill
      offset = bill.bill_offset_balance_entry
      differ("offset", record, bill.shareholder_id, offset&.amount_cents, bill.amount_cents)
      return unless offset
      differ("offset shareholder", record, nil, offset.shareholder_id, bill.shareholder_id)
      check_generated_row("offset", record, offset, bill)
    when AccountBill
      entry = bill.bill_account_entry
      differ("account entry", record, nil, entry&.amount_cents, -bill.amount_cents)
      check_generated_row("account entry", record, entry, bill) if entry
    end
  end

  def check_balance_event(owner)
    record = "#{owner.type}##{owner.id}"
    event = owner.balance_event
    differ("balance event", record, nil, event ? "present" : nil, "present")
    check_generated_row("balance event", record, event, owner) if event
  end

  def check_member_account_entries
    count = 0
    entries = scoped(ShareholderAccountEntry.all).includes(:account_offset_balance_entry, :balance_event)
    entries.find_each do |entry|
      count += 1
      record = "ShareholderAccountEntry##{entry.id}"
      offset = entry.account_offset_balance_entry
      differ("offset", record, entry.shareholder_id, offset&.amount_cents, entry.amount_cents)
      if offset
        differ("offset shareholder", record, nil, offset.shareholder_id, entry.shareholder_id)
        check_generated_row("offset", record, offset, entry)
      end
      check_balance_event(entry)
    end
    count
  end

  # Generated rows carry their source's date and account.
  def check_generated_row(check, record, row, source)
    differ("#{check} date", record, row.try(:shareholder_id), row.date&.iso8601, source.date&.iso8601)
    differ("#{check} account", record, row.try(:shareholder_id), row.account_id, source.account_id)
  end

  def check_orphans
    {
      "BillShareBalanceEntry" => :bill_id, "PotBalanceEntry" => :bill_id,
      "BillOffsetBalanceEntry" => :bill_id, "AccountOffsetBalanceEntry" => :account_entry_id
    }.each do |type, column|
      scoped(BalanceEntry.where(type: type, column => nil)).pluck(:id).each do |id|
        differ("orphan", "#{type}##{id}", nil, nil, column.to_s)
      end
    end

    scoped(BalanceEvent.where(bill_id: nil, account_entry_id: nil)).pluck(:id).each do |id|
      differ("orphan", "BalanceEvent##{id}", nil, nil, "bill_id or account_entry_id")
    end

    duplicates(BalanceEntry.where(type: "PotBalanceEntry"), :bill_id, "pot", "Bill")
    duplicates(BalanceEntry.where(type: "BillOffsetBalanceEntry"), :bill_id, "offset", "Bill")
    duplicates(BalanceEntry.where(type: "AccountOffsetBalanceEntry"), :account_entry_id, "offset", "AccountEntry")
    duplicates(BalanceEvent.where.not(bill_id: nil), :bill_id, "balance event", "Bill")
    duplicates(BalanceEvent.where.not(account_entry_id: nil), :account_entry_id, "balance event", "AccountEntry")
  end

  def duplicates(relation, column, check, owner_type)
    scoped(relation).group(column).having("COUNT(*) > 1").count.each do |owner_id, count|
      differ("duplicate #{check}", "#{owner_type}##{owner_id}", nil, count, 1)
    end
  end

  def differ(check, record, shareholder_id, stored, expected)
    return if stored == expected

    @differences << Difference.new(check:, record:, shareholder_id:, stored:, expected:)
  end
end
