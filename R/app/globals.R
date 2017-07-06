library(shiny)
library(shinyjs)
library(dplyr)
library(wordcloud)
library(tm)
library(RWeka)
library(ggplot2)
library(snakecase)

options(mc.cores=1)
options(shiny.maxRequestSize=30*1024^2)

STATISTICS_DATA_FILE <- "./data/statistics.rds"

FREQUENCIES_DATA_FILE <- "./data/frequencies.rds"

MAX_WORDS <- 30

load_statistics <- function()
    if(file.exists(STATISTICS_DATA_FILE)) {
        readRDS(STATISTICS_DATA_FILE)
    } else {
        data.frame(statistic = c("Suggestions Given (#)",
                                 "Suggestions Accepted (#)",
                                 "Suggestions Accepted (%)",
                                 "Characters Submitted (#)",
                                 "Keystrokes (#)",
                                 "Keystrokes Saved (%)",
                                 "Time Typing (secs)",
                                 "Time Saved (secs)",
                                 "Time Saved (%)"),
                   value = replicate(9, 0)
        )
    }

load_frequencies <- function()
    if(file.exists(FREQUENCIES_DATA_FILE)) {
        readRDS(FREQUENCIES_DATA_FILE)
    } else {
        data.frame(word = character(0),
                   frequency = numeric(0)
        )
    }

empty_submissions_data <- function()
    data.frame(
        timestamp = character(0),
        submission = character(0),
        duration_secs = numeric(0),
        characters = numeric(0),
        keystrokes = numeric(0),
        suggestions_given = numeric(0),
        suggestions_accepted = numeric(0)
    )


insert_submission <- function(timestamp, submission, duration_secs, characters, keystrokes,
                           suggestions_given, suggestions_accepted) {
    SUBMISSIONS_DATA <<- rbind(SUBMISSIONS_DATA,
          data.frame(timestamp = timestamp,
                     submission = submission,
                     duration_secs = duration_secs,
                     characters = characters,
                     keystrokes = keystrokes,
                     suggestions_given = suggestions_given,
                     suggestions_accepted = suggestions_accepted
          )
    )
}

add_to_statistic <- function(statistic, value) {
    STATISTICS_DATA[STATISTICS_DATA$statistic == statistic, ]$value <<-
        STATISTICS_DATA[STATISTICS_DATA$statistic == statistic, ]$value + value
}

update_accuracy <- function() {
    given <- STATISTICS_DATA[STATISTICS_DATA$statistic == "Suggestions Given (#)", ]$value
    accepted <- STATISTICS_DATA[STATISTICS_DATA$statistic == "Suggestions Accepted (#)", ]$value
    if(given > 0)
        STATISTICS_DATA[STATISTICS_DATA$statistic == "Suggestions Accepted (%)", ]$value <<- round(accepted * 100/ given, 2)
}

update_time_saved <- function() {
    characters <- STATISTICS_DATA[STATISTICS_DATA$statistic == "Characters Submitted (#)", ]$value
    keystrokes <- STATISTICS_DATA[STATISTICS_DATA$statistic == "Keystrokes (#)", ]$value
    time_typing <- STATISTICS_DATA[STATISTICS_DATA$statistic == "Time Typing (secs)", ]$value
    if(keystrokes > 0) {
        time_saved <- time_typing * (characters - keystrokes) / keystrokes
        STATISTICS_DATA[STATISTICS_DATA$statistic == "Time Saved (secs)", ]$value <<- time_saved
        STATISTICS_DATA[STATISTICS_DATA$statistic == "Time Saved (%)", ]$value <<-
            round(time_saved * 100 / (time_typing + time_saved), 2)
    }
}

update_statistics <- function() {
    if(nrow(SUBMISSIONS_DATA) > 0) {
        add_to_statistic("Suggestions Given (#)", sum(SUBMISSIONS_DATA$suggestions_given))
        add_to_statistic("Suggestions Accepted (#)", sum(SUBMISSIONS_DATA$suggestions_accepted))
        add_to_statistic("Characters Submitted (#)", sum(SUBMISSIONS_DATA$characters))
        add_to_statistic("Keystrokes (#)", sum(SUBMISSIONS_DATA$keystrokes))
        add_to_statistic("Keystrokes Saved (%)", sum(SUBMISSIONS_DATA$characters) - sum(SUBMISSIONS_DATA$keystrokes))
        add_to_statistic("Time Typing (secs)", sum(SUBMISSIONS_DATA$duration_secs))
        update_accuracy()
        update_time_saved()
    }
}

update_frequencies <- function() {
    if(nrow(SUBMISSIONS_DATA) > 0) {
        max_words <- 30
        new_frequencies <- extract_word_frequencies(SUBMISSIONS_DATA$submission)
        updated_frequencies <- rbind(FREQUENCIES_DATA, new_frequencies) %>%
            group_by(word) %>%
            summarize_all(.funs = sum)

        if(nrow(updated_frequencies) > max_words) {
            FREQUENCIES_DATA <<- updated_frequencies[1:MAX_WORDS, ]
        } else {
            FREQUENCIES_DATA <<- updated_frequencies
        }
    }
}

SUBMISSIONS_DATA <- empty_submissions_data()
STATISTICS_DATA <- load_statistics()
FREQUENCIES_DATA <- load_frequencies()