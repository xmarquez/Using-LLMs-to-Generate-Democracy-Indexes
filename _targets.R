# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes) # Load other packages as needed.
library(tidyverse)

# Set target options:
tar_option_set(
  packages = c("R.AI", "tidyverse"), # Packages that your targets need for their tasks.
  imports = c("R.AI"),
  controller = crew::crew_controller_local(
    workers = 20, seconds_idle = 60,
    options_local = crew::crew_options_local(
      log_directory = "crew-log", log_join = TRUE)
    )
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source()
# tar_source("other_functions.R") # Source other scripts as needed.

# Common Definitions

common_targets <- list(
  # Dataset definitions -----
  tar_target(
    name = vdem,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)),
    description = "The V-Dem dataset, complete"
  ),
  tar_target(
    name = vdem_post_1945,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy), year > 1945),
    description = "The V-Dem dataset, post 1945"
  ),
  tar_target(
    name = vdem_sample,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)) |>
      slice_sample(n = 4000),
    description = "The V-Dem dataset, random sample"
  ),
  tar_target(
    name = vdem_sample_post_1945,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy), year > 1945) |>
      slice_sample(n = 5000),
    description = "The V-Dem dataset, random sample, post_1945"
  ),
  tar_group_count(
    name = vdem_sample_post_1945_claude,
    command = vdem_sample_post_1945 |>
      slice_sample(n = 5000),
    count = 2,
    description = "The V-Dem dataset, random sample, post_1945, Claude only"
  ),
  tar_group_count(
    name = vdem_grouped,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)),
    count = 3,
    description = "The V-Dem dataset, entire, in 3 groups, for use with the Claude batch API"
  ),
  tar_group_count(
    name = vdem_grouped_post_1945,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy), year > 1945),
    count = 2,
    description = "The V-Dem dataset, post 1945, in 2 groups, for use with the batch APIs"
  ),
  tar_group_count(
    name = vdem_grouped_post_1945_4_groups,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy), year > 1945),
    count = 4,
    description = "The V-Dem dataset, post 1945, in 4 groups, for use with the Claude batch API"
  ),
  tar_group_by(
    name = vdem_grouped_country,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)),
    country_id,
    description = "The V-Dem dataset, grouped by country"
  ),
  # Estimated Costs Data -----------------------------
  tar_url(
    name = model_costs_url,
    command = "https://raw.githubusercontent.com/BerriAI/litellm/refs/heads/main/model_prices_and_context_window.json"
  ),
  tar_target(
    name = model_costs,
    command = load_model_costs(model_costs_url),
    deployment = "main"
  )
)


c(common_targets, experiment_1, experiment_2, experiment_3)
