# Calculate number and pct of people within drive time polygons and outside
# For bordering polygons, asign population proportionally using calculated overlap field

library(dplyr)
library(tidyr)

bg_overlap <- read.csv("data/block-group-isochrone-overlap.csv", colClasses = c("geoid" = "character"))
demographics <- read.csv("data/acs-block-group-demographics.csv", 
												 colClasses = c("fips_block_group" = "character", "fips_state" = "character", 
												 							 "fips_county" = "character", "fips_tract" = "character"))
regions <- read.csv("data/fips-appalachia-delta.csv", colClasses = c("fips_county" = "character"))
state_fips <- read.csv("data/fips-states.csv", colClasses = "character")
state_fips <- state_fips %>% select(fips_state, state_code)

###########################################################################
# Join files
###########################################################################
bg_full <- full_join(demographics, bg_overlap, by = c("fips_block_group" = "geoid"))

# nonmatch 
nonmatch <- bg_full %>% filter(is.na(fips_state) | is.na(overlap_all) | is.na(overlap_c))
summary(nonmatch$population)

# A couple blocks have nonzero population, investigate further
nonmatch_check <- nonmatch %>% filter(population > 0)

# Actual join to use
bg <- left_join(bg_overlap, demographics, by = c("geoid" = "fips_block_group")) %>%
	left_join(., state_fips, by = "fips_state")

colnames(bg)
bg <- bg %>% select(fips_state, state_code, geoid, everything())

###########################################################################
# Calculate population in/out of isochrones by state
###########################################################################
summary(bg$overlap)
state_sums <- bg %>% select(state_code, geoid, overlap_all, overlap_c, population, race_black_number, race_white_number) %>%
	pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
	group_by(state_code, certification_type) %>%
	summarize(within_total = sum(population * overlap),
						population_total = sum(population),
						within_black = sum(race_black_number * overlap),
						population_black = sum(race_black_number),
						within_white = sum(race_white_number * overlap),
						population_white = sum(race_white_number)) %>%
	mutate(within_total_pct = within_total/population_total,
				 within_black_pct = within_black/population_black,
				 within_white_pct = within_white/population_white) %>%
	select(state_code, certification_type, ends_with("_pct"), everything()) %>%
	ungroup() %>%
	mutate(certification_type = case_when(
		certification_type == "overlap_all" ~ "any",
		certification_type == "overlap_c" ~ "compthromb"
	))


# Make table for use in story, charts
# Ridiculous pivoting but it works
state_table <- state_sums %>% select(state_code, certification_type, 
																		 within_total_pct, within_black_pct, within_white_pct) %>%
	pivot_wider(names_from = certification_type, values_from = starts_with("within"), names_prefix = "type_") %>%
	pivot_longer(-state_code, names_sep = "_pct_type_", 
							 names_to = c("race", "certification_type"), values_to = "within_pct") %>%
	pivot_wider(names_from = certification_type, values_from = within_pct) %>%
	rename(within_any = any, within_compthromb = compthromb) %>%
	mutate(within_none = 1 - within_any,
				 within_primaryacute_only = within_any - within_compthromb) %>%
	select(state_code, race, within_none, within_primaryacute_only, within_compthromb, within_any) %>%
	mutate(race = case_when(race == "within_total" ~ "Total",
													race == "within_black" ~ "Black",
													race == "within_white" ~ "White"))

write.csv(state_table, "data/state-stroke-access.csv", na = "", row.names = F)

# Chart data
state_chart <- state_table %>% filter(race == "Total" & state_code != "NY") %>%
	arrange(within_any)

# Add names
state_names <- read.csv("data/fips-states.csv", colClasses = "character")
state_names <- state_names %>% select(state_name, state_code)
state_chart <- left_join(state_chart, state_names, by = "state_code")
state_chart <- state_chart %>% select(state_name, within_none, within_primaryacute_only, within_compthromb)

write.csv(state_chart, "data/state-stroke-chart.csv", na = "", row.names = F)

###########################################################################
# Calculate population in/out of isochrones by region
###########################################################################
regions_min <- regions %>% select(fips_county, delta, appalachia)
bg <- left_join(bg, regions_min, by = "fips_county")

delta <- bg %>% filter(delta == 1 )%>%
	select(geoid, overlap_all, overlap_c, population, race_black_number, race_white_number) %>%
	pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
	group_by(certification_type) %>%
	summarize(within_total = sum(population * overlap),
						population_total = sum(population),
						within_black = sum(race_black_number * overlap),
						population_black = sum(race_black_number),
						within_white = sum(race_white_number * overlap),
						population_white = sum(race_white_number)) %>%
	mutate(within_total_pct = within_total/population_total,
				 within_black_pct = within_black/population_black,
				 within_white_pct = within_white/population_white) %>%
	mutate(region = "Mississippi Delta") %>%
	select(region, certification_type, ends_with("_pct"), everything()) %>%
	ungroup() %>%
	mutate(certification_type = case_when(
		certification_type == "overlap_all" ~ "any",
		certification_type == "overlap_c" ~ "compthromb"
	))

appalachia <- bg %>% filter(appalachia == 1 )%>%
	select(geoid, overlap_all, overlap_c, population, race_black_number, race_white_number) %>%
	pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
	group_by(certification_type) %>%
	summarize(within_total = sum(population * overlap),
						population_total = sum(population),
						within_black = sum(race_black_number * overlap),
						population_black = sum(race_black_number),
						within_white = sum(race_white_number * overlap),
						population_white = sum(race_white_number)) %>%
	mutate(within_total_pct = within_total/population_total,
				 within_black_pct = within_black/population_black,
				 within_white_pct = within_white/population_white) %>%
	mutate(region = "Appalachia") %>%
	select(region, certification_type, ends_with("_pct"), everything()) %>%
	ungroup() %>%
	mutate(certification_type = case_when(
		certification_type == "overlap_all" ~ "any",
		certification_type == "overlap_c" ~ "compthromb"
	))

region_sums <- bind_rows(appalachia, delta)

# Make table for use in story, charts
# Ridiculous pivoting but it works
region_table <- region_sums %>% select(region, certification_type, 
																		 within_total_pct, within_black_pct, within_white_pct) %>%
	pivot_wider(names_from = certification_type, values_from = starts_with("within"), names_prefix = "type_") %>%
	pivot_longer(-region, names_sep = "_pct_type_", 
							 names_to = c("race", "certification_type"), values_to = "within_pct") %>%
	pivot_wider(names_from = certification_type, values_from = within_pct) %>%
	rename(within_any = any, within_compthromb = compthromb) %>%
	mutate(within_none = 1 - within_any,
				 within_primaryacute_only = within_any - within_compthromb) %>%
	select(region, race, within_none, within_primaryacute_only, within_compthromb, within_any) %>%
	mutate(race = case_when(race == "within_total" ~ "Total",
													race == "within_black" ~ "Black",
													race == "within_white" ~ "White"))
write.csv(region_table, "data/appalachia-delta-stroke-access.csv", na = "", row.names = F)
