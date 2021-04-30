# Get Census demographic data
# This requires a Census API key, instructions:
# https://www.hrecht.com/censusapi/index.html#api-key-setup

library(censusapi)
library(tidyr)
library(dplyr)

###########################################################################
# Get Census data by block group in relevant states
# Construct: for=block group:*&in=state:01&in=county:*&in=tract:*
###########################################################################

acs_race_vars <- listCensusMetadata(name = "acs/acs5", vintage = 2019, group = "B02001")
acs_raceeth_vars <- listCensusMetadata(name = "acs/acs5", vintage = 2019, group = "B03002")

# Loop over states for block group data
stroke_fips <- c("01", "05", "13", "17", "21", "22", "28", "29", "36", "37", "39", "42", "45", "47", "51", "54")
acs_bg <- NULL
for (f in stroke_fips) {
	print(f)
	stateget <- paste("state:", f, "&in=county:*&in=tract:*", sep="")
	temp <- getCensus(
		name = "acs/acs5",
		vintage = 2019,
		vars = c("NAME", "B01001_001E",
						 "B02001_001E", "B02001_002E", "B02001_003E", "B02001_004E", "B02001_005E", "B02001_006E", 
						 "B03003_001E", "B03003_002E", "B03003_003E"),
						 # "B03002_001E", "B03002_003E", "B03002_004E", "B03002_005E", "B03002_006E", "B03002_007E", "B03002_012E"),
		region = "block group:*",
		regionin = stateget)
	
	acs_bg <- bind_rows(acs_bg, temp)
}

demographics_bg <- acs_bg %>% 
	rename(name = NAME,
				 population = B01001_001E,
				 # Separate race and ethnicity
				 race_universe_number = B02001_001E,
				 race_white_number = B02001_002E,
				 race_black_number = B02001_003E,
				 race_aian_number = B02001_004E,
				 race_asian_number = B02001_005E,
				 race_nhpi_number = B02001_006E,
				 eth_universe_number = B03003_001E,
				 eth_nonhispanic_number = B03003_002E,
				 eth_hispanic_number = B03003_003E,
				 
				 # Combo race and ethnicity
				 # raceeth_universe_number = B03002_001E,
				 # raceeth_white_number = B03002_003E,
				 # raceeth_black_number = B03002_004E,
				 # raceeth_aian_number = B03002_005E,
				 # raceeth_asian_number = B03002_006E,
				 # raceeth_nhpi_number = B03002_007E,
				 # raceeth_hispanic_number = B03002_012E,
				 fips_state = state) %>%
	mutate(
		fips_county = paste0(fips_state, county),
		fips_tract = paste0(fips_state, county, tract),
		fips_block_group = paste0(fips_state, county, tract, block_group),
		
		# Separate race and ethnicity
		race_other_number = race_universe_number - race_white_number - race_black_number - race_aian_number - race_asian_number - race_nhpi_number,
		race_white_pct = race_white_number/race_universe_number,
		race_black_pct = race_black_number/race_universe_number,
		race_aian_pct = race_aian_number/race_universe_number,
		race_asian_pct = race_asian_number/race_universe_number,
		race_nhpi_pct = race_nhpi_number/race_universe_number,
		race_other_pct = race_other_number/race_universe_number,
		eth_nonhispanic_pct = eth_nonhispanic_number/eth_universe_number,
		eth_hispanic_pct = eth_hispanic_number/eth_universe_number,
		
		# Combo race and ethnicity
		# raceeth_other_number = raceeth_universe_number - raceeth_white_number - raceeth_black_number - raceeth_aian_number - raceeth_asian_number - raceeth_nhpi_number - raceeth_hispanic_number,
		# raceeth_white_pct = raceeth_white_number/raceeth_universe_number,
		# raceeth_black_pct = raceeth_black_number/raceeth_universe_number,
		# raceeth_aian_pct = raceeth_aian_number/raceeth_universe_number,
		# raceeth_asian_pct = raceeth_asian_number/raceeth_universe_number,
		# raceeth_nhpi_pct = raceeth_nhpi_number/raceeth_universe_number,
		# raceeth_hispanic_pct = eth_hispanic_number/eth_universe_number,
		# raceeth_other_pct = raceeth_other_number/raceeth_universe_number
	) %>%
	arrange(fips_state) %>%
	select(fips_block_group, fips_state, fips_county, fips_tract, name, population, everything()) %>%
	select(-starts_with("B"), -contains("universe"), -county, -tract, -block_group)
colnames(demographics_bg)

summary(demographics_bg$population)
demographics_bg <- demographics_bg %>% arrange(fips_block_group)
write.csv(demographics_bg, "data/acs-block-group-demographics.csv", na = "", row.names = F)
