require 'rails_helper'

RSpec.describe ProcessMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  describe "#perform" do
    it "is enqueued on the default queue" do
      expect(ProcessMediaJob.new.queue_name).to eq("default")
    end

    it "does nothing if the upload has no file attached" do
      upload = create(:upload, user: user, gallery: gallery)
      upload.file.purge

      expect { ProcessMediaJob.perform_now(upload.id) }.not_to raise_error
    end

    it "generates variants for image uploads" do
      upload = create(:upload, user: user, gallery: gallery)
      upload.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      )

      expect { ProcessMediaJob.perform_now(upload.id) }.not_to raise_error
      # Variants are generated lazily, but the job processes them
      expect(upload.reload.file).to be_attached
    end
  end

  describe "EXIF extraction" do
    context "with an image containing EXIF data" do
      let(:upload) { create(:upload, user: user, gallery: gallery, date_taken: nil) }

      before do
        upload.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test_image_with_exif.jpg")),
          filename: "test_image_with_exif.jpg",
          content_type: "image/jpeg"
        )
      end

      it "extracts EXIF data and stores it in exif_data" do
        ProcessMediaJob.perform_now(upload.id)
        upload.reload

        expect(upload.exif_data).to be_present
        expect(upload.exif_data["Make"]).to eq("Canon")
        expect(upload.exif_data["Model"]).to eq("EOS 5D Mark IV")
      end

      it "sets date_taken from DateTimeOriginal" do
        ProcessMediaJob.perform_now(upload.id)
        upload.reload

        expect(upload.date_taken).to eq(Date.new(2024, 6, 15))
      end

      it "does not overwrite date_taken if already set" do
        existing_date = Date.new(2020, 1, 1)
        upload.update!(date_taken: existing_date)

        ProcessMediaJob.perform_now(upload.id)
        upload.reload

        expect(upload.date_taken).to eq(existing_date)
      end
    end

    context "with an image without EXIF data" do
      let(:upload) { create(:upload, user: user, gallery: gallery, date_taken: nil) }

      before do
        upload.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
          filename: "test_image.jpg",
          content_type: "image/jpeg"
        )
      end

      it "stores exif_data but leaves date_taken nil" do
        ProcessMediaJob.perform_now(upload.id)
        upload.reload

        expect(upload.exif_data).to be_present
        expect(upload.exif_data["DateTimeOriginal"]).to be_nil
        expect(upload.date_taken).to be_nil
      end
    end
  end
end
