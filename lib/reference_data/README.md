# PCPA GIS Data Reference Files

This directory contains reference data from the Pinellas County Property Appraiser (PCPA) GIS service.

## Files

- `example_house.json` - A single example house record for testing
- `raw_pcpa_gis_data.json` - Raw data downloaded from PCPA GIS service (4MB)
- `sanitized_pcpa_gis_data.json` - Cleaned data with HTML fields removed (1.5MB)

## Downloading Fresh Data

To download fresh data from the PCPA GIS service:

```bash
curl -s "https://egis.pinellas.gov/pcpagis/rest/services/Pcpaoorg_b/PropertyPopup/MapServer/0/query?f=json&geometry=%7B%22xmin%22%3A-9209254.680251373%2C%22ymin%22%3A3220258.712726869%2C%22xmax%22%3A-9207500.000000000%2C%22ymax%22%3A3220860.000000000%7D&geometryType=esriGeometryEnvelope&spatialRel=esriSpatialRelIntersects&outFields=*&inSR=102100&outSR=102100&where=1%3D1" > lib/reference_data/raw_pcpa_gis_data.json
```

## Sanitizing Data

The raw data contains many HTML-heavy fields that are not needed for data processing. To sanitize:

```bash
jq 'del(.features[].attributes.HEADER_HTML, .features[].attributes.PLAT, .features[].attributes.PROPERTY_USE, .features[].attributes.SUBDIVISION_NAME, .features[].attributes.SUBDIVISION_NAME_ID, .features[].attributes.TAX_DIST_DSCR, .features[].attributes.TOTAL_ASD_VALUE_DSP, .features[].attributes.TOTAL_JST_VALUE_DSP, .features[].attributes.TOTAL_TAXABLE_VALUE_DSP, .features[].attributes.LATEST_SALE_DSP, .features[].attributes.OWNER1_PU, .features[].attributes.OWNER2_PU)' lib/reference_data/raw_pcpa_gis_data.json > lib/reference_data/sanitized_pcpa_gis_data.json
```

## Real Data Patterns Observed

Based on the sanitized data, here are the key patterns for testing:

### Address Variations
- `"SITE_ADDR": "1st Ave N", "STR_NUM": 0` - No street number
- `"SITE_ADDR": "6555 1st Ave N", "STR_NUM": 6555` - Normal address
- `"SITE_ADDR": "213 66th St N", "STR_NUM": 213` - Different street types

### City Field Issues
- `"SITE_CITY": "St Petersburg,"` - Trailing comma
- `"SITE_CITYZIP": "St Petersburg, Fl 33710"` - Combined city/state/zip

### Owner Patterns
- Single owner: `"OWNER1": "SEAVER, ROGER", "OWNER2": null`
- Multiple owners: `"OWNER1": "OWNER1 NAME", "OWNER2": "OWNER2 NAME"`

### Missing Data
- `"STR_NUM": 0` - Zero street numbers
- `"STR_NUM": null` - Null street numbers
- `"YEAR_BUILT": null` - Missing year built
