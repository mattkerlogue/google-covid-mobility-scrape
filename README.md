
# google-covid-mobility-scrape

<!-- badges: start -->
<!-- badges: end -->

This is a repo to scrape the data from Google's COVID19 community mobility reports https://www.google.com/covid19/mobility/

## Requirements
You'll need the packages: [`dplyr`](https://dplyr.tidyverse.org), [`purrr`](https://purrr.tidyverse.org), [`xml2](https://xml2.r-lib.org/), [`rvest`](http://rvest.tidyverse.org/), [`pdftools`](https://docs.ropensci.org/pdftools/) and [`countrycode`](https://cran.r-project.org/package=countrycode). These are all on CRAN.

## NEWS

2020-04-04 16:51 `get_all_data.R` script pulls data from all reports, saved in the data folder

2020-04-04 16:26 Add comments to the functions, move tidyverse library call to scripts

2020-04-03 18:22 Converted code into a functions, added date and country codes into output tables, created functions for region reports (US state-level data)

2020-04-03 12:59 - First version, scrape of PDF and extract of data into CSV

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