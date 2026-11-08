# Scheduled in config/recurring.yml; see DatabaseBackup.
class BackupJob < ApplicationJob
  queue_as :default

  def perform(kind)
    DatabaseBackup.new.run(kind)
  end
end
