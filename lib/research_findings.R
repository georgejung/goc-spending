# Research paper calculations
# for Government of Canada Proactive Disclosure of Contracts Data

source("lib/_libraries.R")
source("lib/exports.R")

# Work in progress
# These functions will be called from load.R; safe to anticipate that they'll be running when the contracts data is loaded in memory.

# Dataframes:

# contract_spending_by_date is the per-day breakdown of spending,
# useful for calculating (estimated) actual spending over time.

# contract_spending_overall includes a row for each "group" representing
# a contract and its amendments.

# contract_spending_overall_initiated includes entries from contract_spending_overall
# that were new since the start of the summary_start_fiscal_year_short fiscal year

# contract_spending_overall_ongoing includes entries from contract_spending_overall
# that have been active since the start of the summary_start_fiscal_year_short fiscal year



# Research paper findings by section number ===============

# These re-use filter_by_summary_type and filter_vendors_if_required from exports.R

# 4.2.1 Mean contract value
s421_mean_contract_value <- function(df) {
  df %>%
    summarise(
      mean_original_value = mean(d_original_contract_value, na.rm = TRUE), 
      mean_overall_value = mean(d_overall_contract_value, na.rm = TRUE),
      n = n()) %>%
    exports_round_totals()
}

s422_max_contract_value <- function(df) {
  df %>%
    summarise(
      max_overall_value = max(d_overall_contract_value, na.rm = TRUE), 
      n = n()) %>%
    exports_round_totals()
}

s423_min_contract_value <- function(df) {
  df %>%
    summarise(
      min_overall_value = min(d_overall_contract_value, na.rm = TRUE), 
      n = n()) %>%
    exports_round_totals()
}

# Deprecated by calculate_overall_duration in helpers.R which does the same thing:
s42_calculate_duration <- function(df) {
  df <- df %>%
    mutate(
      duration_days = as.integer(d_overall_end_date - d_overall_start_date + 1),
      duration_years = duration_days / 365
    )
  
  # To remove outlier durations (e.g. 112 years, 1600 years, etc.)
  df <- df %>%
    filter(duration_years < summary_maximum_duration_cutoff_years)
  
  df
}

s424_mean_duration <- function(df) {
  
  df <- df %>%
    s42_calculate_duration()
  
  df %>%
    summarise(
      mean_years = mean(duration_years, na.rm = TRUE), 
      n = n()) %>%
    exports_round_years()
  
}

s425_max_duration <- function(df) {
  
  df <- df %>%
    s42_calculate_duration()
  
  df %>%
    summarise(
      max_years = max(duration_years, na.rm = TRUE), 
      n = n()) %>%
    exports_round_years()

}

s43_has_amendments <- function(df) {
  
  df <- df %>%
    mutate(
      has_amendments = case_when(
        d_overall_number_of_amendments > 0 ~ 1,
        TRUE ~ 0
      )
    )
  
  df
  
}

s431_number_of_contracts <- function(df) {

  df <- df %>%
    s43_has_amendments
  
  df %>%
    summarise(
      contracts = n(),
      contracts_with_amendments = sum(has_amendments, na.rm = TRUE),
      has_amendments_percentage = contracts_with_amendments / contracts
      ) %>%
    exports_round_percentages()
  
}

# Note: includes contracts with amendments only
s432_mean_amendment_increase_percentage <- function(df) {
  
  df <- df %>%
    s43_has_amendments
  
  df %>%
    filter(has_amendments == 1) %>%
    # Avoid division by 0 errors
    filter(d_original_contract_value > 0) %>%
    mutate(
      d_contract_value_increase = d_overall_contract_value - d_original_contract_value,
      d_amendment_increase_percentage = d_contract_value_increase / d_original_contract_value
    ) %>%
    summarise(
      mean_amendment_increase_percentage = mean(d_amendment_increase_percentage, na.rm = TRUE), 
      n = n()) %>%
    exports_round_percentages()
  
}

# Note: includes contracts with amendments only
s433_total_amendment_increase_value <- function(df) {
  
  df <- df %>%
    s43_has_amendments
  
  df %>%
    filter(has_amendments == 1) %>%
    # Same as above for consistency
    filter(d_original_contract_value > 0) %>%
    mutate(
      d_contract_value_increase = d_overall_contract_value - d_original_contract_value,
    ) %>%
    summarise(
      total_amendment_increase_value = sum(d_contract_value_increase, na.rm = TRUE), 
      n = n()) %>%
    exports_round_totals()
  
}

# Note: includes contracts with amendments only
s434_mean_number_of_amendments <- function(df) {
  
  df <- df %>%
    s43_has_amendments
  
  df %>%
    filter(has_amendments == 1) %>%
    summarise(
      mean_number_of_amendments = mean(d_overall_number_of_amendments, na.rm = TRUE), 
      n = n()) %>%
    exports_round_mean()
  
}

# Usage is e.g.
# do_research_findings_call("s421_mean_contract_value", "core")
# do_research_findings_call("s421_mean_contract_value", "core", "owner_org")
# do_research_findings_call("s421_mean_contract_value", "core", "d_vendor_name", TRUE)
# do_research_findings_call("s421_mean_contract_value", "core", "d_most_recent_category")
do_research_findings_call <- function(function_name, summary_type, grouping_column = FALSE, filter_vendors = FALSE) {
  
  output <- contract_spending_overall_ongoing %>%
    filter_by_summary_type(summary_type) %>%
    filter_vendors_if_required(filter_vendors)
  
  if(grouping_column != FALSE) {
    output <- output %>%
      group_by(across(all_of(grouping_column)))
  }
  
  # Thanks to
  # https://stackoverflow.com/questions/62202574/how-to-safely-use-do-call-within-dplyr-pipe#comment110012904_62202574
  output %>%
    {exec(function_name, .)}
    
  
}


# Research findings against the full set of contracts =========
# Typical usage is e.g.: contracts %>% s513_unique_vendors()

# How many contracts have vs. don't have economic object codes
s511_contracts_with_and_without_economic_object_codes <- function(df) {
  
  df %>%
    summarise(
      n_with_economic_object_code = sum(!is.na(d_economic_object_code)), 
      n_without_economic_object_code = sum(is.na(d_economic_object_code)), 
      n = n())
  
}

# How many contracts have amendments via each type of amendment matching approach
s512_contracts_with_amendments_via <- function(df) {
  
  df %>%
    count(d_amendment_via, sort = TRUE)
  
}

# How many unique vendors there are in the dataset, after vendor name normalization
s513_unique_vendors <- function(df) {
  
  df %>%
    select(d_vendor_name) %>% 
    distinct() %>% 
    count()
  
}


# Export helper functions =======================
# Note: these are a bit clunky (and don't save results in memory or use map- functions) but they'll work for now.

save_research_findings_call_to_csv <- function(function_name, summary_type, file_suffix = "", grouping_column = FALSE, filter_vendors = FALSE) {
  
  # Pass along the input parameters to do_research_findings_call()
  output <- do_research_findings_call(function_name, summary_type, grouping_column, filter_vendors)
  
  if(file_suffix != "") {
    # Include a _ before the file_suffix after the function name, if specified.
    file_suffix <- str_c("_", file_suffix)
  }
  
  output %>%
    write_csv_if_enabled(str_c(output_overall_path, summary_type, "/", function_name, file_suffix, ".csv"))
  
}

save_research_findings_call_variations_to_csv <- function(function_name, summary_type) {
  
  # Essentially: calls the same analysis function with all 4 of the possible variations (overall across the summary type, by department, by vendor, by category)
  save_research_findings_call_to_csv(function_name, summary_type)
  save_research_findings_call_to_csv(function_name, summary_type, "by_department", "owner_org")
  save_research_findings_call_to_csv(function_name, summary_type, "by_vendor", "d_vendor_name", TRUE)
  save_research_findings_call_to_csv(function_name, summary_type, "by_category", "d_most_recent_category")
  
}

save_all_research_findings_by_summary_type <- function(summary_type) {
  
  # Note: if more functions are added above, be sure to add them here.
  function_names <- c(
    "s421_mean_contract_value",
    "s422_max_contract_value",
    "s423_min_contract_value",
    "s424_mean_duration",
    "s425_max_duration",
    "s431_number_of_contracts",
    "s432_mean_amendment_increase_percentage",
    "s433_total_amendment_increase_value",
    "s434_mean_number_of_amendments"
  )
  
  output <- tibble(function_name = function_names, summary_type = summary_type)
  
  walk2(output$function_name, output$summary_type, save_research_findings_call_variations_to_csv)
  
}

# Export research findings across all summary types
# We'll call this from the load.R
save_all_research_findings <- function() {
  
  summary_types <- c("core", "dnd", "all")
  
  summary_types %>%
    walk(save_all_research_findings_by_summary_type)
  
}
