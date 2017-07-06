dashboard_view <- function() {
    tabPanel(id = "dashboard", "Dashboard",
             absolutePanel(top = 60,
                           width = '30%', height = 400,
                           tableOutput("statistics_table")),
             absolutePanel(left = 300,
                           width = '60%', height = 375,
                           plotOutput("wordcloud")),
             absolutePanel(top = 425, left = 25,
                           width = '97%',
                           plotOutput("frequencies"))
    )
}