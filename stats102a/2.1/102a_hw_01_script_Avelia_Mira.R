#=========================================================
# title: "Stats 102A - Homework 1 - Script File"
# author: "Avelia Mira"
#=========================================================

# Part 1

# write a function by_type 
# takes an atomic vector as input (how to force this)? . 
# there is also an optional argument of sort but we'll default it to FALSE
# the function checks  each element and sees if it can coerce into integers, doubvbles r character
# if the sort is TRUE then we'd sort the results of each vector

by_type <- function(atomic_vector, sort = FALSE){
  # First, let's initialise the vectors to be able to hold the results. We need to have one for integers, one for doubles, one for character.

  # Check for atomic vector

  if(!is.atomic(atomic_vector)){
    integers <- integer(0)
    doubles <- double(0)
    character <- character(0)
    return(list(integers = integers, doubles = doubles, character = character))
  }


  # To be able to declare empty vectors, we can use c()

  integers <- c()
  doubles <- c()
  character <- c()

  # I think the best way to go about this is since we're checking each element, we can apply a for loop to be able to go through each element of the atomic vector. 
  # Recall that the order of coercion for the sake of this assignment is logical < integeer < double < character 
  # That being said, I think the best way to do this is to check for character, doubles, then integers 
  # We actually HAVE to put the is.na before the as.integer because if statements actually evaluate the first condition before moving onto the next one. R is lazy so if the first one returns false, it won't check the next one. 
  # It is also important to note because if as.something(element) returns NA, then the expression == element cannot be evaluated to either true or false which would cause an error. 
  for (element in atomic_vector){
    if (is.na(element)){
      character <- c(character, NA)
    # need to put logicals into characters....
    } else if (is.logical(element)) {
      character <- c(character, as.character(element))
      
    # so i had to check if the number modulo is 1 or 0. when we do this, we can check if the number is an integer by seeing if the remainder is 0 when divided by 1
    # this way, 2.2 stays out (with a remainder of 0.2), but 6 gets in (remainder 0)
    } else if (!is.na(suppressWarnings(as.numeric(element))) && suppressWarnings(as.numeric(element)) %% 1 == 0){
          integers <- c(integers, as.integer(element))
          
    } else if (!is.na(suppressWarnings(as.double(element)))) {
        doubles <- c(doubles, as.double(element))
      
    } else if (!is.na(suppressWarnings(as.character(element))) && suppressWarnings(as.character(element)) == element){
      character <- c(character, as.character(element))
    }
  }
  # Now, we can check if sort is true or false, and if true we sort all three
  if (sort == TRUE){
    integers <- sort(as.integer(integers))
    doubles <- sort(as.double(doubles))
    character <- sort(as.character(character), na.last = TRUE)
  }

  if(length(integers) == 0){
    integers <- integer(0)  
  }

  if(length(doubles) == 0){
    doubles <- double(0)  
  }

  if(length(character) == 0){
    character <- character(0)  
  }

  # Now, we should probably return a list of the three vectors so that we can access $integers, $doubles, $character
  
  return(list(integers = integers, doubles = doubles, character = character))
}

# Part 2

# so prime_factor is intended to be a prime factorisation function. 
# see the issue is i've never really done anything like this so i need to actually do the math
# i think the best way to do this since i'm lazy is to check if the modulus is 0 for all numbers up to half of the number. 
# i'd like to sort it after or whatever yeah

prime_factor <- function(x){
  # first let's make sure it's actually an integer otherwise i'm just going to make the function whine about it

  if(is.na(x)){
    stop("Consider sending me an integer next time.")
  }

  # now let's check if it's greater than 2 without any decimal values using the same logic as part 1 to check for integer. i opted for a combination of checking if grepl finds any non-numerics, it doesn't work, and if there's a number less than 2, it doesn't work as well
  if (grepl("[^0-9]", as.character(x)) || x < 2){
    stop("Consider sending me a positive integer over 2.")
  }

  number <- as.integer(x)

  # now we're going to make a list to hold the prime factors
  prime_factors <- c()

  # i think it may be ideal to make a state when it's done looping from 2 to half the number. because if we get a prime number in between then we need to add it to the list and restart the cycle again
  # we can 

  # now, we're going to make a list of all numbers from 2 to half of the number. we don't have to worry about number %/% 2 being a decimal since it'll always output an integer
  # we can loop through the possible factors and check if the modulus is 0
  # we also need to keep doing this while
  while (TRUE){
    # this is our variable to check if we have a new prime. it is reset every loop
    new_prime <- FALSE 
    
    # define the upper limit of the range of numbers we want to check
    upper_limit <- number %/% 2
    
    # we want to make sure the upper limit is equal or above 2 otherwise if it's at 1 we should honestly just break it (see if statement below)
    if (upper_limit >= 2) {
      for (i in 2:upper_limit){
        if (number %% i == 0){
          # we're going to let add that i to our list of prime factors as an integer, then divide by i
          prime_factors <- c(prime_factors, as.integer(i))
          number <- number / i
          new_prime <- TRUE
          break 
        }
      }
    }
    
    # if we didn't find a new divisor, the remaining number is prime
    if (new_prime == FALSE){
      prime_factors <- c(prime_factors, as.integer(number))
      # prime_factors <- c(prime_factors, as.integer(1)) 
      # APPARENTLY 1 ISN'T A PRIME FACTOR???
      break
    }
  }

  return(sort(prime_factors))
}

# Part 3

# basically we're just trying to convert month names from one language to another. x is a factor with month informatio, then we need to take the from_lang as the appropriate language and convert it to the to_lang language

# first maybe we should import month_names.txt which seems to be a tsv file 

# i high key forgot how to read tsv files so i looked it up https://guides.library.upenn.edu/r-business/filetype. also did ?read.delim in the console to be able to check arguments

month_convert <- function(x, from_lang, to_lang){ 

  # had to check why my df wasn't creating a column name for the languages. it turns out this is because row.names=1 makes the first column row names and we need to account for this accordingly.
  month_names <- read.delim("month_names.txt",
encoding="UTF-8", row.names=1)

  # preserve the order of the input factor x since it's a factor and factors have levels that may not be in the order of input

  input_levels <- levels(x)
  new_months <- c()

  # basically we're just going to apply a loop through each month given from_lang, find the index, then use that index to get the corresponding month in to_lang

  for (month in input_levels){
    # just to make sure it's represented as a NA if it is NA
    if(is.na(month)){
      new_months <- c(new_months, NA)
      next
    }
    month <- as.character(month) # convert factor to character just to make sure it works properly
    found_match <- FALSE
    for (i in 1:ncol(month_names)){
      if (month == month_names[from_lang, i]){
        new_months <- c(new_months, month_names[to_lang, i])
        found_match <- TRUE
        break
      }
    }
      # if the input contains a value which is not a real month, then we should just return NA for that value (even though I personally think it would have just been better to just remove it)

    if (found_match == FALSE){
      new_months <- c(new_months, NA)
    }

    
  }
  # now we need to translate the factor levels accordingly from new_months to be in the same order as x

  # first, let's make our translated values as integers for our factor function
  new_values <- new_months[as.integer(x)]

  # now, we can make a vector of the valid levels (non-NA values only)
  valid_levels <- new_months[!is.na(new_months)]

  # now, make the factor with the appropriate levels
  final_factor <- factor(new_values, levels = valid_levels)

  # finally, we return the converted months
  return(final_factor)




}