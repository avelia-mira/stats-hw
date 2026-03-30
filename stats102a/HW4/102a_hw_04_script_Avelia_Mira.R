library(R6)

# gameboard and decks -----------------------------------------------------
# Do not change this code

gameboard <- data.frame(
  space = 1:40, 
  title = c(
    "Go", "Mediterranean Avenue", "Community Chest", "Baltic Avenue",
    "Income Tax", "Reading Railroad", "Oriental Avenue", "Chance",
    "Vermont Avenue", "Connecticut Avenue", "Jail", "St. Charles Place",
    "Electric Company", "States Avenue", "Virginia Avenue",
    "Pennsylvania Railroad", "St. James Place", "Community Chest",
    "Tennessee Avenue", "New York Avenue", "Free Parking",
    "Kentucky Avenue", "Chance", "Indiana Avenue", "Illinois Avenue",
    "B & O Railroad", "Atlantic Avenue", "Ventnor Avenue", "Water Works",
    "Marvin Gardens", "Go to jail", "Pacific Avenue",
    "North Carolina Avenue", "Community Chest", "Pennsylvania Avenue",
    "Short Line Railroad", "Chance", "Park Place", "Luxury Tax",
    "Boardwalk"), stringsAsFactors = FALSE)
chancedeck <- data.frame(
  index = 1:15, 
  card = c(
    "Advance to Go", "Advance to Illinois Ave.",
    "Advance to St. Charles Place", "Advance token to nearest Utility",
    "Advance token to the nearest Railroad",
    "Take a ride on the Reading Railroad",
    "Take a walk on the Boardwalk", "Go to Jail", "Go Back 3 Spaces",
    "Bank pays you dividend of $50", "Get out of Jail Free",
    "Make general repairs on all your property", "Pay poor tax of $15",
    "You have been elected Chairman of the Board", 
    "Your building loan matures"), stringsAsFactors = FALSE)
communitydeck <- data.frame(
  index = 1:16, 
  card = c(
    "Advance to Go", "Go to Jail",
    "Bank error in your favor. Collect $200", "Doctor's fees Pay $50",
    "From sale of stock you get $45", "Get Out of Jail Free",
    "Grand Opera Night Opening", "Xmas Fund matures", "Income tax refund",
    "Life insurance matures. Collect $100", "Pay hospital fees of $100",
    "Pay school tax of $150", "Receive for services $25",
    "You are assessed for street repairs",
    "You have won second prize in a beauty contest",
    "You inherit $100"), stringsAsFactors = FALSE)

# RandomDice class --------------------------------------------------------
# Do not change this code

RandomDice <- R6Class(
  classname = "RandomDice",
  public = list(
    verbose = NA,
    initialize = function(verbose = FALSE){
      stopifnot(is.logical(verbose))
      self$verbose = verbose
    },
    roll = function() {
      outcome <- sample(1:6, size = 2, replace = TRUE)
      if(self$verbose){
        cat("Dice Rolled:", outcome[1], outcome[2], "\n")
      }
      outcome
    }
  )
)

# Preset Dice -------------------------------------------------------------
# Do not change this code

PresetDice <- R6Class(
  classname = "PresetDice",
  public = list(
    verbose = NA,
    preset_rolls = double(0),
    position = 1,
    initialize = function(rolls, verbose = FALSE){
      stopifnot(is.logical(verbose))
      stopifnot(is.numeric(rolls))
      self$preset_rolls = rolls
      self$verbose = verbose
    },
    roll = function(){
      if(self$position > length(self$preset_rolls)){
        stop("You have run out of predetermined dice outcomes.")
      }
      outcome <- c(self$preset_rolls[self$position], 
                   self$preset_rolls[self$position + 1])
      self$position <- self$position + 2
      if(self$verbose){
        cat("Dice Rolled:", outcome[1], outcome[2], "\n")
      }
      outcome
    }
  )
)


# Chance and Community Decks ----------------------------------------------
# Do not change this code

# This R6 class object shuffles the card deck when initialized.
# It has one method $draw(), which will draw a card from the deck.
# If all the cards have been drawn (position = deck length), then it will
# shuffle the cards again.
# The verbose option cats the card that is drawn on to the screen.
CardDeck <- R6Class(
  classname = "CardDeck",
  public = list(
    verbose = NA,
    deck_order = double(0), 
    deck = data.frame(),
    position = 1,
    initialize = function(deck, verbose = FALSE){
      stopifnot(is.data.frame(deck),
                is.numeric(deck[[1]]),
                is.character(deck[[2]]))
      self$deck_order <- sample(length(deck[[1]]))
      self$verbose <- verbose
      self$deck <- deck
    },
    draw = function(){
      if(self$position > length(self$deck_order)){
        # if we run out of cards, shuffle deck
        # and reset the position to 1
        if(self$verbose){
          cat("Shuffling deck.\n")
        }
        self$deck_order <- sample(length(self$deck[[1]]))
        self$position <- 1
      }
      outcome <- c(self$deck_order[self$position]) # outcome is the value at position
      self$position <- self$position + 1 # advance the position by 1
      if(self$verbose){
        cat("Card:", self$deck[outcome, 2], "\n")
      }
      outcome # return the outcome
    }
  )
)


# R6 Class SpaceTracker ---------------------------------------------------
# Do not change this code

SpaceTracker <- R6Class(
  classname = "SpaceTracker",
  public = list(
    counts = rep(0, 40),
    verbose = TRUE,
    tally = function(x){
      self$counts[x] <- self$counts[x] + 1
      if(self$verbose){
        cat("Added tally to ", x, ": ", gameboard$title[x], ".\n", sep = "")
      }
    },
    initialize = function(verbose){
      self$verbose <- verbose
    }
  )
)


# VERY BASIC turn taking example ------------------------------------------
# You will need to expand this
# You can write helper function if you want

# R6 Class Player ---------------------------------------------------------

Player <- R6Class(
  classname = "Player",
  public = list(
    pos = 1,
    verbose = TRUE,
    in_jail = FALSE,
    jail_turn_count = 0,
    
    initialize = function(verbose = FALSE, pos = 1) {
      # check the inputs, then set defaults
      stopifnot(is.logical(verbose), is.numeric(pos))
      self$verbose <- verbose
      self$pos <- pos
      self$in_jail <- FALSE
      self$jail_turn_count <- 0
    },
    
    move_fwd = function(n){
      # handles board wrap-around
      self$pos <- (self$pos + n - 1) %% 40 + 1
      
      if(self$verbose){
        # if pos is a vector, this prints multiple statuses
        cat("Player is now at ", self$pos, ": ", gameboard$title[self$pos], ".\n", sep = "")
      }
      invisible(self)
    },
    
    set_pos = function(n){
      # when a card or rule teleports the player directly, clean jump to a new location
      self$pos <- n
      if(self$verbose){
        cat("Player moves to ", self$pos, ": ", gameboard$title[self$pos], ".\n", sep = "")
      }
      invisible(self)
    },
    
    send_to_jail = function(){
      # whenever we go to jail, reset the jail counter. counter also tracks how many turns we have been stuck there
      if(self$verbose) cat("Player goes to jail.\n")
      self$pos <- 11
      self$in_jail <- TRUE
      self$jail_turn_count <- 0
      invisible(self)
    }
  )
)

# take_turn function
take_turn <- function(player, spacetracker) {
  
  if (player$in_jail) {
    # if we are in jail, we always roll first, then decide if we can leave. check for doubles or third attempt
    player$jail_turn_count <- player$jail_turn_count + 1
    dice_rolls <- dice$roll()
    
    # doubles comparison
    is_doubles <- dice_rolls[1] == dice_rolls[2]
    
    # exit conditions check
    can_exit <- is_doubles || player$jail_turn_count == 3
    
    if (player$verbose) {
        cat("In Jail. Rolled:", dice_rolls, "\n")
        if (can_exit) cat("Player exits jail.\n") else cat("Player stays in jail.\n")
    }

    if (!can_exit) {
      # tally jail, no movement if stayed
      spacetracker$tally(11) # 11 = Jail
      return()
    }
    
    # execute exit once conditions and clear jail flags
    player$in_jail <- FALSE
    player$jail_turn_count <- 0
    player$move_fwd(sum(dice_rolls))
    
    # check landing and honor landing effects right after leaving jail
    if (player$pos == 31) {
       player$send_to_jail()
       spacetracker$tally(11)
    } else {
       spacetracker$tally(player$pos)
       handle_cards(player, spacetracker)
    }
    return() 
  }
  
  # doubles streak to trigger jail if it's at 3
  doubles_streak <- 0
  rolling <- TRUE
  
  while (rolling) {
    dice_rolls <- dice$roll()
    
    # doubles comparison
    is_doubles <- dice_rolls[1] == dice_rolls[2]
    
    # reset streak if not doubles
    if (is_doubles) {
      doubles_streak <- doubles_streak + 1
    } else {
      doubles_streak <- 0 
    }
    
    # three double jail check
    if (doubles_streak == 3) {
      if (player$verbose) cat("3 Doubles! Speeding -> Jail.\n")
      player$send_to_jail()
      spacetracker$tally(11)
      break
    }
    
    # movement
    if (player$verbose) cat("Rolled:", dice_rolls, "- Moving.\n")
    player$move_fwd(sum(dice_rolls))
    
    # jail chekc
    if (player$pos == 31) {
      player$send_to_jail()
      spacetracker$tally(11)
      break
    }
    
    # tally landing
    spacetracker$tally(player$pos)
    
    # if sent to jail, break
    if (handle_cards(player, spacetracker)) break 
    
    # if we rolled doubles, get an extra roll
    rolling <- is_doubles
    
    if (rolling && player$verbose) cat("Doubles! Rolling again.\n")
  }
}

handle_cards <- function(player, spacetracker) {
  
  # these are the chance cards that move to an exact space
  static_moves <- c(
    "Advance to Go" = 1,
    "Advance to Illinois Ave." = 25,
    "Advance to St. Charles Place" = 12,
    "Take a ride on the Reading Railroad" = 6,
    "Take a walk on the Boardwalk" = 40
  )
  
  # we handle chance first, then community chest. if a card sends us to jail, we return TRUE so the caller can stop
  
  # chance (spaces 8, 23, 37)
  # if we land on a chance space, draw and process exactly one card
  if(player$pos %in% c(8, 23, 37)) {
    if(player$verbose) cat("Draw a Chance card.\n")
    
    card_idx <- chance$draw()
    card_text <- chancedeck$card[chancedeck$index == card_idx]
    
    # if the card is in our lookup table, we can jump directly to that spot
    if (card_text %in% names(static_moves)) {
      new_dest <- static_moves[[card_text]]
      player$set_pos(new_dest)
      spacetracker$tally(new_dest)
      
    } else if (card_text == "Advance token to nearest Utility") {
      # map current position to destination using character subsetting
      util_map <- c("8" = 13, "23" = 29, "37" = 13)
      dest <- util_map[[as.character(player$pos)]]
      
      player$set_pos(dest)
      spacetracker$tally(dest)
      
    } else if (card_text == "Advance token to the nearest Railroad") {
      # railroads are at 6, 16, 26, 36. this means that (pos + 5) %/% 10 gives the tens digit of the next railroad
      # wrap around implementation
      dest <- ((player$pos + 5) %/% 10) * 10 + 6
      if (dest > 40) dest <- 6 
      
      player$set_pos(dest)
      spacetracker$tally(dest)
      
    } else if (card_text == "Go Back 3 Spaces") {
      # (current - 1 - 3) %% 40 + 1
      new_pos <- (player$pos - 4) %% 40 + 1
      player$set_pos(new_pos)
      spacetracker$tally(new_pos)
      
    } else if (card_text == "Go to Jail") {
      # jail check
      player$send_to_jail()
      spacetracker$tally(11)
      return(TRUE)
    }
  }
  
  # community chest (spaces 3, 18, 34)
  # community chest only has two movement cards, so we handle them directly
  if(player$pos %in% c(3, 18, 34)) {
    if(player$verbose) cat("Draw a Community Chest card.\n")
    
    card_idx <- community$draw()
    card_text <- communitydeck$card[communitydeck$index == card_idx]
    
    if (card_text == "Advance to Go") {
      # simple move to go and tally it
      player$set_pos(1)
      spacetracker$tally(1)
    } else if (card_text == "Go to Jail") {
      # same jail handling as chance
      player$send_to_jail()
      spacetracker$tally(11)
      return(TRUE)
    }
  }
  
  return(FALSE)
}