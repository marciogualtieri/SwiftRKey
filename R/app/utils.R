epithets <- readLines("./data/epithets.txt")

remove_epithets <- function(text) {
    words <- strsplit(text, split = "[[:punct:] ]")
    for(word in words[[1]]) {
        if(tolower(word) %in% epithets) text <- gsub(word, "<epithet>", text)
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

frequency_barchart <-function(frequencies) {
    par(lwd = 3)
    barplot(frequencies$frequency, names.arg = frequencies$word,
         main = "Top Words Typed",
         xlab ="Word", ylab = "Frequency",
         font.lab = 2,
         col = alpha("grey", 0.8),
         border = "grey")
    box(lwd = 1, lty = "solid")
}
