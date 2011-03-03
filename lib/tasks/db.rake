namespace :db do
  desc "This loads the development data."
  task :seed => :environment do
    require 'active_record/fixtures'
    Dir.glob(RAILS_ROOT + '/db/fixtures/*.yml').each do |file|
      base_name = File.basename(file, '.*')
      puts "Loading #{base_name}..."
      Fixtures.create_fixtures('db/fixtures', base_name)
    end
  end

  desc "This drops the db, builds the db, and seeds the data."
  task :reseed => [:environment, 'db:reset', 'db:seed']
end
