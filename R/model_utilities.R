load_model_costs <- function() {
  json_file <- "https://raw.githubusercontent.com/BerriAI/litellm/refs/heads/main/model_prices_and_context_window.json"
  res <- jsonlite::fromJSON(json_file) |>
    purrr::map(\(x) tibble::as_tibble_row(x) |>
                 dplyr::mutate(dplyr::across(dplyr::everything(), as.character))) |>
    purrr::list_rbind(names_to = "model") |>
    dplyr::filter(model != "sample_spec") |>
    dplyr::mutate(dplyr::across(dplyr::matches("max_|cost_|output_vector_size"), as.numeric),
                  dplyr::across(dplyr::matches("supports"), as.logical))
  res

}

models_df <- bind_rows(
  expand_grid(
    api = "groq",
    model = c("llama3-8b-8192",
              "llama3-70b-8192",
              "llama-3.1-8b-instant",
              "mixtral-8x7b-32768",
              "gemma2-9b-it")),
  expand_grid(
    api = "claude",
    model = c(
      # "claude-3-5-sonnet-20241022",
      "claude-3-haiku-20240307"
    )),
  expand_grid(
    api = "openai",
    model = c(
      # "gpt-4o",
      "gpt-4o-mini"
    )),
  expand_grid(
    api = "gemini",
    model = c(
      # "gemini-1.5-pro-latest",
      "gemini-1.5-flash-latest"
    ))
)

prompt_names <- c("democracy_simple")

dataset_names <- c("vdem")

api_names <- c(
  "claude",
  "openai",
  "groq",
  "gemini"
  )

prompt_files_df <- expand_grid(
    api = api_names,
    prompt_name = prompt_names,
    dataset_name = dataset_names,
    prompt_type = c("user")) |>
  mutate(prompt_filename = paste(api, prompt_name, prompt_type, "prompt.md", sep = "_"),
         prompt = paste("prompt", api, prompt_name, sep = "_") |>
           rlang::syms(),
         dataset = dataset_name |>
           rlang::syms()) |>
  group_by(prompt, api, prompt_name, dataset_name, dataset) |>
  summarise(prompt_type = list(prompt_type), prompt_filename = list(prompt_filename))

responses_df <- prompt_files_df |>
  inner_join(models_df, relationship = "many-to-many") |>
  mutate(responses = paste("responses", prompt_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms(),
         responses_joined = paste("responses_joined", prompt_name, model, sep = "-") |>
           str_replace_all("\\-", "_") |>
           rlang::syms())

claude_democracy_simple_response_validation <- function(response) {
  R.AI:::claude_default_response_validation(response)
}

claude_democracy_simple_content_extraction <- function(response) {
  R.AI:::claude_default_content_extraction(response)
}

openai_democracy_simple_response_validation <- function(response) {
  R.AI:::openai_default_response_validation(response)
}

openai_democracy_simple_content_extraction <- function(response) {
  R.AI:::openai_default_content_extraction(response)
}

gemini_democracy_simple_response_validation <- function(response) {
  R.AI:::gemini_default_response_validation(response)
}

gemini_democracy_simple_content_extraction <- function(response) {
  R.AI:::gemini_default_content_extraction(response)
}

groq_democracy_simple_response_validation <- function(response) {
  R.AI:::groq_default_response_validation(response)
}

groq_democracy_simple_content_extraction <- function(response) {
  R.AI:::groq_default_content_extraction(response)
}
