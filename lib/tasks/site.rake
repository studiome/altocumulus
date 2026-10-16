namespace :site do
  desc "Create the master records (departments, surgery locations, surgical devices) listed under `masters` in the site config; never deletes or renames existing ones"
  task seed_masters: :environment do
    SiteMasterSeeder.call.each do |key, created|
      puts "#{key}: #{created} created"
    end
  end
end
