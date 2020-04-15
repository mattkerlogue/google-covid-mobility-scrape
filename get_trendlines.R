library(tidyverse)
source("R/trendline_functions.R")

url_list <- get_pdf_links() %>%
  mutate(file = map(url, download_pdf))

pdf_base_dt <- url_list %>%
  mutate(pages = map_int(file, pdftools::pdf_length))

pdf_data_dt <- pdf_base_dt %>%
  mutate(trend = pmap(list(file, pages, date), get_svg_pages))

# uncomment to save intermediate object, useful when testing/running interactively
# saveRDS(pdf_data_dt, "data/intermediate_trendline_data.RDS")
# pdf_data_dt <- readRDS("data/intermediate_trendline_data.RDS")

location_trends <- pdf_data_dt %>%
  select(country, type, country_name, region, ref_date = date, trend) %>%
  unnest(trend) %>%
  mutate(drop = case_when(
    country == "US" & 
      type == "country" & 
      location != "OVERALL" ~ 1,
    TRUE ~ 0 )) %>%
  filter(drop == 0) %>%
  select(-drop) %>%
  unnest(coords) %>%
  drop_na(entity, location, value) %>%
  mutate(
    location_ref = toupper(
      str_replace(
        paste(country, region, location, sep = "."),
        "\\.NA\\.",
        "\\..")),
    timeplace_ref = toupper(paste(date, entity, sep = ".")),
    full_ref = paste(location_ref, timeplace_ref, sep = "."),
    value = round(value, 4))

location_trends_long <- location_trends %>%
  select(country, type, country_name, region, ref_date, 
         location, entity, date, full_ref, value)

location_trends_long_slim <- location_trends %>%
  select(full_ref, value)

location_trends_wide <- location_trends_long %>%
  pivot_wider(names_from = date, 
              values_from = value, 
              values_fill = list(value = NA_real_),
              values_fn = list(value = min))

report_date <- unique(pdf_data_dt$date)

processing_dt <- pdf_data_dt %>%
  select(-file, -pages, -trend) %>%
  mutate(processed = Sys.Date())

write_excel_csv(
  processing_dt,
  path = file.path("data", "processed_trendlines.csv"),
  append = TRUE)

write_rds(
  location_trends_long, 
  path = file.path("data", paste0(report_date, "_trendline_long.rds")),
  compress = "bz2")

write_excel_csv(
  location_trends_wide, 
  path = file.path("data", paste0(report_date, "_trendline_wide.csv.bz2")),
  na = "")

write_excel_csv(
  location_trends_long_slim, 
  path = file.path("data", "latest_trendline_long_slim.csv.bz2"),
  na = "")

write_excel_csv(
  location_trends_wide, 
  path = file.path("data", "latest_trendline_wide.csv"),
  na = "")

write_lines(report_date, "LASTUPDATE_TRENDLINE_DATE.txt")
log_msg <- paste0(Sys.time(), "  TRENDLINES EXTRACTED | Report date: ", report_date)
write_lines(log_msg, "processing.trendline.log", append = TRUE)
