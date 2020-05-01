# function to get overall data from a country report
get_national_data <- function(url) {
  
  # get the report, subset to overall pages and and convert to a dataframe
  report_data <- pdftools::pdf_data(url)
  national_pages <- report_data[1:2]
  national_data <- map_dfr(national_pages, bind_rows, .id = "page")
  
  # get the report file name extract the date and country
  filename <- basename(url)
  
  date <- strsplit(filename, "_")[[1]][1]
  country <- strsplit(filename, "_")[[1]][2]
  
  # extract the data at relevant y position
  national_datapoints <- national_data %>%
    filter(y == 369 | y == 486 | y == 603 | 
           y == 62  | y == 179 | y == 296) %>%
    mutate(
      entity = case_when(
        page == 1 & y == 369 ~ "retail_recr",
        page == 1 & y == 486 ~ "grocery_pharm",
        page == 1 & y == 603 ~ "parks",
        page == 2 & y == 62  ~ "transit",
        page == 2 & y == 179 ~ "workplace",
        page == 2 & y == 296 ~ "residential",
        TRUE ~ NA_character_)) %>%
    mutate(value = as.numeric(str_remove_all(text, "\\%"))/100,
           date = date,
           country = country,
           location = "COUNTRY OVERALL") %>%
    select(date, country, location, entity, value)
  
  # return data
  return(national_datapoints)
  
}

# get locality data from a country level report
get_subnational_data <- function(url) {
  
  # get the report, subset to locality pages and convert to dataframe
  report_data <- pdftools::pdf_data(url)
  
  # reports with sub-national data have more than 3 pages
  if (length(report_data) > 3) {
    subnational_pages <- report_data[3:(length(report_data) - 1)]
    subnational_data <- map_dfr(subnational_pages, bind_rows, .id = "page")
    
    # get the report file name and the date and country
    filename <- basename(url)
    
    date <- strsplit(filename, "_")[[1]][1]
    country <- strsplit(filename, "_")[[1]][2]
    
    # extract information for each locality
    subnational_datapoints <- subnational_data %>%
      filter(y == 36  | y == 104 | y == 242 | 
               y == 363 | y == 431 | y == 568) %>%
      mutate(
        entity = case_when(
          y == 36 ~ "location",
          y == 104 & x == 36  ~ "retail_recr",
          y == 104 & x == 210 ~ "grocery_pharm",
          y == 104 & x == 384 ~ "parks",
          y == 242 & x == 36  ~ "transit",
          y == 242 & x == 210 ~ "workplace",
          y == 242 & x == 384 ~ "residential",
          y == 363 ~ "location",
          y == 431 & x == 36  ~ "retail_recr",
          y == 431 & x == 210 ~ "grocery_pharm",
          y == 431 & x == 384 ~ "parks",
          y == 568 & x == 36  ~ "transit",
          y == 568 & x == 210 ~ "workplace",
          y == 568 & x == 384 ~ "residential"),
        position = case_when(
          y == 36 ~ "first",
          y == 104 ~ "first",
          y == 242 ~ "first",
          y == 363 ~ "second",
          y == 431 ~ "second",
          y == 568 ~ "second")
      )
    
    # combine location information into a label
    locations <- subnational_datapoints %>% 
      filter(entity == "location") %>%
      select(page, position, text) %>%
      group_by(page, position) %>%
      nest() %>%
      mutate(location = map_chr(data, paste),
             location = str_remove_all(location, "^c\\(\""),
             location = str_replace_all(location, "\", \"", " "),
             location = str_remove_all(location, "\"\\)"),
             location = str_replace_all(location, "And", "and")) %>%
      select(page, position, location)
    
    # merge location label with datapoints
    location_data <- subnational_datapoints %>%
      left_join(locations, by = c("page", "position")) %>%
      filter(entity != "location") %>%
      mutate(value = as.numeric(str_remove_all(text, "\\%"))/100,
             date = date,
             country = country) %>%
      select(date, country, location, entity, value)
    
  } else {
    # create empty tibble if no sub-national data
    location_data <- tibble::tibble(
      date = character(), 
      country = character(),
      location = character(),
      entity = character(),
      value = double()
    )
  }
  
  # return data
  return(location_data)
  
}

get_country_list <- function(url = "https://www.google.com/covid19/mobility/") {
  
  # get webpage
  page <- xml2::read_html(url)
  
  
  pageJSON <- page %>% 
    rvest::html_nodes(xpath = "/html/body/div[1]/section[3]/div[2]/script[1]") %>% 
    rvest::html_text() %>%
    str_remove("^window.templateData=JSON.parse\\('") %>%
    str_remove("'\\)$") %>%
    stringi::stri_unescape_unicode() %>%
    jsonlite::fromJSON()
  
  
  countries <- pageJSON$countries %>%
    select(name, pdfLink) %>%
    mutate(filename = basename(pdfLink),
           date = map_chr(filename, ~strsplit(., "_")[[1]][1]),
           country = countrycode::countrycode(name, 
                                              "country.name", 
                                              "iso2c"),
           country_name = countrycode::countrycode(country, 
                                                   "iso2c", 
                                                   "country.name")) %>%
    select(country, country_name, date, url = pdfLink)
  
  # return data
  return(countries)
  
}

get_region_list <- function(url = "https://www.google.com/covid19/mobility/") {
  
  # get webpage
  page <- xml2::read_html(url)
  
  # extract region URLs
  pageJSON <- page %>% 
    rvest::html_nodes(xpath = "/html/body/div[1]/section[3]/div[2]/script[1]") %>% 
    rvest::html_text() %>%
    str_remove("^window.templateData=JSON.parse\\('") %>%
    str_remove("'\\)$") %>%
    stringi::stri_unescape_unicode() %>%
    jsonlite::fromJSON()
  
  regions <- pageJSON$countries %>%
    select(name, childRegionLabel, childRegions) %>%
    filter(name == "United States") %>%
    pull(childRegions) %>%
    pluck(1) %>%
    mutate(filename = basename(pdfLink),
           date = map_chr(filename, ~strsplit(., "_")[[1]][1]),
           country = map_chr(filename, ~strsplit(., "_")[[1]][2])) %>%
    select(country, region = name, date, url = pdfLink)
  
  # return data
  return(regions)
  
}

get_region_data <- function(url) {
  
  # get report, subset to overall pages and convert to data frame
  report_data <- pdftools::pdf_data(url)
  region_pages <- report_data[1:2]
  region_data <- map_dfr(region_pages, bind_rows, .id = "page")
  
  # get file name and extract country and date
  filename <- basename(url)
  
  date <- strsplit(filename, "_")[[1]][1]
  country <- strsplit(filename, "_")[[1]][2]
  
  # extract region from file name
  region <- map_chr(filename, 
                    ~str_remove_all(., "-") %>% 
                      str_remove("\\d+_\\w{2}_") %>% 
                      str_remove("_Mobility_Report_en.pdf") %>% 
                      str_replace_all("_", " "))
  
  # extract the data at relevant y position
  region_datapoints <- region_data %>%
    filter(y == 369 | y == 486 | y == 603 | 
             y == 62  | y == 179 | y == 296) %>%
    mutate(
      entity = case_when(
        page == 1 & y == 369 ~ "retail_recr",
        page == 1 & y == 486 ~ "grocery_pharm",
        page == 1 & y == 603 ~ "parks",
        page == 2 & y == 62  ~ "transit",
        page == 2 & y == 179 ~ "workplace",
        page == 2 & y == 296 ~ "residential",
        TRUE ~ NA_character_)) %>%
    mutate(value = as.numeric(str_remove_all(text, "\\%"))/100,
           date = date,
           country = country,
           region = region,
           location = "REGION OVERALL") %>%
    select(date, country, region, location, entity, value)
  
  # return data
  return(region_datapoints)
  
}


get_subregion_data <- function(url) {
  
  # get report, subset to localities and convert to data frame
  report_data <- pdftools::pdf_data(url)
  subregion_pages <- report_data[3:(length(report_data)-1)]
  subregion_data <- map_dfr(subregion_pages, bind_rows, .id = "page")
  
  # get report file name extract date, country and region
  filename <- basename(url)
  
  date <- strsplit(filename, "_")[[1]][1]
  country <- strsplit(filename, "_")[[1]][2]
  
  region <- map_chr(filename, 
                    ~str_remove_all(., "-") %>% 
                      str_remove("\\d+_\\w{2}_") %>% 
                      str_remove("_Mobility_Report_en.pdf") %>% 
                      str_replace_all("_", " "))
  
  # extract information for each locality
  subregion_datapoints <- subregion_data %>%
    filter(y == 36  | y == 104 | y == 242 | 
             y == 363 | y == 431 | y == 568) %>%
    mutate(
      entity = case_when(
        y == 36 ~ "location",
        y == 104 & x == 36  ~ "retail_recr",
        y == 104 & x == 210 ~ "grocery_pharm",
        y == 104 & x == 384 ~ "parks",
        y == 242 & x == 36  ~ "transit",
        y == 242 & x == 210 ~ "workplace",
        y == 242 & x == 384 ~ "residential",
        y == 363 ~ "location",
        y == 431 & x == 36  ~ "retail_recr",
        y == 431 & x == 210 ~ "grocery_pharm",
        y == 431 & x == 384 ~ "parks",
        y == 568 & x == 36  ~ "transit",
        y == 568 & x == 210 ~ "workplace",
        y == 568 & x == 384 ~ "residential"),
      position = case_when(
        y == 36 ~ "first",
        y == 104 ~ "first",
        y == 242 ~ "first",
        y == 363 ~ "second",
        y == 431 ~ "second",
        y == 568 ~ "second")
    )
  
  # convert location data into labels
  locations <- subregion_datapoints %>% 
    filter(entity == "location") %>%
    select(page, position, text) %>%
    group_by(page, position) %>%
    nest() %>%
    mutate(location = map_chr(data, paste),
           location = str_remove_all(location, "^c\\(\""),
           location = str_replace_all(location, "\", \"", " "),
           location = str_remove_all(location, "\"\\)"),
           location = str_replace_all(location, "And", "and")) %>%
    select(page, position, location)
  
  # merge location data with labels
  location_data <- subregion_datapoints %>%
    left_join(locations, by = c("page", "position")) %>%
    filter(entity != "location") %>%
    mutate(value = as.numeric(str_remove_all(text, "\\%"))/100,
           date = date,
           country = country,
           region = region) %>%
    select(date, country, region, location, entity, value)
  
  # return data
  return(location_data)
  
}

get_update_time <- function(url = "https://www.google.com/covid19/mobility/") {
  
  # get webpage
  page <- xml2::read_html(url)
  
  # get script block that contains date
  update_text <- page %>% 
    rvest::html_nodes("p.report-info-text") %>% 
    rvest::html_text() %>%
    pluck(1) %>%
    str_remove_all("^Reports updated ") %>%
    str_remove_all("\\.|\\,")
    
  update_time <- lubridate::ymd_hm(update_text) %>%
    lubridate::round_date("second")
  
  return(update_time)
  
}
