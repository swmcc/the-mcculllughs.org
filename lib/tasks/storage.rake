namespace :storage do
  desc "Restructure S3 sync files for local Active Storage directory structure"
  task restructure: :environment do
    require "fileutils"

    source_dir = Rails.root.join("tmp/s3_sync")
    target_dir = Rails.root.join("storage")

    unless source_dir.exist?
      puts "Error: #{source_dir} does not exist. Run 'aws s3 sync' first."
      exit 1
    end

    # Get all blob keys from the database
    blob_keys = ActiveStorage::Blob.pluck(:key)
    puts "Found #{blob_keys.count} blobs in database"

    synced = 0
    missing = 0

    blob_keys.each do |key|
      # S3 stores files flat, local storage uses nested dirs: {key[0..1]}/{key[2..3]}/{key}
      source_file = source_dir.join(key)

      unless source_file.exist?
        puts "  Missing: #{key}"
        missing += 1
        next
      end

      # Create nested directory structure
      nested_dir = target_dir.join(key[0..1], key[2..3])
      FileUtils.mkdir_p(nested_dir)

      target_file = nested_dir.join(key)
      FileUtils.cp(source_file, target_file)
      synced += 1
    end

    puts ""
    puts "Synced: #{synced} files"
    puts "Missing: #{missing} files" if missing > 0
    puts "Done! Files are now in #{target_dir}"
  end

  desc "Pull files directly from S3 using blob keys (no ListBucket permission needed)"
  task pull_from_s3: :environment do
    require "fileutils"

    bucket = ENV.fetch("S3_BUCKET", "the-mcculloughs-org")
    region = ENV.fetch("AWS_REGION", "eu-west-1")
    target_dir = Rails.root.join("storage")

    # Only get original uploads, not auto-generated variants
    blob_ids = ActiveStorage::Attachment
      .where.not(record_type: "ActiveStorage::VariantRecord")
      .pluck(:blob_id)

    blob_keys = ActiveStorage::Blob.where(id: blob_ids).pluck(:key)
    puts "Downloading #{blob_keys.count} original files from S3 (skipping #{ActiveStorage::Blob.count - blob_keys.count} variants)..."

    downloaded = 0
    failed = 0

    blob_keys.each_with_index do |key, idx|
      # Create nested directory structure for local storage
      nested_dir = target_dir.join(key[0..1], key[2..3])
      FileUtils.mkdir_p(nested_dir)
      target_file = nested_dir.join(key)

      # Skip if already exists
      if target_file.exist?
        print "s"
        next
      end

      # Download directly using aws s3 cp
      result = system("aws s3 cp s3://#{bucket}/#{key} #{target_file} --region #{region} 2>/dev/null")

      if result
        downloaded += 1
        print "."
      else
        failed += 1
        print "x"
      end

      # Progress update every 100 files
      puts " [#{idx + 1}/#{blob_keys.count}]" if (idx + 1) % 100 == 0
    end

    puts ""
    puts "Downloaded: #{downloaded}"
    puts "Skipped (existing): #{blob_keys.count - downloaded - failed}"
    puts "Failed: #{failed}" if failed > 0
  end

  desc "Clean up S3 sync temp directory"
  task clean_sync: :environment do
    sync_dir = Rails.root.join("tmp/s3_sync")
    if sync_dir.exist?
      FileUtils.rm_rf(sync_dir)
      puts "Cleaned up #{sync_dir}"
    else
      puts "Nothing to clean"
    end
  end
end
