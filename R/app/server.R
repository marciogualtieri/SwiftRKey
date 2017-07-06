source("globals.R")
source("apply_styles.R")
source("controllers/keyboard_controller.R")
source("controllers/readme_controller.R")
source("controllers/dashboard_controller.R")

shinyServer(function(input, output, session) {
    session$onSessionEnded(function() {
        saveRDS(STATISTICS_DATA, STATISTICS_DATA_FILE)
        saveRDS(FREQUENCIES_DATA, FREQUENCIES_DATA_FILE)
    })
    
    observe({
        invalidateLater(180000, session)
        print("Updating dashboard data...")
        update_statistics()
        update_frequencies()
        print("Emptying submitted data...")
        SUBMISSIONS_DATA <<- empty_submissions_data()
        print("Boom. Done!")
    })

    apply_styles()
    keyboard_controller(input, output, session)
    create_dashboard(input, output)
    readme_controller(output)
})