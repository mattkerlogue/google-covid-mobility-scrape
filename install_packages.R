local({
  r <- getOption("repos")
  r["CRAN"] <- "https://cloud.r-project.org/" 
  options(repos = r)
})

install.packages("tidyverse")
install.packages("pdftools")
install.packages("countrycode")