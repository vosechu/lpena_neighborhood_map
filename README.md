# LPENA Neighborhood Map App


## Starting

```
bin/dev
```

## Standard Rails Operations

### Start the Rails server
```
bin/rails server
```

### Open a Rails console
```
bin/rails console
```

### Reset the database (drop, create, migrate, seed)
```
bin/rails db:reset
bundle exec rails runner 'DownloadPropertyDataJob.perform_now'
rake import:legacy_residents
```

### Run the test suite (RSpec)
```
bundle exec rspec
```

### Run background jobs (Sidekiq)
```
bundle exec sidekiq
```

## Random zsh commands

Download the neighborhood data from pcpao
```
curl -G 'https://egis.pinellas.gov/pcpagis/rest/services/Pcpaoorg_b/PropertyPopup/MapServer/0/query' \
  --data-urlencode 'f=json' \
  --data-urlencode 'geometry={"xmin":-9209254.680251373,"ymin":3220258.712726869,"xmax":-9207500.000000000,"ymax":3220860.000000000,"spatialReference":{"wkid":102100}}' \
  --data-urlencode 'geometryType=esriGeometryEnvelope' \
  --data-urlencode 'spatialRel=esriSpatialRelIntersects' \
  --data-urlencode 'outFields=*' \
  --data-urlencode 'inSR=102100' \
  --data-urlencode 'outSR=102100' \
  --data-urlencode 'where=1=1' \
  --output bbox_response.json
```

Coordinate data:
```
upper left: "x":-9209242.63817138,"y":3220872.310199216
upper right: "x":-9207958.604332186,"y":3220863.1754518156
lower left: "x":-9209249.057687428,"y":3220258.7145672343
lower right: "x":-9207958.42704904,"y":3220262.2788915504
```

Strip out HTML from the responses
```
jq 'del(.features[].attributes.HEADER_HTML)' bbox_response.json > cleaned.json
```

Extract only the features array
```
jq '{features: .features}' cleaned.json > houses.json
```

Read only the addresses and owners
```
