library(PEcAn.ED2)
library(PEcAn.data.atmosphere)
library(here)
library(tibble)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)

PEcAn.logger::logger.setLevel("DEBUG")

############################################################
# User configuration
root <- here()
site_dir <- normalizePath("sites")
#root <- normalizePath("~/Projects/nasa-rtm/edr-da")

############################################################
# Additional paths (should be relative, so no user config required)
inputs_dir <- file.path(root, "ed-inputs")
edi_dir <- file.path(inputs_dir, "EDI")
pda_dir <- file.path(root, "ed-outputs", "multi_site_pda")
dir.create(pda_dir, showWarnings = FALSE)

############################################################
# Load site data
sites <- tibble(files = list.files(site_dir)) %>%
  mutate(
    years = map(file.path(site_dir, files), list.files) %>%
      map(~str_match(., "^FFT.([[:digit:]]+)")[,2]) %>%
      map_dbl(~unique(as.numeric(.)) %>% tail(1)),
    prefixes = file.path(site_dir, files, paste0("FFT.", years, ".")),
    veg = map(prefixes, read_ed_veg),
    latitude = map_dbl(veg, "latitude"),
    longitude = map_dbl(veg, "longitude"),
    GFDL_lat = floor(floor(latitude) / 2) + 45 + 1,
    GFDL_lon = floor(floor(longitude) / 2.5) + 1,
    GFDL_dir = file.path(pda_dir, paste("met", GFDL_lat, GFDL_lon, "GFDL", sep = "_")),
    CRUNCEP_dir = file.path(pda_dir, paste("met", latitude, longitude, "CRUNCEP", sep = "_"))
  )

############################################################
# Download meteorology data
start_run <- "2006-07-01"
end_run <- "2006-07-14"

met_data <- sites %>%
  mutate(
    met = pmap(
      list(
        lat.in = latitude,
        lon.in = longitude,
        outfolder = CRUNCEP_dir
      ),
      get_cruncep,
      start_run = start_run,
      end_run = end_run
    )
  )

############################################################
# Convert met to ED format
ed_met_dat <- met_data %>%
  mutate(
    rundir = file.path(pda_dir, files),
    full_name = map_chr(met, "file"),
    ed_met = pmap(
      list(
        rundir = rundir,
        full_name = full_name,
        latitude = latitude,
        longitude = longitude
      ),
      met2ed,
      overwrite = TRUE
    )
  )

############################################################
# Set global ED2IN settings
ed2in <- read_ed2in(system.file("ED2IN.rgit", package = "PEcAn.ED2")) %>%
  modify_ed2in(
    run_name = "EDR multi-site PDA",
    EDI_path = edi_dir,
    output_types = "all",
    runtype = "INITIAL"
  )

############################################################
# Set site-specific ED2IN settings
site_ed2in <- ed_met_dat %>%
  mutate(
    ed2in = pmap(
      list(
        latitude = latitude,
        longitude = longitude,
        start_date = map(ed_met, "startdate"),
        end_date = map(ed_met, "enddate"),
        met_driver = map(ed_met, "file"),
        run_dir = rundir,
        output_dir = file.path(rundir, "output"),
        veg_prefix = prefixes
      ),
      modify_ed2in,
      ed2in = ed2in
    ),
    ed2in_path = file.path(rundir, "ED2IN")
  )

############################################################
# Check ED2IN validity and write to file
checks <- map_lgl(site_ed2in$ed2in, possibly(check_ed2in, FALSE, quiet = FALSE))
walk2(site_ed2in$ed2in, site_ed2in$ed2in_path, write_ed2in)

############################################################
# Run ED at each site
#img_path <- "~/Projects/ED2/ed2.simg"
walk(site_ed2in$ed2in_path, ~system2("/projectnb/dietzelab/ashiklom/ED2/ED/build/ed_2.1-dbg", c("-f", .)))
#walk(site_ed2in$ed2in_path, ~run_ed_singularity(img_path, ed2in_path = .))
