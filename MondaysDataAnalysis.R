#This script is for looking at a single 24 hour period - a typical Monday, if you will. 

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
library(chron)
library(lubridate)

# since this can be running on an arbitrary date, get a date for the end of the previous month
range_end <- as.Date(paste(format(Sys.Date(), "%Y-%m"), "-01", sep="")) - 1
range_start <- range_end - (365*1)

#Add day of week to Data
Bulk311$CreationWeekday <- weekdays(as.Date(Bulk311$CREATION.DATE))

##Create Creation Date and Time Merge. 
Bulk311$CreationDateTime <- paste(Bulk311$CREATION.DATE, Bulk311$CREATION.TIME, sep = " ")
Bulk311$CreationDateTime <- as.POSIXct(Bulk311$CreationDateTime, format = "%Y-%m-%d %I:%M %p")

#grab only the requested_datetime and service_name columns
#truncate requested_datetime so it only has dates
#filter for the last year of data, remove any "future" records, 
#Had an issue with the first mutate command not liking the POSIXct format. Hence, the "as.Date()" was added.
Bulk311_Last365Days <- Bulk311 %>%
  filter(CreationWeekday == "Monday") %>%
  select(CreationDateTime, REQUEST.TYPE) %>% 
  filter(as.Date(CreationDateTime) >= range_start & as.Date(CreationDateTime) <= range_end) %>%
  mutate(year_month=format(CreationDateTime, "%Y-%B"), day=format(CreationDateTime, "%d")) %>%
  mutate(first_of_month = as.Date(paste(year_month, "-01", sep=""),"%Y-%B-%d"))

# get the top 10 most frequent service_names based upon entire year of data
Bulk311_TopTenServiceNames <- Bulk311_Last365Days %>%
  select(REQUEST.TYPE) %>%
  group_by(REQUEST.TYPE) %>%
  tally(sort=TRUE) %>%
  top_n(10)

# filter out last year's data so it only includes the top 10 most frequent services
Bulk311_Last365Days_of_TopTenServiceNames <- Bulk311_Last365Days %>% 
  filter(REQUEST.TYPE %in% Bulk311_TopTenServiceNames$REQUEST.TYPE)

# aggregate last year's data by month and service name and count them up
#Need to strip off minutes

#####Issue is that we need to convert to as.Date without losting the time... Posix is not currently supported
#https://hrbrmstr.github.io/streamgraph/
Bulk311_Last365Days_of_TopTenServiceNames$FakeDate <- strftime(Bulk311_Last365Days_of_TopTenServiceNames$CreationDateTime, "%I:%M %p")
Bulk311_Last365Days_of_TopTenServiceNames$FakeDate <- as.POSIXct(Bulk311_Last365Days_of_TopTenServiceNames$FakeDate, format = "%I:%M %p")
Bulk311_Last365Days_of_TopTenServiceNames$FakeDate <- floor_date(Bulk311_Last365Days_of_TopTenServiceNames$FakeDate, unit = "minute")

#Bulk311_Last365Days_of_TopTenServiceNames$FakeDate <- (Bulk311_Last365Days_of_TopTenServiceNames$FakeDate, format = "%Y-%m-%d %I:%M %p")
Bulk311_MonthAggregation_of_TopTenServices <- Bulk311_Last365Days_of_TopTenServiceNames %>%
  group_by(REQUEST.TYPE, FakeDate) %>%
    tally()
     
#Give up because the streampgrah package doesn't support posixCT graphing and therefore we must find another solution!
#Export data to csv
write.csv(Bulk311_MonthAggregation_of_TopTenServices, file = "MondaysAt311.csv")

