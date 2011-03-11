namespace :merlin do

  task :cloudinit => :environment do
    Cloud.all.each do |c|
      puts "Updating #{c.name} state from API endpoint"
      c.update_from_api
    end
  end

  task :loaduserdata => :environment do
    u = Userdata.new
    f = File.open("public/files/userdata.erb").read
    u.script = f
    u.name = "userdata-default"
    u.description = "The default userdata script that ships with Merlin."
    u.save
  end

  task :resetuserdata => :environment do
    Userdata.destroy_all
    puts "All userdata destroyed."
  end

  task :destroytest => :environment do
    i = Instance.find_or_create_by_instance_id('i-DEADBEEF')
    i.destroy
  end

  task :testuserdata => :environment do
    # Test the userdata script. Only populate the stuff we need to actually check
    # if it builds correctly.
    i = Instance.find_or_create_by_instance_id('i-DEADBEEF')
    i.hostname = 'userdatatest.tld'
    i.cloud = Cloud.first
    i.availability_zone = Cloud.first.availability_zone.first
    i.userdata = Userdata.find_by_name("userdata-default")

    v = Volume.new
    v.size=30
    v.attachment_device='/dev/sdb'
    v.mount_point='/srv/test'
    v.name='Rake test volume'
    v.description='Rake test volume'
    v.availability_zone = i.availability_zone
    v.volume_id = 'vol-DEADBEEF'

    v.save
    i.save

    i.volume.push v

    i.generate_access_token

    if !i.generate_userdata then
      puts "Userdata script generation failed: #{i.instance_values['userdata_error']}"
    else 
      puts "Success, raw output follows"
      puts Base64.decode64(i.raw_userdata)
    end

  end
end
