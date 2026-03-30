#=========================================================
# title: "Stats 102A - Homework 2 - Script File"
# author: "Avelia Mira"
#=========================================================

# Part 2

# real quick i DID end up using ? on all the functions suggested in the assignment, being plot.new(), plot.window(), segments(), arrows(), and text()

# so... i realized i need to use the board setup logic for the extra credit too.
# instead of copy-pasting (gross), i made a helper function to do the boring grid stuff. so i split the initial implementation i had to create a new function -- setup_board_canvas() -- in order to clean the code in my extra credit

# this function sets up the blank board canvas and returns a data frame with the coordinates of each tile for later use
setup_board_canvas <- function(board) {
  rows <- board$rows
  cols <- board$cols
  
  # we want to setup the blank canvas. similar to the example window.
  plot.new()
  plot.window(xlim = c(0, cols), ylim = c(0, rows), asp = 1)
  
  # for drawing the grid lines
  # vertical lines
  segments(x0 = 0:cols, y0 = 0, x1 = 0:cols, y1 = rows)
  # horizontal lines
  segments(x0 = 0, y0 = 0:rows, x1 = cols, y1 = 0:rows)
  
  # draw the box around it
  box()
  
  # i made a function to be able to convert the tile numbers to (x, y) coordinates.
  # we'll note that the numbering goes left to right on even rows and right to left on odd rows.
  # this handles the "snakelike" numbering
  
  # first, fill a matrix with numbers 1 to 100
  id_matrix <- matrix(1:(rows * cols), nrow = rows, byrow = TRUE)
  
  # now, we want to FLIP THE ODD ROWS (visually)
  # to detect for an even row, we use the modulus operand
  for (r in 1:rows) {
    if (r %% 2 == 0) {
      id_matrix[r, ] <- rev(id_matrix[r, ])
    }
  }
  
  # next we want to make a data frame with the tile id, x coord, and y coord for each tile
  coordinates_df <- data.frame(
    id = as.vector(id_matrix),
    x  = as.vector(col(id_matrix)) - 0.5,
    y  = as.vector(row(id_matrix)) - 0.5
  )
  
  # return the sorted coords so other functions can use them!
  return(coordinates_df[order(coordinates_df$id), ])
}

# helper function to check where a player lands if they hit a chute or ladder
# i'm putting this here so i can use it in the extra credit without rewriting it!
get_final_spot <- function(square, board) {
  # check ladders
  if (!is.null(board$ladders)) {
    idx <- which(board$ladders[, 1] == square)
    if (length(idx) > 0) return(board$ladders[idx, 2])
  }
  # check chutes
  if (!is.null(board$chutes)) {
    idx <- which(board$chutes[, 1] == square)
    if (length(idx) > 0) return(board$chutes[idx, 2])
  }
  return(square)
}

# we want the function to accept the board as a list with rows, cols, ladders, and chutes
# then i'll go ahead and extract that information from the list so i can actually use it properly

show_board <- function(board) {
  
  # call my helper function to get the grid ready and grab the coordinates
  coordinates_df <- setup_board_canvas(board)
  
  # next, we want to label each tile with its number
  # looping through rows * cols and using text() at the coords we just calculated
  for (i in 1:nrow(coordinates_df)) {
    text(x = coordinates_df$x[i], y = coordinates_df$y[i], labels = i)
  }
  
  # now we want to draw the ladders and chutes
  # basically, initialise an empty data frame to hold all the arrow data.
  arrow_data <- NULL
  
  # prep ladders (green)
  if (!is.null(board$ladders)) {
    ld <- as.data.frame(board$ladders)
    ld$color <- "green"
    arrow_data <- rbind(arrow_data, ld)
  }
  
  # prep chutes (red)
  if (!is.null(board$chutes)) {
    cd <- as.data.frame(board$chutes)
    cd$color <- "red"
    arrow_data <- rbind(arrow_data, cd)
  }
  
  if (!is.null(arrow_data)) {
    for (i in 1:nrow(arrow_data)) {
      # grab values from our combined table
      start_square <- arrow_data[i, 1]
      end_square   <- arrow_data[i, 2]
      arrow_color  <- arrow_data[i, "color"]
      
      # grab coords from lookup table
      point_1 <- coordinates_df[start_square, ]
      point_2 <- coordinates_df[end_square, ]
      
      # draw arrow 
      arrows(x0 = point_1$x, y0 = point_1$y, x1 = point_2$x, y1 = point_2$y,
             col = arrow_color, lwd = 2, length = 0.1)
    }
  }
}

# Part 5

# for our arguments we want to take the board as a list and a verbose flag and default it to false

# we're also using the standard rules of the game to emulate the gameplay, so we unfortunately do NOT get to use the "roll again on a 6" rule or go backwards on overshoot past the winning spot

play_solo <- function(board, verbose = FALSE) {
  # to setup the game, we need to initialise the position and turn counter. additionally, we want to log the moves in accordance to the assignment instructions
  current_position <- 0
  turns <- 0
  move_log <- c()

  # now i wanna make a df to hold all the ladders and chutes for easy lookup later called teleports
  teleports <- NULL

  # if the board has ladders, we add them to teleports first
  if (!is.null(board$ladders)) {
    ladders_df <- as.data.frame(board$ladders)
    ladders_df$type <- "ladder"
    ladders_df$id <- 1:nrow(board$ladders) # keep track of which ladder (1st, 2nd, etc.)
    teleports <- rbind(teleports, ladders_df)
  }
  
  # next we do the same for chutes
  if (!is.null(board$chutes)) {
    chutes_df <- as.data.frame(board$chutes)
    chutes_df$type <- "chute"
    chutes_df$id <- 1:nrow(board$chutes) # keep track of which chute
    teleports <- rbind(teleports, chutes_df)
  }
  
  # next we want to define what the winning spot is so we can end the game when we reach it
  winning_spot <- board$rows * board$cols
  
  # we want to initialise the tallies of ladders and chutes as per instructions. if there aren't any ladders or chutes, we'll just have empty numeric vectors
  if (!is.null(board$ladders)) {
    ladder_tally <- rep(0, nrow(board$ladders))
  } else {
    ladder_tally <- numeric(0)
  }
  
  if (!is.null(board$chutes)) {
    chute_tally <- rep(0, nrow(board$chutes))
  } else {
    chute_tally <- numeric(0)
  }
  
  # we need to spin the wheel. and thus we shall define a function to do so. it just samples a number from 1 to 6
  spin_wheel <- function() {
    sample(6, 1)
  }
  
  # while the current position is not the winning spot, we keep playing
  while (current_position != winning_spot) {

    # increment turn counter per loop
    turns <- turns + 1
    
    # let's go gambling!!
    spin <- spin_wheel()
    
    # if we have the verbose output: start of turn
    if (verbose) {
      cat(paste("Turn", turns, "\n"))
      cat(paste("Start at", current_position, "\n"))
      cat(paste("Spinner:", spin, "\n"))
    }
    
    # here we can calculate the tentative new position
    temporary_position <- current_position + spin
    
    # finally, basically if we go over the winning_spot we want to set the temporary_position back to the current_position (we don't move)
    if (temporary_position > winning_spot) {
      # stay at current_position
      temporary_position <- current_position 
    } else {
      # check if temporary_position is in the start column (column 1) of our master list of teleports
      if (!is.null(teleports)) {
        hit_index <- which(teleports[, 1] == temporary_position)
        
        if (length(hit_index) > 0) {
          # we hit something! grab the row info
          target <- teleports[hit_index, ]
          
          # verbose output
          if (verbose) {
            cat(paste("Landed on:", temporary_position, "\n"))
            if (target$type == "ladder") cat("Ladder!\n") else cat("Chute!\n")
          }
          
          # update the tallies
          if (target$type == "ladder") {
            ladder_tally[target$id] <- ladder_tally[target$id] + 1
          } else {
            chute_tally[target$id] <- chute_tally[target$id] + 1
          }
          
          # teleport to the target position
          temporary_position <- target[, 2]
        }
      }
    }
    
    # now, we can finalise the movement
    current_position <- temporary_position
    move_log <- c(move_log, current_position)
    
    if (verbose) {
      cat(paste("Turn ends at:", current_position, "\n"))
      cat(paste("\n"))
    }
  }
  
  # return the list of stats
  return(list(
    turns = turns,
    chute_tally = chute_tally,
    ladder_tally = ladder_tally,
    move_log = move_log
  ))
}

# Extra Credit

# function to build the transition matrix. i was initially building this in the qmd but i wanted to put it here to keep it tidy!
create_transition_matrix <- function(board) {
  # this calculates the size dynamically, so we could take any of the other boards we made and use it here too
  total_squares <- board$rows * board$cols
  matrix_size <- total_squares + 1
  
  # initalise matrix of zeros. Index 1 = Square 0.
  probability_transition_matrix <- matrix(0, nrow = matrix_size, ncol = matrix_size)
  
  # fill matrix using standard loops + our get_final_spot helper
  # loop up to total_squares - 1 because the last square is the winner
  for (from_square in 0:(total_squares - 1)) {
    for (roll in 1:6) {
      land_square <- from_square + roll
      
      if (land_square > total_squares) {
        final_square <- from_square 
      } else {
        final_square <- get_final_spot(land_square, board)
      }
      
      # +1 for R indexing
      probability_transition_matrix[from_square + 1, final_square + 1] <- probability_transition_matrix[from_square + 1, final_square + 1] + (1/6)
    }
  }
  
  probability_transition_matrix[matrix_size, matrix_size] <- 1 # absorbing state for the winner
  return(probability_transition_matrix)
}

# helper to multiply state vector by transition matrix
multiply_state <- function(current_state, trans_matrix) {
  # determine size dynamically from the matrix itself
  size <- nrow(trans_matrix)
  next_state <- numeric(size)
  
  for (j in 1:size) {
    # dot product: sum(row * col)
    next_state[j] <- sum(current_state * trans_matrix[, j])
  }
  return(next_state)
}

# plotting helper for the probability map, i added board as an argument so we can get info on the board and reuse the setup_board_canvas() function to grab the coordinates
# updated plotting helper for the heat map colors!
plot_prob_map <- function(probability_vector, turn_number, board) {
  
  # reuse our canvas setup helper!
  coordinates_df <- setup_board_canvas(board)
  
  # we need to define how big our tiles are here in order to draw the rectangles
  half_width <- 0.5
  
  # loop to draw the colored squares
  for (i in 1:nrow(coordinates_df)) {
    # +1 to index because vector includes square 0
    probability <- probability_vector[i + 1]
    
    # this assumes that if our prob is 0, we don't draw anything (leave it blank)
    if (probability > 0) {
      # i was thinking about how to scale the color, and i decided that using the max probability would be the most consistent
      # in other words, if prob is max_p, alpha is 1.0 (full red). 
      relative_alpha_value <- probability / max(probability_vector)
      
      fill_color <- rgb(1, 0, 0, alpha = relative_alpha_value) 
      
      # draw the square using the rect() function
      rect(xleft = coordinates_df$x[i] - half_width, 
           ybottom = coordinates_df$y[i] - half_width,
           xright = coordinates_df$x[i] + half_width, 
           ytop = coordinates_df$y[i] + half_width,
           col = fill_color, border = "black")
    }
  }
}