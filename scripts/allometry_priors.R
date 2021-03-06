library(PEcAn.allometry)
library(dplyr)
library(RPostgres)
library(purrr)
library(tidyr)

bety <- dbConnect(
  Postgres(),
  dbname = "bety",
  user = "bety",
  password = "bety",
  host = "localhost",
  port = 7990
)

ed_modeltype <- 1
used_pfts <- c(
  "temperate.Early_Hardwood",
  "temperate.North_Mid_Hardwood",
  "temperate.Late_Hardwood",
  "temperate.Northern_Pine",
  "temperate.Southern_Pine",
  "temperate.Mid_conifer",
  "temperate.Late_Conifer"
)

ed_pft_species <- tbl(bety, "species") %>%
  select(species.id = id, SpeciesCode = AcceptedSymbol, spcd) %>%
  inner_join(
    tbl(bety, "pfts_species") %>%
      select(species.id = specie_id, pft.id = pft_id)
  ) %>%
  inner_join(
    tbl(bety, "pfts") %>%
      filter(modeltype_id == ed_modeltype, name %in% used_pfts) %>%
      select(pft.id = id, pft.name = name)
  ) %>%
  filter(SpeciesCode != "") %>%
  select(SpeciesCode, pft.name, bety_species_id = species.id, spcd) %>%
  collect(n = Inf)


pft_nested <- ed_pft_species %>%
  filter(!is.na(spcd)) %>%
  group_by(pft.name) %>%
  select(pft.name, acronym = SpeciesCode, spcd) %>%
  nest()

pft_list <- pft_nested$data %>% setNames(pft_nested$pft.name)

data(allom.components)
allom.components

outdir <- "zAllom_results"
dir.create(outdir, showWarnings = FALSE)

# component 18 -- Foliage total
allom_stats <- AllomAve(pft_list, components = 18, outdir = outdir)
saveRDS(allom_stats, "priors/allometry_stats.rds")

# Component 16 -- Wood (stem + branches)
wood_allom_stats <- AllomAve(pft_list, components = 16, outdir = outdir)
saveRDS(wood_allom_stats, "priors/wood_allometry_stats.rds")
