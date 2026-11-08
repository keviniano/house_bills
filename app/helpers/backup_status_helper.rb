# The admin footer (plan Phase 9): when the last backup and verified restore happened, and the
# ledger result from the last restore test. Anything failed or overdue shows in red.
module BackupStatusHelper
  def backup_status_item(label, kind, stale_after:)
    latest = BackupCheck.latest(kind)
    passed = BackupCheck.last_passed(kind)
    text = passed ? "#{label} #{time_ago_in_words(passed.created_at)} ago" : "#{label}: never"
    problem = backup_problem(latest, passed, stale_after)
    tag.span(problem ? "#{text} (#{problem})" : text, class: ("text-danger" if problem),
             title: (latest.details.to_json if latest&.details.present?))
  end

  def backup_problem(latest, passed, stale_after)
    return "last attempt failed" if latest && !latest.ok?
    "overdue" if passed.nil? || passed.created_at < stale_after.ago
  end

  def ledger_status_item
    count = BackupCheck.where(kind: "restore_test").where.not(details: nil).order(:created_at).last&.ledger_unexpected
    return tag.span("Ledger: not checked yet") if count.nil?

    tag.span("Ledger: #{pluralize(count, 'unexpected difference')}", class: ("text-danger" if count.positive?))
  end
end
