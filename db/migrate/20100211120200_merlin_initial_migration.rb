class MerlinInitialMigration < ActiveRecord::Migration 
  def self.up
    create_table :availability_zones do |t|
      t.column :name, :string
      t.column :description, :text
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :cloud
    end

    create_table :key_pairs do |t|
      t.column :fingerprint, :text
      t.column :name, :string
      t.column :key_material, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :cloud
    end

    create_table :dns_providers do |t|
      t.enum :provider_type
      t.column :username, :string
      t.column :credentials, :string
      t.column :update_zone, :string
      t.column :record_ttl, :integer
      t.column :api_url, :string
      t.column :api_usessl, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
    end

    create_table :clouds do |t|
      t.column :name, :string
      t.column :description, :string
      t.column :api_url, :string
      t.column :api_usessl, :boolean
      t.column :query_key, :string
      t.column :query_key_id, :string
      t.references :security_group
      t.column :puppet_server, :string
      t.column :puppet_port, :integer
      t.column :notify_address, :string
      t.column :user_data_script, :text
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.column :status_code, :integer
      t.column :status_message, :string
      t.column :ready, :boolean
      t.column :update_dns, :boolean
      t.references :dns_provider
      t.references :cloud_type
    end

    create_table :userdatas do |t|
      t.column :name, :string
      t.column :description, :text
      t.column :script, :text
    end

    create_table :cloud_types do |t|
      t.column :name, :string
      t.column :description, :text
      t.column :support_elastic_ip, :boolean
      t.column :support_multiple_ebs_volumes, :boolean
      t.column :support_multiple_sec_groups, :boolean
      t.column :use_root_path, :boolean
    end

    create_table :vm_types do |t|
      t.column :name, :string
      t.column :description, :string
      t.column :cpu_units, :float
      t.column :memory, :float
      t.column :disk, :float
      t.column :bits, :integer
      t.references :cloud_type
    end

    create_table :instance_types do |t|
      t.column :name, :string
      t.column :image_id, :string
      t.column :kernel_id, :string
      t.column :ramdisk_id, :string
      t.references :vm_type
      t.references :cloud
      t.column :bits, :integer
      t.column :description, :text
      t.column :region, :text
      t.column :root_store, :string
      t.column :version, :string
      t.column :os, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
    end

    create_table :volume_types do |t|
      t.column :size, :integer
      t.column :name, :string
      t.column :description, :text
      t.column :fs_label, :string
      t.column :mount_point, :string
      t.column :filesystem, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.column :status_code, :integer
      t.column :status_message, :string
    end

    create_table :instances do |t|
      t.column :instance_id, :string
      t.column :ip_address, :string
      t.column :private_ip_address, :string
      t.column :dns_name, :string
      t.column :private_dns_name, :string
      t.column :architecture, :string
      t.column :virtualization_type, :string
      t.column :reason, :string
      t.column :image_id, :string
      t.column :kernel_id, :string
      t.column :ramdisk_id, :string
      t.column :hostname, :string
      t.column :request_id, :string
      t.column :reservation_id, :string
      t.column :root_device_name, :string
      t.column :root_device_type, :string
      t.column :launch_time, :timestamp
      t.column :elastic_ip, :boolean
      t.column :status_code, :integer
      t.column :status_message, :string
      t.column :raw_userdata, :text
      t.column :monitoring, :boolean
      t.column :owner_id, :string
      t.column :seen, :boolean
      t.column :active, :boolean
      t.column :has_run_userdata, :boolean
      t.column :needs_api_update, :boolean
      t.column :access_token, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :key_pair
      t.references :userdata
      t.references :vm_type
      t.references :cloud
      t.references :availability_zone
      t.references :instance_type
    end

    create_table :instances_security_groups, :id => false do |t|
      t.integer :instance_id
      t.integer :security_group_id
    end

    create_table :volumes do |t|
      t.column :volume_id, :string
      t.column :size, :integer
      t.column :create_time, :timestamp
      t.column :attach_time, :timestamp
      t.column :snapshot_id, :string
      t.column :attachment_status_code, :integer
      t.column :attachment_status_message, :string
      t.column :attachment_attach_time, :timestamp
      t.column :attachment_device, :string
      t.column :delete_on_termination, :boolean
      t.column :root_device, :boolean
      t.column :status_code, :string
      t.column :status_message, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :availability_zone
      t.references :cloud
      t.references :instance
      t.references :volume_type
    end

    create_table :volume_snapshots do |t|
      t.column :snapshot_id, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :availability_zone
      t.references :volume
    end

    create_table :security_groups do |t|
      t.column :name, :string
      t.column :description, :string
      t.column :owner_id, :string
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.references :cloud
    end

  end

  def self.down
    drop_table :availability_zones
    drop_table :public_keys
    drop_table :dns_providers
    drop_table :clouds
    drop_table :userdatas
    drop_table :cloud_types
    drop_table :instance_types
    drop_table :volume_types
    drop_table :instances
    drop_table :instances_security_groups
    drop_table :volumes
    drop_table :volume_snapshots
    drop_table :security_groups
    drop_table :vm_types
  end
end
