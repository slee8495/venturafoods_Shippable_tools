library(tidyverse)
library(magrittr)
library(openxlsx)
library(readxl)
library(writexl)
library(reshape2)
library(skimr)
library(janitor)
library(lubridate)


####################################### File read ##################################
# Inventory Lot Details ----
inv_lot_details <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/Automation/expiration_for_R.xlsx",
                              sheet = "Inventory Lot Detail")

inv_lot_details[-1, ] -> inv_lot_details
colnames(inv_lot_details) <- inv_lot_details[1, ]
inv_lot_details[-1, ] -> inv_lot_details

inv_lot_details %>% 
  janitor::clean_names() %>%
  readr::type_convert() %>% 
  dplyr::mutate(ref = paste0(location, "_", sku)) %>% 
  dplyr::relocate(ref) %>% 
  dplyr::mutate(mfg_date = as.Date(mfg_date, origin = "1899-12-30"),
                calculated_shippable_date = as.Date(calculated_shippable_date, origin = "1899-12-30"),
                expiration_date = as.Date(expiration_date, origin = "1899-12-30"),
                last_purchase_price = round(last_purchase_price, 2)) -> inv_lot_details
  



##################################### ETL ####################################

# supply_pivot 
inv_lot_details %>% 
  dplyr::group_by(ref, location, sku, description, days_to_past_ssl, lot_number, expiration_date, calculated_shippable_date, last_purchase_price) %>% 
  dplyr::summarise(sum_of_inventory_qty = sum(inventory_qty_cases)) -> supply_pivot


supply_pivot -> analysis_ref.2
as.data.frame(analysis_ref.2) -> analysis_ref.2

# Days left on SSL
analysis_ref.2 %>% 
  dplyr::rename(days_left_on_ssl = days_to_past_ssl) -> analysis_ref.2

# Days left on expired
analysis_ref.2 %>% 
  dplyr::mutate(days_left_on_expired = expiration_date - Sys.Date(),
                days_left_on_expired = as.numeric(days_left_on_expired)) %>% 
  dplyr::relocate(days_left_on_expired, .after = days_left_on_ssl) -> analysis_ref.2

# Unit Cost
analysis_ref.2 %>% 
  dplyr::rename(unit_cost = last_purchase_price) -> analysis_ref.2


# Days Range
analysis_ref.2 %>% 
  dplyr::mutate(days_range = ifelse(days_left_on_ssl <= 0, "unshippable",
                                    ifelse(days_left_on_ssl <= 30, "1-30",
                                           ifelse(days_left_on_ssl <= 60, "31-60", ">60")))) %>% 
  dplyr::relocate(days_range, .after = unit_cost) -> analysis_ref.2

# Inventory in $
analysis_ref.2 %>% 
  dplyr::mutate(inventory_in_cost = ifelse(sum_of_inventory_qty < 0, 0, sum_of_inventory_qty) * unit_cost) %>% 
  dplyr::relocate(inventory_in_cost, .after = sum_of_inventory_qty) %>% 
  dplyr::mutate(inventory_in_cost = paste("$", inventory_in_cost)) -> analysis_ref.2


# Diff Factor
ref <- "fist_row"
days_left_on_ssl <- NA

data.frame(ref, days_left_on_ssl) -> dummy_1

analysis_ref.2 %>% 
  dplyr::select(ref, days_left_on_ssl) -> dummy_2

rbind(dummy_1, dummy_2) -> dummy
rm(dummy_1, dummy_2)

rm(days_left_on_ssl, ref)

dummy %>% 
  dplyr::mutate(days_left_on_ssl = round(days_left_on_ssl, 0)) %>% 
  dplyr::slice(1:nrow(dummy) -1) %>% 
  dplyr::rename(dummy_ref = ref,
                dummy_days_left_on_ssl = days_left_on_ssl) %>% 
  dplyr::bind_cols(analysis_ref.2) %>% 
  dplyr::mutate(diff_factor = ifelse(dummy_ref == ref & dummy_days_left_on_ssl > 0, days_left_on_ssl - dummy_days_left_on_ssl, 0)) %>% 
  dplyr::relocate(diff_factor, .after = inventory_in_cost) %>% 
  dplyr::select(-dummy_ref, -dummy_days_left_on_ssl) -> analysis_ref.2









