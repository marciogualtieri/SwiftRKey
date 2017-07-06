source("utils.R")

model <- readRDS("./data/model.rds")
current_suggestions <- as.list(replicate(6, ""))
first_keystroke <- TRUE
keystroke_discount <- 0
submission_start <- NA
suggestions_given_counter <- 0
suggestions_accepted_counter <- 0

create_suggestion_button <- function(button_id, input, session) {
    actionButton(inputId = button_id, label = button_id,
                 class = "suggestion_button", id = button_id)
}

update_suggestion_button <- function(index, session) {
    button_id <- paste0("suggestion", index)
    updateActionButton(session, inputId = button_id, label = current_suggestions[[index]])
}

create_suggestion_button_observer <- function(index, session, input) {
    button_id <- paste0("suggestion", index)
    observeEvent(input[[button_id]], {
        suggestions_accepted_counter <<- suggestions_accepted_counter + 1
        keystroke_discount <<- keystroke_discount - nchar(current_suggestions[[index]])
        updateTextInput(session, inputId = "text", value = paste0(input$text, current_suggestions[[index]]))
        hide(id = "suggestions_panel", anim = TRUE)
    })
}

create_submission_button_observer <- function(input, output) {
    observeEvent(input$submission_button, {
        submission_end <- Sys.time()
        insert_submission(format(submission_end,  "%a, %d %b %Y %H:%M:%S"),
                       remove_epithets(input$text),
                       submission_end - submission_start,
                       nchar(input$text),
                       nchar(input$text) + keystroke_discount,
                       suggestions_given_counter, suggestions_accepted_counter)
        output$submissions_table <- renderTable({ SUBMISSIONS_DATA[, 1:2] })
        first_keystroke <<- TRUE
        keystroke_discount <<- 0
        suggestions_given_counter <<- 0
        suggestions_accepted_counter <<- 0
    })
}

formatted_suggestions <- function(model, history, n = 4) {
    lowercase_suggestions <- suggestions(model, history, n)
    camelcase_suggestions <- to_any_case(lowercase_suggestions, case = "big_camel")
    append(lowercase_suggestions, camelcase_suggestions)
}

create_text_input <- function(input, output, session) {
    observeEvent(input$text, {
        if(first_keystroke) {
            submission_start <<- Sys.time()
            first_keystroke <<- FALSE
        }
        if(grepl(paste0("[ ']$"), input$text) == TRUE) {
            suggestions_given_counter <<- suggestions_given_counter + 1
            current_suggestions <<- formatted_suggestions(model, input$text)
            if(length(suggestions) > 0) {
                sapply(1:length(current_suggestions), update_suggestion_button, session = session)
                show(id = "suggestions_panel", anim = TRUE)
                
            }
        } else
            hide(id = "suggestions_panel", anim = TRUE)
    })
    
    sapply(1:length(current_suggestions), create_suggestion_button_observer, session = session, input = input)
    create_submission_button_observer(input, output)
}


keyboard_controller <- function(input, output, session) {
    create_text_input(input, output, session)
}