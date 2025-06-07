require 'rails_helper'

RSpec.describe HouseSerializer do
  let(:house) { House.new(id: 1, street_number: 123, street_name: "Main St", city: "Townsville", state: "TS", zip: "12345", latitude: 1.23, longitude: 4.56, boundary_geometry: nil, created_at: Time.now, updated_at: Time.now) }
  let(:resident) { Resident.new(display_name: "Jane", hide_display_name: false, homepage: "https://example.com", skills: "gardening", comments: "Nice neighbor") }

  before do
    allow(house).to receive(:residents).and_return([ resident ])
  end

  it "includes all expected house fields" do
    json = HouseSerializer.new(house).as_json
    expect(json).to include(:id, :street_number, :street_name, :city, :state, :zip, :latitude, :longitude, :boundary_geometry, :created_at, :updated_at, :residents)
  end

  it "serializes residents using ResidentSerializer" do
    json = HouseSerializer.new(house).as_json
    expect(json[:residents]).to be_an(Array)
    expect(json[:residents].first[:display_name]).to eq("Jane")
    expect(json[:residents].first[:homepage]).to eq("https://example.com")
    expect(json[:residents].first[:skills]).to eq("gardening")
    expect(json[:residents].first[:comments]).to eq("Nice neighbor")
  end
end
