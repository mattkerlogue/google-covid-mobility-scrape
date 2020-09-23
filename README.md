
# google-covid-mobility-scrape

<!-- badges: start -->
![lifecycle: archived](https://img.shields.io/badge/lifecycle-archived-critical)
<!-- badges: end -->

This is a repo to scrape the data from Google's [COVID19 community mobility reports](https://www.google.com/covid19/mobility/) using R. This code is released freely under the MIT Licence, it is provided 'as-is'.

**This project is now archived, no further development is planned and GitHub actions paused. Google have been [publishing the underlying data]( https://www.gstatic.com/covid19/mobility/Global_Mobility_Report.csv) for some time, this should be preferred over any data held in this repository.**



------

This project is built in R and extracts both the headline mobility comparison figures and trendline data from Google's PDFs. Trendline data exists in the `feature/trendlines` branch until verified.

The trendline extraction work benefits significantly from the following work:

* ONS Data Science Campus' [python-based extraction tool](https://github.com/datasciencecampus/mobility-report-data-extractor) and [data archive](https://github.com/datasciencecampus/google-mobility-reports-data) (for UK overall, UK localities, and country-level for G20 countries)
* Duncan Garmonsway's [port of the ONS code to R](https://github.com/nacnudus/google-location-coronavirus/), which includes a file with data from all trendlines.

If you'd like to read about the process of developing this code please read the following blogs:

* [Scraping Google’s COVID-19 mobility report PDFs](https://lapsedgeographer.london/2020-04/covid19-scraping/)
* [Automating the COVID19 PDF scraping](https://lapsedgeographer.london/2020-04/automating-pdf-scraping/)

## Data
You can browse the data extracted in the `data` folder, this folder also contains a log of the processed countries and regions.

A [GitHub action workflow](.github/workflows/main.yaml) runs the `get_all_data.R` script on an hourly basis to check for new reports. If new reports have been published (or existing reports updated) the script will run and new data will be pushed to the repository, files continue to have the format `YYYY-MM-DD_alldata_[wide|long].csv` however there are now also `latest_alldata_[wide|long].csv` files which are copies of the last produced data. All files contain a reference date column. A [workflow](.github/workflows/trendlines.yaml) has also been written to scrape the trendlines which will execute when an update to `LASTUPDATE_UTC.txt` is pushed to the repository (i.e. when new headline figures have been added).

The table below provides a list of data in the repository, but is manually updated, check [`processing.log`](processing.log) for a log of activity, and [`LASTUPDATE_UTC.txt`](LASTUPDATE_UTC.txt) for the metadata relating to updates if you want to check whether there has been an update. 

```
cd ~/r/google-covid-mobility-scrape
Rscript get_all_data.R
```

## NEWS (date/time in London local time; BST)

| Date             | Update                                                    |
| ---------------- | --------------------------------------------------------- |
| 2020-09-23 13:10 | Project archived. GitHub Actions paused |
| 2020-04-23 19:30 | Code updated, GitHub Actions resumed |
| 2020-04-23 20:04 | Google updated their website, breaking the code so GitHub Actions automated checking was paused |
| 2020-04-17 12:45 | Google are now publishing their own CSV, this should be considered the canonical source, this project will continue for now |
| 2020-04-17 12:40 | Trendlines moved to `feature/trendline` branch while reviewing. |
| 2020-04-16 01:50 | Corrected an error with the baselining of trendlines for the overall report trends. |
| 2020-04-15 22:16 | **TRENDLINES EXTRACTED** data for the trendlines is now being extracted, with thanks to Duncan Garmonsway's [port of the ONS code to R](https://github.com/nacnudus/google-location-coronavirus/) for the code inspiration. |
| 2020-04-13 19:30 | `get_all_data.R` now runs hourly via GitHub actions |
| 2020-04-10 16:16 | `get_all_data.R` amended to check update time, doesn't run extraction code if times are the same,  gives a warning if update times have changed but report dates are unchanged |
| 2020-04-10 15:36 | Added function `get_update_time()` to extract time of update |
| 2020-04-10 13:15 | Extracted new mobility data (reference date 2020-04-05) <br /> `get_all_data.R` updated so can be run without needing to change filenames (i.e. will programmatically extract date and use that for the filenames) |
| 2020-04-07 16:52 | Updated README to reference ONS work on trendline extraction |
| 2020-04-04 16:51 | `get_all_data.R` script pulls data from all reports, saved in the data folder |
| 2020-04-04 16:26 | Add comments to the functions, move tidyverse library call to scripts |
| 2020-04-03 18:22 | Converted code into a functions, added date and country codes into output tables, created functions for region reports (US state-level data) |
| 2020-04-03 12:59 | First version, scrape of PDF and extract of data into CSV (reference date 2020-03-29) |

## How to use

You'll need the following R packages: [`dplyr`](https://dplyr.tidyverse.org), [`purrr`](https://purrr.tidyverse.org), [`xml2`](https://xml2.r-lib.org/), [`rvest`](http://rvest.tidyverse.org/), [`pdftools`](https://docs.ropensci.org/pdftools/) and [`countrycode`](https://cran.r-project.org/package=countrycode). These are all on CRAN.

```r
install.packages("tidyverse")       # installs dplyr, purrr, rvest and xml2
install.packages("pdftools")
install.packages("countrycode")
```

The `R/functions.R` script provides a number of functions to interact with the Google COVI19 Community Mobility Reports:

* `get_country_list()` gets a list of the country reports available
* `get_national_data()` extracts the overall figures from a country report
* `get_subnational_data()` extracts the locality figures from a country report
* `get_region_list()` gets a list of the region reports available (currently just US states)
* `get_region_data()` extracts the overall figures from a region report
* `get_subregion_data()` extracts the locality figures from a region report
* `get_update_time()` extracts the time the reports were updated (not the reference date of the reports)

The functions return tibbles providing the headline mobility report figures, they do not extract or interact with the trend-lines provided in the chart reports. The tibbles have the following columns:

* `date`: the date from the PDF file name
* `country`: the ISO 2-character country code from the PDF file name
* `region`: for region reports the region name
* `entity`: the datapoint label, one of
* `value`: the datapoint value, these are presented as percentages in the report but are converted to decimal representation in the tables

There are six mobility entities presented in the reports:

| `entity` value  | Description                                                |
| --------------- | ---------------------------------------------------------- |
| `retail_recr`   | *Retail & recreation*:  Mobility trends for places like restaurants, cafes, shopping centers, theme parks, museums, libraries, and movie theaters |
| `grocery_pharm` | *Grocery & pharmacy*:  Mobility trends for places like grocery markets, food warehouses, farmers markets, specialty food shops, drug stores, and pharmacies. |
| `parks`         | *Parks*: Mobility trends for places like national parks, public beaches, marinas, dog parks, plazas, and public gardens. |
| `transit`       | *Transit stations*: Mobility trends for places like public transport hubs such as subway, bus, and train stations. |
| `workplace`     | *Workplaces*: Mobility trends for places of work. |
| `residential`   | *Residential*: Mobility trends for places of residence. |


## Example code

This code is also provided in `mobility_report_scraping.R`

```r
library(tidyverse)       # pdftools and countrycode do not need to be loaded
source("R/functions.R")  # they are referenced in my functions using pkg::fun()

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
