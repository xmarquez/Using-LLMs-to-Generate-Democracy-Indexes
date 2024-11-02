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
  # format = "qs", # Optionally set the default storage format. qs is fast.
  #
  # Pipelines that take a long time to run may benefit from
  # optional distributed computing. To use this capability
  # in tar_make(), supply a {crew} controller
  # as discussed at https://books.ropensci.org/targets/crew.html.
  # Choose a controller that suits your needs. For example, the following
  # sets a controller that scales up to a maximum of two workers
  # which run as local R processes. Each worker launches when there is work
  # to do and exits if 60 seconds pass with no tasks to run.
  #
  # controller = crew::crew_controller_local(workers = 6, seconds_idle = 60)
  #
  # Alternatively, if you want workers to run on a high-performance computing
  # cluster, select a controller from the {crew.cluster} package.
  # For the cloud, see plugin packages like {crew.aws.batch}.
  # The following example is a controller for Sun Grid Engine (SGE).
  #
  #   controller = crew.cluster::crew_controller_sge(
  #     # Number of workers that the pipeline can scale up to:
  #     workers = 10,
  #     # It is recommended to set an idle time so workers can shut themselves
  #     # down if they are not running tasks.
  #     seconds_idle = 120,
  #     # Many clusters install R as an environment module, and you can load it
  #     # with the script_lines argument. To select a specific verison of R,
  #     # you may need to include a version string, e.g. "module load R/4.3.2".
  #     # Check with your system administrator if you are unsure.
  #     script_lines = "module load R"
  #   )
  #
  # Set other options as needed.
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source()
# tar_source("other_functions.R") # Source other scripts as needed.

# Replace the target list below with your own:
list(
  tar_target(
    name = fh,
    command = democracyData::download_fh(verbose = FALSE) |>
      mutate(country = fh_country)
  ),
  tar_target(
    name = vdem,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)) |>
      slice_sample(n = 2000)
  ),
  tar_target(
    name = prompt_files,
    command = here::here("prompts", unlist(prompt_files_df$prompt_filename)),
    format = "file"
  ),
  tar_eval(
    values = prompt_files_df,
    tar_target(
      name = prompt,
      command = build_prompts_from_files(
        files = here::here("prompts", prompt_filename),
        roles = "user",
        api = api,
        data = dataset)
    )
  ),
  tar_eval(
    values = responses_df,
    tar_target(
      name = responses,
      command = call_api(
        prompts = prompt,
        model = model,
        prompt_name = prompt_name,
        rate_limit = 2,
        temperature = 0,
        max_tokens = 2000,
        json_mode = FALSE)  |>
        select(where(\(x) !all(is.na(x)))),
      pattern = map(prompt)
    )
  ),
  tar_eval(
    values = responses_df,
    tar_target(
      name = responses_joined,
      command = responses |>
        bind_cols(dataset) |>
        mutate(score = str_extract(
          response,
          "(?<=\\\\?<democracy\\\\?>)([0-9]*\\.?[0-9]+)(?=\\\\?<(/)?democracy\\\\?>)") |>
            as.numeric()) |>
        select(-starts_with("max_"), -litellm_provider,
               -mode, -starts_with("supports_"),
               -starts_with("tool"), -input_cost,
               -output_cost, -total_cost,
               -contains("_details"))
    )
  ),
  tar_target(
    name = combined_responses,
    command = dplyr::bind_rows(!!!responses_df$responses_joined),
    deployment = "main"
  ),
  tar_target(
    name = combined_responses_wide,
    command = combined_responses  |>
      pivot_wider(id_cols = c("prompt_id", "country", "year", "country_id",
                              "v2x_polyarchy", "v2x_polyarchy_codelow",
                              "v2x_polyarchy_codehigh", "v2x_polyarchy_sd"),
                  names_from = "model",
                  values_from = c(score, response)) |>
      janitor::clean_names()
  ),
  tar_target(
    name = correlations,
    command = combined_responses_wide |>
      select(v2x_polyarchy, starts_with("score")) |>
      as.matrix() |>
      Hmisc::rcorr()
  ),
  tar_target(
    name = combined_responses_summary,
    command = combined_responses |>
      group_by(country_id, country_text_id, country, year, v2x_polyarchy) |>
      summarise(n = sum(!is.na(score)),
                score = list(Hmisc::smean.cl.boot(score) |>
                               as_tibble_row())) |>
      unnest(score) |>
      ungroup()
  ),
  tar_target(
    name = estimated_costs,
    command = combined_responses |>
      group_by(api) |>
      summarise(est_input_cost = sum(input_tokens*input_cost_per_token, na.rm = TRUE),
                est_output_cost = sum(output_tokens*output_cost_per_token, na.rm = TRUE),
                est_total_cost = est_input_cost + est_output_cost)
  ),
  tar_target(
    name = rmse_per_year_summary,
    command = combined_responses_summary |>
      group_by(year) |>
      summarise(rmse = sqrt(sum((v2x_polyarchy-Mean)^2)),
                n = n())
  ),
  tar_target(
    name = rmse_per_country_summary,
    command = combined_responses_summary |>
      group_by(country) |>
      summarise(rmse = sqrt(sum((v2x_polyarchy-Mean)^2)),
                n = n()) |>
      arrange(rmse)
  ),
  tar_target(
    name = rmse_per_model,
    command = combined_responses |>
      filter(!is.na(score)) |>
      group_by(model) |>
      summarise(rmse = sqrt(sum((v2x_polyarchy-score)^2)),
                n = n()) |>
      arrange(rmse)
  ),
  tar_target(
    name = rmse_per_model_country,
    command = combined_responses |>
      filter(!is.na(score)) |>
      group_by(country, model) |>
      summarise(rmse = sqrt(sum((v2x_polyarchy-score)^2)),
                n = n()) |>
      arrange(rmse)
  )
)
