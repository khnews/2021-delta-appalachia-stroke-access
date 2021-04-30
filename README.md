# Mississippi Delta and Appalachia Stroke Access Analysis

This repository contains data used in "In Appalachia and the Mississippi Delta, Millions Face Long Drives to Stroke Care", a series examining access to stroke care in the Mississippi Delta and Appalachia. The project is a collaboration between KHN and InvestigateTV.

Read the [methodology](https://khn.org/news/article/methodology-how-we-reported-on-rural-stroke-care/).

## About the analysis
Preparation work, can be run in any order:
* [scripts/get-census-data.R](scripts/get-census-data.R) gets block group population data
* [scripts/clip-to-water.R](scripts/clip-to-water.R) makes water shapefile for clipping block groups
* [scripts/make-delta-appalachia-region.R](scripts/make-delta-appalachia-region.R) makes a CSV of county FIPS codes with Delta and Appalachia variables

Analysis:
1. [scripts/get-isochrones.R](scripts/get-isochrones.R) retrieves drive time isochrones
2. [scripts/calculate-polygon-overlap.R](scripts/calculate-polygon-overlap.R) calculates overlap between block groups and isochrones
3. [scripts/calculate-polygon-demographics.R](scripts/calculate-polygon-demographics.R) calculates population within a 45-minute drive to stroke centers and farther than a 45-minute drive

### Getting stroke center locations
Getting stroke center locations was a messy process that involved a lot of manual matching and spreadsheets ― it is not fully code-reproducible and not included here. The locations used in this project include stroke centers certified by the [Joint Commission](https://www.qualitycheck.org/data-download/), [DNV](https://www.dnvglhealthcare.com/hospitals?search_type=and&q=&c=&c=&c=&c=&prSubmit=Search) and [HFAP](https://www.hfap.org/search-facilities/), retrieved in March 2021.

We matched the stroke centers in states in or adjacent to the Mississippi Delta and Appalachia regions to the [HIFLD hospitals dataset](https://hifld-geoplatform.opendata.arcgis.com/datasets/hospitals/data), which includes hospital names, addresses, lat/lng and more. In most cases, names provided by the stroke certifiers did not match exactly to the names in the HIFLD dataset. We first matched centers by name and ZIP code, and then by ZIP code alone to verify, and then completed the remainder by hand. It's possible that a small number of matches might be incorrect, matching to a different hospital in the same area. For our purposes of generating drive time isochrones, this will have negligible effect.

The resulting stroke centers data file is saved in [data/stroke-centers.csv](data/stroke-centers.csv).

### Getting drive time isochrones
The drive time isochrones are retrieved in [scripts/get-isochrones.R](scripts/get-isochrones.R) using the [hereR package](https://munterfinger.github.io/hereR/) wrapper for the [HERE API](https://developer.here.com/documentation/isoline-routing-api/8.4.0/api-reference-swagger.html).

The HERE API requires a developer key. This project does not exceed the "Freemium" price tier.

We got 45-minute, two-hour and three-hour drive times for each stroke center. The HERE API rate limits when too many requests are made too quickly, so it runs center by center with a small pause between each one. This takes some time to complete.

### Making shapefiles
Note: the shapefile folder (data/shp/) is not included here due to large file sizes.

The block group national shapefile is from the 2019 ACS via [NHGIS](https://www.nhgis.org/). This file is clipped to shorelines but not interior bodies of water like lakes.

[scripts/clip-to-water.R](scripts/clip-to-water.R) takes this NHGIS block group shapefile and filters it to relevant states. Then it gets water shapefiles from the [USGS NHD files](https://www.usgs.gov/core-science-systems/ngp/national-hydrography/access-national-hydrography-products) for relevant states. The script filters to water body features (e.g. lakes and ponds) that are over a certain size, joins and dedupes the files, and creates a single water shapefile. The block group shapefile is then clipped to water in QGIS using the vector overlay `difference` function.

### Calculating population in driving distance

To calculate how many people live within and outside of the drive time isochrones, we identified the percent of each Census block group that lies within the isochrones. This is calculated in [scripts/calculate-polygon-overlap.R](scripts/calculate-polygon-overlap.R).

Block group population data is from the 2015-2019 ACS, retrieved in [scripts/get-census-data.R](scripts/get-census-data.R). This uses the [censusapi](https://github.com/hrecht/censusapi) R package, which requires a free Census API key.

The population that lives within driving distance of stroke centers is then calculated in [scripts/calculate-polygon-demographics.R](scripts/calculate-polygon-demographics.R). This combines the CSV of polygon overlaps with Census population data to calculate overall and by race how many people live within 45 minutes of stroke centers.

The resulting files used in the story and graphics are [data/state-stroke-chart.csv](data/state-stroke-chart.csv) and [data/appalachia-delta-stroke-access.csv](data/appalachia-delta-stroke-access.csv).

## Attribution
Findings should be cited as: “According to a KHN and InvestigateTV analysis.” The data should be credited to KHN and InvestigateTV.
