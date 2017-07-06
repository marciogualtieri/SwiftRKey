dashboard_view <- function() {
    tabPanel(id = "dashboard", "Dashboard",
             absolutePanel(top = 50, left = 35,
                           width = '50%', height = 400,
                           tableOutput("statistics_table")),
             absolutePanel(left = 350,
                           width = '50%', height = 375,
                           plotOutput("wordcloud")),
             absolutePanel(top = 425, left = 15,
                           width = '97%',
                           plotOutput("frequencies"))
    )
}
