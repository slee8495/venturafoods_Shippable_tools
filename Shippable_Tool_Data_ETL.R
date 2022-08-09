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
inv_shippable <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test2/Inventory Analysis_Shippable Tool (4).xlsx")

inv_shippable[-1, ] -> inv_shippable
colnames(inv_shippable) <- inv_shippable[1, ]
inv_shippable[-1, ] -> inv_shippable

inv_shippable %>% 
  janitor::clean_names() %>% 
  dplyr::mutate(sku = gsub("-", "", sku)) %>% 
  readr::type_convert() %>% 
  dplyr::mutate(ref = paste0(location, "_", sku),
                mfg_date = as.Date(mfg_date, origin = "1899-12-30"),
                expiration_date = as.Date(expiration_date, origin = "1899-12-30"),
                calculated_shippable_date = as.Date(calculated_shippable_date, origin = "1899-12-30")) %>% 
  dplyr::relocate(ref)  -> inv_shippable



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
  dplyr::filter(dplyr::between(sales_order_requested_ship_date, Sys.Date(), Sys.Date() + 28)) -> open_orders_1month


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
  dplyr::left_join(forecast_pivot) -> a

skim(a)
