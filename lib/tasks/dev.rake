namespace :dev do
  desc "Create clearly fictional demo data (users, teams, patients, hospitalizations, surgeries...) for UI review; development only, additive and idempotent"
  task demo_data: :environment do
    DevDemoData.run.each do |kind, created|
      puts "#{kind}: #{created} created"
    end
  end
end
