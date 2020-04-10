library(tidyverse)
source("R/functions.R")

country_list <- get_country_list()

country_dt <- country_list %>%
  mutate(overall_data = map(url, get_national_data),
         locality_data = map(url, get_subnational_data))

region_list <- get_region_list()

region_dt <- region_list %>%
  mutate(overall_data = map(url, get_region_data),
         locality_data = map(url, get_subregion_data))

full_dt <- country_dt %>%
  bind_rows(region_dt)

countries_overall <- map_dfr(full_dt$overall_data, bind_rows)
locality_overall <- map_dfr(full_dt$locality_data, bind_rows) %>%
  filter(!(country == "US" & is.na(region)))

all_data_long <- countries_overall %>%
  bind_rows(locality_overall) %>%
  mutate(country_name = countrycode::countrycode(country, "iso2c", "country.name")) %>%
  select(date, country, country_name, region, location, entity, value)

all_data_wide <- all_data_long %>% 
  pivot_wider(names_from = entity, values_from = value)

write_excel_csv(country_list, "data/processed_countries.csv", append = TRUE)
write_excel_csv(region_list, "data/processed_regions.csv", append = TRUE)

outdate <- paste0(unique(all_data_wide$date), collapse = "_")

write_excel_csv(all_data_long, 
                file.path("data", 
                          paste(outdate, "alldata_long.csv", sep = "_")))
write_excel_csv(all_data_wide,
                file.path("data", 
                          paste(outdate, "alldata_wide.csv", sep = "_")))
