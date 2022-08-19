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
# (Path revision Needed) Inventory Lot Details ----
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

# supply_pivot 
inv_lot_details %>% 
  dplyr::group_by(ref, location, sku, description, days_to_past_ssl, lot_number, expiration_date, calculated_shippable_date, last_purchase_price) %>% 
  dplyr::summarise(sum_of_inventory_qty = sum(inventory_qty_cases)) -> supply_pivot


supply_pivot -> analysis_ref.2
as.data.frame(analysis_ref.2) -> analysis_ref.2


  
# (Path revision Needed) Custord ----
custord <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/Automation/expiration_for_R.xlsx",
                              sheet = "CustOrd")


custord[-1, ] -> custord
colnames(custord) <- custord[1, ]
custord[-1, ] -> custord

custord %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  dplyr::rename(sku = product_label_sku) %>% 
  dplyr::mutate(sales_order_requested_ship_date = as.Date(sales_order_requested_ship_date, origin = "1899-12-30"),
                ref = paste0(location, "_", sku)) %>% 
  dplyr::relocate(ref) -> custord

# custord_pivot
custord %>% 
  dplyr::group_by(ref) %>% 
  dplyr::summarise(sum_of_open_order_cases = sum(open_order_cases)) %>% 
  as.data.frame() %>% 
  dplyr::mutate(custord_daily_avg = sum_of_open_order_cases / 15,
                custord_daily_avg = round(custord_daily_avg, 0)) -> custord_pivot



# (Path revision Needed) planner address book (If updated, correct this link) ----
planner_address <- read_excel("S:/Supply Chain Projects/Linda Liang/reference files/Address Book - 08.04.22.xlsx")
planner_address %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  dplyr::select(1:2) %>% 
  dplyr::rename(planner_number = address_number,
                planner_name = alpha_name) -> planner_address


# (Path revision Needed) exception report ----
exception_report <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/Automation/exception report 08.17.22 (1).xlsx")

exception_report[-1:-2, ] -> exception_report
colnames(exception_report) <- exception_report[1, ]
exception_report[-1, ] -> exception_report

exception_report %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  dplyr::rename(location = b_p,
                sku = item_number,
                planner_number = planner) %>% 
  dplyr::select(location, sku, planner_number) %>% 
  dplyr::mutate(ref = paste0(location, "_", sku)) %>% 
  dplyr::mutate(planner_number = replace(planner_number, is.na(planner_number), 0)) -> exception_planner


# (Path revision Needed) IOM for MBX ----
# Make sure to unlock the password before import (Elli)
iom_mbx <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/Automation/SS Optimization by Location - Finished Goods August 2022.xlsx",
                      sheet = "Fin Goods")

iom_mbx[-1:-6, ] -> iom_mbx
colnames(iom_mbx) <- iom_mbx[1, ]
iom_mbx[-1, ] -> iom_mbx

iom_mbx %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  dplyr::select(ship_ref, type) %>% 
  dplyr::mutate(ship_ref = gsub("-", "_", ship_ref)) %>% 
  dplyr::rename(ref = ship_ref,
                mbx = type) -> iom_mbx



##################################### ETL ####################################

# Planner #
merge(analysis_ref.2, exception_planner[, c("ref", "planner_number")], by = "ref", all.x = TRUE) %>% 
  dplyr::relocate(planner_number, .after = description) %>% 
  dplyr::mutate(planner_number = replace(planner_number, is.na(planner_number), "DNRR")) -> analysis_ref.2


  # Planner Name
merge(analysis_ref.2, planner_address[, c("planner_number", "planner_name")], by = "planner_number", all.x = TRUE) %>% 
  dplyr::relocate(c(planner_number, planner_name), .after = description) %>% 
  dplyr::mutate(planner_name = ifelse(planner_number == "DNRR", "DNRR",
                                      ifelse(planner_number == 0, NA, planner_name))) -> analysis_ref.2



# Days left on SSL
analysis_ref.2 %>% 
  dplyr::rename(days_left_on_ssl = days_to_past_ssl) -> analysis_ref.2

# Days left on expired
analysis_ref.2 %>% 
  dplyr::mutate(days_left_on_expired = expiration_date - Sys.Date(),
                days_left_on_expired = as.numeric(days_left_on_expired)) %>% 
  dplyr::relocate(days_left_on_expired, .after = days_left_on_ssl) -> analysis_ref.2



# MBX
# What is the logic of DNRR on MBX column? 
merge(analysis_ref.2, iom_mbx[, c("ref", "mbx")], by = "ref", all.x = TRUE) %>% 
  dplyr::mutate(mbx = ifelse(planner_number == "DNRR", "DNRR", mbx)) %>% 
  dplyr::relocate(mbx, .after = calculated_shippable_date) -> analysis_ref.2


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
  dplyr::relocate(diff_factor, .after = inventory_in_cost) -> analysis_ref.2



# Total CustOrd (within 15 days)
merge(analysis_ref.2, custord_pivot[, c("ref", "sum_of_open_order_cases")], by = "ref", all.x = TRUE) %>% 
  dplyr::rename(total_custord_within_15_days = sum_of_open_order_cases) %>% 
  dplyr::mutate(total_custord_within_15_days = replace(total_custord_within_15_days, is.na(total_custord_within_15_days), 0)) -> analysis_ref.2


# Inv after Custord
analysis_ref.2 %>% 
  dplyr::mutate(inv_after_custord = ifelse(days_left_on_ssl <= 0, sum_of_inventory_qty ,
                                           ifelse(ref = dummy_ref, 
                                                  ifelse(dummy_days_left_on_ssl > 0 & S3 > 0, sum_of_inventory_qty, 
                                                         SUMIFS($O$4:O4, $A$4:A4, $A4, $H$4:H4, ">0") -R3),O4-R4)))








