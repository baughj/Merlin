class AddPuppetCapathToCloud < ActiveRecord::Migration
  def self.up
    add_column :clouds, :puppet_capath, :string
  end

  def self.down
    remove_column :clouds, :puppet_capath
  end
end
