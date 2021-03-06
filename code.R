library(tidyverse)
house <- read.csv("./data/pton-market-data.csv")

#Tidying up

house <- house %>% 
  mutate(Price = strtoi(str_replace_all(str_sub(Sold.Price, 2, -4), ",", ""))) %>%
  rename(nbhd = Neighborhood, 
         bed = Bed.Rooms, 
         fullBath = Full.Baths, 
         halfBath = Half.Baths, 
         style = Style, 
         age = Year.Built) %>%
  rename(lotSize = Lot.Size, 
         lastPrice = Last.Price, 
         originalPrice = Original.Price, 
         soldPrice = Price) %>%
  select(- Sold.Price) %>%
  rename(marketDays = Days.on.Market) %>%
  separate(col = Sold.Date, into = c("monthSold", "daySold", "yearSold"), sep = "/") %>%
  mutate(yearSold = strtoi(yearSold) + 2000) %>%
  mutate(daySold = strtoi(daySold), monthSold = strtoi(monthSold)) %>%
  mutate(age = yearSold - strtoi(age)) %>%
  select(- Property.Marketing.Period) %>%
  mutate(originalPrice = strtoi(str_replace_all(str_sub(originalPrice, 2, -4), ",", ""))) %>%
  mutate(lastPrice = strtoi(str_replace_all(str_sub(lastPrice, 2, -4), ",", ""))) %>%
  select(- X) %>%
  mutate(lotSize = as.double(lotSize)) %>%
  select(- Address) %>%
  mutate(marketDays = strtoi(marketDays))

#some final tidying

badStyles <- house %>% 
  group_by(style) %>%
  summarise(count = n()) %>%
  arrange(count) %>%
  head(43)

house <- house %>%
  select(- lotSize) %>%     #too many NAs
  select(- originalPrice) %>%
  select(- lastPrice) %>%  #omit these two predictors because they are obviously way too similar to the response variable
  mutate(nbhd = replace(nbhd, nbhd == "Battelfield Area", "Battlefield Area"), 
         nbhd = replace(nbhd, nbhd == "princeton Ridge", "Princeton Ridge"), 
         nbhd = replace(nbhd, nbhd == "LIttlebrook", "Littlebrook"), 
         nbhd = replace(nbhd, nbhd == "griggs Farm", "Griggs Farm"), 
         nbhd = replace(nbhd, nbhd == "PrettyBrook Area", "Pretty Brook Area"), 
         nbhd = replace(nbhd, nbhd == "Palmer Sq", "Palmer Square"), 
         nbhd = replace(nbhd, nbhd == "Institute", "Institute Area"), 
         nbhd = replace(nbhd, nbhd == "Rriverside", "Riverside"), 
         nbhd = replace(nbhd, nbhd == "Rriverside", "Riverside"), 
         nbhd = replace(nbhd, nbhd == "Carnegie Lake", "Carnegie Lake Area"), 
         nbhd = replace(nbhd, nbhd == "Town", "Township")) %>%     #fix area names
  filter(! nbhd %in% c("Edgerstoune", "Northridge", "Rushbrook", "Russell Estates", 
                       "The Preserve", "Governors Lane", "Princeton Borough", 
                       "Preserve", "Queenston")) %>%  #delete areas with few houses
  filter(! style %in% badStyles$style) %>%  #delete styles with at most 3 houses
  mutate(style = replace(style, style == "Bi-level", "Bi-Level"), 
         style = replace(style, style == "End Unit", "End-Unit"), 
         style = replace(style, style == "Townhouse", "Townhome"))  #fix style names

house <- na.omit(house)



#normalize numerical data

houseNorm <- house %>%
  mutate_at(c("bed", "fullBath", "halfBath", "age", "monthSold", 
              "daySold", "yearSold", "marketDays"), ~(scale(.) %>% as.vector))

#divide data into 10 parts for cross-validation

set.seed(42)
houseSplit <- houseNorm
houseSplit$id <- sample(0:9, size = nrow(houseSplit), replace = TRUE)
# houseSplit %>%
#  group_by(id) %>%
#  summarize(count = n())

#define evaluation metrics: returns R-squared and RMS error. 

evalMetrics <- function(model, df, predictions, target){
  resids = df[,target] - predictions
  resids2 = resids**2
  N = length(predictions)
  r2 = round(summary(model)$r.squared, 3)
  adjR2 = round(summary(model)$adj.r.squared, 3)
  rmse = round(sqrt(sum(resids2)/N), 3)
  return(c(adjR2, rmse))
}

evalResults <- function(true, predicted, df) {
  SSE <- sum((predicted - true)^2)
  SST <- sum((true - mean(true))^2)
  R_square <- round(1 - SSE / SST, 3)
  RMSE = round(sqrt(SSE/nrow(df)), 3)
  return(c(R_square, RMSE))
}

#performance prints two numbers: 
#the first one is the average R-squared across all 10 cross-validations
#the second one is the average RMSE (standard deviation of the ten RMS)

performance <- function(df, modelName) {
  pf <- data.frame(modelName(df, 0))
  for (i in 1:9) {
    pf <- cbind(pf, modelName(df, i))
  }
  pf <- t(pf)
  print(c(mean(pf[,1]), mean(pf[,2])))
  return(c(mean(pf[,1]), mean(pf[,2])))
}



#now we define the regression models!

#linear regression model using all predictors

linearModel <- function(df, testSet) {
  lr <- lm(soldPrice ~ ., data = select(filter(df, id != testSet), -id))
  summary(lr)
  predictions <- predict(lr, newdata = select(filter(df, id == testSet), -id))
  evalMetrics(lr, select(filter(df, id == testSet), -id), predictions, target = "soldPrice")
}

#linear regression with a subset of the predictors
#we use the step function for this

forwardModel <- function(df, testSet) {
  fitNone <- lm(soldPrice ~ 1 , data = select(filter(df, id != testSet), -id))
  forward <- step(fitNone, direction = "forward", trace = 0, 
                  scope = formula(lm(soldPrice ~ ., data = select(filter(df, id != testSet), -id))))
  predForward <- predict(forward, newdata = select(filter(df, id == testSet), -id))
  evalMetrics(forward, select(filter(df, id == testSet), -id), predForward, target = "soldPrice")
}

backwardModel <- function(df, testSet) {
  fitAll <- lm(soldPrice ~ ., data = select(filter(df, id != testSet), -id))
  backward <- step(fitAll, direction = "backward", trace = 0)
  predBackward <- predict(backward, newdata = select(filter(df, id == testSet), -id))
  evalMetrics(backward, select(filter(df, id == testSet), -id), predBackward, target = "soldPrice")
}

#performance(houseSplit, linearModel)
#performance(houseSplit, forwardModel)
#performance(houseSplit, backwardModel)
#all three models behave fairly similarly: R-Squared is acceptable, but there is a large variance

#we will use the glmnet package to build regularized regression models
#these include ridge, lasso, and elastic net

# install.packages("glmnet")
# install.packages("caret")
library(glmnet)
library(caret)

dummy <- as.data.frame(predict(dummyVars(soldPrice ~ ., data = house), newdata = house))
dummyNorm <- as.data.frame(scale(dummy))
dummySplit <- dummyNorm
dummySplit$id = houseSplit$id
#these don't have the response variable as a column!
dummySplitWithResponse <- dummySplit
dummySplitWithResponse$soldPrice = house$soldPrice

ridgeModel <- function(df, testSet) {
  x = as.matrix(select(filter(dummySplit, id != testSet), -id))
  xTest = as.matrix(select(filter(dummySplit, id == testSet), -id))
  y = filter(df, id != testSet)$soldPrice
  yTest = filter(df, id == testSet)$soldPrice
  cvModel <- cv.glmnet(x, y, alpha = 0)
  bestLambda <- cvModel$lambda.min
  bestModel <- glmnet(x, y, alpha = 0, lambda = bestLambda)
  predictions <- predict(bestModel, newx = xTest)
  evalResults(yTest, predictions, filter(df, id == testSet))
}

lassoModel <- function(df, testSet) {
  x = as.matrix(select(filter(dummySplit, id != testSet), -id))
  xTest = as.matrix(select(filter(dummySplit, id == testSet), -id))
  y = filter(df, id != testSet)$soldPrice
  yTest = filter(df, id == testSet)$soldPrice
  cvModel <- cv.glmnet(x, y, alpha = 1)
  bestLambda <- cvModel$lambda.min
  bestModel <- glmnet(x, y, alpha = 1, lambda = bestLambda)
  predictions <- predict(bestModel, newx = xTest)
  evalResults(yTest, predictions, filter(df, id == testSet))
}

#for the elastic net approach, we need to tune the parameters alpha and lambda
elasticNetModel <- function(df, testSet) {
  trCont <- trainControl(method = "repeatedcv", number = 10, repeats = 3, search = "random", verboseIter = FALSE)
  elasticBest <- train(soldPrice ~ ., data = select(filter(df, id != testSet), -id), method = "glmnet",
                       preProcess = c("center", "scale"), tuneLength = 10, trControl = trCont)
  xTest = as.matrix(select(filter(dummySplit, id == testSet), -id))
  yTest = filter(houseSplit, id == testSet)$soldPrice
  predictions <- predict(elasticBest, xTest)
  evalResults(yTest, predictions, filter(houseSplit, id == testSet))
}

#performance(houseSplit, ridgeModel)
#the ridge model has roughly the same RMSE, but slightly lower R2
#performance(houseSplit, lassoModel)
#lasso has slightly lower RMSE, and a slightly higher R2 compared to ridge, but still lower than the linear model
#performance(dummySplitWithResponse, elasticNetModel)
#elastic net is between ridge and lasso in terms of both R2 and variance

#finally we try principal component regression (PCR)
#this is worth trying because many predictors are already correlated
#we can fine-tune the parameter ncomp, which has been set to 30 (half of the total number of predictors)

# install.packages("pls")
library(pls)

PCRModel <- function(df, testSet) {
  housePCR <- pcr(soldPrice ~ ., data = select(filter(df, id != testSet), -id), scale = TRUE, validation = "CV", ncomp = 30)
  predictions <- predict(housePCR, select(filter(df, id == testSet), -id), ncomp = 30)
  yTest <- filter(df, id == testSet)$soldPrice
  return(c(round(mean((predictions - yTest)^2)/mean((yTest - mean(yTest))^2),3), round(sqrt(sum((predictions - yTest)^2)/length(predictions)), 3)))
}

#performance(dummySplitWithResponse, PCRModel)
#This one has a higher R squared, but as a trade-off it also has higher variance



#compare the models

models <- data.frame(lm = performance(houseSplit, linearModel), 
                     forward = performance(houseSplit, forwardModel), 
                     backward = performance(houseSplit, backwardModel), 
                     ridge = performance(houseSplit, ridgeModel), 
                     lasso = performance(houseSplit, lassoModel), 
                     ela = performance(dummySplitWithResponse, elasticNetModel), 
                     pcr = performance(dummySplitWithResponse, PCRModel))
models

#make plots for lasso and pcr, our two final models

lassoPlot <- function(df, testSet, lambda) {
  x = as.matrix(select(filter(dummySplit, id != testSet), -id))
  xTest = as.matrix(select(filter(dummySplit, id == testSet), -id))
  y = filter(df, id != testSet)$soldPrice
  yTest = filter(df, id == testSet)$soldPrice
  model <- glmnet(x, y, alpha = 1, lambda = lambda)
  predictions <- predict(model, newx = xTest)
  evalResults(yTest, predictions, filter(df, id == testSet))
}

PCRPlot <- function(df, testSet, ncomp) {
  housePCR <- pcr(soldPrice ~ ., data = select(filter(df, id != testSet), -id), scale = TRUE, validation = "CV", ncomp = ncomp)
  predictions <- predict(housePCR, select(filter(df, id == testSet), -id), ncomp = ncomp)
  yTest <- filter(df, id == testSet)$soldPrice
  return(c(ncomp, round(mean((predictions - yTest)^2)/mean((yTest - mean(yTest))^2),3), round(sqrt(sum((predictions - yTest)^2)/length(predictions)), 3)))
}

performancePlot <- function(df, modelName, parameter) {
  pf <- data.frame(modelName(df, 0, parameter))
  for (i in 1:9) {
    pf <- cbind(pf, modelName(df, i, parameter))
  }
  pf <- t(pf)
  return(list(parameter, mean(pf[,1]), mean(pf[,2])))
}

lassoPerformance <- data.frame(lambda = numeric(), R2 = numeric(), RMSE = numeric())
for (i in seq(-2, 4, by = 0.2)) {
  lassoPerformance[5*(i+2),] <- performancePlot(houseSplit, lassoPlot, 10^i)
}
as.data.frame(lassoPerformance) %>%
  ggplot(aes(x = log10(lambda), y = R2)) +
  geom_line()
as.data.frame(lassoPerformance) %>%
  ggplot(aes(x = log10(lambda), y = RMSE)) +
  geom_line()

PCRPerformance <- data.frame(ncomp = numeric(), R2 = numeric(), RMSE = numeric())
for (i in seq(1, 61)) {
  PCRPerformance[i,] <- performancePlot(dummySplitWithResponse, PCRPlot, i)
}
as.data.frame(PCRPerformance) %>%
  ggplot(aes(x = ncomp, y = R2)) +
  geom_line()
as.data.frame(PCRPerformance) %>%
  ggplot(aes(x = ncomp, y = RMSE)) +
  geom_line()