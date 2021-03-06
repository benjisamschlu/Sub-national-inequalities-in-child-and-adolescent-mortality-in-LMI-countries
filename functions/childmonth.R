


# FUNCTION: Create childmonth for multiple DHS surveys

# Code by: Benjamin-Samuel Schlüter
# Date: 4/3/2020

# Notes:
# 1) # for gsub (end code):
# pattern: start by nothing or one digit followed by two digit
# -
# followed by nothing or one digit followed by two digit
# replace by: 1st element in paranthesis, 2nd and 3rd

#-------------------------------------------------------------

childmonth <- function(u5mr = FALSE, ...) { # arguments are directly passed to periodbreaks() (i.e data, period length, nber of period)
        
        if (u5mr == TRUE) {m_cut <- c(1, 12, 24, 36, 48, 60)} # month cuts depend on age group studied
        else {m_cut <- seq(60, 180, by = 12)}
        
        y_cut <- periodbreaks(...) # own function to create period breaks
        
        data <- mapply(FUN = getBirths, 
                       data =data, year.cut = y_cut, 
                       MoreArgs = list(strata = c("v023"), dob = "b3", # function to get childmonth from SUMMER pkg
                                       alive = "b5", age = "b7", date.interview = "v008", 
                                       variables = c("v001", "v002", "v004", "v005", "v021", "v022", "v023", "v024", "v025", "v139"), #v139 are regions
                                       month.cut = m_cut),
                       SIMPLIFY = FALSE)
        
        data <- lapply(data, function(x) x[, c("v001", "v002", "v024", "time", "age", "v005", "strata", "died")]) # subset data.frames
        data <- lapply(data, setNames, nm = c("clustid", "id", "region", "time", "age", "weights", "strata", "died")) # rename columns
        
        if (u5mr == FALSE) {
                data <- lapply(data, function(x) x[x[,"age"] != "0-59", ]) 
                data <- lapply(data, function(x) { x$age <- droplevels(x$age); x } ) #;x is particularly important to make it work
        }
        print("Verify that regions are in the same order as REGNAME from geo:")
        print(geo$REGNAME) # could be an argument of the function. For now, check in global environment
        print(lapply(data, function(x) levels(x$region)))
        # transform date into 2 digits - 2 digits
        data <- lapply(data, function(x) { levels(x$time) <- gsub("^|\\d{1}(\\d{2})(\\-)|\\d{1}(\\d{2})", "\\1\\2\\3", levels(x$time)); x } ) # transform three digits date into two
        
        

}
