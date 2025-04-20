require "rails_helper"

RSpec.describe Connections::PcpaGisConnection do
  let(:connection) { described_class.new }
  let(:mock_response) do
    {
      "features" => [
        {
          "attributes" => {
            "HEADER_HTML" => "<div>Some HTML</div>",
            "PROPERTY_ID" => "123",
            "ADDRESS" => "123 Main St"
          }
        }
      ]
    }
  end

  describe "#fetch_properties" do
    context "when the request is successful" do
      let(:response) { HTTParty.get("http://example.com") }

      before do
        allow(HTTParty).to receive(:get).and_return(response)
        allow(response).to receive(:success?).and_return(true)
        allow(response).to receive(:body).and_return(mock_response.to_json)
        allow(response).to receive(:code).and_call_original
        allow(response).to receive(:message).and_call_original
      end

      it "makes a request to the correct URL with correct parameters" do
        connection.fetch_properties

        expect(HTTParty).to have_received(:get).with(
          described_class::BASE_URL,
          query: connection.send(:query_params)
        )
      end

      it "returns cleaned data" do
        result = connection.fetch_properties

        expect(result["features"].size).to eq(1)
        expect(result["features"].first["attributes"]["HEADER_HTML"]).to be_nil
      end
    end

    context "when the request fails" do
      let(:response) { HTTParty.get("http://example.com") }

      before do
        allow(HTTParty).to receive(:get).and_return(response)
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:code).and_return(500)
        allow(response).to receive(:message).and_return("Internal Server Error")
        allow(response).to receive(:body).and_call_original
      end

      it "raises an error" do
        expect { connection.fetch_properties }.to raise_error(RuntimeError)
      end
    end
  end

  describe "#clean_data" do
    let(:data) do
      {
        "features" => [
          { "attributes" => { "HEADER_HTML" => "html1", "other" => "value1" } },
          { "attributes" => { "HEADER_HTML" => "html2", "other" => "value2" } }
        ]
      }
    end

    it "removes HEADER_HTML from all features" do
      cleaned_data = connection.send(:clean_data, data)

      expect(cleaned_data["features"][0]["attributes"]["HEADER_HTML"]).to be_nil
      expect(cleaned_data["features"][1]["attributes"]["HEADER_HTML"]).to be_nil
      expect(cleaned_data["features"][0]["attributes"]["other"]).to eq("value1")
      expect(cleaned_data["features"][1]["attributes"]["other"]).to eq("value2")
    end
  end

  describe "#query_params" do
    it "returns the correct parameters" do
      params = connection.send(:query_params)

      expect(params[:f]).to eq("json")
      expect(params[:geometryType]).to eq("esriGeometryEnvelope")
      expect(params[:spatialRel]).to eq("esriSpatialRelIntersects")
      expect(params[:outFields]).to eq("*")
      expect(params[:inSR]).to eq(102100)
      expect(params[:outSR]).to eq(102100)
      expect(params[:where]).to eq("1=1")

      geometry = JSON.parse(params[:geometry])
      expect(geometry["xmin"]).to eq(-9209254.680251373)
      expect(geometry["ymin"]).to eq(3220258.712726869)
      expect(geometry["xmax"]).to eq(-9207500.000000000)
      expect(geometry["ymax"]).to eq(3220860.000000000)
    end
  end
end
