source("globals.R")
source("views/keyboard_view.R")
source("views/readme_view.R")
source("views/dashboard_view.R")

shinyUI(fluidPage(theme = "style.css", useShinyjs(), tabsetPanel(id = "tabs",
                                                                 keyboard_view(),
                                                                 dashboard_view(),
                                                                 readme_view()
)))