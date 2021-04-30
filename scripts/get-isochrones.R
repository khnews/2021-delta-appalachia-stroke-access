# Get isochrones from the HERE API via the hereR wrapper (requires API key)

library(dplyr)
library(tidyr)
library(stringr)
library(hereR)
library(sf)
library(leaflet)

###########################################################################
# Loop through stroke centers to get isochrones

# Need to use a timer to not get rate limited
# Note: hereR version released after this code was written included
# handling for rate limiting, could refactor this code without 
# timer in the future
###########################################################################

centers <- read.csv("data/stroke-centers.csv", colClasses = c("fips_county" = "character", "zip" = "character"))

# Make SF dataset
centers_sf <- st_as_sf(centers, coords = c("longitude", "latitude")) %>% 
	st_set_crs(4326)

# Function to get isochrone for a single point with error catching
tryLocation <- function(location) {
	out <- tryCatch({
		temp <- isoline(
			poi = location,
			range = c(45 * 60, 120 * 60, 180 * 60),
			range_type = "time",
			transport_mode = "car",
			url_only = F,
			optimize = "quality",
			traffic = F,
			aggregate = F
		)
		temp <- temp %>%
			mutate(hospital_id = point_id)
		return(temp)},
		
		error = function(cond) {
			message(paste("Hospital ID failed: ", point_id))
			message(paste(cond))
			# Choose a return value in case of error
			return(NULL)},
		
		warning = function(cond) {
			message(paste("Hospital ID caused a warning:", point_id))
			message(paste(cond))
			# Choose a return value in case of warning
			return(NULL)
		})    
	return(out)
}


# Loop over points to make isochrones file
# Using a timer to avoid rate limit errors

isochrones <- NULL
error_rows <- NULL
for (i in 1:nrow(centers_sf)) {
	# Get isochrones for that point
	print(i)
	Sys.sleep(0.1)
	# Filter to ith point
	point_temp <- centers_sf %>% filter(row_number() == i)
	point_id <- point_temp$hospital_id
	
	isochrones_temp <- tryLocation(point_temp)
	
	# If the point errored out save it
	if (is.null(isochrones_temp)) {
		error_rows <- bind_rows(error_rows, point_temp)
	} else {
		isochrones <- bind_rows(isochrones, isochrones_temp)	
	}
}

###########################################################################
# Get isochrones for points that glitched in initial run
# The hereR author fixed this issue, no longer needed
# But keeping this code just in case
###########################################################################
is.null(error_rows)

if (!is.null(error_rows)) {
	isochrones2 <- NULL
	for (i in 1:nrow(error_rows)) {
		# Get isochrones for that point
		print(i)
		Sys.sleep(0.1)
		# Filter to ith point
		point_temp <- error_rows %>% filter(row_number() == i)
		point_id <- point_temp$hospital_id
		
		isochrones_temp <- tryLocation(point_temp)
		
		# If the point errored out save it
		if (is.null(isochrones_temp)) {
			print(point_id)
		} else {
			isochrones2 <- bind_rows(isochrones2, isochrones_temp)	
		}
	}
	isochrones <- bind_rows(isochrones, isochrones2)
}

###########################################################################
# Add characteristics to isochrones file, save out
###########################################################################
isochrones <- left_join(isochrones, centers, by = "hospital_id")
colnames(isochrones)

isochrones <- isochrones %>%
	mutate(drive_time = range/60) %>%
	select(-range, -departure, -arrival, -id, -rank) %>%
	select(hospital_id, drive_time, everything()) %>% 
	arrange(state, city, hospital_id, drive_time)

# Make sure number of isochrones = 3 * number of points
nrow(isochrones) == 3 * nrow(centers)

# Save out as RDS
saveRDS(isochrones, "data/isochrones.rds")
# Shapefile for QGIS only
st_write(isochrones, "data/shp/isochrones/isochrones.shp", delete_dsn = TRUE)
