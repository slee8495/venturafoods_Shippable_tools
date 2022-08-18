library(tidyverse)
library(magrittr)
library(openxlsx)
library(readxl)
library(writexl)
library(reshape2)
library(skimr)
library(janitor)
library(lubridate)


# File read ----
# (1) Inventory Analysis_Shippable Tool
inv_shippable <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test2/Inventory Analysis_Shippable Tool (5).xlsx")

inv_shippable[-1, ] -> inv_shippable
colnames(inv_shippable) <- inv_shippable[1, ]
inv_shippable[-1, ] -> inv_shippable

inv_shippable %>% 
  janitor::clean_names() %>% 
  dplyr::mutate(sku = gsub("-", "", sku)) %>% 
  dplyr::filter(days_left > 0) %>%
  dplyr::filter(!is.na(mfg_date)) %>%
  dplyr::filter(!is.na(label)) %>% 
  readr::type_convert() %>% 
  dplyr::mutate(ref = paste0(location, "_", sku),
                mfg_date = as.Date(mfg_date, origin = "1899-12-30"),
                expiration_date = as.Date(expiration_date, origin = "1899-12-30"),
                calculated_shippable_date = as.Date(calculated_shippable_date, origin = "1899-12-30")) %>% 
  dplyr::relocate(ref) -> inv_shippable



# (2) Open Orders - 1 Month
open_orders_1month <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test2/Open Orders - 1 Month (2).xlsx")

open_orders_1month[-1, ] -> open_orders_1month
colnames(open_orders_1month) <- open_orders_1month[1, ]
open_orders_1month[-1, ] -> open_orders_1month

open_orders_1month %>% 
  janitor::clean_names() %>% 
  dplyr::rename(sku = product_label_sku) %>% 
  readr::type_convert() %>% 
  dplyr::mutate(sku = gsub("-", "", sku),
                ref = paste0(location, "_", sku),
                sales_order_requested_ship_date = as.Date(sales_order_requested_ship_date, origin = "1899-12-30")) %>% 
  dplyr::relocate(ref) %>% 
  dplyr::mutate(year = stringr::str_sub(sales_order_requested_ship_date, 1, 4),
                month = stringr::str_sub(sales_order_requested_ship_date, 6, 7),
                year_month = paste0(year, "_", month, " (open)")) %>% 
  dplyr::filter(dplyr::between(sales_order_requested_ship_date, Sys.Date(), Sys.Date() + 15)) -> open_orders_1month


# (3) Forecast - 5 months begins after 1 month
forecast_5months <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test2/Forecast - 5 months begins after 1 month.xlsx")

forecast_5months[-1, ] -> forecast_5months
colnames(forecast_5months) <- forecast_5months[1, ]
forecast_5months[-1, ] -> forecast_5months

forecast_5months %>% 
  janitor::clean_names() %>% 
  dplyr::rename(sku = product_label_sku) %>% 
  readr::type_convert() %>% 
  dplyr::mutate(sku = gsub("-", "", sku),
                ref = paste0(location, "_", sku),
                adjusted_forecast_cases = replace(adjusted_forecast_cases, is.na(adjusted_forecast_cases), 0),
                year = stringr::str_sub(forecast_month_year, 1, 4),
                month = stringr::str_sub(forecast_month_year, 5, 6),
                year_month = paste0(year, "_", month, " (forecast)")) %>% 
  dplyr::relocate(ref) -> forecast_5months


# Pivot tables (open_orders_1month)
reshape2::dcast(open_orders_1month, ref ~ year_month , value.var = "open_order_cases", sum) -> open_orders_pivot 

# Pivot tables (forecast_5months)
reshape2::dcast(forecast_5months, ref ~ year_month , value.var = "adjusted_forecast_cases", sum) -> forecast_pivot


open_orders_pivot %>% head()
forecast_pivot %>% head()

                       
# vlookup (inv_shippable & open_orders_1month)
inv_shippable %>% 
  dplyr::left_join(open_orders_pivot, by = "ref") %>% 
  dplyr::left_join(forecast_pivot) -> inv_shippable


# Past SSL but not on Hold
inv_shippable %>% 
  dplyr::mutate(past_ssl_but_not_on_hold = ifelse(calculated_days_left_to_ship < 0, 1, 0)) %>% 
  dplyr::relocate(past_ssl_but_not_on_hold, .after = inventory_qty_cases) -> inv_shippable

##############################################################################################################################################
##############################################################################################################################################
##############################################################################################################################################

# avg_sales_per_day 
colnames(inv_shippable) -> colnames_inv_shippable
data.frame(colnames_inv_shippable) -> colnames_inv_shippable

colnames_inv_shippable[nrow(colnames_inv_shippable), ] -> colnames_inv_shippable

colnames_inv_shippable %>% 
  stringr::str_sub(1, 7) %>% 
  as.data.frame() %>% 
  dplyr::rename(last_day = ".") %>% 
  dplyr::mutate(last_day = gsub("_", "", last_day),
                last_day = as.factor(last_day),
                last_day = lubridate::ym(last_day),
                last_day = lubridate::ceiling_date(last_day, unit = "month")-1) %>% 
  dplyr::mutate(days = last_day - Sys.Date(),
                days = as.integer(days)) -> duration
  
duration$days -> duration


inv_shippable %>% 
  dplyr::mutate(avg_of_sales_per_day_sum = rowSums(across(.cols = ends_with(")")), na.rm =  T),
                avg_of_sales_per_day = avg_of_sales_per_day_sum / duration,
                avg_of_sales_per_day = round(avg_of_sales_per_day, 0)) %>% 
  dplyr::select(-avg_of_sales_per_day_sum) %>% 
  dplyr::relocate(avg_of_sales_per_day, .after = past_ssl_but_not_on_hold) -> inv_shippable




# Risk 0 - 30 days
# excel line 3682
inv_shippable %>% 
  dplyr::mutate(risk_in_30_days = ifelse(calculated_days_left_to_ship > 30, 0, inventory_qty_cases - (avg_of_sales_per_day * calculated_days_left_to_ship))) %>% 
  dplyr::relocate(risk_in_30_days, .after = avg_of_sales_per_day) -> inv_shippable


# Risk 31 - 60 days
inv_shippable %>% 
  dplyr::mutate(risk_in_60_days = ifelse(calculated_days_left_to_ship > 60, 0, inventory_qty_cases - (avg_of_sales_per_day * calculated_days_left_to_ship))) %>% 
  dplyr::relocate(risk_in_60_days, .after = risk_in_30_days) -> inv_shippable


# Risk 61 - 90 days
inv_shippable %>% 
  dplyr::mutate(risk_in_90_days = ifelse(calculated_days_left_to_ship > 90, 0, inventory_qty_cases - (avg_of_sales_per_day * calculated_days_left_to_ship))) %>% 
  dplyr::relocate(risk_in_90_days, .after = risk_in_60_days)-> inv_shippable



writexl::write_xlsx(inv_shippable, "test.8.10.22.xlsx")

