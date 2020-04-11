library(tidyverse)
source("R/functions.R")

last_update <- read_lines("LASTUPDATE_UTC.txt") %>%
  lubridate::as_datetime()

live_update <- get_update_time()

if (live_update == last_update) {
  
  log_msg <- "  No update"
  
  data_update <- FALSE
  
} else {
  country_list <- get_country_list()
  
  this_outdate <- paste0(unique(country_list$date))
  max_past_outdate <- suppressMessages(
    read_csv("data/processed_countries.csv") %>%
      pull(date) %>%
      max()
  )
  
  existing_report_update <- FALSE
  
  if (this_outdate == max_past_outdate) {
    warning("Report update date has changed, date of reports has not changed")
    existing_report_update <- TRUE
  }
  
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
  
  write_lines(live_update, "LASTUPDATE_UTC.txt")
  
  if (existing_report_update) {
    
    time_file <- paste0(format(live_update, "%y%m%dT%H%M%SZ"), ".csv") 
    
    write_excel_csv(country_list, 
                    file.path("data", 
                              paste("processed_countries", 
                                    time_file, 
                                    sep = "_")))
    write_excel_csv(region_list,
                    file.path("data", 
                              paste("processed_regions", 
                                    time_file, 
                                    sep = "_")))
    
    write_excel_csv(all_data_long, 
                    file.path("data", 
                              paste(this_outdate, 
                                    "alldata_long",
                                    time_file,
                                    sep = "_")))
    
    write_excel_csv(all_data_wide,
                    file.path("data", 
                              paste(this_outdate, 
                                    "alldata_wide",
                                    time_file,
                                    sep = "_"))) 
    
    log_msg <- "!! Previously published reports were updated"
    
  } else {
    
    write_excel_csv(country_list, "data/processed_countries.csv", append = TRUE)
    write_excel_csv(region_list, "data/processed_regions.csv", append = TRUE)
    
    write_excel_csv(all_data_long, 
                    file.path("data", 
                              paste(this_outdate, "alldata_long.csv", sep = "_")))
    write_excel_csv(all_data_wide,
                    file.path("data", 
                              paste(this_outdate, "alldata_wide.csv", sep = "_")))
    
    log_msg <- "!! New reports were published"
    
  }
  
  data_update <- TRUE
  
}

if (interactive()) {
  message(log_msg)
}

log_msg <- paste0(Sys.time(), " ", log_msg)
write_lines(log_msg, "processing.log", append = TRUE)

if (data_update) {
  git2r::checkout(".", "autoupdate")
  commit_msg <- paste("AUTOUPDATE", Sys.time())
  git2r::commit(".", message = commit_msg, all = TRUE)
  git2r::push(".", "origin", "refs/heads/autoupdate", 
              credentials = git2r::cred_token())
}