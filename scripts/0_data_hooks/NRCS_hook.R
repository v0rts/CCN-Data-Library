## CCN Data Library ########

## Data hook script for NJ-NRCS data
## contact: Jaxine Wolfe; wolfejax@si.edu 

# load necessary libraries
library(tidyverse)
# library(readxl)
library(lubridate)
library(RefManageR)
library(leaflet)
# library(knitr)

# load in helper functions
source("scripts/1_data_formatting/curation_functions.R") # For curation
source("scripts/1_data_formatting/qa_functions.R") # For QAQC

# link to database guidance for easy reference:
# https://smithsonian.github.io/CCN-Community-Resources/soil_carbon_guidance.html

# load in data 
nrcs_sites <- readxl::read_xlsx("data/primary_studies/NRCS_NJ/original/NJTWMN_SoilSampling.xlsx", sheet = 1, skip = 1)
nrcs_ds <- readxl::read_xlsx("data/primary_studies/NRCS_NJ/original/NJTWMN_SoilSampling.xlsx", sheet = 2, skip = 1)

## 1. Curation ####

id <- "NRCS"

## ... Depthseries ####

depthseries <- nrcs_ds %>% 
  fill(Pedon) %>% drop_na(Horizon) %>% 
  rename(depth_min = `Top Depth, cm`, 
         depth_max = `Bot. Depth, cm`,
         dry_bulk_density = `OD Db, g/cc`,
         depth_interval_notes = ...19) %>% 
  separate(Pedon, into = c("core_id", "site_id"), sep = " - ") %>% 
  mutate(study_id = id, 
         method_id = "see original source",
         core_id = recode(core_id, "S2019011001" = "S2019NJ011001"),
         # TC seems to match OC (though OC looks to be rounded to the tenths place)
         fraction_carbon = `Total C`/100) %>% 
  reorderColumns("depthseries",.) %>% 
  select(-c(...2:...21))

limited_sampling_depth <- depthseries %>% filter(!is.na(depth_interval_notes)) %>% pull(core_id)
  
## ... Cores ####

# !!! needs position method !!!

cores <- nrcs_sites %>% 
  drop_na(Lat) %>% 
  rename(latitude = Lat, longitude = Long,
         core_id = `Ped. ID`,
         core_notes = `KSSL Analyses Link`) %>% 
  mutate(study_id = id,
         latitude = as.numeric(latitude), longitude = as.numeric(longitude),
         year = year(as.Date(`Description / Sampling Date`)),
         month = month(as.Date(`Description / Sampling Date`)),
         day = day(as.Date(`Description / Sampling Date`)),
         salinity_class = recode(tolower(`Fresh / Salt`), "salt" = "estuarine"),
         vegetation_class = "emergent", 
         habitat = "marsh", 
         # need more clarity here
         core_length_flag = "not specified"
           # case_when(core_id %in% limited_sampling_depth ~ "core depth limited by length of corer",
                                      # T ~ "core depth represents deposit depth")
         ) %>% 
  full_join(depthseries %>% distinct(site_id, core_id)) %>% 
  reorderColumns("cores", .) %>% 
  select(-c(State:`Fresh / Salt`)) %>% 
  select(-c(Organization:Source))

leaflet(cores) %>% 
  addTiles() %>% 
  addCircleMarkers(radius = 2, label = ~site_id)

## ... Methods ####
# lab data mart: https://ncsslabdatamart.sc.egov.usda.gov/
# look up method codes here: https://www.nrcs.usda.gov/sites/default/files/2023-01/SSIR42.pdf
# start around pg 30

# these cores are from different sources across different years, and probably used different methods?
# methods <- data.frame(study_id = id, 
#                       coring_method = "vibracore",
#                       roots_flag = "roots and rhizomes included",
#                       sediment_sieved_flag = "sediment sieved",
#                       compaction_flag = "not specified",
#                       dry_bulk_density_temperature = 60,
#                       dry_bulk_density_flag = "to constant mass",
#                       carbon_measured_or_modeled = "measured", 
#                       fraction_carbon_method = "EA", 
#                       fraction_carbon_type = "total carbon")

## Table testing
table_names <- c("cores", "depthseries")

# Check col and varnames
testTableCols(table_names)
testTableVars(table_names)

# test required and conditional attributes
testRequired(table_names)
testConditional(table_names)

# test uniqueness
testUniqueCores(cores)
testUniqueCoords(cores)

# test relational structure of data tables
testIDs(cores, depthseries, by = "site")
testIDs(cores, depthseries, by = "core")

# test numeric attribute ranges
fractionNotPercent(depthseries)
test_numeric_vars(depthseries)

## 3. Write Curated Data ####

# write data to final folder
# write_excel_csv(methods, "data/primary_studies/Cifuentes_and_Torres_2024/derivative/Cifuentes_and_Torres_2024_methods.csv")
write_excel_csv(cores, "data/primary_studies/NRCS_NJ/derivative/NRCS_cores.csv")
write_excel_csv(depthseries, "data/primary_studies/NRCS_NJ/derivative/NRCS_depthseries.csv")


# Bibliography include KSSL Analyses Links?
# How to cite: https://ncsslabdatamart.sc.egov.usda.gov/datause.aspx

# National Cooperative Soil Survey
# National Cooperative Soil Survey Soil Characterization Database
# http://ncsslabdatamart.sc.egov.usda.gov/
#   Accessed Wednesday, January 8, 2025

# misc - A fallback type for entries which do not fit into any other category. Required fields:
  # author/editor, title, year/date

# combine all citations 
synthesis_citations <- data.frame(study_id = id,
                                  bibliography_id = "NRCS_data",
                                  bibtype = "Misc",
                                  publication_type = "primary dataset", 
                                  title = "National Cooperative Soil Survey Soil Characterization Database",
                                  author = "National Cooperative Soil Survey",
                                  url = "http://ncsslabdatamart.sc.egov.usda.gov/",
                                  note = "Accessed Wednesday, January 8, 2025") %>% 
  # bind_rows(xia_synth) %>% 
  arrange(study_id) %>% 
  # select(-c(keywords, copyright)) %>%  # editor, language
  select(study_id, bibliography_id, publication_type, everything())

# unique(cores$study_id)[!(unique(cores$study_id) %in% unique(synthesis_citations$study_id))]

# Create .bib file
# this is more of a test that bib IDs are unique
bib_file <- synthesis_citations %>%
  select(-study_id, -publication_type) %>%
  distinct() %>%
  column_to_rownames("bibliography_id")
# link to bibtex guide
# https://www.bibtex.com/e/entry-types/

write_excel_csv(synthesis_citations, "data/primary_studies/NRCS_NJ/derivative/NRCS_study_citations.csv")
WriteBib(as.BibEntry(bib_file), "data/primary_studies/NRCS_NJ/derivative/NRCS_2025.bib")





## ... Webscraping ####

# Test workflow to webscrape information for each pedon ID from the lab data mart
# https://stackoverflow.com/questions/55092329/extract-table-from-webpage-using-r
library(rvest)
# 
url <- cores %>% pull(core_notes)

# df <- url[1] %>%
#   read_html() %>%
#   html_nodes("table") %>%
#   html_table(fill = T)

# scrape information for each core and compile  
pedon_info <- map(url, 
                  . %>% read_html() %>%
                    html_nodes("table") %>%
                    html_table(fill = T))

## pull methods codes
pedon_info %>% map(c(4, 3, 5))
## its all the same: 1B1A, 2A1, 2B

# pull a table
test <- pedon_info[[1]][[26]]
