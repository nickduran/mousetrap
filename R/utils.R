#' @importFrom magrittr %>%
magrittr::`%>%`

# Check that data is a mousetrap object
is_mousetrap_data <- function(data){

  return(class(data)=="list")

}


# Extract data from mousetrap object
extract_data <- function(data, use) {

  if (is_mousetrap_data(data)){

    extracted <- data[[use]]
    if(is.null(extracted)){
      stop("No data called '",use,"' found.")
    }
    return(extracted)

  } else {

    return(data)
  }

}

# Function to create results
create_results <- function(data, results, use, save_as, ids=NULL, overwrite=TRUE) {

  # Procedure for trajectories
  if (length(dim(results)) > 2) {
    if (is_mousetrap_data(data)) {
      data[[save_as]] <- results
      return(data)
    } else {
      return(results)
    }


  # Procedure for measures
  } else {
    results <- as.data.frame(results)

    # Extract / set ids
    if (is.null(ids)) {
      if (is.null(rownames(results))) {
        stop("No ids for create_results function provided.")
      } else {
        ids <- rownames(results)
      }
    } else {
      rownames(results) <- ids
    }

    # Return results depending on type of data and overwrite setting
    if (is_mousetrap_data(data)){
      if (save_as %in% names(data) & overwrite == FALSE) {
        # ensure id column is present
        data[[save_as]][,"mt_id"] <- rownames(data[[save_as]])
        results[,"mt_id"] <- rownames(results)
        # merge by rownames
        data[[save_as]] <- dplyr::inner_join(data[[save_as]], results, by="mt_id")
        # set rownames again
        rownames(data[[save_as]]) <- data[[save_as]][,1]
        # sort data and remove row.names column
        data[[save_as]] <- data[[save_as]][ids,]
      } else {
        data[[save_as]] <- cbind(mt_id=ids, results)
      }
      # ensure rownames are just characters
      data[[save_as]][,1] <- as.character(data[[save_as]][,1])
      return(data)
      #
    } else {
      return(cbind(mt_id=ids, results))
    }
  }
}


# Function to determine the point on the line between P1 and P2
# that forms a line with P0 so that it is orthogonal to P1-P2.
# For details regarding the formula, see
# http://paulbourke.net/geometry/pointlineplane/
#
# The function expects P0 to be a matrix of points.
point_to_line <- function(P0, P1, P2){

  u <- ( (P0[1,]-P1[1]) * (P2[1]-P1[1]) +
           (P0[2,]-P1[2]) * (P2[2]-P1[2]) ) /
    ( (P2[1]-P1[1])^2 + (P2[2]-P1[2])^2 )

  P <- matrix(c(
    P1[1] + u * (P2[1] - P1[1]),
    P1[2] + u * (P2[2] - P1[2])),
    nrow = 2, byrow = TRUE
  )

  rownames(P) <- rownames(P0)

  return(P)
}


# Function to determine points on the straight line connecting the start and end
# points that result from an orthogonal projection of the individual points on
# the curve
points_on_ideal <- function(points, start=NULL, end=NULL) {

  # Fill start and end values if otherwise unspecified
  if (is.null(start)) {
    start <- points[,1]
  }
  if (is.null(end)) {
    end <- points[,ncol(points)]
  }

  if (all(start == end)) {
    # If start and end points are identical,
    # no projection can be computed.
    # Therefore, we return the start/end point
    # as a fallback result.
    warning(
      "Start and end point identical in trajectory. ",
      "This might lead to strange results for some measures (e.g., MAD)."
    )
    result <- points
    result[1,] <- start[1]
    result[2,] <- start[2]
  } else {
    # compute the projection onto the idealized straight line for all points
    result <- point_to_line(P0 = points, P1 = start, P2 = end)
  }

  return(result)
}


# Function to calculate the number of flips
count_changes <- function(pos, threshold=0, zero_threshold=0) {

  # Calculate differences in positions between subsequent steps
  # (pos is a one-dimensional vector)
  changes <- diff(pos, lag=1)

  # Exclude logs without changes (above zero_threshold)
  changes <- changes[abs(changes) > zero_threshold]

  # Initialize variables
  cum_changes <- c() # vector of accumulated deltas
  cum_delta <- changes[1] # current accumulated delta

  # Iterate over the changes, and summarize
  # those with the same sign by generating the sum.
  # When the sign changes, a new value is added to
  # the cum_changes vector and the cumulative sum
  # of consecutive changes is reset.
  for (delta in changes[-1]) {

    # check if previous (accumulated) and current delta have the same sign
    if (sign(cum_delta) == sign(delta)) {

      # if so, accumulate deltas
      cum_delta <- delta + cum_delta
    } else {
      # if not, save accumulated delta
      cum_changes <- c(cum_changes, cum_delta)

      # reset cum_delta to current delta
      cum_delta <- delta
    }
  }

  # save last cum_delta
  cum_changes <- c(cum_changes, cum_delta)

  # Count changes in direction/sign

  # If there is no threshold, simply look at the number of the accumulated deltas
  if (threshold == 0) {
    n <- length(cum_changes) - 1

  } else {
    # If a threshold is set,
    # exclude changes below threshold
    cum_changes <- cum_changes[abs(cum_changes) > abs(threshold)]

    # Count changes in sign
    # (the diff converts changes in sign into +-1s or 0s for no changes,
    # and their absolute values are added up along the vector)
    n <- sum(abs(diff(cum_changes > 0)))
  }

  return(n)
}
