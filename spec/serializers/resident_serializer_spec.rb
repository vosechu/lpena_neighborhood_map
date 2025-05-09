require 'rails_helper'

RSpec.describe ResidentSerializer do
  let(:resident) do
    Resident.new(
      display_name: "Jane",
      share_display_name: true,
      email: "jane@example.com",
      share_email: true,
      homepage: "https://example.com",
      skills: "gardening",
      comments: "Nice neighbor"
    )
  end

  it "includes shareable fields when privacy is enabled" do
    json = ResidentSerializer.new(resident).as_json
    expect(json[:display_name]).to eq("Jane")
    expect(json[:email]).to eq("jane@example.com")
  end

  it "does not include email if share_email is false" do
    resident.share_email = false
    json = ResidentSerializer.new(resident).as_json
    expect(json).not_to have_key(:email)
  end

  it "always includes homepage, skills, and comments" do
    json = ResidentSerializer.new(resident).as_json
    expect(json[:homepage]).to eq("https://example.com")
    expect(json[:skills]).to eq("gardening")
    expect(json[:comments]).to eq("Nice neighbor")
  end

  it "does not include display_name if share_display_name is false" do
    resident.share_display_name = false
    json = ResidentSerializer.new(resident).as_json
    expect(json).not_to have_key(:display_name)
  end

  it "does not include anything if hidden" do
    resident.hidden = true
    json = ResidentSerializer.new(resident).as_json
    expect(json).to be_empty
  end
end
