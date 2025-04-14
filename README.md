# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version
* System dependencies
* Configuration
* Database creation
* Database initialization
* How to run the test suite
* Services (job queues, cache servers, search engines, etc.)
* Deployment instructions
* ...

## Starting

```
bin/dev
```

## Random zsh commands

Download the neighborhood data from pcpao
```
curl -G 'https://egis.pinellas.gov/pcpagis/rest/services/Pcpaoorg_b/PropertyPopup/MapServer/0/query' \
  --data-urlencode 'f=json' \
  --data-urlencode 'geometry={"xmin":-9209254.680251373,"ymin":3220258.712726869,"xmax":-9207550.000000000,"ymax":3220854.000000000,"spatialReference":{"wkid":102100}}' \
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
jq '.features' cleaned.json > houses.json
```

Read only the addresses and owners
```
