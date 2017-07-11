library(plyr)

.backoff_history <- function(history) {
    history_words <- strsplit(history, split = " |'")
    ifelse(
        length(history_words[[1]]) > 1,
        trimws(paste(backoff_history_words <- history_words[[1]][2:length(history_words[[1]])], collapse = " ")),
        ""
    )
}

.extract_words_from_history <- function(model) unique(
    unname(
        unlist(
            sapply(rownames(model), function(x) ifelse(x == "", x, strsplit(x, split = "[[:punct:] ]")))
        )
    )
)

.build_top_suggestions <- function(model, history, word_row, n) {
    word_row["<unknown>"] <- NA
    top_suggestions_indexes <- head(order(word_row, decreasing = TRUE), n = n)
    top_suggestions <- colnames(model)[top_suggestions_indexes]
    as.list(top_suggestions)
}

.build_top_suggestions_with_probabilities <- function(model, history, word_row, n) {
    word_row["<unknown>"] <- NA
    top_suggestions_indexes <- head(order(word_row, decreasing = TRUE), n = n)
    top_suggestions <- colnames(model)[top_suggestions_indexes]
    top_suggestions <- as.list(top_suggestions)
    names(top_suggestions) <- model[ifelse(history == "", 1, history), top_suggestions_indexes]
    top_suggestions
}

.replace_unknown_words <-function(history, model) {
    words <- .extract_words_from_history(model)
    if(history == "") return(history)
    history_words <- strsplit(history, split = " ")
    history_words <- sapply(history_words, function(x) ifelse(x %in% words, x, "<unknown>"))
    paste(history_words, collapse = " ")
}


#' Given a history of words, returns word suggestions (predictions) ordered by greatest probability.
#'
#' The function uses an included model (a Markov transition matrix) generated with the notebook
#' created for this project.
#'
#' @param model the prediction model. At the moment there's a single one for the English language
#' (named "model"). Future releases might include new ones (e.g. "model_german" or "model_french").
#'
#' @param history history of words (string) used to predict the next word (suggestion).
#'
#' @param n number of suggestions to return.
#'
#' @param with_probabilities if TRUE, names the suggestions with their correspondent
#' probabilities.
suggestions <- function(model, history, n = 5, with_probabilities = FALSE) {
    history <- tolower(history)
    history <- .replace_unknown_words(history, model)
    history <- ifelse(history == "", 1, history)
    word_row <- try_default(model[history, ], c(), quiet = TRUE)
    if(length(word_row) > 0)
        if(with_probabilities) .build_top_suggestions_with_probabilities(model, history, word_row, n)
        else .build_top_suggestions(model, history, word_row, n)
    else suggestions(model, .backoff_history(history), n = n)
}
