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

## Monitoring

### Check for errors in New Relic
```bash
newrelic nrql query -q "SELECT count(*) FROM TransactionError SINCE 30 DAYS AGO"
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

## Connection to production

### Downloading the values from prod

```
railway login
railway link # select lpena_neighborhood_map and then web
railway shell
env | sort > .env.production
# Now sift through these and pull out the interesting values like the DATABASE_URL and REDIS_URL
```

### Connecting to prod

```
dotenv -f .env.production bin/rails import:legacy_residents
# OR
dotenv -f .env.production bin/rails console
```

## Downloading db backups

Download
```
dotenv -f .env.production pg_dump -h trolley.proxy.rlwy.net -U postgres -p 34534 -d railway > production_backup_full.sql
dotenv -f .env.production pg_dump -h trolley.proxy.rlwy.net -U postgres -p 34534 -d railway --data-only > production_backup_data_only.sql
```

Restore TO PROD
```
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 dotenv -f .env.production rails db:drop db:create
dotenv -f .env.production psql -h trolley.proxy.rlwy.net -U postgres -p 34534 -d railway < production_backup_full.sql
```

Restoring prod backups to local env
```
RAILS_ENV=development bin/rails db:drop db:create
psql -d lpena_neighborhood_map_development < production_backup_full.sql
# This will ensure that later runs don't think that this is a prod database.
# See https://github.com/rails/rails/issues/34041#issuecomment-426817146
RAILS_ENV=development bin/rails db:environment:set
```

## Activating an email for a resident that somehow didn't get a user

If the resident already has a user, you'll need to remove the email first and then update it again to trigger the welcome email:

```ruby
resident_id = 844
resident = Resident.find(resident_id)
ResidentMailer.welcome_new_user(resident, resident.user).deliver_later
```
