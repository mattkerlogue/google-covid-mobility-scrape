local({
  r <- getOption("repos")
  r["CRAN"] <- "https://cloud.r-project.org/" 
  options(repos = r)
})

install.packages("tibble")
install.packages("dplyr")
install.packages("tidyr")
install.packages("purrrr")
install.packages("lubridate")
install.packages("stringr")
install.packages("xml2")
install.packages("rvest")
install.packages("scales")
install.packages("jsonlite")
install.packages("pdftools")
install.packages("countrycode")