keyboard_view <- function() {
    tabPanel(id = "keyboard", "Keyboard",

             absolutePanel(width = 410,
                 div(div(class = "side_by_side_div", textInput("text", "", value = "", width = 325, placeholder = NULL)),
                     div(class = "side_by_side_div", actionButton(inputId = "submission_button",
                                                                  label = "Submit", class = "submission_button",
                                                                  width = 70))
                 ),
                 absolutePanel(id = "suggestions_panel", class = "colored_panel",
                               width = 400, height = 100,
                               actionButton(inputId = "suggestion1", label = "Information", class = "suggestion_button"),
                               actionButton(inputId = "suggestion2", label = "is", class = "suggestion_button"),
                               actionButton(inputId = "suggestion3", label = "the", class = "suggestion_button"),
                               actionButton(inputId = "suggestion4", label = "resolution", class = "suggestion_button"),
                               br(),
                               actionButton(inputId = "suggestion5", label = "of", class = "suggestion_button"),
                               actionButton(inputId = "suggestion6", label = "uncertainty", class = "suggestion_button"),
                               actionButton(inputId = "suggestion7", label = "Claude", class = "suggestion_button"),
                               actionButton(inputId = "suggestion8", label = "Shannon", class = "suggestion_button")
                 )
                 
             ),
             absolutePanel(top = 63, left = 430,
                           width = 400,
                           tableOutput("submissions_table")
             )
    )
}