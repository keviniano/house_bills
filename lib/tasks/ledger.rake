namespace :ledger do
  desc "Report stored balance rows that differ from what their bills and entries should " \
       "generate. Read-only. ACCOUNT=<id> limits it to one account; FORMAT=json for machine output. " \
       "Exits 1 when there are differences not in config/ledger_known_differences.yml."
  task verify: :environment do
    result = LedgerVerifier.new(account_id: ENV["ACCOUNT"]).run
    puts ENV["FORMAT"] == "json" ? JSON.pretty_generate(result.as_json) : result.report
    exit 1 if result.unexpected.any?
  end
end
