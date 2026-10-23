# Exposes an integer-cents column as a BigDecimal attribute, so views, forms and
# reified PaperTrail versions (whose YAML holds `amount`) keep working:
#
#   money_attribute :amount   # amount / amount= backed by amount_cents
#
# Values are cast the way the old decimal(10,2) column cast them, then rounded
# half away from zero to the cent.
module MoneyColumn
  extend ActiveSupport::Concern

  DECIMAL = ActiveModel::Type::Decimal.new

  class_methods do
    def money_attribute(name)
      cents_column = :"#{name}_cents"

      define_method(name) do
        MoneyColumn.from_cents(self[cents_column])
      end

      define_method(:"#{name}=") do |value|
        self[cents_column] = MoneyColumn.to_cents(value)
      end
    end

    # Sums a money attribute across a relation: account_entries.sum_money(:amount)
    def sum_money(name = :amount)
      MoneyColumn.from_cents(sum(:"#{name}_cents"))
    end
  end

  def self.from_cents(cents)
    BigDecimal(cents) / 100 unless cents.nil?
  end

  def self.to_cents(value)
    return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

    decimal = DECIMAL.cast(value)
    (decimal * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i unless decimal.nil?
  end
end
