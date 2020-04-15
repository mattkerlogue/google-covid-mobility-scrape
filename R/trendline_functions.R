# UTILITY FUNCTIONS ============================

extract_region <- function(filename) {
  
  region <- str_remove_all(filename, "-") %>% 
    str_remove("\\d+_\\w{2}_") %>% 
    str_remove("_Mobility_Report_en.pdf") %>% 
    str_replace_all("_", " ")
  
  return(region)
  
}

download_pdf <- function(url) {
  
  filename <- basename(url)
  
  tmp_pdf <- file.path("tmp", filename)
  
  download.file(url, tmp_pdf, mode = "wb")
  
  return(tmp_pdf)
  
}

pdf2svg <- function(file, page) {

  svgfile <- file.path("tmp", paste(str_remove("file.pdf", "\\.pdf$"),
                                        page,
                                        ".svg",
                                        sep = "_"))
  
  command <- paste("pdf2svg", file, svgfile, page)
  
  system(command)
  
  return(svgfile)
  
}

entity_assign <- function(base_x, base_y) {
  
  base_x <- round(as.numeric(base_x))
  base_y <- round(as.numeric(base_y))
  
  entity <- case_when(
    base_y == 360 ~ "retail_recr",
    base_y == 477 ~ "grocery_pharm",
    base_y == 594 ~ "parks",
    base_y ==  53 ~ "transit",
    base_y == 170 ~ "workplace",
    base_y == 287 ~ "residential",
    base_x ==  70 & base_y == 133 ~ "retail_recr",
    base_x == 245 & base_y == 133 ~ "grocery_pharm",
    base_x == 419 & base_y == 133 ~ "parks",
    base_x ==  70 & base_y == 271 ~ "transit",
    base_x == 245 & base_y == 271 ~ "workplace",
    base_x == 419 & base_y == 271 ~ "residential",
    base_x ==  70 & base_y == 460 ~ "retail_recr",
    base_x == 245 & base_y == 460 ~ "grocery_pharm",
    base_x == 419 & base_y == 460 ~ "parks",
    base_x ==  70 & base_y == 598 ~ "transit",
    base_x == 245 & base_y == 598 ~ "workplace",
    base_x == 419 & base_y == 598 ~ "residential",
  )
  
  return(entity)
  
}

position_assign <- function(base_x, base_y) {
  
  base_x <- round(as.numeric(base_x))
  base_y <- round(as.numeric(base_y))
  
  position <- case_when(
    base_y == 360 | base_y == 477 | base_y == 594 | base_y ==  53 | 
      base_y == 170 | base_y == 287 ~ "overall",
    base_y == 133 | base_y == 271 ~ "upper",
    base_y == 460 | base_y == 598 ~ "lower",
  )
  
  return(position)
  
}

gen_path_dt <- function(text, report_date, page) {
  
  y_ext <- ifelse(page < 3, 120, 100)
  
  path_dt <- separate_rows(tibble(text = text), text, sep = "\\|") %>%
    separate(text, into = c("path_x", "path_y"), sep = ",") %>%
    distinct() %>% 
    mutate_all(as.numeric) %>%
    mutate(rel_x = path_x/200,
           rel_y = scales::rescale(path_y, c(0.8, -0.8), c(0, y_ext)),
           round_x = round(rel_x, 2),
           round_y = round(rel_y, 4))
  
  date_lookup <- tibble(
    date = seq(lubridate::ymd(20200223), lubridate::ymd(report_date), "day"), 
    x = scales::rescale(1:43, c(0,1)), 
    round_x = round(x, 2)) %>%
    select(date, round_x)
  
  path_dt <- path_dt %>% left_join(date_lookup, by = "round_x") %>%
    select(date, value = round_y)
  
  return(path_dt)
  
}

# GET FUNCTIONS ============================
get_pdf_links <- function(url="https://www.google.com/covid19/mobility/") {
  
  # get webpage
  page <- xml2::read_html(url)
  
  # extract country urls 
  country_urls <- page %>% 
    rvest::html_nodes("div.country-data > a.download-link") %>% 
    rvest::html_attr("href")
  
  region_urls <- page %>%
    rvest::html_nodes("div.region-data > a.download-link") %>% 
    rvest::html_attr("href")
  
  url_data <- tibble(url = country_urls, type = "country") %>%
    bind_rows(tibble(url = region_urls, type = "region")) %>%
    mutate(filename = basename(url),
           date = map_chr(filename, ~strsplit(., "_")[[1]][1]),
           country = map_chr(filename, ~strsplit(., "_")[[1]][2]),
           country_name = countrycode::countrycode(country, 
                                                   "iso2c", 
                                                   "country.name"),
           region = if_else(type == "region", 
                            map_chr(filename, extract_region),
                            NA_character_)) %>%
    select(country, type, country_name, region, date, url)
  
  # return data
  return(url_data)
  
}

get_svg_data <- function(file, page, report_date) {
  
  svgfile <- pdf2svg(file, page)
  
  svg_path_dt <- xml2::read_html(svgfile) %>%
    rvest::html_nodes("path") %>% 
    rvest::html_attrs() %>%
    map_dfr(bind_rows) %>% 
    filter(str_detect(style, "rgb\\(25.878906\\%,52.159119\\%,95.689392\\%\\)")) %>%
    drop_na(transform) %>%
    mutate(transformdat = str_remove_all(transform, "matrix\\(|\\)")) %>%
    separate(transformdat, into = c(NA, NA, NA, NA, "base_x", "base_y"), sep = ",") %>%
    # select(base_x, base_y, d) %>%
    mutate(
      nd = str_replace(d,"^M[ |-]+\\d+\\.\\d+ \\d+.\\d+", "0 50") %>%
        str_trim() %>%
        str_replace_all(" [L|M|(M)] ", "|") %>%
        str_replace_all(" ", ","),
      coords = pmap(list(nd, report_date, page), gen_path_dt),
      entity = map2_chr(base_x, base_y, entity_assign),
      position = map2_chr(base_x, base_y, position_assign)) %>%
    select(position, entity, coords) %>%
    drop_na()
  
  if (interactive()) {
    message(".")
  }
  
  return(svg_path_dt)
  
}


get_svg_pages <- function(file, pages, report_date) {
  
  allsvg <- pmap_dfr(list(file, seq(1, pages - 1), report_date), get_svg_data, .id = "page")
  
  if (pages == 3) {
    locations <- tibble(page = character(), position = character(), location = character())
  } else {
    
    locations <- pdftools::pdf_data(file) %>%
      map_dfr(bind_rows, .id = "page") %>%
      filter((page > 2 | page < pages) & (y == 36 | y == 363)) %>%
      mutate(position = case_when(
        y == 36 ~ "upper", 
        y == 363 ~ "lower", 
        TRUE ~ NA_character_)) %>%
      select(page, position, text) %>%
      group_by(page, position) %>%
      nest() %>%
      mutate(location = map_chr(data, ~paste(unlist(.), collapse = " "))) %>%
      select(page, position, location)
  
  }
  
  location_dt <- allsvg %>%
    left_join(locations, by = c("page", "position")) %>%
    mutate(location = if_else(position == "overall", "OVERALL", location)) %>%
    select(location, entity, coords)
  
  if (interactive()) {
    message("Processed: ", basename(file))
  }
  
  return(location_dt)
  
}
