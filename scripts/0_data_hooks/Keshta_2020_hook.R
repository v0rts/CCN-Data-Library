# CCRCN Data Library hook script
# contact: Jaxine Wolfe, wolfejax@si.edu

# Dataset: Soil Redox and Hydropattern control Soil Carbon Stocks across different habitats in Tidal Freshwater Wetlands in a Sub-estuary of the Chesapeake Bay
# Authors: Amr E. Keshta, Stephanie A. Yarwood, and Andrew H. Baldwin.
# DOI: 10.25573/serc.13187549

# load libs
library(tidyverse)
library(RefManageR)
# library(lubridate)

source("./scripts/1_data_formatting/qa_functions.R")

# load data
cores_raw <- read.csv("./data/primary_studies/Keshta_et_al_2020/original/Keshta_et_al_2020_cores.csv")
depthseries_raw <- read.csv("./data/primary_studies/Keshta_et_al_2020/original/Keshta_et_al_2020_depthseries.csv")
species_raw <- read_csv("./data/primary_studies/Keshta_et_al_2020/original/Keshta_et_al_2020_species.csv")
methods_raw <- read_csv("./data/primary_studies/Keshta_et_al_2020/original/Keshta_et_al_2020_material_and_methods.csv")
study_citations_raw <- read_csv("./data/primary_studies/Keshta_et_al_2020/original/Keshta_et_al_2020_study_citations.csv")

## Trim Data to Library ####

id <- "Keshta_et_al_2020"

# cores uncontrolled: 
# core_length, habitat (keep habitat, it will be included in V2 guidance)
cores <- cores_raw %>% select(-core_length) %>%
  mutate(study_id = id)

# depthseries uncontrolled: 
# total_carbon_stock, soil_moisture
depthseries <- depthseries_raw %>%
  mutate(method_id = ifelse(study_id == "Keshta_et_al_2020_a", 
                            "wetland cores", "upland cores")) %>%
  mutate(study_id = id) %>%
  select(-c(total_carbon_stock, soil_moisture, fraction_carbon)) %>%
  reorderColumns("depthseries", .)

# methods (no change)
methods <- methods_raw %>%
  mutate(study_id = id) %>%
  mutate(method_id = ifelse(coring_method == "russian corer", 
                            "wetland cores", "upland cores")) %>%
  reorderColumns("methods", .)

# species uncontrolled:
# genus species
# transfer habitats from cores table
habitats <- cores %>% distinct(core_id, habitat) 

species <- species_raw %>%
  mutate(species_code = paste(genus, species, sep=" "),
         code_type = "Genus species",
         study_id = id) %>%
  left_join(habitats) %>%
  select(-genus, -species)
# species already has habitat and code_type => doesn't need update

## 2. Create Citations ####

pub_bib <- GetBibEntryWithDOI("10.1111/rec.13437")
pub_citation <- as.data.frame(pub_bib) %>%
  mutate(study_id = id) %>%
  mutate(bibliography_id = paste0("Keshta_et_al_", year, "_article"),
         publication_type = "associated source") %>%
  remove_rownames()

study_citations <- study_citations_raw %>% 
  mutate(study_id = id) %>% distinct() %>%
  mutate(publication_type = recode(publication_type,
                                   "primary" = "primary dataset",
                                   "associated" = "associated source"),
         year = as.character(year)) %>% 
  bind_rows(pub_citation)

# Write .bib file
bib_file <- study_citations %>%
  select(-study_id, -publication_type) %>%
  distinct() %>%
  column_to_rownames("bibliography_id")

WriteBib(as.BibEntry(bib_file), "data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020.bib")
write_csv(study_citations, "./data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020_study_citations.csv")

# Update Tables ###########
source("./scripts/1_data_formatting/versioning_functions.R")

table_names <- c("methods", "cores", "depthseries", "species")

updated <- updateTables(table_names)

# save listed tables to objects

# sites <- updated$sites
methods <- updated$methods
depthseries <- updated$depthseries
cores <- updated$cores
species <- updated$species

## QA/QC ###############

writeQualityReport(id)

# test cols and vars
# testTableCols(table_names)
# testTableVars(table_names)
# testRequired(table_names) # not working, needs investigation
# 
# test_unique_cores(cores)
# test_unique_coords(cores)
# test_core_relationships(cores, depthseries)
# fraction_not_percent(depthseries)
# test_depthseries <- test_numeric_vars(depthseries)

## Write derivative data ####
write_csv(cores, "./data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020_cores.csv")
write_csv(species, "./data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020_species.csv")
write_csv(methods, "./data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020_methods.csv")
write_csv(depthseries, "./data/primary_studies/Keshta_et_al_2020/derivative/Keshta_et_al_2020_depthseries.csv")
