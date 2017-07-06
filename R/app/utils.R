backoff_history <- function(history) {
    history_words <- strsplit(history, split = " |'")
    ifelse(
        length(history_words[[1]]) > 1,
        trimws(paste(backoff_history_words <- history_words[[1]][2:length(history_words[[1]])], collapse = " ")),
        ""
    )
}

extract_words_from_history <- function(model) unique(
    unname(
        unlist(
            sapply(rownames(model), function(x) ifelse(x == "", x, strsplit(x, split = "[[:punct:] ]")))
        )
    )
)

build_top_suggestions <- function(model, history, word_row, n) {
    word_row["<unknown>"] <- NA
    top_suggestions_indexes <- head(order(word_row, decreasing = TRUE), n = n)
    top_suggestions <- colnames(model)[top_suggestions_indexes]
    as.list(top_suggestions)
}

replace_unknown_words <-function(history, model) {
    words <- extract_words_from_history(model)
    if(history == "") return(history)
    history_words <- strsplit(history, split = " ")
    history_words <- sapply(history_words, function(x) ifelse(x %in% words, x, "<unknown>"))
    paste(history_words, collapse = " ")
}

suggestions <- function(model, history, n = 5) {
    history <- tolower(history)
    history <- replace_unknown_words(history, model)
    history <- ifelse(history == "", 1, history)
    word_row <- try_default(model[history, ], c(), quiet = TRUE)
    if(length(word_row) > 0) build_top_suggestions(model, history, word_row, n)
    else suggestions(model, backoff_history(history), n = n)
}

epithets <- readLines("./data/epithets.txt")

remove_epithets <- function(text) {
    words <- strsplit(text, split = "[[:punct:] ]")
    for(word in words[[1]]) {
        if(word %in% epithets) text <- gsub(word, "<epithet>", text)
    }
    text
}

clean_corpus <- function(corpus, words_to_remove){
    corpus <- tm_map(corpus, content_transformer(bracketX))
    corpus <- tm_map(corpus, stripWhitespace)
    corpus <- tm_map(corpus, removePunctuation)
    corpus <- tm_map(corpus, content_transformer(tolower))
    return(corpus)
}

tokenizer <- function(x) 
    NGramTokenizer(x, Weka_control(min = 1, max = 1))

create_frequencies_data_frame <- function(document_term_matrix) {
    frequencies <- colSums(document_term_matrix)
    word_frequencies <- data.frame(word = names(frequencies), frequency = frequencies)
    rownames(word_frequencies) <- 1:nrow(word_frequencies)
    return(word_frequencies)
}

create_corpus <- function(data) {
    data <- data[!is.na(data) & !is.null(data)]
    VCorpus(VectorSource(data))
}

extract_word_frequencies <- function(data) {
    data_corpus <- create_corpus(data)
    data_corpus <- clean_corpus(data_corpus)
    document_term_matrix <- DocumentTermMatrix(data_corpus, control = list(tokenize = tokenizer))
    frequencies <- create_frequencies_data_frame(as.matrix(document_term_matrix))
    frequencies <- frequencies[order(frequencies$frequency, decreasing = TRUE), ]
    return(frequencies)
}

frequency_barchart <-function(frequencies)
    ggplot(frequencies, aes(x = word, y = frequency)) +
    geom_bar(stat="identity", fill = "grey") +
    scale_x_discrete(limits = frequencies$word) +
    ggtitle(paste("Top", nrow(frequencies), "Word Frequencies Typed")) +
    ylab("Frequency") +
    theme(axis.text.x = element_text(size = 12, angle = 90, hjust = 1, vjust = 0.5)) +
    theme(plot.title = element_text(size = 18, face = "bold",
                                    hjust = 0.5, margin = margin(b = 30, unit = "pt"))) +
    theme(axis.title.x = element_blank()) +
    theme(axis.title.y = element_text(size = 14, face="bold")) +
    theme(panel.background = element_blank(), axis.line = element_line(colour = "black")) +
    theme(panel.border = element_rect(colour = "black", fill = NA, size = 0.5)) +
    theme(strip.background = element_rect(fill = alpha("grey", 0.3), color = "black", size = 0.5)) +
    theme(legend.title = element_blank())