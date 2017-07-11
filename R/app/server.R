source("globals.R")
source("apply_styles.R")
source("controllers/keyboard_controller.R")
source("controllers/readme_controller.R")
source("controllers/dashboard_controller.R")

shinyServer(function(input, output, session) {
    observe({
        invalidateLater(60000, session)
        update_statistics()
        update_frequencies()
        save(STATISTICS_DATA, file = STATISTICS_DATA_FILE)
        save(FREQUENCIES_DATA, file = FREQUENCIES_DATA_FILE)
        SUBMISSIONS_DATA <<- empty_submissions_data()
    })

    apply_styles()
    keyboard_controller(input, output, session)
    create_dashboard(input, output)
    readme_controller(output)
})
