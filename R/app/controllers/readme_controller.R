readme_controller <- function(output) {
    output$readme <- renderUI({
        tags$iframe(src = "./README.html", height=900)
    })
}