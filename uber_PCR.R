# Using uber data for Boston, MA from Nov to Dec to build a model with multiple regression and PCA
# to predict the price of rides

# Setting the directory
setwd(choose.dir())

# Installs
packages <- c("dplyr", "ggplot", "leaps", "car", 'fastDummies', "lattice")
install.packages( packages )

# Libraries
library(dplyr)
library(ggplot2)
library(leaps)
library(car)
library(fastDummies)
library(lattice)

# Getting the data
# The csv can be found on kaggle here: https://www.kaggle.com/brllrb/uber-and-lyft-dataset-boston-ma
file = "rideshare_kaggle.csv"
ride_data <- read.csv(file)

# The data actually contains data for Lyft and Uber. Since the model is being built for Uber the data
# will be filtered and the column indicator dropped to reduce the data frame

ride_data <- ride_data[ride_data$cab_type == 'Uber',]
ride_data <- ride_data[, !(names(ride_data) %in% "cab_type")]


# There is data for uber rides with the exact date, time, source and drop offs. It also has weather information
# and the type of ride it was whether it was "Shared" or "Premier" etc.

str(ride_data)

# First look at the top 5 rows

head(ride_data)

# Looking at summary statistics
# It seems rides range from $4.50 to $89.50 with most rides staying around #12.50 in the city. The distance
# of these rides ranges between about 7.86 mi to 0.02 mi with most trips being 2.17 mi long. There are many
# nulls (55,095) prices that will need to be handled moving forward

summary(ride_data)

# Removing the rows with null prices. They all appear to belong to "Taxi" which we will be ignoring

ride_data <- ride_data[ride_data$name != 'Taxi',]

# Removing cols that won't be considered in the model. surge_multiplier has 1 unique value so it will be removed 
ride_data[sapply(ride_data, function(x) length(unique(x)) == 1)]

drop.cols <- c("id", "timestamp", "timezone", "product_id", "surge_multiplier","datetime")
ride_data <- ride_data[, !(names(ride_data) %in% drop.cols)]

# Models don't mesh with categorical data so dummy cols will be made to convert them
# One of the requirements for PCA is that all data inputs in the analysis are numeric as well
ride_data_num <- dummy_cols(ride_data, remove_first_dummy = TRUE)
ride_data_num <- ride_data_num[, !sapply(ride_data_num, is.character)]
ride_data_num <- mutate_all(ride_data_num, function(x) as.numeric(as.character(x)))

# Splitting the data into test/train sets
set.seed(101)
sample <- sample.int(n = nrow(ride_data_num), size = floor(.75*nrow(ride_data_num)), replace = F)
train <- ride_data_num[sample, ]
test  <- ride_data_num[-sample, ]

# Removing price from splits
pca.train <- subset(train, select=-c(price))
pca.test  <- subset(test, select=-c(price))

# Using PCA to reduce the dimensions of the data since there are 50 predictor variables
# PCA is a good way to get around multicollinearity (correlated independent variables that can
# confuse models) since the data is being reduced to the minimum components
# while still explaining the majority of the variance of the dataset

# PCA
prin_comp  <- prcomp(pca.train, center = TRUE, scale = TRUE)

# Results
prin_comp$rotation[1:10,1:5]

# Plotting the proportion of explained variance in the data by component. We want PCs that explain
# at least 95% of the dataset. It looks as if 95% of the variance in the dataset can be explained
# with 46 of the 94 PCs. These 46 PCs will be used as predictor variables in the model
prop_varex <- cumsum( (prin_comp$sdev)^2 / sum((prin_comp$sdev)^2) )

plot(prop_varex, xlab = "Principal Component",
     ylab = "Proportion of Variance Explained",
     type = "b",
     ylim = 0:1)

summary(prin_comp)

# Using the model
# To build the model a new train dataset will be made (it will have the original Price col + 46 PC cols)
# This trains the model to predict price based on the 46 PCs. Then the pca.test set will be
# transformed to be in terms with PCs. Otherwise we would be testing a model on the original
# dataset while the model was built by standardizing the data and performing PCA.

# The training set
train.data <- data.frame(Price = train$price, prin_comp$x)
# Using the first 46 PCs
train.data <- train.data[,1:47]

# Building a multiple regression: The model has a good p value and most of the predictors do as well.
# The model can describe around 83% of the variance in price in the test data based on the PCs used
model <- lm(Price ~ ., data = train.data)
summary(model)

# Translating model coefficients from PC to original (scaled) versions
# The results are interesting. They show what would be expected.
# The trip price being more influenced by distance and the type of ride i.e. SUV, UberX
# It's important to note the transformed coefficients are sometimes not completely reliable
pca.rotation <- prin_comp$rotation
betas <- pca.rotation[, 1:46] %*% model$coefficients[-1]
betas

# Preparing the test data by transforming test into PCs as it is still in terms of the orig data
# The output shows the converted rows and cols into PC1 - P94, the price will be predicted for this new set
test.data <- predict(prin_comp, newdata = pca.test)
test.data <- as.data.frame(test.data)
# Select the first 46 components
test.data <- test.data[,1:46]

# Predicting the price for each row of the test.data set
price.prediction <- predict(model, test.data)

# Interpreting results
actuals_preds <- data.frame(cbind(actuals = test$price, predicteds = price.prediction))
correlation_accuracy <- cor(actuals_preds)  # 91.1%
head(actuals_preds)

# Min/Max Accuracy & MAPE
mean(apply(actuals_preds, 1, min) / apply(actuals_preds, 1, max))  
# 84.5% Min/Max Accuracy
mean(abs((actuals_preds$predicteds - actuals_preds$actuals))/actuals_preds$actuals)  
# 18.10% MAPE


# The overall accuracy of the model was 91.1% on the test data which is great. The
# max/min accuracy was 84.5% which is good since the ideal number is 100%. Looking at the MAPE
# value we can see the model is on average off by 18.1%, but could be a result of values close to zero
# inflating the number, since the accuracy was so high

# Plot to see fitted and actuals
xyplot(actuals_preds$actuals ~ actuals_preds$predicteds, data = actuals_preds, type = c("p","r"), col.line = "red")

# Note: Another method before PCR was to iterate with the leaps package through every combination of the
# 95 variables from the original dataset (the one with the smallest BIC value). Due to the amount of data
# and cols the strategy was unable to be used but is useful for med-small sized datasets

# leaps <- regsubsets(Price ~., data = priceX.pca, nbest = 1, method = "exhaustive", really.big = T)
# subsets(leaps, statistic="bic",  xlim = c(-10, 40))


