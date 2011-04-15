namespace :merlin do
  task :cloudinit => :environment do
    Cloud.all.each do |c|
      puts "Updating #{c.name} state from API endpoint"
      c.update_from_api
    end
  end

  task :loadsiteuserdata => :environment do
    u = Userdata.new
    f = File.open("config/site-userdata.erb").read
    u.script = f
    u.name = "userdata-sitedefault"
    u.description = "The default site userdata script."
    u.save
  end

  task :loaduserdata => :environment do
    u = Userdata.new
    f = File.open("config/userdata.erb").read
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
    i = Instance.find_or_create_by_instance_id('i-00000000').destroy
    i = Instance.find_or_create_by_instance_id('i-00000001').destroy
    i = Instance.find_or_create_by_instance_id('i-00000002').destroy

  end

  task :testnovoluserdata => :environment do
    # Test the userdata script. Only populate the stuff we need to actually check
    # if it builds correctly.

    i = Instance.create(:instance_id => 'i-00000000',
                        :hostname => 'userdatatest-novol.tld',
                        :availability_zone => Cloud.first.availability_zones.first,
                        :userdata => Userdata.find_by_name("userdata-sitedefault"),
                        :cloud => Cloud.first)

    i.generate_access_token
    
    if !i.generate_userdata then
      puts "Userdata script generation failed: #{i.instance_values['userdata_error']}"
    else 
      puts "Success, raw output follows"
      puts Base64.decode64(i.raw_userdata)
    end
  end 
  
  task :testmultiplevoluserdata => :environment do
    i = Instance.create(:instance_id => 'i-00000001',
                        :hostname => 'userdatatest-onevol.tld',
                        :availability_zone => Cloud.first.availability_zones.first,
                        :userdata => Userdata.find_by_name("userdata-sitedefault"),
                        :cloud => Cloud.first)

    i.generate_access_token

    v = Volume.create(:size => 30, :attachment_device => '/dev/sdb',
                      :mount_point => '/srv/test',
                      :name => 'Rake test volume',
                      :description => 'Rake test volume',
                      :availability_zone => i.availability_zone,
                      :volume_id => 'vol-00000000')

    v2 = Volume.create(:size => 10, :attachment_device => '/dev/sdc',
                       :mount_point => '/srv/test',
                       :name => 'Second Rake test volume',
                       :description => 'Second Rake test volume',
                       :availability_zone => i.availability_zone,
                       :volume_id => 'vol-00000001')

    i.volumes << v
    i.volumes << v2
    i.save

    i.generate_access_token

    if !i.generate_userdata then
      puts "Userdata script generation failed: #{i.instance_values['userdata_error']}"
    else 
      puts "Success, raw output follows"
      puts Base64.decode64(i.raw_userdata)
    end
  end
    
  task :testonevoluserdata => :environment do
    
    i = Instance.create(:instance_id => 'i-00000002',
                        :hostname => 'userdatatest-onevol.tld',
                        :availability_zone => Cloud.first.availability_zones.first,
                        :userdata => Userdata.find_by_name("userdata-sitedefault"),
                        :cloud => Cloud.first)

    i.generate_access_token
    
    v = Volume.create(:size => 30, :attachment_device => '/dev/sdb',
                      :mount_point => '/srv/test',
                      :name => 'Rake test volume',
                      :description => 'Rake test volume',
                      :availability_zone => i.availability_zone,
                      :volume_id => 'vol-00000003')
    
    i.volumes << v
    i.save
    
    i.generate_access_token
    
    if !i.generate_userdata then
      puts "Userdata script generation failed: #{i.instance_values['userdata_error']}"
    else 
      puts "Success, raw output follows"
      puts Base64.decode64(i.raw_userdata)
    end
  end

end
