#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
source('bikedata.R')

# Define UI for application that draws a histogram
ui <- fluidPage(
  
  # Application title
  titlePanel("NYC Automated Bike Counters: Bikes Trips Summary"),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    sidebarPanel(
      checkboxInput("checkbox", label = "Filter dates with known interference", value = TRUE),

      selectInput("location", label = h3("Select location"), 
                  choices = counter_locations$name,
                  selected = 'Prospect Park West'),
      selectInput("type", label = h3("Select summary level"), 
                  choices = c('Day', 'Month'),
                  selected = 'Month'),
      uiOutput("dateRange") #reactive changes min/max dates to match data--see server
    ),
    
    
    # Show a plot of the generated distribution
    mainPanel(
      plotOutput("distPlot")
    )
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  #get df
  currentdf        <- reactive({ load(input$location, input$type) })
  #make reactive date range for UI
  #source: https://stackoverflow.com/questions/48633984/pass-a-dynamic-date-date-range-to-daterangeinput-in-r-shiny
  output$dateRange <- renderUI({
    dateRangeInput("date", h3("Select the date range:"),
                   start = 
                     as.character(format(as.Date(min(currentdf()$date))),"yyyy-mm-dd"), # Start 
                   end = 
                     as.character(format(as.Date(max(currentdf()$date))),"yyyy-mm-dd"), # End 
                   min = 
                     as.character(format(as.Date(min(currentdf()$date))),"yyyy-mm-dd"),
                   max = 
                     as.character(format(as.Date(max(currentdf()$date))),"yyyy-mm-dd"),
                   format = "yyyy-mm-dd")
    
  })
  
  #make plot
  output$distPlot   <- renderPlot({
    # draw the plot with the specified number of bins
    df <- currentdf() # df is the user selected dataset
    dfDates<- subset(df, date >= input$date[1] & date <= 
                      input$date[2] )
    plot(dfDates, input$type )
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
