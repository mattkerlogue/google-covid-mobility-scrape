suppressPackageStartupMessages(library(tidyverse))
source("R/functions.R")

# get time of last data update
last_update <- read_lines("LASTUPDATE_UTC.txt") %>%
  lubridate::as_datetime() %>%
  lubridate::round_date("minute")

# get current update time
live_update <- get_update_time()

# if no update set message & flag otherwise scrape
if (live_update == last_update) {
  
  log_msg <- "  No update"
  
  data_update <- FALSE
  
} else {
  # get list of countries with reports
  country_list <- get_country_list()
  
  # get the date of the reports and the latest update already processed
  this_outdate <- paste0(unique(country_list$date))
  max_past_outdate <- suppressMessages(
    read_csv("data/processed_countries.csv") %>%
      pull(date) %>%
      max()
  )
  
  # create existing reports updated flag
  existing_report_update <- FALSE
  
  # if the report dates are the same then set flag to true
  if (this_outdate == max_past_outdate) {
    warning("Report update date has changed, date of reports has not changed")
    existing_report_update <- TRUE
  }
  
  # get country and subnational data
  country_dt <- country_list %>%
    mutate(overall_data = map(url, get_national_data),
           locality_data = map(url, get_subnational_data))
  
  # get list of regional reports
  region_list <- get_region_list()
  
  # get regional data
  region_dt <- region_list %>%
    mutate(overall_data = map(url, get_region_data),
           locality_data = map(url, get_subregion_data))
  
  # combine the country and region data
  full_dt <- country_dt %>%
    bind_rows(region_dt)
  
  # get data for all countries and all localities (drop US-level report's 
  # subnational data as duplicated in regional reports)
  countries_overall <- map_dfr(full_dt$overall_data, bind_rows)
  locality_overall <- map_dfr(full_dt$locality_data, bind_rows) %>%
    filter(!(country == "US" & is.na(region)))
  
  # combine all the data into a long form dataset, get countryname from code
  all_data_long <- countries_overall %>%
    bind_rows(locality_overall) %>%
    mutate(country_name = countrycode::countrycode(country, "iso2c", "country.name")) %>%
    select(date, country, country_name, region, location, entity, value)
  
  # pivot into a wide table
  all_data_wide <- all_data_long %>% 
    pivot_wider(names_from = entity, values_from = value)
  
  # write the update time
  write_lines(live_update, "LASTUPDATE_UTC.txt")
  
  # if existing reports updated add update timestamp to filenames
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
    
    # also write data to 'latest' CSVs for easy use of latest available data 
    # in other applications
    write_excel_csv(all_data_long, file.path("data","latest_alldata_long.csv"))
    write_excel_csv(all_data_wide, file.path("data","latest_alldata_wide.csv"))
    
    # set log message
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
    
    # also write data to 'latest' CSVs for easy use of latest available data 
    # in other applications
    write_excel_csv(all_data_long, file.path("data","latest_alldata_long.csv"))
    write_excel_csv(all_data_wide, file.path("data","latest_alldata_wide.csv"))
    
    # set log message
    log_msg <- "!! New reports were published"
    
  }
  
  # set data update flag
  data_update <- TRUE
  
}

# if in interactive R tell the user what's happened
if (interactive()) {
  message(log_msg)
}

# write the log message to the processing log
log_msg <- paste0(Sys.time(), " ", log_msg)
write_lines(log_msg, "processing.log", append = TRUE)

