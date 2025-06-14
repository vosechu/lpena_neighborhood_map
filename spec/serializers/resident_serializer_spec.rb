require 'rails_helper'

RSpec.describe ResidentSerializer do
  let(:resident) do
    Resident.new(
      display_name: "Jane",
      hide_display_name: false,
      email: "jane@example.com",
      hide_email: false,
      homepage: "https://example.com",
      skills: "gardening",
      comments: "Nice neighbor"
    )
  end

  it "includes fields when not hidden" do
    json = ResidentSerializer.new(resident).as_json
    expect(json[:display_name]).to eq("Jane")
    expect(json[:email]).to eq("jane@example.com")
  end

  it "does not include email if hide_email is true" do
    resident.hide_email = true
    json = ResidentSerializer.new(resident).as_json
    expect(json[:email]).to eq('(hidden by user)')
  end

  it "always includes homepage, skills, and comments" do
    json = ResidentSerializer.new(resident).as_json
    expect(json[:homepage]).to eq("https://example.com")
    expect(json[:skills]).to eq("gardening")
    expect(json[:comments]).to eq("Nice neighbor")
  end

  it "shows '(hidden by user)' for display_name if hide_display_name is true" do
    resident.hide_display_name = true
    json = ResidentSerializer.new(resident).as_json
    expect(json[:display_name]).to eq('(hidden by user)')
  end

  it "does not include anything if hidden" do
    resident.hidden = true
    json = ResidentSerializer.new(resident).as_json
    expect(json).to be_empty
  end

  describe '#as_json' do
    let(:resident) { build_stubbed(:resident, hidden: false, first_seen_at: Time.zone.now) }

    it 'includes hidden state and first_seen_at metadata' do
      json = described_class.new(resident).as_json
      expect(json).to include(
        hidden: false,
        first_seen_at: resident.first_seen_at
      )
    end
  end
end
