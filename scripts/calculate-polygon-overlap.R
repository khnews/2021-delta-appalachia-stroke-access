# Calculate which Census block groups are in, out, or on the border of drive time isochrones
# If on the border, split proportionally based on percent overlap

library(sf)
library(dplyr)
library(tidyr)
library(janitor)
library(ggplot2)
library(leaflet)

###########################################################################
# Prep data files for overlap calculation
###########################################################################
isochrones <- readRDS("data/isochrones.rds")
bg_shp <- st_read("data/shp/block-groups/block-groups-water-removed.shp")

# Make files planar and valid, needed for sf computation
# https://epsg.io/2163
bg_shp <- bg_shp %>% st_transform(2163)
bg_shp %>% st_crs()
bg_shp <- st_make_valid(bg_shp)

isochrones <- isochrones %>% st_transform(2163)
isochrones %>% st_crs()
isochrones <- st_make_valid(isochrones)

# 45 minute isochrones - combine into one feature
isochrones_1 <- isochrones %>% filter(drive_time == 45)
isochrones_joined_1 <- st_union(isochrones_1)
isochrones_joined_1 <- st_sf(iso_id = 1, geometry = isochrones_joined_1)

# 45 minutes just comprehensive and thrombectomy
isochrones_1_c <- isochrones %>% 
	filter(drive_time == 45 & certification_type %in% c("Comprehensive", "Thrombectomy"))
isochrones_joined_1_c <- st_union(isochrones_1_c)
isochrones_joined_1_c <- st_sf(iso_id = 1, geometry = isochrones_joined_1_c)

###########################################################################
# Quick map for reference and to make sure isochrone join is working correctly
# Need to project back to lat/lng for mapping
###########################################################################
# All centers
isochrones_map <- isochrones_joined_1 %>% st_transform(4326)
leaflet() %>% 	
	setView(
		-86.7667415602124, 36.188530779087586,
		zoom = 5) %>%
	addProviderTiles("CartoDB.Voyager") %>% 
	addPolygons(
		data = isochrones_map, 
		fillColor = "forestgreen",
		fillOpacity = 0.5, 
		stroke = FALSE)

# Just comprehensive and thrombectomy
isochrones_map_c <- isochrones_joined_1_c %>% st_transform(4326)
leaflet() %>% 	
	setView(
		-86.7667415602124, 36.188530779087586,
		zoom = 5) %>%
	addProviderTiles("CartoDB.Voyager") %>% 
	addPolygons(
		data = isochrones_map_c, 
		fillColor = "forestgreen",
		fillOpacity = 0.5, 
		stroke = FALSE)

###########################################################################
# Calculate overlap between block groups and isochrones
###########################################################################
# Calculate area for all block groups
bg_shp <- mutate(bg_shp, bg_area = st_area(bg_shp))

# Calculate intersection - will take many minutes
calculateIntersection <- function(isochrones_file) {
	dt <- st_intersection(bg_shp, isochrones_file) %>% 
		mutate(intersect_area = st_area(.)) %>%
		select(GEOID, intersect_area) %>% 
		st_drop_geometry()
	return(dt)
}
intersect_all <- calculateIntersection(isochrones_joined_1)
intersect_c <- calculateIntersection(isochrones_joined_1_c)

intersect_all <- intersect_all %>% 
	rename(intersect_area_all = intersect_area)
intersect_c <- intersect_c %>% 
	rename(intersect_area_c = intersect_area)

intersect_pct <- full_join(intersect_all, intersect_c, by = "GEOID")
	
# Merge intersection area by geoid
bg_shp <- left_join(bg_shp, intersect_pct, by = "GEOID")

# Calculate overlap percent between block groups and isochrones
bg_shp <- bg_shp %>% 
	mutate(intersect_area_all = ifelse(is.na(intersect_area_all), 0, intersect_area_all),
				 intersect_area_c = ifelse(is.na(intersect_area_c), 0, intersect_area_c),
		overlap_all = as.numeric(intersect_area_all/bg_area),
		overlap_c = as.numeric(intersect_area_c/bg_area))
summary(bg_shp$overlap_all)
summary(bg_shp$overlap_c)

# Save out files - big! Don't save in git
saveRDS(bg_shp, "data/block-group-isochrone-overlap.rds")

# Save out just overlap info
colnames(bg_shp)
bg_overlap <- bg_shp %>% select(geoid = GEOID, overlap_all, overlap_c) %>%
	st_drop_geometry()
bg_overlap <- as.data.frame(bg_overlap)
write.csv(bg_overlap, "data/block-group-isochrone-overlap.csv", na = "", row.names = F)

###########################################################################
# Plot data to make sure it's working right
###########################################################################
# Don't do this on all states it's too much for R to render
bg_ms <- bg_shp %>% filter(STATEFP == "01") %>% 
	st_transform(4326)

pal <- colorNumeric("Purples", domain = bg_ms$overlap_all)

# All stroke centers
leaflet() %>%
	addProviderTiles("CartoDB.Positron") %>%
	setView(
		-86.7667415602124, 36.188530779087586,
		zoom = 5) %>%
	addPolygons(
		data = bg_ms , 
		fillColor = ~pal(bg_ms$overlap_all), 
		fillOpacity = 1, 
		weight = 0.5, 
		smoothFactor = 0.2, 
		stroke = TRUE,
		color = "black") %>%
	# Isochrone outlines
	addPolygons(
		data = isochrones_map, 
		fill = TRUE,
		stroke = TRUE,
		fillColor = "yellow",
		fillOpacity = 0.05,
		color = "red",
		weight = 1.5) %>%
	addLegend(pal = pal, 
						values = bg_ms$overlap_all, 
						position = "bottomright", 
						title = "Intersection with isochrones",
						opacity = 1)

# Just comprehensive/thrombectomy
leaflet() %>%
	addProviderTiles("CartoDB.Positron") %>%
	setView(
		-86.7667415602124, 36.188530779087586,
		zoom = 5) %>%
	addPolygons(
		data = bg_ms , 
		fillColor = ~pal(bg_ms$overlap_c), 
		fillOpacity = 1, 
		weight = 0.5, 
		smoothFactor = 0.2, 
		stroke = TRUE,
		color = "black") %>%
	# Isochrone outlines
	addPolygons(
		data = isochrones_map_c, 
		fill = TRUE,
		stroke = TRUE,
		fillColor = "yellow",
		fillOpacity = 0.05,
		color = "red",
		weight = 1.5) %>%
	addLegend(pal = pal, 
						values = bg_ms$overlap_c, 
						position = "bottomright", 
						title = "Intersection with isochrones",
						opacity = 1)
