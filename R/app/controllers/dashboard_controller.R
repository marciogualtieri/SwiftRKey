create_dashboard <- function(input, output) {
    observeEvent(input$tabs, {
        output$statistics_table <- renderTable({ STATISTICS_DATA })
        if(nrow(FREQUENCIES_DATA) > 0) {
            output$wordcloud <- renderPlot({
                suppressWarnings(isolate(
                    wordcloud(FREQUENCIES_DATA$word,
                              FREQUENCIES_DATA$frequency,
                              scale=c(4,0.5),
                              min.freq = 1, max.words=30,
                              colors = brewer.pal(9,"Greys"))
                ))
            })
        }
        if(nrow(FREQUENCIES_DATA) > 0) {
            output$frequencies <- renderPlot({
                suppressWarnings(isolate(
                    frequency_barchart(FREQUENCIES_DATA)
                ))
            })
        }
    })
}
