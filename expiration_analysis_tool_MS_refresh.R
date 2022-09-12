################################# DON'T FORGET WITH SYS.DATE() ###############################

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
inv_lot_details <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test 3/Inventory Lot Detail - 08.23.22.xlsx")

inv_lot_details[-1, ] -> inv_lot_details
colnames(inv_lot_details) <- inv_lot_details[1, ]
inv_lot_details[-1, ] -> inv_lot_details

inv_lot_details %>% 
  janitor::clean_names() %>%
  readr::type_convert() %>% 
  dplyr::mutate(sku = gsub("-", "", sku), 
                ref = paste0(location, "_", sku)) %>% 
  dplyr::relocate(ref) %>% 
  dplyr::mutate(mfg_date = as.Date(mfg_date, origin = "1899-12-30"),
                calculated_shippable_date = as.Date(calculated_shippable_date, origin = "1899-12-30"),
                expiration_date = as.Date(expiration_date, origin = "1899-12-30"),
                last_purchase_price = round(last_purchase_price, 2)) %>% 
  data.frame() %>% 
  dplyr::rename(days_to_past_ssl = calculated_days_left_to_ship) %>% 
  dplyr::mutate(inventory_qty_cases = replace(inventory_qty_cases, is.na(inventory_qty_cases), 0)) -> inv_lot_details

# supply_pivot 
inv_lot_details %>% 
  dplyr::group_by(ref, location, sku, description, days_to_past_ssl, lot_number, expiration_date, calculated_shippable_date, last_purchase_price) %>% 
  dplyr::summarise(sum_of_inventory_qty = sum(inventory_qty_cases)) %>% 
  dplyr::arrange(ref, days_to_past_ssl) -> supply_pivot


supply_pivot -> analysis_ref.2
as.data.frame(analysis_ref.2) -> analysis_ref.2

analysis_ref.2 %>%
  dplyr::arrange(ref, expiration_date) %>% 
  dplyr::mutate(index = dplyr::row_number()) %>%
  dplyr::relocate(index) -> analysis_ref.2
  
# (Path revision Needed) Custord ----
custord <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test 3/MSTR custord - 08.23.22.xlsx")


custord[-1, ] -> custord
colnames(custord) <- custord[1, ]
custord[-1, ] -> custord

custord %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  dplyr::rename(sku = product_label_sku,
                open_order_cases = oo_cases) %>% 
  dplyr::mutate(sku = gsub("-", "", sku),
                sales_order_requested_ship_date = as.Date(sales_order_requested_ship_date, origin = "1899-12-30"),
                ref = paste0(location, "_", sku)) %>% 
  dplyr::relocate(ref) %>% 
  dplyr::mutate(date_2 = ifelse(sales_order_requested_ship_date < Sys.Date()-20 + 15, "Y", "N")) %>% 
  dplyr::filter(date_2 == "Y") %>% 
  dplyr::select(-date_2) %>% 
  dplyr::mutate(open_order_cases = replace(open_order_cases, is.na(open_order_cases), 0)) -> custord


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
exception_report <- read_excel("C:/Users/slee/OneDrive - Ventura Foods/Ventura Work/SCE/Project/FY 23/Shippable Tool Creation/test 3/exception report 08.23.22 (1).xlsx")

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


# (Path revision Needed) fcst ----
fcst <- read_excel("S:/Global Shared Folders/Large Documents/S&OP/Demand Planning/Demand Planning Team/BI Forecast Backup/2022/DSX Forecast Backup - 2022.08.23.xlsx")

fcst[-1, ] -> fcst
colnames(fcst) <- fcst[1, ]
fcst[-1, ] -> fcst

fcst %>% 
  janitor::clean_names() %>% 
  readr::type_convert() %>% 
  as.data.frame() %>% 
  dplyr::rename(location = location_no,
                sku = product_label_sku_code) %>% 
  dplyr::mutate(sku = gsub("-", "", sku),
                ref = paste0(location, "_", sku),
                adjusted_forecast_pounds_lbs = replace(adjusted_forecast_pounds_lbs, is.na(adjusted_forecast_pounds_lbs), 0),
                adjusted_forecast_cases = replace(adjusted_forecast_cases, is.na(adjusted_forecast_cases ), 0)) -> fcst


reshape2::dcast(fcst, ref ~ forecast_month_year_code, value.var = "adjusted_forecast_cases", sum) -> fcst_pivot

# fcst_pivot ETL  (duration for average sales per day)
fcst_pivot %>% 
  dplyr::select(1:8) -> fcst_pivot

# avg_sales_per_day 
colnames(fcst_pivot) -> colnames_fcst_pivot
data.frame(colnames_fcst_pivot) -> colnames_fcst_pivot

colnames_fcst_pivot[nrow(colnames_fcst_pivot), ] -> colnames_fcst_pivot

colnames_fcst_pivot %>% 
  as.data.frame() %>% 
  dplyr::rename(last_day = ".") %>% 
  dplyr::mutate(last_day = gsub("_", "", last_day),
                last_day = as.factor(last_day),
                last_day = lubridate::ym(last_day),
                last_day = lubridate::ceiling_date(last_day, unit = "month")-1) %>% 
  dplyr::mutate(days = last_day - Sys.Date()+20,
                days = as.integer(days)) -> duration

duration$days -> duration
duration-15 -> duration

# fcst_pivot with avg
colnames(fcst_pivot)[2] <- "pre_month"
colnames(fcst_pivot)[3] <- "current_month"
colnames(fcst_pivot)[4] <- "fcst_month_1"
colnames(fcst_pivot)[5] <- "fcst_month_2"
colnames(fcst_pivot)[6] <- "fcst_month_3"
colnames(fcst_pivot)[7] <- "fcst_month_4"
colnames(fcst_pivot)[8] <- "fcst_month_5"


fcst_pivot %>% 
  dplyr::mutate(sum_fcst_5months = rowSums(across(.cols = starts_with("fcst"))),
                fcst_daily = sum_fcst_5months / duration,
                fcst_daily = round(fcst_daily, 0)) -> fcst_pivot



##################################### ETL ####################################


# Planner #
merge(analysis_ref.2, exception_planner[, c("ref", "planner_number")], by = "ref", all.x = TRUE) %>% 
  dplyr::relocate(planner_number, .after = description) %>% 
  dplyr::mutate(planner_number = replace(planner_number, is.na(planner_number), "DNRR")) %>% 
  dplyr::arrange(index) -> analysis_ref.2


# Planner Name
merge(analysis_ref.2, planner_address[, c("planner_number", "planner_name")], by = "planner_number", all.x = TRUE) %>% 
  dplyr::relocate(c(planner_number, planner_name), .after = description) %>% 
  dplyr::mutate(planner_name = ifelse(planner_number == "DNRR", "DNRR",
                                      ifelse(planner_number == 0, NA, planner_name))) %>% 
  dplyr::arrange(index) -> analysis_ref.2



# Days left on SSL
analysis_ref.2 %>% 
  dplyr::rename(days_left_on_ssl = days_to_past_ssl) -> analysis_ref.2


# Days left on expired
analysis_ref.2 %>% 
  dplyr::mutate(days_left_on_expired = expiration_date - Sys.Date()+20,
                days_left_on_expired = as.numeric(days_left_on_expired)) %>% 
  dplyr::relocate(days_left_on_expired, .after = days_left_on_ssl) -> analysis_ref.2



# MBX
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
  dplyr::relocate(inventory_in_cost, .after = sum_of_inventory_qty) -> analysis_ref.2


# Total CustOrd (within 15 days)
merge(analysis_ref.2, custord_pivot[, c("ref", "sum_of_open_order_cases")], by = "ref", all.x = TRUE) %>% 
  dplyr::rename(total_custord_within_15_days = sum_of_open_order_cases) %>% 
  dplyr::mutate(total_custord_within_15_days = replace(total_custord_within_15_days, is.na(total_custord_within_15_days), 0)) %>% 
  dplyr::arrange(index) -> analysis_ref.2



# Dummie ref
ref <- "fist_row"
days_left_on_ssl <- NA
total_custord_within_15_days <- NA

data.frame(ref, days_left_on_ssl, total_custord_within_15_days) -> dummy_1

analysis_ref.2 %>% 
  dplyr::select(ref, days_left_on_ssl, total_custord_within_15_days) -> dummy_2

rbind(dummy_1, dummy_2) -> dummy
rm(dummy_1, dummy_2)

rm(days_left_on_ssl, ref, total_custord_within_15_days)

dummy %>% 
  dplyr::slice(1:nrow(dummy) -1) %>% 
  dplyr::rename(dummy_ref = ref,
                dummy_days_left_on_ssl = days_left_on_ssl,
                dummy_total_custord_within_15_days = total_custord_within_15_days) %>% 
  dplyr::mutate(dummy_index = dplyr::row_number())-> dummy

analysis_ref.2 %>% 
  dplyr::arrange(index) %>% 
  dplyr::bind_cols(dummy) %>% 
  dplyr::relocate(dummy_ref, .after = ref) %>% 
  dplyr::relocate(dummy_days_left_on_ssl, .after = days_left_on_ssl) %>% 
  dplyr::relocate(dummy_total_custord_within_15_days, .after = total_custord_within_15_days) %>% 
  dplyr::relocate(dummy_index, .after = index) -> analysis_ref.2


# Dummie ref_2
ref <- "last_row"

data.frame(ref) -> dummy_12

analysis_ref.2 %>% 
  dplyr::select(ref) -> dummy_13

rbind(dummy_13, dummy_12) -> dummy_14
rm(dummy_12, dummy_13)

rm(ref)

dummy_14 %>%
  dplyr::slice(2:nrow(dummy_14)) %>% 
  dplyr::rename(dummy_ref_2 = ref) %>% 
  dplyr::mutate(dummy_index = dplyr::row_number())-> dummy_14

analysis_ref.2 %>% 
  dplyr::arrange(index) %>% 
  dplyr::bind_cols(dummy_14) %>% 
  dplyr::relocate(dummy_ref_2, .after = dummy_ref) -> analysis_ref.2

# Diff Factor
analysis_ref.2 %>% 
  dplyr::mutate(diff_factor = ifelse(dummy_ref == ref & dummy_days_left_on_ssl > 0, days_left_on_ssl - dummy_days_left_on_ssl, 0)) %>% 
  dplyr::relocate(diff_factor, .after = inventory_in_cost) -> analysis_ref.2


# Inv after Custord
analysis_ref.2 %>% 
  dplyr::rename(sum_of_inventory_qty_w_neg = sum_of_inventory_qty) %>% 
  dplyr::mutate(sum_of_inventory_qty = ifelse(sum_of_inventory_qty_w_neg < 0, 0, sum_of_inventory_qty_w_neg)) -> analysis_ref.2


analysis_ref.2 %>% 
  plyr::ddply("ref", transform, inv_qty_cum_sum = cumsum(sum_of_inventory_qty)) %>% 
  dplyr::mutate(inv_after_custord_cal_1 = ifelse(days_left_on_ssl <= 0, 0, sum_of_inventory_qty)) %>% 
  plyr::ddply("ref", transform, inv_qty_cum_sum_cal = cumsum(inv_after_custord_cal_1)) %>% 
  dplyr::mutate(inv_qty_cum_sum_cal_2 = inv_qty_cum_sum_cal - total_custord_within_15_days) -> analysis_ref.2

# dummy_inv_qty_cum_sum
inv_qty_cum_sum <- "NA"
data.frame(inv_qty_cum_sum) -> dummy_8

analysis_ref.2 %>% 
  dplyr::select(inv_qty_cum_sum) -> dummy_9

rbind(dummy_8, dummy_9) -> dummy_10
rm(dummy_8, dummy_9)
rm(inv_qty_cum_sum)


dummy_10 %>% 
  dplyr::slice(1:nrow(dummy_10) -1) %>% 
  dplyr::rename(dummy_inv_qty_cum_sum = inv_qty_cum_sum) -> dummy_10

analysis_ref.2 %>% 
  dplyr::arrange(index) %>% 
  dplyr::bind_cols(dummy_10) -> analysis_ref.2

analysis_ref.2 %>% 
  dplyr::mutate(dummy_inv_qty_cum_sum = as.numeric(dummy_inv_qty_cum_sum),
                dummy_cumsum_minus_total_custord = dummy_inv_qty_cum_sum - total_custord_within_15_days) -> analysis_ref.2



# inv_qty_cum_sum_cal_2_dummy
inv_qty_cum_sum_cal_2 <- NA

data.frame(inv_qty_cum_sum_cal_2) -> dummy_15

analysis_ref.2 %>% 
  dplyr::select(inv_qty_cum_sum_cal_2) -> dummy_16

rbind(dummy_15, dummy_16) -> dummy_17
rm(dummy_15, dummy_16)

rm(inv_qty_cum_sum_cal_2)

dummy_17 %>%
  dplyr::slice(1:nrow(dummy_17) -1) %>% 
  dplyr::rename(inv_qty_cum_sum_cal_2_dummy = inv_qty_cum_sum_cal_2) %>% 
  dplyr::mutate(dummy_index = dplyr::row_number())-> dummy_18

analysis_ref.2 %>% 
  dplyr::arrange(index) %>% 
  dplyr::bind_cols(dummy_18) %>% 
  dplyr::relocate(inv_qty_cum_sum_cal_2_dummy, .after = inv_qty_cum_sum_cal_2) -> analysis_ref.2



# inv_after_custord_algorithm

analysis_ref.2 %>% 
  dplyr::mutate(inv_after_custord_case1 = ifelse(ref != dummy_ref & days_left_on_ssl <= 0, inv_qty_cum_sum, 
                                                 ifelse(dummy_days_left_on_ssl <= 0, inv_qty_cum_sum_cal - total_custord_within_15_days, inv_qty_cum_sum_cal - total_custord_within_15_days)),
                inv_after_custord_case2 = ifelse(total_custord_within_15_days == 0, sum_of_inventory_qty, 
                                                 ifelse(ref != dummy_ref & days_left_on_ssl <= 0, sum_of_inventory_qty,
                                                        ifelse(ref != dummy_ref & days_left_on_ssl > 0, inv_qty_cum_sum - total_custord_within_15_days,
                                                               ifelse(ref == dummy_ref & days_left_on_ssl <= 0, sum_of_inventory_qty,
                                                                      ifelse(ref == dummy_ref & dummy_days_left_on_ssl <= 0 & days_left_on_ssl > 0, inv_qty_cum_sum_cal - total_custord_within_15_days, 
                                                                             ifelse(ref == dummy_ref & ref != dummy_ref_2 & dummy_days_left_on_ssl > 0 & days_left_on_ssl > 0 & dummy_cumsum_minus_total_custord > 0 & inv_qty_cum_sum_cal_2_dummy > 0,
                                                                                    inv_qty_cum_sum_cal_2 - inv_qty_cum_sum_cal_2_dummy,
                                                                                    ifelse(ref == dummy_ref & ref != dummy_ref_2 & dummy_days_left_on_ssl > 0 & days_left_on_ssl > 0 & dummy_cumsum_minus_total_custord > 0 & inv_qty_cum_sum_cal_2_dummy <= 0,
                                                                                           inv_qty_cum_sum_cal_2,
                                                                                    ifelse(ref == dummy_ref & ref == dummy_ref_2 & dummy_days_left_on_ssl > 0 & days_left_on_ssl > 0 & dummy_cumsum_minus_total_custord > 0,
                                                                                           inv_after_custord_cal_1 , 
                                                                                    ifelse(ref == dummy_ref & dummy_days_left_on_ssl > 0 & days_left_on_ssl > 0 & dummy_cumsum_minus_total_custord <= 0,
                                                                                           inv_qty_cum_sum_cal_2, NA)))))))))) %>% 
  dplyr::rename(inv_after_custord = inv_after_custord_case2) -> analysis_ref.2


analysis_ref.2


######################### Testing #################################
analysis_ref.2 %>% select(ref, diff_factor, sum_of_inventory_qty, inv_after_custord_case1, inv_after_custord) %>% filter(ref == "10_19194PIG")
analysis_ref.2 %>% filter(ref == "260_20397EBQ")
analysis_ref.2 %>% filter(ref == "10_19194PIG") %>% select(ending_inv_after_custord)

sum(analysis_ref.2$inv_after_custord)


# Linda's file error
# 36-20776SCR: This one, Expiration date in Linda's file reversed
# 260_20397EBQ: good example of sum_of_inventory (-) value

# sum_of_inventory remains as it is for (-) ones as well. -> create another column for it, and work on that -> change the column name and delete all after the calculation
# Look at Linda's excel file. work on n. 



# In Excel in the folder test 4, there are column with R Test with "N" and "N/A". (Check if the Lot # is the issue before get into detail)

###################################################################


# Ending Inv After CustOrd
analysis_ref.2 %>% 
  dplyr::mutate(ending_inv_after_custord = ifelse(inv_after_custord <= 0, 0, inv_after_custord)) -> analysis_ref.2

# Ending Inv After CustOrd in $
analysis_ref.2 %>% 
  dplyr::mutate(ending_inv_after_custord_in_cost = ending_inv_after_custord * unit_cost) -> analysis_ref.2


# Fcst daily avg (after 15 days)
merge(analysis_ref.2, fcst_pivot[, c("ref", "fcst_daily")], by = "ref", all.x = TRUE) %>% 
  dplyr::arrange(index) %>% 
  dplyr::rename(fcst_daily_avg_after_15_days = fcst_daily) %>% 
  dplyr::mutate(fcst_daily_avg_after_15_days = replace(fcst_daily_avg_after_15_days, is.na(fcst_daily_avg_after_15_days), 0)) -> analysis_ref.2

# Consumption Factor
analysis_ref.2 %>% 
  dplyr::mutate(consumption_factor = ifelse(days_left_on_ssl <= 15, 0,
                                            ifelse(diff_factor == 0, fcst_daily_avg_after_15_days * (days_left_on_ssl - 15), 
                                                   fcst_daily_avg_after_15_days * diff_factor))) -> analysis_ref.2


# Inv after Custord & Fcst
analysis_ref.2 %>% 
  dplyr::mutate(inv_after_custord_and_fcst = ifelse(days_left_on_ssl <= 0, 
                                                    ending_inv_after_custord, 
                                                    ending_inv_after_custord - consumption_factor)) -> analysis_ref.2

# Ending Inv after Custord & Fcst
analysis_ref.2 %>% 
  dplyr::mutate(ending_inv_after_custord_and_fcst = ifelse(inv_after_custord_and_fcst < 0, 0, inv_after_custord_and_fcst)) -> analysis_ref.2


# Ending Inv after Custord & Fcst in $
analysis_ref.2 %>% 
  dplyr::mutate(ending_inv_after_custord_and_fcst_in_Cost = ending_inv_after_custord_and_fcst * unit_cost) -> analysis_ref.2



##################################################################### testing
analysis_ref.2 %>% 
  dplyr::select(ref, location, sku, description, planner_number, planner_name, lot_number, days_left_on_ssl, days_left_on_expired,
                expiration_date, calculated_shippable_date, mbx, unit_cost, days_range, sum_of_inventory_qty, inventory_in_cost,
                diff_factor, total_custord_within_15_days, inv_after_custord, ending_inv_after_custord, ending_inv_after_custord_in_cost,
                fcst_daily_avg_after_15_days, consumption_factor, inv_after_custord_and_fcst, ending_inv_after_custord_and_fcst,
                ending_inv_after_custord_and_fcst_in_Cost) -> aa


aa %>% filter(ref == "10_12522LOU" & lot_number == "Z13822046")
writexl::write_xlsx(aa, "test.xlsx")


##### Don't forget with the Sys.Date() 

##################################################################################################################################################
#################################################################### final touch #################################################################
##################################################################################################################################################


analysis_ref.2 %>% 
  dplyr::select(ref, location, sku, description, planner_number, planner_name, lot_number, days_left_on_ssl, days_left_on_expired,
                expiration_date, calculated_shippable_date, mbx, unit_cost, days_range, sum_of_inventory_qty, inventory_in_cost,
                diff_factor, total_custord_within_15_days, inv_after_custord, ending_inv_after_custord, ending_inv_after_custord_in_cost,
                fcst_daily_avg_after_15_days, consumption_factor, inv_after_custord_and_fcst, ending_inv_after_custord_and_fcst,
                ending_inv_after_custord_and_fcst_in_Cost) -> final_analysis_result


analysis_ref.2 %>% 
  dplyr::mutate(ref = gsub("_", "-", ref)) -> analysis_ref.2


colnames(final_analysis_result)[1]<-"ref"
colnames(final_analysis_result)[2]<-"Location"
colnames(final_analysis_result)[3]<-"Sku"
colnames(final_analysis_result)[4]<-"Description"
colnames(final_analysis_result)[5]<-"Planner#"
colnames(final_analysis_result)[6]<-"Planner Name"
colnames(final_analysis_result)[7]<-"Lot#"
colnames(final_analysis_result)[8]<-"Days left on SSL"
colnames(final_analysis_result)[9]<-"Days left on expired"
colnames(final_analysis_result)[10]<-"Expiration Date"
colnames(final_analysis_result)[11]<-"Calculated Shippable Date"
colnames(final_analysis_result)[12]<-"MBX"
colnames(final_analysis_result)[13]<-"Unit Cost"
colnames(final_analysis_result)[14]<-"Days Range"
colnames(final_analysis_result)[15]<-"Sum of Inventory Qty (Cases)"
colnames(final_analysis_result)[16]<-"Inventory in $"
colnames(final_analysis_result)[17]<-"Diff Factor"
colnames(final_analysis_result)[18]<-"Total CustOrd (within 15 days)"
colnames(final_analysis_result)[19]<-"Inv after CustOrd"
colnames(final_analysis_result)[20]<-"Ending Inv After CustOrd"
colnames(final_analysis_result)[21]<-"Ending Inv After CustOrd in $"
colnames(final_analysis_result)[22]<-"Fcst daily avg. (after 15 days)"
colnames(final_analysis_result)[23]<-"Consumption Factor"
colnames(final_analysis_result)[24]<-"Inv after Custord & Fcst"
colnames(final_analysis_result)[25]<-"Ending Inv after Custord & Fcst"
colnames(final_analysis_result)[26]<-"Ending Inv after Custord & Fcst in $"


writexl::write_xlsx(final_analysis_result, "expiration analysis ver3.xlsx")
