module Connections
  class PcpaGisConnection
    BASE_URL = 'https://egis.pinellas.gov/pcpagis/rest/services/Pcpaoorg_b/PropertyPopup/MapServer/0/query'.freeze

    def initialize
      @bbox = {
        xmin: -9209254.680251373,
        ymin: 3220258.712726869,
        xmax: -9207500.000000000,
        ymax: 3220860.000000000
      }
    end

    def fetch_properties
      response = HTTParty.get(BASE_URL, query: query_params)

      if response.success?
        data = JSON.parse(response.body)
        clean_data(data)
      else
        raise "Failed to download property data: #{response.code} - #{response.message}"
      end
    end

    private

    def query_params
      {
        f: 'json',
        geometry: @bbox.to_json,
        geometryType: 'esriGeometryEnvelope',
        spatialRel: 'esriSpatialRelIntersects',
        outFields: '*',
        inSR: 102100,
        outSR: 102100,
        where: '1=1'
      }
    end

    def clean_data(data)
      data['features'].each do |feature|
        feature['attributes'].delete('HEADER_HTML')
      end
      data
    end
  end
end
