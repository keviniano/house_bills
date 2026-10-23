namespace :import do
  desc "Copy the legacy Postgres database into this one, keeping IDs; needs psql. " \
       "REPLACE=1 replaces existing rows. Also writes each member's final balance to " \
       "test/fixtures/golden/final_balances.csv. e.g. bin/rails 'import:legacy_dump[postgres://postgres@127.0.0.1:5433/house_bills_2016]'"
  task :legacy_dump, [ :url ] => :environment do |_, args|
    url = args[:url] or abort "usage: bin/rails 'import:legacy_dump[postgres://...]'"
    puts LegacyImport.new(LegacyImport::Psql.new(url)).run(replace: ENV["REPLACE"] == "1")

    path = Rails.root.join("test/fixtures/golden/final_balances.csv")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, LegacyImport.final_balances_csv)
    puts "Final member balances: #{path.relative_path_from(Rails.root)}"
  rescue LegacyImport::Error => e
    abort e.message
  end
end
