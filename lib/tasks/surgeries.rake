namespace :surgeries do
  desc "Move elective off-slot surgeries that use a special slot resource (hybrid room, cath lab, robot...) to the regular slots, slot unassigned. Lists them only unless APPLY=1 (DRY_RUN=1 always wins); idempotent"
  task move_special_off_slot_to_regular: :environment do
    apply = ENV["APPLY"] == "1" && ENV["DRY_RUN"] != "1"
    result = SpecialOffSlotMove.new(apply: apply).run

    puts(apply ? "APPLY: moving to regular slot (slot unassigned)" : "DRY RUN (nothing is changed; run with APPLY=1 to move)")
    result.candidates.each do |surgery|
      resources = [ surgery.surgery_location&.name, surgery.surgical_device&.name ].compact.join(" / ")
      puts "  ##{surgery.id}  #{surgery.surgery_date || '(undated)'}  #{surgery.patient.hospital_id}  #{resources}"
    end
    puts "candidates: #{result.candidates.size}"
    puts "moved: #{result.moved}" if apply
    result.failed.each { |id, message| puts "  failed ##{id}: #{message}" }
  end
end
