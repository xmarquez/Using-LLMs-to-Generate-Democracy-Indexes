load_model_costs <- function(url) {
  res <- jsonlite::fromJSON(url) |>
    purrr::map(\(x) tibble::as_tibble_row(x) |>
                 dplyr::mutate(dplyr::across(dplyr::everything(), as.character))) |>
    purrr::list_rbind(names_to = "model") |>
    dplyr::filter(model != "sample_spec") |>
    dplyr::mutate(dplyr::across(dplyr::matches("max_|cost_|output_vector_size"), as.numeric),
                  dplyr::across(dplyr::matches("supports"), as.logical))
  res |>
    select(model, source, litellm_provider, input_cost_per_token, output_cost_per_token) |>
    mutate(model = str_remove(model, ".+/")) |>
    filter(litellm_provider %in% c("anthropic", "gemini", "groq", "openai", "mistral")) |>
    distinct()

}

models_df <- bind_rows(
  expand_grid(
    api = "groq",
    model = c("llama3-8b-8192",
              "llama3-70b-8192",
              "llama-3.1-8b-instant"),
    type = "single",
    fun = "call_api"),
  expand_grid(
    api = "llamafile",
    model = c("Llama-3.2-1B-Instruct.Q6_K",
              "Llama-3.2-3B-Instruct.Q6_K",
              "gemma-2-2b-it.Q6_K"),
    type = "single",
    fun = "call_api"),
  expand_grid(
    api = "mistral",
    model = c(
      "mistral-small-latest",
      "ministral-8b-latest",
      "mistral-medium-latest",
      "open-mixtral-8x7b"
    ),
    type = "batch",
    fun = "call_batch_api"),
  expand_grid(
    api = "claude",
    model = c(
      # "claude-3-5-sonnet-20241022",
      "claude-3-haiku-20240307"
    ),
    type = "batch",
    fun = "call_batch_api"),
  expand_grid(
    api = "openai",
    model = c(
      "gpt-4o",
      "gpt-4o-mini"
    ),
    type = "batch",
    fun = "call_batch_api"),
  expand_grid(
    api = "gemini",
    model = c(
      # "gemini-1.5-pro-latest",
      "gemini-1.5-flash-latest"
    ),
    type = "single",
    fun = "call_api")
)

prompt_names <- c("democracy_simple")

dataset_names <- c("vdem")

api_names <- c(
  "claude",
  "openai",
  "mistral",
  "groq",
  "gemini",
  "llamafile"
  )

prompt_files_df <- expand_grid(
    api = api_names,
    prompt_name = prompt_names,
    dataset_name = dataset_names,
    prompt_type = c("user")) |>
  mutate(prompt_filename = paste(api, prompt_name, prompt_type, "prompt.md", sep = "_"),
         prompt = paste("prompt", api, prompt_name, dataset_name, sep = "_") |>
           rlang::syms(),
         dataset_name = case_when(api == "groq" & dataset_name == "vdem" ~ "vdem_sample",
                                  api == "claude" & dataset_name == "vdem" ~ "vdem_grouped",
                                  api == "gemini" & dataset_name == "vdem" ~ "vdem_grouped_country",
                                  TRUE ~ dataset_name),
         dataset = dataset_name |>
           rlang::syms()) |>
  group_by(prompt, api, prompt_name, dataset_name, dataset) |>
  summarise(prompt_type = list(prompt_type), prompt_filename = list(prompt_filename))

responses_df <- prompt_files_df |>
  inner_join(models_df, relationship = "many-to-many") |>
  mutate(responses = paste("responses", prompt_name, dataset_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms(),
         responses_joined = paste("responses_joined", prompt_name, dataset_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms(),
         batch_download_fun = case_when(type == "batch" ~ paste(api, "poll_and_retrieve", sep = "_")))

extract_and_join <- function(response, dataset) {
  response <- poll_and_download(response, quiet = TRUE)

  dataset$id <- 1:nrow(dataset) |>
    as.character()

  dataset <- dataset |>
    left_join(response, by = join_by(id)) |>
    mutate(score = stringr::str_extract(
      response,
      "(?<=.?\\<.?democracy.?\\>)(0(?:\\.\\d+)?|1(?:\\.0+)?)(?=.?\\<)"
    ) |>
      as.numeric())

  dataset

}

extract_and_join_single <- function(response, dataset) {
  dataset$id <- 1:nrow(dataset) |>
    as.character()

  dataset <- dataset |>
    left_join(response, by = join_by(id)) |>
    unnest(response) |>
    mutate(score = stringr::str_extract(
      response,
      "(?<=.?\\<.?democracy.?\\>)(0(?:\\.\\d+)?|1(?:\\.0+)?)(?=.?\\<)"
    ) |>
      as.numeric())

  dataset

}

estimate_costs <- function(df, model_costs) {
  res <- df |>
    left_join(model_costs) |>
    select(where(\(x) !all(is.na(x)))) |>
    group_by(model) |>
    mutate(across(ends_with("_cost_per_token"), \(x) case_when(api_type == "batch" ~ x/2,
                                                               TRUE ~ x)),
           input_tokens = case_when(api_name %in% c("openai", "mistral") ~ prompt_tokens,
                                    TRUE ~ input_tokens),
           output_tokens = case_when(api_name %in% c("openai", "mistral") ~ completion_tokens,
                                    TRUE ~ output_tokens),
           input_cost_per_token = case_when(model == "mistral-small-latest" ~ 0.2/2000000,
                                            TRUE ~ input_cost_per_token),
           output_cost_per_token = case_when(model == "mistral-small-latest" ~ 0.6/2000000,
                                             TRUE ~ output_cost_per_token),
           input_cost_per_token = case_when(model == "ministral-8b-latest" ~ 0.1/2000000,
                                            TRUE ~ input_cost_per_token),
           output_cost_per_token = case_when(model == "ministral-8b-latest" ~ 0.1/2000000,
                                            TRUE ~ output_cost_per_token)) |>
    summarise(
      api_type = unique(api_type),
      input_cost = sum(input_tokens*input_cost_per_token, na.rm = TRUE),
      output_cost = sum(input_tokens*output_cost_per_token, na.rm = TRUE),
      total_cost = input_cost+output_cost,
      input_cost_per_token = unique(input_cost_per_token),
      output_cost_per_token = unique(output_cost_per_token),
      input_tokens = sum(input_tokens, na.rm = TRUE),
      output_tokens = sum(output_tokens, na.rm = TRUE),
      total_tokens = input_tokens + output_tokens)
  res
}
