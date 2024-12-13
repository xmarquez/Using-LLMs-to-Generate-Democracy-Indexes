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
  controller = crew::crew_controller_local(workers = 20, seconds_idle = 60)
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
      filter(!is.na(v2x_polyarchy))
  ),
  tar_target(
    name = vdem_post_1945,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy), year > 1945)
  ),
  tar_target(
    name = vdem_sample,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)) |>
      slice_sample(n = 1000)
  ),
  tar_group_count(
    name = vdem_grouped,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)),
    count = 3
  ),
  tar_group_by(
    name = vdem_grouped_country,
    command = vdemdata::vdem |>
      select(country_name:year, starts_with("v2x_polyarchy")) |>
      mutate(country = country_name) |>
      as_tibble() |>
      filter(!is.na(v2x_polyarchy)),
    country_id
  ),
  tar_target(
    name = prompt_files,
    command = here::here("prompts", unlist(prompt_files_df$prompt_filename)),
    format = "file"
  ),
  tar_eval(
    values = prompt_files_df |>
      filter(!str_detect(dataset_name, "vdem_grouped")),
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
    values = prompt_files_df |>
      filter(str_detect(dataset_name, "vdem_grouped")),
    tar_target(
      name = prompt,
      command = build_prompts_from_files(
        files = here::here("prompts", prompt_filename),
        roles = "user",
        api = api,
        data = dataset),
      pattern = map(dataset)
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(type == "single",
             api == "gemini",
             dataset_name == "vdem_grouped_country"),
    tar_target(
      name = responses,
      command = fun(
        prompts = prompt,
        model = model,
        prompt_name = prompt_name,
        rate_limit = 2,
        temperature = 0,
        max_tokens = 2000,
        json_mode = FALSE),
      pattern = map(prompt),
      error = "null"
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(type == "batch",
             dataset == "vdem",
             api %in% c("openai", "mistral")),
    tar_target(
      name = responses,
      command = fun(
        prompts = prompt,
        model = model,
        max_tokens = 2000),
      deployment = "main"
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(type == "batch",
             dataset_name == "vdem",
             api %in% c("openai", "mistral")),
    tar_target(
      name = responses_joined,
      command = extract_and_join(responses, dataset),
      deployment = "main",
      error = "continue"
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(str_detect(dataset_name, "vdem_grouped"),
             type == "batch"),
    tar_target(
      name = responses_joined,
      command = extract_and_join(responses, dataset),
      deployment = "main",
      error = "continue",
      pattern = map(responses, dataset)
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(str_detect(dataset_name, "vdem_grouped"),
             type == "single"),
    tar_target(
      name = responses_joined,
      command = extract_and_join_single(responses, dataset),
      pattern = map(responses, dataset)
    )
  ),
  tar_eval(
    values = responses_df |>
      filter(type == "batch",
             dataset_name == "vdem_grouped"),
    tar_target(
      name = responses,
      command = fun(
        prompts = prompt,
        model = model,
        max_tokens = 2000),
      deployment = "main",
      pattern = map(prompt, dataset),
      iteration = "list"
    )
  ),
  tar_target(
    name = combined_responses,
    command = dplyr::bind_rows(!!!responses_df$responses_joined[
      responses_df$api %in% c("openai", "mistral", "claude", "gemini") &
        responses_df$dataset_name != "fh"]) |>
      filter(!is.na(model)) |>
      left_join(responses_df |>
                  ungroup() |>
                  select(model, api, type, dataset_name) |>
                  rename(api_name = api,
                         api_type = type) |>
                  filter(dataset_name != "fh") |>
                  mutate(model = case_when(model == "gpt-4o" ~ "gpt-4o-2024-08-06",
                                           model == "gpt-4o-mini" ~ "gpt-4o-mini-2024-07-18",
                                           TRUE ~ model))),
    deployment = "main"
  ),
  tar_target(
    name = combined_responses_wide,
    command = combined_responses  |>
      select(all_of(c("country", "year", "country_id",
                      "model", "v2x_polyarchy",
                      "v2x_polyarchy_codelow",
                      "v2x_polyarchy_codehigh", "v2x_polyarchy_sd",
                      "response", "score"))) |>
      pivot_wider(id_cols = c("country", "year", "country_id",
                              "v2x_polyarchy", "v2x_polyarchy_codelow",
                              "v2x_polyarchy_codehigh", "v2x_polyarchy_sd"),
                  names_from = "model",
                  values_from = c(score, response)) |>
      janitor::clean_names(),
    deployment = "main"
  ),
  tar_target(
    name = correlations,
    command = combined_responses_wide |>
      select(v2x_polyarchy, starts_with("score")) |>
      as.matrix() |>
      Hmisc::rcorr(),
    deployment = "main"
  ),
  tar_target(
    name = combined_responses_summary,
    command = combined_responses |>
      group_by(country_id, country_text_id, country, year, v2x_polyarchy,
               v2x_polyarchy_codelow, v2x_polyarchy_codehigh, v2x_polyarchy_sd) |>
      summarise(n = sum(!is.na(score)),
                score = list(Hmisc::smean.cl.boot(score) |>
                               as_tibble_row())) |>
      unnest(score) |>
      ungroup(),
    deployment = "main"
  ),
  tar_target(
    name = rmse_per_year_summary,
    command = combined_responses_summary |>
      group_by(year) |>
      summarise(rmse = sqrt(sum((v2x_polyarchy-Mean)^2)),
                n = n())
  ),
  tar_url(
    name = model_costs_url,
    command = "https://raw.githubusercontent.com/BerriAI/litellm/refs/heads/main/model_prices_and_context_window.json"
  ),
  tar_target(
    name = model_costs,
    command = load_model_costs(model_costs_url),
    deployment = "main"
  ),
  tar_target(
    name = estimated_costs,
    command = estimate_costs(combined_responses, model_costs),
    deployment = "main"
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
