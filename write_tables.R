library(jsonlite)
library(tidyverse)
library(lubridate)

######GENERATE COUNTER LOCATIONS

# add the locations so we can join descriptions of each counting station
counter_locations_Raw <- read_csv('https://data.cityofnewyork.us/resource/smn3-rzf9.csv')

#filter locations
counter_locations <- counter_locations_Raw %>% 
  select(name, id, sens, counter) %>%
  subset(sens == 0) %>%
  mutate(name = trimws(as.character(name))) %>%
  filter(!grepl("Interference", name)) %>%
  drop_na(counter)

write.csv(counter_locations, "locations.csv", row.names=F)


#######HELPER FUNCTIONS

#get id from name
id <- function(name){
  print(id)
  id <- counter_locations$id[counter_locations$name==name]
  return(id)
}

# the endpoint for the source dataset
downloadURL <- 'https://data.cityofnewyork.us/resource/uczf-rk3c.json?'

#function to download data based on id
rawData <- function(name){
  id <- id(name)
  #  print(id)
  url <- paste0(downloadURL,"$order=date&$limit=500000&id=",id)
  print(paste("Downloading data from", url))
  rawdata  <- fromJSON(url)
  return(as.tbl(rawdata))
}  


#function to filter data
cleanData <- function(name){
  rawdata <- rawData(name) #get raw data from API
  cleandata <- rawdata %>% # filter and merge
    mutate(date=ymd_hms(date), 
           id = as.numeric(id), 
           counts = as.numeric(counts), 
           year = year(date)) %>% 
    #remove extra counts
    arrange(counts)%>% distinct(id, date, .keep_all = TRUE) %>%
    #add names  
    left_join(select(counter_locations, id, name), by='id')
  return(cleandata)
} 

sumByMonth <- function(df){
  dfByMonth <- df %>%
    #summarize counts by month
    mutate(date = floor_date(date, unit = "months")) %>%
    group_by(date, name) %>%
    summarize(total = sum(counts)) 
  return(dfByMonth)
}

sumByDay <- function(df){
  dfByDay <- df %>%
    #summarize counts by month
    mutate(date = floor_date(date, unit = "days")) %>%
    group_by(date, name) %>%
    summarize(total = sum(counts)) %>% 
    mutate(fillColor = ifelse((wday(date) == 1 | wday(date) == 7), 'Weekend', 'Weekday'), wday = wday(date))
  return(dfByDay)
}

dataList <- list()

#checks to see if locaton already downloaded
known <- function(location){
  
  if (is.null(dataList[[location]])){ 
    print(paste(location, "not yet downloaded"))
    qry <- cleanData(location)
    dataList[[location]] <<- qry
  }
  else{
    print(paste(location, "found in data"))
  }
  
  all_data <- do.call(rbind, dataList)
  return(all_data)
}




################################################

########### LOAD DATA
#filter known interference dates
#dates based on metadata here https://data.cityofnewyork.us/Transportation/Bicycle-Counts/uczf-rk3c
#note: this does *not* update automatically if new interference found
filterDates <- read_csv("FilteredLoc.csv") %>% 
  select(id, filterBefore) %>%
  drop_na() %>%
  mutate(filterBefore = parse_date_time(filterBefore, "%B %d, %Y"))

#Download all locations
for (l in counter_locations$name){
  known(l)
  }


#### PROCESS DATA

#Filter data for interefence
data_f <- do.call(rbind, dataList) %>%
  left_join(filterDates) %>% 
  dplyr::filter(date > filterBefore | is.na(filterBefore)) %>%
  arrange(date, name) %>%
  mutate(key = paste(name, year)) # add key to match to complete years

#Count days of data in year of location
completeYears <- data_f %>% 
  sumByDay() %>% 
  mutate(year = year(date), month=month(date)) %>%
  group_by(year, name) %>%
  summarise(days_of_year = n()) %>%
  filter(days_of_year >= 365) %>%
  mutate(key=paste(name, year))

#filter for complete years
data_complete_yr <- data_f %>%
  filter(key %in% completeYears$key) # here is where you select the complete years by locations

##### WRITE TABLES
data_f %>% 
  sumByDay() %>% 
  arrange(name, date) %>%
  write_csv("All Locations By Day.csv")

data_f %>% 
  sumByMonth() %>% 
  arrange(name, date) %>%
  write_csv("All Locations By Month.csv")

#complete year data
data_complete_yr  %>% 
  sumByMonth() %>% 
  arrange(name, date) %>%
  write_csv("Complete Year All Locations By Month.csv")
