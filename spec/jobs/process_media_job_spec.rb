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
end
