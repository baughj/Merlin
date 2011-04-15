class CreateNotificationLogs < ActiveRecord::Migration
  def self.up
    create_table :notification_logs do |t|
      t.column :recipient, :string
      t.column :notification, :text 
      t.column :delivered, :boolean
      t.references :instance
      t.timestamps
    end
  end

  def self.down
    drop_table :notification_logs
  end
end
