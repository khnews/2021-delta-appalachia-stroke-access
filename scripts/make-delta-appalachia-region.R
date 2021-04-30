# Make files for Mississippi Delta and Appalachia region

library(dplyr)
library(tidyr)
library(readxl)
library(sf)
library(ggplot2)

state_fips <- read.csv("data/fips-states.csv", colClasses = "character")

###########################################################################
# Clean up Excel file of regions
###########################################################################
raw <- read_excel("data-original/FIPS App_Delta.xlsx")
colnames(raw)

crosswalk <- raw
colnames(crosswalk) <- c("fips_county", "state_name", "county_name", "region")
crosswalk <- left_join(crosswalk, state_fips, by = "state_name")
crosswalk <- crosswalk %>% select(state_code, fips_county, region)

# Make two columns for regions
crosswalk %>% count(region)
crosswalk <- crosswalk %>% mutate(delta = case_when(
	region == "Appalachian" ~ 0,
	region == "Delta" | region == "App_Delta" ~ 1), 
	appalachia = case_when(
		region == "Appalachian" | region == "App_Delta" ~ 1,
		region == "Delta" ~ 0)) %>%
	select(-region) %>%
	arrange(fips_county)


###########################################################################
# Make shapefile using CBF - just for mapping, not for analysis
###########################################################################

counties <- st_read("data/shp/cb_2019_us_county_5m/cb_2019_us_county_5m.shp")

counties <- left_join(counties, crosswalk, by = c("GEOID" = "fips_county"))

# Make sure join is correct - numbers should match crosswalk
table(counties$appalachia)
table(crosswalk$appalachia)
table(counties$delta)
table(crosswalk$delta)

counties <- counties %>% 
	mutate(delta = ifelse(is.na(delta), 0, delta),
				 appalachia = ifelse(is.na(appalachia), 0, appalachia))

counties <- counties %>% 
	mutate(region = case_when(
		delta == 1 & appalachia == 1 ~ "Delta and Appalachia",
		delta == 1 & appalachia == 0 ~ "Delta",
		delta == 0 & appalachia == 1 ~ "Appalachia",
		delta == 0 & appalachia == 0 ~ "Neither"))
table(counties$region)
colnames(counties)

###########################################################################
# Files for saving
###########################################################################
# Remove territories
counties <- counties %>% filter(!(STATEFP %in% c( "60", "66", "69", "78", "72"))) %>%
	select(GEOID, STATEFP, NAME, region, delta, appalachia, geometry)

regions <- counties %>% st_drop_geometry() %>%
	rename(fips_county = GEOID, fips_state = STATEFP, county_name = NAME)
regions <- as.data.frame(regions)

write.csv(regions, "data/fips-appalachia-delta.csv", na = "", row.names = F)

# Remove AK and HI for mapping
counties <- counties %>% filter(!(STATEFP %in% c("02", "15")))

###########################################################################
# Map
###########################################################################
regionmap <- ggplot() +
	geom_sf(data = counties, color="#cccccc", size = 0.3, aes(fill = region)) +
	coord_sf(crs = st_crs(5070)) +
	scale_fill_manual(values = c("gold", "blue", "forestgreen", "white")) +
	theme_void() +
	theme(legend.title=element_blank(),
				plot.title = element_text(size = 18, color = "black"),
				plot.caption = element_text(hjust = 0, size = 12),
				legend.position = "top") +
	labs(title = "Delta")
regionmap

# Subset shapefiles
delta <- counties %>% filter(delta == 1)
plot(st_geometry(delta))
appalachia <- counties %>% filter(appalachia == 1)
plot(st_geometry(appalachia))

