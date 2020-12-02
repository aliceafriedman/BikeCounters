library(RColorBrewer)
library(tidyverse)
library(lubridate)
library(scales)
library(jsonlite)

######graphics settings
lineColor <- "#aaaaaa"
lineThickness <- 0.1


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


#######HELPER FUCNTIONS

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
########### LOAD DATA
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

#load data function
load <- function(location, type){
  #load data and subset
  all_data <- known(location)
  df <- subset(all_data, name==location)
  if(type == "Day"){df <- sumByDay(df)}
  else{df <- sumByMonth(df)}
  df <- df %>% mutate(year = year(date))
  return(df)
}




###GENERATE PLOT
plot <- function(df, type) {
  p <- ggplot(df)
  
  #differentiate by aggregation type
  if(type=="Month") { #for MONTH aggregation
    
    #how many years are in the data determines the color scale
    n <- n_distinct(df$year, na.rm = FALSE)
    greens <- brewer.pal(n, "Greens")
    
    #month-specific plot
    p <- p + 
      geom_col(aes(month(date, label=TRUE, abbr=TRUE), total, fill=factor(year)), position = 'dodge') +
      scale_y_continuous(labels = comma,expand = c(0, 10)) + 
      scale_fill_manual(values = greens) +
      labs(x= "Date", y="Bikes per Month")
    } 
  else { #for DAY aggregation
    p <- p + 
      geom_col(aes(date, total, fill=factor(fillColor)), position = 'dodge') +
      labs(x= "Date", y="Bikes per Day")+  
      scale_fill_manual(values=c('#08FF7D', '#00a54e')) 
  }
  
  # SAME for all plots  
  p <- p+
    theme_bw() + 
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y =  element_line(colour = lineColor, size = lineThickness),
          panel.border = element_blank(),
          axis.line.x = element_line(colour = lineColor, size = lineThickness),
          axis.line.y = element_blank(),
          axis.ticks.x = element_line(colour = lineColor, size = lineThickness),
          axis.ticks.y = element_blank(),
          legend.title=element_blank(),
          strip.background = element_blank(),
          text = element_text(family="sans", size=14)
          )
  return(p)
}


#pre-load some big datasets 
#known('Kent Avenue Bike Path')
all_data <- known('Prospect Park West')



