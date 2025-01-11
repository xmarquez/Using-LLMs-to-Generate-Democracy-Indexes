library(tidyverse)
library(mirt)
# Experiment 1: Replicating the V-Dem Polyarchy Score by aggregating multiple models.

# First we set up the models to be used:

experiment_1_models_df <- bind_rows(
  expand_grid(
    api = "cerebras",
    model = c("llama-3.3-70b",
              "llama3.1-8b"),
    type = "single",
    fun = "call_api",
    dataset_name = "vdem_sample"),
  expand_grid(
    api = "deepseek",
    model = c("deepseek-chat"),
    type = "single",
    fun = "call_api",
    dataset_name = "vdem_grouped_country"),
  expand_grid(
    api = "qwen",
    model = c("qwen-plus"),
    type = "single",
    fun = "call_api",
    dataset_name = "vdem_sample"),
  expand_grid(
    api = "groq",
    model = c("gemma2-9b-it"),
    type = "single",
    fun = "call_api",
    dataset_name = "vdem_sample"),
  expand_grid(
    api = "mistral",
    model = c(
      "mistral-small-latest",
      "ministral-8b-latest",
      "mistral-medium-latest",
      "open-mixtral-8x7b"
    ),
    type = "batch",
    fun = "call_batch_api",
    dataset_name = "vdem"),
  expand_grid(
    api = "claude",
    model = c(
      # "claude-3-5-haiku-latest",
      # "claude-3-5-sonnet-20241022",
      "claude-3-haiku-20240307"
    ),
    type = "batch",
    fun = "call_batch_api",
    dataset_name = "vdem_grouped"),
  expand_grid(
    api = "openai",
    model = c(
      "gpt-4o",
      "gpt-4o-mini"
    ),
    type = "batch",
    fun = "call_batch_api",
    dataset_name = "vdem"),
  expand_grid(
    api = "gemini",
    model = c(
      # "gemini-1.5-pro-latest",
      "gemini-1.5-flash-latest"
    ),
    type = "single",
    fun = "call_api",
    dataset_name = "vdem_grouped_country")
) |>
  mutate(prompt_name = "democracy_simple",
         prompt_filename = "democracy_simple_user_prompt.md",
         prompt = paste("prompt", api, prompt_name, dataset_name, sep = "_") |>
           rlang::syms(),
         dataset = dataset_name |>
           rlang::syms(),
         responses = paste("responses", prompt_name, dataset_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms(),
         responses_joined = paste("responses_joined", prompt_name, dataset_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms(),
         batch_download_fun = case_when(type == "batch" ~ paste(api, "poll_and_retrieve", sep = "_")))

experiment_1_irt_model_calculate <- function(data) {
  df_mirt <- data |>
    select(starts_with("score_")) |>
    mutate(across(everything(), ~ as.integer(. * 10 + 1)))

  irt_model <- mirt(data = df_mirt,
                    model = 1,             # 1-factor model
                    itemtype = "gpcm",     # or 'graded'
                    SE = TRUE, SE.type = "sandwich", method = "EM")
  irt_model
}

experiment_1_irt_discrimination <- function(irt_model) {

  res <- coef(irt_model, IRTpars = TRUE, as.data.frame = TRUE) |>
    as_tibble(rownames = "model") |>
    separate_wider_delim(model, delim = ".", names = c("model", "param")) |>
    filter(param == "a")

  res |>
    select(-param)
}

experiment_1_irt_cutpoints <- function(irt_model) {

  res <- coef(irt_model, IRTpars = TRUE, as.data.frame = TRUE) |>
    as_tibble(rownames = "model") |>
    separate_wider_delim(model, delim = ".", names = c("model", "param")) |>
    filter(param != "a")

  res
}

experiment_1_irt_scores <- function(irt_model, combined_responses_wide) {
  scores <- mirt::fscores(irt_model, full.scores.SE = TRUE) |>
    as_tibble()

  combined_responses_wide |>
    select(country, year, country_id, starts_with("v2x_")) |>
    bind_cols(scores) |>
    mutate(F1_upper = F1 + 1.96*SE_F1,
           F1_lower = F1 - 1.96*SE_F1,
           irt_score = pnorm(F1),
           irt_score_upper = pnorm(F1_upper),
           irt_score_lower = pnorm(F1_lower))
}


experiment_1 <- list(

    # Prompt creation -------------------

    tar_target(
      name = experiment_1_prompt_filenames,
      command = here::here("prompts", unlist(experiment_1_models_df |>
                                               distinct(prompt_filename) |>
                                               pull(prompt_filename))),
      format = "file",
      description = "Prompt files for experiment 1: Reproducing the VDem Polyarchy score"
    ),
    tar_eval(
      values = experiment_1_models_df |>
        filter(!str_detect(dataset_name, "vdem_grouped")) |>
        distinct(api, dataset, prompt, prompt_filename),
      tar_target(
        name = prompt,
        command = format_chat(
          api = api,
          user = experiment_1_prompt_filenames,
          data = dataset)
      )
    ),
    tar_eval(
      values = experiment_1_models_df |>
        filter(str_detect(dataset_name, "vdem_grouped")) |>
        distinct(api, dataset, prompt, prompt_filename),
      tar_target(
        name = prompt,
        command = format_chat(
          api = api,
          user = experiment_1_prompt_filenames,
          data = dataset),
        pattern = map(dataset)
      )
    ),

    # Raw responses ----------------------------------
    tar_eval(
      values = experiment_1_models_df |>
        filter(type == "single"),
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
        error = "null",
        description = "Raw responses for APIs without batching",
        cue = tar_cue("never", depend = FALSE, seed = FALSE, command = FALSE)
      )
    ),
    tar_eval(
      values = experiment_1_models_df |>
        filter(type == "batch",
               dataset_name == "vdem",
               api %in% c("openai", "mistral")),
      tar_target(
        name = responses,
        command = fun(
          prompts = prompt,
          model = model,
          max_tokens = 2000),
        deployment = "main",
        description = "Raw responses for batch APIs with large file limits - OpenAI and Mistral",
        cue = tar_cue("never", depend = FALSE, seed = FALSE, command = FALSE)
      )
    ),
    tar_eval(
      values = experiment_1_models_df |>
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
        iteration = "list",
        description = "Raw responses for batch APIs with lower file limits - Claude",
        cue = tar_cue("never", depend = FALSE, seed = FALSE, command = FALSE)
      )
    ),

    # Joined responses ----------------------------------

    tar_eval(
      values = experiment_1_models_df |>
        filter(type == "batch",
               dataset_name == "vdem",
               api %in% c("openai", "mistral")),
      tar_target(
        name = responses_joined,
        command = extract_and_join(responses, dataset),
        deployment = "main",
        error = "continue",
        description = "Joined responses for batch APIs with higher file limits - OpenAI and Mistral",
        cue = tar_cue("never", depend = FALSE, seed = FALSE)
      )
    ),
    tar_eval(
      values = experiment_1_models_df |>
        filter(str_detect(dataset_name, "vdem_grouped"),
               type == "batch"),
      tar_target(
        name = responses_joined,
        command = extract_and_join(responses, dataset),
        deployment = "main",
        error = "continue",
        pattern = map(responses, dataset),
        description = "Joined responses for batch APIs with lower file limits - Claude",
        cue = tar_cue("never", depend = FALSE, seed = FALSE)
      )
    ),

    tar_eval(
      values = experiment_1_models_df |>
        filter(str_detect(dataset_name, "vdem_grouped"),
               type == "single"),
      tar_target(
        name = responses_joined,
        command = extract_and_join_single(responses, dataset),
        pattern = map(responses, dataset),
        description = "Joined responses for non-batch APIs - Gemini",
        cue = tar_cue("never", depend = FALSE, seed = FALSE),
      )
    ),

    tar_eval(
      values = experiment_1_models_df |>
        filter(str_detect(dataset_name, "vdem_sample"),
               type == "single"),
      tar_target(
        name = responses_joined,
        command = extract_and_join_single(responses |>
                                            dplyr::mutate(id = as.character(id)), dataset),
        pattern = map(responses, dataset),
        description = "Joined responses for non-batch APIs - Cerebras, Groq, Qwen, Deepseek",
        priority = 0.5
      )
    ),

    # Combined Responses ---------------------------------------
    tar_target(
      name = experiment_1_combined_responses,
      command = dplyr::bind_rows(!!!experiment_1_models_df$responses_joined) |>
        filter(!is.na(model)) |>
        select(country_name:model, response, score) |>
        democracyData::country_year_coder(country_name, year,
                                          include_in_output = "extended_country_name",
                                          verbose = FALSE) |>
        relocate(extended_country_name, country, .before = everything()) |>
        select(-country_name)
        ,
      deployment = "main"
    ),
    tar_target(
      name = experiment_1_combined_responses_tokens,
      command = dplyr::bind_rows(!!!experiment_1_models_df$responses_joined) |>
        filter(!is.na(model)) |>
        select(model, api, contains("tokens"))  |>
        mutate(input_tokens = case_when(!is.na(input_tokens) ~ input_tokens, TRUE ~ prompt_tokens),
               output_tokens = case_when(!is.na(output_tokens) ~ output_tokens, TRUE ~ prompt_tokens)) |>
        group_by(model, api) |>
        reframe(n_prompts = n(),
                  input_tokens = sum(input_tokens, na.rm = TRUE),
                  output_tokens = sum(output_tokens, na.rm = TRUE),
                  total_tokens = input_tokens + output_tokens) |>
        mutate(api = case_when(is.na(api) & str_detect(model, "claude") ~ "claude",
                               is.na(api) & str_detect(model, "gpt-4o") ~ "openai",
                               is.na(api) & str_detect(model, "mistral|ministral|mixtral") ~ "mistral",
                               TRUE ~ api)) |>
        left_join(experiment_1_models_df |>
                    distinct(api, type)) |>
        mutate(api = case_when(str_detect(model, "claude") ~ "anthropic",
                               TRUE ~ api)) |>
        rename(api_type = type),
      deployment = "main"
    ),
    tar_target(
      name = experiment_1_combined_responses_wide,
      command = experiment_1_combined_responses  |>
        select(all_of(c("extended_country_name", "country", "year", "country_id",
                        "model", "v2x_polyarchy",
                        "v2x_polyarchy_codelow",
                        "v2x_polyarchy_codehigh", "v2x_polyarchy_sd",
                        "response", "score"))) |>
        pivot_wider(id_cols = c("extended_country_name", "country", "year", "country_id",
                                "v2x_polyarchy", "v2x_polyarchy_codelow",
                                "v2x_polyarchy_codehigh", "v2x_polyarchy_sd"),
                    names_from = "model",
                    values_from = c(score, response)) |>
        janitor::clean_names(),
      deployment = "main"
    ),
    tar_target(
      name = experiment_1_correlations,
      command = experiment_1_combined_responses_wide |>
        select(v2x_polyarchy, starts_with("score")) |>
        as.matrix() |>
        Hmisc::rcorr(),
      deployment = "main"
    ),
    tar_target(
      name = experiment_1_combined_responses_summary,
      command = experiment_1_combined_responses |>
        group_by(country_id, country_text_id, country, year, v2x_polyarchy,
                 v2x_polyarchy_codelow, v2x_polyarchy_codehigh, v2x_polyarchy_sd) |>
        summarise(n = sum(!is.na(score)),
                  score = list(Hmisc::smean.cl.boot(score) |>
                                 as_tibble_row())) |>
        unnest(score) |>
        ungroup(),
      deployment = "main"
    ),

    # IRT model --------
    tar_target(
      name = experiment_1_irt_model,
      command = experiment_1_irt_model_calculate(data = experiment_1_combined_responses_wide),
      deployment = "main"
    ),

    tar_target(
      name = experiment_1_irt_model_discrimination,
      command = experiment_1_irt_discrimination(experiment_1_irt_model),
      deployment = "main"
    ),

    tar_target(
      name = experiment_1_irt_model_cutpoints,
      command = experiment_1_irt_cutpoints(experiment_1_irt_model),
      deployment = "main"
    ),
    tar_target(
      name = experiment_1_irt_model_scores,
      command = experiment_1_irt_scores(experiment_1_irt_model, experiment_1_combined_responses_wide),
      deployment = "main"
    ),

    # Word embedding ---------------

    tar_group_by(
      name = embeddings_data,
      command = experiment_1_combined_responses |>
        mutate(id = paste(country_name, year)) |>
        filter(id %in% intersect(id[model == "qwen"],
                                 id[model == "gpt-4o-mini-2024-07-18"])),
      country_name
    ),

    tar_target(
      name = embeddings_responses,
      command = embeddings_data  |>
        group_by(model) |>
        reframe(country_name = country_name,
                year = year,
                embed = R.AI::format_character("openai", response) |>
                  R.AI::embed() |>
                  as.matrix()),
      pattern = map(embeddings_data)

    ),

    tar_target(
      name = embed_means,
      command = embeddings_responses |>
        group_by(model) |>
        summarise(embed_means = matrix(colMeans(embed), nrow = 1, ncol = 3072))
    ),

    # Estimated Costs -----------------------------
    tar_target(
      name = experiment_1_estimated_costs,
      command = estimate_costs(experiment_1_combined_responses_tokens, model_costs),
      deployment = "main"
    ),

    # Report ----------------------------------------
    tar_quarto(
      name = experiment_1_notebook,
      path = here::here("experiment-notebooks", "experiment-01.qmd"),
      cue = tar_cue("always")
    )
  )
