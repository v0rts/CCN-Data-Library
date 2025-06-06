## CCN Data Library ########

## Soil core data curation script for Poppe et al 2024
## contact: Jaxine Wolfe, wolfejax@si.edu

## Notes about the dataset 
## Link to the data release and associated publication(s) for easy access

# load necessary libraries
library(tidyverse)
library(readxl)
library(lubridate)
library(RefManageR)
library(leaflet)

# load in helper functions
source("scripts/1_data_formatting/curation_functions.R") # For curation
source("scripts/1_data_formatting/qa_functions.R") # For QAQC


# link to database guidance for easy reference:
# https://smithsonian.github.io/CCRCN-Community-Resources/soil_carbon_guidance.html

# read data
poppe_methods <- read_csv("data/primary_studies/Poppe_et_al_2024/original/poppe_et_al_2024_methods.csv")
poppe_cores <- read_csv("data/primary_studies/Poppe_et_al_2024/original/Poppe_et_al_2024_cores.csv")
poppe_ds <- read_csv("data/primary_studies/Poppe_et_al_2024/original/Poppe_et_al_2024_depthseries.csv")
poppe_species <- read_csv("data/primary_studies/Poppe_et_al_2024/original/Poppe_et_al_2024_species.csv")

## 1. Curation ####

# this study ID must match the name of the dataset folder
# include this id in a study_id column for every curated table
id <- "Poppe_et_al_2024"
# if there are only two authors: Author_and_Author_year
# "year" will be exchanged with "unpublished" in some cases

## ... Methods ####

# curate materials and methods table
methods <- poppe_methods %>% select(-corer_diameter)

## ... Cores ####

id_lookup <- poppe_cores %>% distinct(core_id, PNWBCWG_id) %>% 
  # combine the two for a new core ID
  mutate(new_core_id = paste(core_id, PNWBCWG_id, sep = "-"),
         new_core_id = gsub(",", "", new_core_id))

# curate core-level data table

veg_notes <- poppe_species %>% distinct(site_id, species_notes) %>% 
  rename(site_description = site_id) %>% 
  mutate(species_notes = recode(species_notes, 
                                "veg for core vicinity" = "species noted at core-level",       
                                "veg for site - stocks project"  = "species noted at site-level"))

cores <- poppe_cores %>% 
  full_join(id_lookup) %>% select(-core_id, -PNWBCWG_id) %>% rename(core_id = new_core_id) %>% 
  select(study_id, site_id, core_id, everything()) %>% 
  full_join(veg_notes) %>% # patch in
  mutate(position_method = case_when(position_method == "RTK or handheld" ~ "other moderate resolution",
                                     grepl("Averaged coordinates", position_notes) ~ "other low resolution", 
                                     T ~ position_method),
         elevation_method = case_when(grepl("Averaged elevation", elevation_notes) ~ "other low resolution", 
                                      T ~ elevation_method),
         salinity_notes = ifelse(!is.na(salinity_method), 
                                 paste(salinity_method, salinity_measurement, salinity_notes, sep = ", "),
                                 NA),
         habitat = case_when(vegetation_notes == "non-tidal pasture/grassland" ~ "upland", 
                             vegetation_notes == "Former tidal wetland, now in agriculture" ~ "marsh", # double check
                             T ~ habitat),
         salinity_method = recode(salinity_method, "groundwater well" = "measurement"),
         vegetation_notes = case_when(!is.na(vegetation_notes) ~ paste(vegetation_notes, species_notes, sep = "; "), 
                                      T ~ species_notes),
         core_notes = site_description) %>% 
  select(-c(project, impact_class, estuary, salinity_measurement, species_notes, site_description)) 

## ... Depthseries ####

# curate core depthseries data table
depthseries <- poppe_ds %>% 
  full_join(id_lookup) %>% select(-core_id, -PNWBCWG_id) %>% rename(core_id = new_core_id) %>% 
  select(study_id, site_id, core_id, everything()) %>% 
  mutate(study_id = id)

## ... Species ####

species <- poppe_species %>%   
  full_join(id_lookup) %>% select(-core_id, -PNWBCWG_id) %>% rename(core_id = new_core_id) %>% 
  rename(site_description = site_id) %>% 
  left_join(cores %>% distinct(site_id, site_description), multiple = "all") %>% 
  mutate(species_code = na_if(species_code, "None"),
         code_type = case_when(grepl("[.]", species_code) ~ "Genus",
                               is.na(species_code) ~ NA, 
                               T ~ "Genus species")) %>% 
  drop_na(species_code) %>% 
  select(study_id, site_id, core_id, species_code, code_type) 
  

## ... Sites ####

impacts <- poppe_cores %>% 
  full_join(id_lookup) %>% select(-core_id, -PNWBCWG_id) %>% rename(core_id = new_core_id) %>% 
  select(study_id, site_id, core_id, everything()) %>% 
  distinct(study_id, site_id, core_id, impact_class)

## 2. QAQC ####

## Mapping
leaflet(cores) %>%
  addTiles() %>% 
  addCircleMarkers(lng = ~longitude, lat = ~latitude, radius = 2, label = ~core_id)

## Table testing
table_names <- c("methods", "cores", "depthseries", "species", "impacts")

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
testIDs(cores, impacts, by = "core")

# test numeric attribute ranges
fractionNotPercent(depthseries)
testNumericCols(depthseries)

## 3. Write Curated Data ####

# write data to final folder
write_csv(methods, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_methods.csv")
# write_csv(sites, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_sites.csv")
write_csv(cores, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_cores.csv")
write_csv(depthseries, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_depthseries.csv")
write_csv(species, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_species.csv")
write_csv(impacts, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_impacts.csv")

## 4. Bibliography ####

library(RefManageR)

poppe_datapub <- as.data.frame(GetBibEntryWithDOI("10.25573/serc.27156465")) %>%
  mutate(study_id = "Poppe_et_al_2024",
         bibliography_id = "Poppe_et_al_2024_data",
         publication_type = "primary dataset") %>%
  select(-keywords)

# poppe_bib <- as.data.frame(ReadBib("data/primary_studies/Poppe_et_al_2024/original/Poppe_et_al_2024_associated_publications.bib")) %>%
#   mutate(study_id = "Poppe_et_al_2024",
#          bibliography_id = "Rogers_et_al_2019_article",
#          publication_type = "associated source")

study_citations <-  poppe_datapub %>% 
  # bind_rows(poppe_bib, poppe_datapub) %>%
  select(study_id, bibliography_id, everything()) %>%
  remove_rownames()

write_csv(study_citations, "data/primary_studies/Poppe_et_al_2024/derivative/Poppe_et_al_2024_study_citations.csv")
