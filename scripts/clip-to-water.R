# Prepare to clip block groups to water
# NOTE: shapefiles are too big for github, gitignored

# Block group data source: IPUMS NHGIS 2019 national shapefile
# https://nhgis.org/

# USGS NHD water source: https://www.usgs.gov/core-science-systems/ngp/national-hydrography/access-national-hydrography-products
# State shapefiles: http://prd-tnm.s3-website-us-west-2.amazonaws.com/?prefix=StagedProducts/Hydrography/NHD/State/HighResolution/Shape/

library(dplyr)
library(tidyr)
library(stringr)
library(sf)

state_fips <- read.csv("data/fips-states.csv", colClasses = "character")
stroke_fips <- c("01", "05", "13", "17", "21", "22", "28", "29", "36", "37", "39", "42", "45", "47", "51", "54")
stroke_states <- state_fips %>% filter(fips_state %in% stroke_fips)

###########################################################################
# National shapefile of block groups from NHGIS - 1.2 GB file
# Filter shapefile to relevant states and columns (only need to run once)
###########################################################################
bg_shp <- st_read("data-original/ipums/nhgis0003_shapefile_tl2019_us_blck_grp_2019/US_blck_grp_2019.shp")
stroke_fips <- c("01", "05", "13", "17", "21", "22", "28", "29", "36", "37", "39", "42", "45", "47", "51", "54")

colnames(bg_shp)
bg_shp <- bg_shp %>% filter(STATEFP %in% stroke_fips) %>% 
	select(GISJOIN, GEOID, STATEFP, COUNTYFP, TRACTCE, BLKGRPCE, geometry)

bg_shp <- st_make_valid(bg_shp)
bg_shp <- bg_shp %>% st_transform(4326)
bg_shp %>% st_crs()

st_write(bg_shp, "data/shp/block-groups/block-groups-stroke-states.shp", delete_dsn = TRUE)

###########################################################################
# Get water shapefiles from USGS NHD dataset
# National GDB file is massive, also isn't projecting correctly
# Try state shaepfiles instead
# http://prd-tnm.s3-website-us-west-2.amazonaws.com/?prefix=StagedProducts/Hydrography/NHD/State/HighResolution/Shape/
# These are large files, will take some minutes
# Water FCode list
# https://nhd.usgs.gov/userGuide/Robohelpfiles/NHD_User_Guide/Feature_Catalog/Hydrography_Dataset/Complete_FCode_List.htm
###########################################################################
# Turn fips into names for file downloading
nhd_directory <- "data/shp/water/NHD_State/"

# Actually doing the downloads this way failed bc of timeout, files are too big...
# Downloaded manually, then run code to unzip in nice subfolders

for (i in stroke_states$state_name) {
	formatted <- str_replace_all(i, " ", "_")
	print(formatted)
	#url_path <- paste0("https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/NHD/State/HighResolution/Shape/NHD_H_",
	#									 formatted, "_State_Shape.zip")
	save_path <- paste0(nhd_directory, "NHD_H_", formatted, "_State_Shape.zip")
	#download.file(url_path, destfile = save_path)
	dir.create(paste0(nhd_directory, formatted, "/"))
	unzip(save_path, exdir = paste0(nhd_directory, formatted, "/"))
}

###########################################################################
# Read in Waterbody shapefiles and join non-tiny features
###########################################################################
water <- NULL
for (i in stroke_states$state_name) {
	formatted <- str_replace_all(i, " ", "_")
	print(formatted)
	
	# If more than 200k features it's split into multiple files
	waterbody_files <- fs::dir_info(paste0(nhd_directory, formatted, "/Shape/"), recurse = FALSE, glob = "*.shp")%>%
		filter(type == "file" & str_detect(path, "NHDWaterbody")) %>%
		select(path)
	
	for (f in 1:nrow(waterbody_files)) {
		water_full <- st_read(waterbody_files[f,])
		water_min <- water_full %>% filter(AreaSqKm > 1)
		water <- bind_rows(water, water_min)
	}
	
}
rm(water_full, water_min)

# Remove duplicate features (this is slow)
# Features near state borders get put in both states, so this is necessary
water <- water %>% distinct(geometry, .keep_all = TRUE)
table(water$FCode)
summary(water$AreaSqKm)

water <- st_make_valid(water)

# Project
water <- water %>% st_transform(4326)
water %>% st_crs()

# Exclude swamps and marshes
water2 <- water %>% filter(FCode < 46600)

saveRDS(water, "data/shp/water/water-processed/nhd-water.rds")
st_write(water, "data/shp/water/water-processed/nhd-water.shp", delete_dsn = TRUE)

###########################################################################
# Remove water areas from block groups
# This crashed R in multiple attempts even for just one state, so did it in QGIS
###########################################################################

# Remove water from block groups (this is slow)
# bg_ms <- bg_shp %>% filter(STATEFP == "28")
# bg_ms <- st_difference(bg_ms, st_union(water))

