require "rails_helper"

RSpec.describe ApiKey, type: :model do
  describe "validations" do
    subject { build(:api_key) }

    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:scope).in_array(%w[admin read_only]) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "key generation" do
    it "generates a key on create" do
      api_key = build(:api_key, key: nil)
      api_key.valid?
      expect(api_key.key).to start_with("mc_")
      expect(api_key.key.length).to eq(67) # mc_ (3) + 64 hex chars
    end

    it "does not override existing key" do
      api_key = build(:api_key, key: "mc_existing123")
      api_key.valid?
      expect(api_key.key).to eq("mc_existing123")
    end
  end

  describe ".authenticate" do
    let!(:api_key) { create(:api_key) }

    it "returns the key when valid" do
      result = described_class.authenticate(api_key.key)
      expect(result).to eq(api_key)
    end

    it "returns nil for invalid key" do
      result = described_class.authenticate("invalid_key")
      expect(result).to be_nil
    end

    it "returns nil for blank token" do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
    end

    it "updates last_used_at" do
      expect { described_class.authenticate(api_key.key) }
        .to change { api_key.reload.last_used_at }
    end

    context "with expired key" do
      let!(:api_key) { create(:api_key, :expired) }

      it "returns nil" do
        result = described_class.authenticate(api_key.key)
        expect(result).to be_nil
      end
    end

    context "with revoked key" do
      let!(:api_key) { create(:api_key, :revoked) }

      it "returns nil" do
        result = described_class.authenticate(api_key.key)
        expect(result).to be_nil
      end
    end
  end

  describe "#active?" do
    it "returns true for active key" do
      api_key = build(:api_key)
      expect(api_key.active?).to be true
    end

    it "returns false for expired key" do
      api_key = build(:api_key, :expired)
      expect(api_key.active?).to be false
    end

    it "returns false for revoked key" do
      api_key = build(:api_key, :revoked)
      expect(api_key.active?).to be false
    end
  end

  describe "#revoke!" do
    let(:api_key) { create(:api_key) }

    it "sets revoked_at" do
      expect { api_key.revoke! }
        .to change { api_key.revoked? }.from(false).to(true)
    end
  end
end
