class BackupCheck < ApplicationRecord
  KINDS = %w[daily monthly restore_test].freeze

  validates :kind, inclusion: { in: KINDS }

  scope :passed, -> { where(ok: true) }

  def self.latest(kind)
    where(kind: kind).order(:created_at).last
  end

  def self.last_passed(kind)
    passed.where(kind: kind).order(:created_at).last
  end

  def ledger_unexpected
    details&.dig("ledger_unexpected")
  end
end
