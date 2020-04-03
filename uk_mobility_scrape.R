library(tidyverse)

pdf_url <- "https://www.gstatic.com/covid19/mobility/2020-03-29_GB_Mobility_Report_en.pdf"

report_data <- pdftools::pdf_data(pdf_url)

subnational_pages <- report_data[3:(length(report_data)-1)]

subnational_data <- map_dfr(subnational_pages, bind_rows, .id = "page")

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

location_data <- subnational_datapoints %>%
  left_join(locations, by = c("page", "position")) %>%
  select(location, entity, text) %>%
  filter(entity != "location") %>%
  mutate(value = as.numeric(str_remove_all(text, "\\%"))/100)

write_excel_csv(location_data, "location_mobility_data.csv")
