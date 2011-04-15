# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110408150041) do

  create_table "availability_zones", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cloud_id"
  end

  create_table "cloud_types", :force => true do |t|
    t.string  "name"
    t.text    "description"
    t.boolean "support_elastic_ip"
    t.boolean "support_multiple_ebs_volumes"
    t.boolean "support_multiple_sec_groups"
    t.boolean "paravirtualized"
    t.boolean "use_root_path"
  end

  create_table "clouds", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "api_url"
    t.boolean  "api_usessl"
    t.string   "query_key"
    t.string   "query_key_id"
    t.integer  "security_group_id"
    t.string   "puppet_server"
    t.integer  "puppet_port"
    t.string   "notify_address"
    t.text     "user_data_script"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status_code"
    t.string   "status_message"
    t.boolean  "ready"
    t.boolean  "update_dns"
    t.integer  "dns_provider_id"
    t.integer  "cloud_type_id"
    t.string   "puppet_capath"
  end

  create_table "dns_providers", :force => true do |t|
    t.string   "provider_type"
    t.string   "name"
    t.text     "description"
    t.string   "identity"
    t.string   "credentials"
    t.string   "update_zone"
    t.integer  "record_ttl"
    t.integer  "status_code"
    t.string   "status_message"
    t.string   "api_url"
    t.boolean  "api_usessl"
    t.boolean  "create_a_record"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cloud_id"
  end

  create_table "instance_types", :force => true do |t|
    t.string   "name"
    t.string   "image_id"
    t.string   "kernel_id"
    t.string   "ramdisk_id"
    t.integer  "vm_type_id"
    t.integer  "cloud_id"
    t.integer  "bits"
    t.text     "description"
    t.text     "region"
    t.string   "root_store"
    t.string   "version"
    t.string   "os"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "instances", :force => true do |t|
    t.string   "instance_id"
    t.string   "ip_address"
    t.string   "private_ip_address"
    t.string   "dns_name"
    t.string   "private_dns_name"
    t.string   "architecture"
    t.string   "virtualization_type"
    t.string   "reason"
    t.string   "name"
    t.text     "description"
    t.string   "image_id"
    t.string   "kernel_id"
    t.string   "ramdisk_id"
    t.string   "hostname"
    t.string   "request_id"
    t.string   "reservation_id"
    t.string   "root_device_name"
    t.string   "root_device_type"
    t.datetime "launch_time"
    t.boolean  "elastic_ip"
    t.integer  "status_code"
    t.string   "status_message"
    t.text     "raw_userdata"
    t.boolean  "monitoring"
    t.string   "owner_id"
    t.boolean  "seen"
    t.boolean  "active"
    t.boolean  "has_run_userdata"
    t.boolean  "needs_api_update"
    t.string   "access_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "key_pair_id"
    t.integer  "userdata_id"
    t.integer  "vm_type_id"
    t.integer  "cloud_id"
    t.integer  "availability_zone_id"
    t.integer  "instance_type_id"
  end

  create_table "instances_security_groups", :id => false, :force => true do |t|
    t.integer "instance_id"
    t.integer "security_group_id"
  end

  create_table "instances_volume_types", :id => false, :force => true do |t|
    t.integer "instance_id"
    t.integer "volume_type_id"
  end

  create_table "key_pairs", :force => true do |t|
    t.text     "fingerprint"
    t.string   "name"
    t.string   "key_material"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cloud_id"
  end

  create_table "notification_logs", :force => true do |t|
    t.string   "recipient"
    t.text     "notification"
    t.boolean  "delivered"
    t.integer  "instance_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "notification_templates", :force => true do |t|
    t.string   "name"
    t.string   "lang"
    t.string   "subject"
    t.text     "template"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "security_groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "owner_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cloud_id"
  end

  create_table "userdatas", :force => true do |t|
    t.string "name"
    t.text   "description"
    t.text   "script"
  end

  create_table "vm_types", :force => true do |t|
    t.string  "name"
    t.text    "description"
    t.float   "cpu_units"
    t.float   "memory"
    t.float   "disk"
    t.integer "bits"
    t.integer "cloud_type_id"
  end

  create_table "volume_snapshots", :force => true do |t|
    t.string   "snapshot_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "availability_zone_id"
    t.integer  "volume_id"
  end

  create_table "volume_types", :force => true do |t|
    t.integer  "size"
    t.string   "name"
    t.text     "description"
    t.string   "fs_label"
    t.string   "mount_point"
    t.string   "filesystem"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status_code"
    t.string   "status_message"
  end

  create_table "volumes", :force => true do |t|
    t.string   "volume_id"
    t.integer  "size"
    t.datetime "create_time"
    t.datetime "attach_time"
    t.string   "snapshot_id"
    t.string   "mount_point"
    t.string   "name"
    t.text     "description"
    t.string   "request_id"
    t.integer  "attachment_status_code"
    t.string   "attachment_status_message"
    t.datetime "attachment_attach_time"
    t.string   "attachment_device"
    t.string   "filesystem"
    t.boolean  "delete_on_termination"
    t.boolean  "root_device"
    t.integer  "status_code"
    t.string   "status_message"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "availability_zone_id"
    t.integer  "cloud_id"
    t.integer  "instance_id"
    t.integer  "volume_type_id"
  end

end
