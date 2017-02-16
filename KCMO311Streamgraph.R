# Process and streamgraph-visualize compatible government service request data
# Orignally by @technickle. and adapted to KCMO's data by @EricRoche 
# This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
# (see https://creativecommons.org/licenses/by-sa/4.0/ for more)

#Streamgraph doesn't always install correctly. So you have to do a devtools dance to get it to work.
library(devtools)

#Was having an issue with not getting the zoo package. You may also need to install the yaml package. Installed those and then this worked. 
devtools::install_github("hrbrmstr/streamgraph")

#load remaining packages
library(readr)
library(dplyr)
library(streamgraph)
library(RSocrata)

#Get 311 Data.
#This can take awhile. It's a lot of data. 
Bulk311 <- read.socrata("https://data.kcmo.org/311/311-Call-Center-Service-Requests/7at3-sxhp")
#Dates are in POSIXct format

# since this can be running on an arbitrary date, get a date for the end of the previous month
range_end <- as.Date(paste(format(Sys.Date(), "%Y-%m"), "-01", sep="")) - 1
range_start <- range_end - (365*1)

# grab only the requested_datetime and service_name columns;
# truncate requested_datetime so it only has dates
# filter for the last year of data, remove any "future" records, 
#Had an issue with the first mutate command not liking the POSIXct format. Hence, the "as.Date()" was added.
Bulk311_Last365Days <- Bulk311 %>%
  select(CREATION.DATE, REQUEST.TYPE) %>% 
  filter(as.Date(CREATION.DATE) >= range_start & as.Date(CREATION.DATE) <= range_end) %>%
  mutate(year_month=format(CREATION.DATE, "%Y-%B"), day=format(CREATION.DATE, "%d")) %>%
  mutate(first_of_month = as.Date(paste(year_month, "-01", sep=""),"%Y-%B-%d"))

# get the top 10 most frequent service_names based upon entire year of data
Bulk311_TopTenServiceNames <- Bulk311_Last365Days %>%
  select(REQUEST.TYPE) %>%
  group_by(REQUEST.TYPE) %>%
  tally(sort=TRUE) %>%
  top_n(Bulk311)

# filter out last year's data so it only includes the top 10 most frequent services
Bulk311_Last365Days_of_TopTenServiceNames <- Bulk311_Last365Days %>% 
  filter(REQUEST.TYPE %in% Bulk311_TopTenServiceNames$REQUEST.TYPE)

# aggregate last year's data by month and service name and count them up
Bulk311_MonthAggregation_of_TopTenServices <- Bulk311_Last365Days_of_TopTenServiceNames %>%
  group_by(REQUEST.TYPE,first_of_month) %>%
  tally()

# generate the graph! the last line suppresses the Y-axis labels
Bulk311_MonthAggregation_of_TopTenServices %>%
  streamgraph("REQUEST.TYPE","n","first_of_month", offset="zero") %>%
  sg_axis_x(tick_format = "%b%Y") %>%
  sg_axis_y(tick_count = 0, tick_format = )
