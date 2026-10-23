# Compares this database with the reference figures recorded from the legacy Postgres
# dump by script/record_golden_figures: table row counts, each account's register,
# cleared and pot balances, and every member's balance, all to the cent.
class GoldenFigures
  PATH = Rails.root.join("test/fixtures/golden/figures.json")

  TABLES = %w[accounts account_entries balance_entries balance_events bill_types bills
              payees roles shareholders users versions].freeze

  def self.recorded(path = PATH)
    JSON.parse(File.read(path)) if File.exist?(path)
  end

  # The same figures as the recording script, from this database.
  def self.current
    {
      "counts" => TABLES.index_with { |table| ApplicationRecord.connection.select_value("SELECT COUNT(*) FROM #{table}") },
      "accounts" => Account.order(:id).to_h { |account|
        [ account.id.to_s, {
          "balance_cents"         => account.account_entries.sum(:amount_cents),
          "cleared_balance_cents" => account.account_entries.where(cleared: true).sum(:amount_cents),
          "pot_cents"             => account.pot_balance_entries.sum(:amount_cents),
          "balance_entries_cents" => BalanceEntry.where(account_id: account.id).sum(:amount_cents),
          "bills_cents"           => Bill.where(account_id: account.id).sum(:amount_cents)
        } ]
      },
      "shareholders" => Shareholder.order(:id).pluck(:id).index_with(0)
        .merge(BalanceEntry.where.not(shareholder_id: nil).group(:shareholder_id).sum(:amount_cents))
        .transform_keys(&:to_s)
    }
  end

  # ["accounts.1.pot_cents: expected 15742, got 15741", ...]; empty when everything matches.
  def self.differences(expected, actual = current)
    flatten(expected).each_with_object([]) do |(key, value), diffs|
      got = flatten(actual)[key]
      diffs << "#{key}: expected #{value.inspect}, got #{got.inspect}" unless got == value
    end + (flatten(actual).keys - flatten(expected).keys).map { |key| "#{key}: not in the recorded figures" }
  end

  def self.flatten(hash, prefix = nil)
    hash.each_with_object({}) do |(key, value), flat|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flat.merge!(flatten(value, path)) : flat[path] = value
    end
  end
  private_class_method :flatten
end
