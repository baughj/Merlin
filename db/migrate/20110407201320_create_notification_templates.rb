class CreateNotificationTemplates < ActiveRecord::Migration
  def self.up
    create_table :notification_templates do |t|
      t.column :name, :string
      t.column :lang, :string
      t.column :subject, :string
      t.column :template, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :notification_templates
  end
end
