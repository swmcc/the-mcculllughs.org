# frozen_string_literal: true

namespace :uploads do
  desc "Generate missing variants for all existing uploads"
  task generate_variants: :environment do
    puts "Starting variant generation for existing uploads..."

    total = Upload.count
    processed = 0
    errors = 0

    Upload.find_each do |upload|
      next unless upload.file.attached?
      next unless upload.file.content_type&.start_with?("image/")

      print "Processing upload #{upload.id} (#{upload.title.presence || 'untitled'})... "

      ProcessMediaJob::VARIANTS.each do |name, options|
        upload.file.variant(options).processed
        print "#{name} "
      rescue StandardError => e
        print "#{name}:ERROR "
        errors += 1
        Rails.logger.error "Failed #{name} for upload #{upload.id}: #{e.message}"
      end

      processed += 1
      puts "✓"
    rescue StandardError => e
      errors += 1
      puts "✗ #{e.message}"
    end

    puts ""
    puts "=" * 50
    puts "Completed!"
    puts "  Total uploads: #{total}"
    puts "  Processed: #{processed}"
    puts "  Errors: #{errors}"
  end

  desc "Check which uploads are missing variants"
  task check_variants: :environment do
    puts "Checking variant status for all uploads..."

    missing = []

    Upload.find_each do |upload|
      next unless upload.file.attached?
      next unless upload.file.content_type&.start_with?("image/")

      ProcessMediaJob::VARIANTS.each do |name, options|
        variant = upload.file.variant(options)
        unless variant.key.present? && upload.file.service.exist?(variant.key)
          missing << { upload_id: upload.id, variant: name }
        end
      rescue StandardError
        missing << { upload_id: upload.id, variant: name }
      end
    end

    if missing.empty?
      puts "All variants are present! ✓"
    else
      puts "Missing variants:"
      missing.each do |m|
        puts "  Upload #{m[:upload_id]}: #{m[:variant]}"
      end
      puts ""
      puts "Run `rake uploads:generate_variants` to generate missing variants."
    end
  end

  desc "Purge legacy :thumbnail Active Storage attachments left over from the pre-variant pipeline"
  task purge_legacy_thumbnails: :environment do
    attachments = ActiveStorage::Attachment.where(record_type: "Upload", name: "thumbnail")
    total = attachments.count

    if total.zero?
      puts "No legacy thumbnail attachments found. ✓"
      next
    end

    puts "Purging #{total} legacy thumbnail attachment(s)..."

    purged = 0
    errors = 0

    attachments.find_each do |attachment|
      attachment.purge
      purged += 1
      print "\rPurged: #{purged}/#{total}"
    rescue StandardError => e
      errors += 1
      Rails.logger.error "Failed to purge thumbnail attachment #{attachment.id}: #{e.message}"
    end

    puts ""
    puts "Done! Purged #{purged} attachment(s), #{errors} error(s)."
  end
end
