# One row per backup or restore test (plan Phase 9), read by the admin footer.
class CreateBackupChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_checks do |t|
      t.string  :kind, null: false   # daily, monthly or restore_test
      t.boolean :ok, null: false
      t.string  :object_name         # where the copy went in the bucket
      t.bigint  :bytes
      t.json    :details             # figures, ledger result or the error
      t.datetime :created_at, null: false
      t.index [ :kind, :created_at ]
    end
  end
end
