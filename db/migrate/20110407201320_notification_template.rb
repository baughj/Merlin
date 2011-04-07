class NotificationTemplate < ActiveRecord::Migration
  def self.up
    create_table :notificationtemplates do |t|
      t.column :name, :string
      t.column :lang, :string
      t.column :template, :text
  end

  def self.down
    drop_table :notificationtemplates
  end
end
