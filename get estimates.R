


#######################################################################################
##      PROJECT: Space-time smoothing of 5-14 mortality estimates in SSA
##      -- by Benjamin-Samuel Schlüter --
##      UCLouvain
##      Dec. 2020
#######################################################################################
#
#       Obtain direct sub-national estimates of 5q0 and 10q5 with getDirectList()
#       Perform a meta-analysis with aggregateSurvey() to pool info across multiple DHS
#       Perform the space-time smoothing with fitINLA
#       Perform variance decomposition
#
#######################################################################################
#
#
# Notes:
# 1) 

########################################################################################################################################################



# ----- Horvitz-Thompson estimate step ------------------------------------------------------------------------------------------------------------

# merge all period into one vector using period from 5-15
years <- unique(unlist(lapply(data_a5, function(x) {gsub("^|\\d{1}(\\d{2})(\\-)|\\d{1}(\\d{2})", "\\1\\2\\3", levels(x[, "time"]))})))
# remove oldest periods not covered by 5-15
data_u5 <- lapply(data_u5, function(x) x[x$time %in% years, ]) 
# years have to be matching in all child-month data
data.multi_u5 <- getDirectList(births = data_u5, years = years, regionVar = "region",  timeVar = "time", 
                               clusterVar = "~clustid + id", ageVar = "age", weightsVar = "weights", geo.recode = NULL)

data.multi_a5 <- getDirectList(births = data_a5, years = years, regionVar = "region",  timeVar = "time", 
                               clusterVar = "~clustid + id", ageVar = "age", weightsVar = "weights", geo.recode = NULL)


# ----- Meta-analysis step ----------------------------------------------------------------------------------------------------------

# Combine estimates from different surveys into a single estimate using 
# weighted average and weights are given by inverse of their variance

# HIV correction for some countries using Li et al. (2019) code
if (ctry %in% c("Malawi", "Namibia", "Kenya", "Rwanda", "Zimbabwe", "Lesotho", "Zambia", "Tanzania")) {
        
        source("./code/hiv.R", echo = TRUE)
        est_u5 <- rbind(data, data.national)
        names(est_u5)[names(est_u5) %in% "u5m"] <- "mean"
        
} else {est_u5 <- aggregateSurvey(data.multi_u5) }

est_a5 <- aggregateSurvey(data.multi_a5)


# ----- Space-time model ------------------------------------------------------------------------------------------------------------------------

# National

fit_u5 <- fitINLA(data = est_u5, geo = NULL, Amat = NULL, year_label = years, 
                  rw = 2, is.yearly = FALSE) 
fit_a5 <- fitINLA(data = est_a5, geo = NULL, Amat = NULL, year_label = years, 
                  rw = 2, is.yearly = FALSE) 

out_u5 <- getSmooth2(fit_u5, year_label = years)
sim_u5 <- out_u5[["sim"]]
out_u5 <- out_u5[["outputs"]]

out_a5 <- getSmooth2(fit_a5, year_label = years)
sim_a5 <- out_a5[["sim"]]
out_a5 <- out_a5[["outputs"]]

# Subnational 

# arg. hyper=gamma to obtain region.unst term
fit.sub_u5 <- fitINLA(data = est_u5, geo = geo, Amat = Amat, year_label = years, 
                      rw = 2, is.yearly = FALSE, type.st = 4, hyper = "gamma") 
fit.sub_a5 <- fitINLA(data = est_a5, geo = geo, Amat = Amat, year_label = years, 
                      rw = 2, is.yearly = FALSE, type.st = 4, hyper = "gamma")

out.sub_u5 <- getSmooth2(fit.sub_u5, Amat = Amat, year_label = years)
sim.sub_u5 <- out.sub_u5[["sim"]]
out.sub_u5 <- out.sub_u5[["outputs"]]

out.sub_a5 <- getSmooth2(fit.sub_a5, Amat = Amat, year_label = years)
sim.sub_a5 <- out.sub_a5[["sim"]]
out.sub_a5 <- out.sub_a5[["outputs"]]


# ----- Create data sets for outputs --------------------------------------------------------------------------------------------------------

u5 <- create_df(meta.est = est_u5, st.est_nat = out_u5, st.est_subnat = out.sub_u5)
a5 <- create_df(meta.est = est_a5, st.est_nat = out_a5, st.est_subnat = out.sub_a5)


# ----- Variance decomposition --------------------------------------------------------------------------------------------------------------

periods <- years
n.periods <- length(years)
n.area <- length(levels(data_a5[[3]][, "region"]))
n.periods.area <- n.area*n.periods


# U5

marg.icar <- matrix(NA, nrow = n.area, ncol = 100000)
icars <- fit.sub_u5$fit$marginals.random$region.struct
for(i in 1:n.area){
        marg.icar[i, ] <- inla.rmarginal(100000, icars[[i]])
}
vars.icar <- apply(marg.icar, 2, var)
var.icar <- median(vars.icar)


marg.rw <- matrix(NA, nrow = n.periods, ncol = 100000)
rws <- fit.sub_u5$fit$marginals.random$time.struct
for(i in 1:n.periods){
        marg.rw[i, ] <- inla.rmarginal(100000, rws[[i]])
}
vars.rw <- apply(marg.rw, 2, var)
var.rw <- median(vars.rw)

marg.utimes <- matrix(NA, nrow = n.periods, ncol = 100000)
utimes <- fit.sub_u5$fit$marginals.random$time.unstruct
for(i in 1:n.periods){
        marg.utimes[i, ] <- inla.rmarginal(100000, utimes[[i]])
}
vars.utimes <- apply(marg.utimes, 2, var)
var.utimes <- median(vars.utimes)

marg.uregions <- matrix(NA, nrow = n.area, ncol = 100000)
uregions <- fit.sub_u5$fit$marginals.random$region.unstruct
for(i in 1:n.area){
        marg.uregions[i, ] <- inla.rmarginal(100000, uregions[[i]])
}
vars.uregions <- apply(marg.uregions, 2, var)
var.uregions <- median(vars.uregions)

utimeregions <- fit.sub_u5$fit$marginals.random$time.area
marg <- matrix(NA, nrow = n.periods.area, ncol = 100000)
for(i in 1:n.periods.area){
        marg[i,] <- inla.rmarginal(100000, utimeregions[[i]])  
}
var.utimeregions <- median(apply(marg, 2, var))


all.vars_u5 <- c(var.rw, var.icar, var.utimes, var.uregions, var.utimeregions)
prop_u5 <- all.vars_u5/sum(all.vars_u5)*100


# A5

marg.icar <- matrix(NA, nrow = n.area, ncol = 100000)
icars <- fit.sub_a5$fit$marginals.random$region.struct
for(i in 1:n.area){
        marg.icar[i, ] <- inla.rmarginal(100000, icars[[i]])
}
vars.icar <- apply(marg.icar, 2, var)
var.icar <- median(vars.icar)


marg.rw <- matrix(NA, nrow = n.periods, ncol = 100000)
rws <- fit.sub_a5$fit$marginals.random$time.struct
for(i in 1:n.periods){
        marg.rw[i, ] <- inla.rmarginal(100000, rws[[i]])
}
vars.rw <- apply(marg.rw, 2, var)
var.rw <- median(vars.rw)

marg.utimes <- matrix(NA, nrow = n.periods, ncol = 100000)
utimes <- fit.sub_a5$fit$marginals.random$time.unstruct
for(i in 1:n.periods){
        marg.utimes[i, ] <- inla.rmarginal(100000, utimes[[i]])
}
vars.utimes <- apply(marg.utimes, 2, var)
var.utimes <- median(vars.utimes)

marg.uregions <- matrix(NA, nrow = n.area, ncol = 100000)
uregions <- fit.sub_a5$fit$marginals.random$region.unstruct
for(i in 1:n.area){
        marg.uregions[i, ] <- inla.rmarginal(100000, uregions[[i]])
}
vars.uregions <- apply(marg.uregions, 2, var)
var.uregions <- median(vars.uregions)

utimeregions <- fit.sub_a5$fit$marginals.random$time.area
marg <- matrix(NA, nrow = n.periods.area, ncol = 100000)
for(i in 1:n.periods.area){
        marg[i,] <- inla.rmarginal(100000, utimeregions[[i]])  
}
var.utimeregions <- median(apply(marg, 2, var))

# Compute proportion of variation explained by each component
all.vars_a5 <- c(var.rw, var.icar, var.utimes, var.uregions, var.utimeregions)
prop_a5 <- all.vars_a5/sum(all.vars_a5)*100

# Create the data.frame with proportion variance explained for each component and age group
names <- c("RW2", "ICAR", "time.unstruct", "region.unstruct", "time.area")
variance <- data.frame(
        Median = c(all.vars_u5, all.vars_a5),
        Proportion = c(prop_u5, prop_a5), 
        Name = rep(factor(names, levels=rev(names)), 2),
        Age = c(rep("<5", 5), rep(">=5", 5)))






