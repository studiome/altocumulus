namespace :dev do
  desc "Create clearly fictional demo data (users, teams, patients, hospitalizations, surgeries...) for UI review; development only, additive and idempotent. REFRESH=1 also rewrites the clinical content of the demo cases (marker \"デモデータ #NN\") in place"
  task demo_data: :environment do
    DevDemoData.run(refresh: ENV["REFRESH"].present?).each do |kind, count|
      puts kind == :refreshed_cases ? "refreshed demo cases: #{count}" : "#{kind}: #{count} created"
    end
  end
end
