# frozen_string_literal: true

namespace :variants do
  desc "Generate missing image variants for all uploads"
  task regenerate: :environment do
    total = Upload.count
    processed = 0
    skipped = 0

    puts "Processing #{total} uploads..."

    Upload.find_each do |upload|
      unless upload.file.attached?
        skipped += 1
        next
      end

      unless upload.file.content_type.start_with?("image/")
        skipped += 1
        next
      end

      ProcessMediaJob.perform_now(upload.id)
      processed += 1

      print "\rProcessed: #{processed}/#{total - skipped} (#{skipped} skipped)"
    end

    puts "\nDone! Processed #{processed} uploads, skipped #{skipped}."
  end
end
