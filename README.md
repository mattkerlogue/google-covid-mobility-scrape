
# google-mobility-scrape-UK

<!-- badges: start -->
<!-- badges: end -->

This is a repo to scrape the data from Google's COVID19 community mobility reports https://www.google.com/covid19/mobility/


## NEWS

2020-03-03 18:22 Converted code into a functions, added date and country codes into output tables, created functions for region reports (US state-level data)

2020-03-03 12:59 - First version, scrape of PDF and extract of data into CSV

## How to use

The `R/functions.R` script provides a number of functions to interact with the Google COVI19 Community Mobility Reports:

* `get_country_list()` gets a list of the country reports available
* `get_national_data()` extracts the overall figures from a country report
* `get_subnational_data()` extracts the locality figures from a country report
* `get_region_list()` gets a list of the region reports available (currently just US states)
* `get_region_data()` extracts the overall figures from a region report
* `get_subregion_data()` extracts the locality figures from a region report

The functions return tibbles.

## Example code

This code is also provided at `mobility_report_scraping.R`

``` {r}
# get list of countries
# default url is https://www.google.com/covid19/mobility/
countries <- get_country_list()

# extract the url for the uk
uk_url <- countries %>% filter(country == "GB") %>% pull(url)

# extract overall data for the uk
uk_overall_data <- get_national_data(uk_url)

# extract locality data for the uk
uk_location_data <- get_subnational_data(uk_url)

# get list of us states
states <- get_region_list()

# extract the url for new york
ny_url <- states %>% filter(region == "New York") %>% pull(url)

# extract overall data for new york state
ny_data <- get_region_data(ny_url)

# extract locality data for new york state
ny_locality_data <- get_subregion_data(ny_url)
```