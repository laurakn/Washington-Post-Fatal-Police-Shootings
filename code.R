### Kidus
library('plyr')
library('ggplot2')
library('e1071')
library(data.table)
library('nnet')
library('mlbench')
library('caret')

# Create function which converts (0,0.5) to 0 and (0.5,1) to 1
binary_decision <- function(vec){
  return(ifelse(vec < 0.5, 0, 1))
}

# load in shared data with Laura, Zoe and Ed
master_data = readRDS('~/Desktop/UM/COURSES/STAT601/project/df.location.RDS')

# clean up the data per email by Laura
master_data = master_data[complete.cases(master_data),]
master_data = master_data[-which(master_data$id == 2304),]
master_data = master_data[-which(master_data$id == 2158),]

# create weapon converting function
weapon_converter <- function(x){
  if(x %in% c('gun', 'guns and explosives', 'gun and knife', 'hatchet and gun',
              'machete and gun')) return(as.factor('gun'))
  if(x %in% c('knife','pole and knife','sword','machete')) return(as.factor('knife'))
  if(x %in% c('vehicle','motorcycle'))return(as.factor('vehicle'))
  if(x %in% c('','undetermined')) return(as.factor('undetermined'))
  if(x %in% c('toy weapon')) return(as.factor('toy weapon'))
  if(x == 'unarmed') return(as.factor('unarmed'))
  return(as.factor('other'))
}

# add weapon category column
weapon_cat = sapply(master_data$armed, function(x) weapon_converter(x))
master_data = cbind(master_data, weapon_cat)

# create race converting function with bad name
race_converter <- function(x){
  if(x == 'B') return(as.factor('B'))
  if(x == 'W') return(as.factor('W'))
  return(as.factor('O'))
}

# add race category column
race_cat = sapply(master_data$race, function(x) race_converter(x))
master_data = cbind(master_data, race_cat)

# adding region column
region_converter <- function(x){
  if(x == 'CT' | x == 'ME' | x == 'MA' | x == 'NH' | x == 'RI' |
     x == 'VT' | x == 'NJ' | x == 'NY' | x == 'PA') return(as.factor(1))
  if(x == 'IL' | x == 'IN' | x == 'MI' | x == 'OH' | x == 'WI' |
     x == 'IA' | x == 'KS' | x == 'MN' | x == 'MO' | x == 'NE' |
     x == 'SD' | x == 'ND') return(as.factor(2))
  if(x == 'DE' | x == 'FL' | x == 'GA' | x == 'MD' | x == 'NC' |
     x == 'SC' | x == 'VA' | x == 'DC' | x == 'WV' | x == 'AL' |
     x == 'KY' | x == 'MS' | x == 'TN' | x == 'AR' | x == 'LA' |
     x == 'OK' | x == 'TX') return(as.factor(3))
  if(x == 'AZ' | x == 'CO' | x == 'ID' | x == 'MT' | x == 'NV' |
     x == 'NM' | x == 'UT' | x == 'WY' | x == 'AK' | x == 'CA' |
     x == 'HI' | x == 'OR' | x == 'WA') return(as.factor(4))
}
region_defn = c('Northeast','Midwest','South','West')
region = sapply(master_data$state, function(x) region_converter(as.character(x)))
master_data = cbind(master_data, region)

# subset the data in  ways
drops1 = c("state","city","city.state","name","id","region","race", "date","armed")
fatal_data1 = master_data[,!(names(master_data) %in% drops1)]
drops2 = c("state","city","city.state","name","id","race","region","date","manner_of_death","armed","gender","flee","body_camera","weapon_cat")
fatal_data2 = master_data[,!(names(master_data) %in% drops2)]
drops3 = c("state","city","city.state","name","id","lat","lon","race", "date","armed")
fatal_data3 = master_data[,!(names(master_data) %in% drops3)]
drops4 = c("state","city","city.state","name","id","race", "date","armed")
fatal_data4 = master_data[,!(names(master_data) %in% drops4)]
drops5 = c("state","city","city.state","name","id","race","region","date","manner_of_death","armed","flee","body_camera")
fatal_data5 = master_data[,!(names(master_data) %in% drops5)]
################ BASELINE #######################
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(fatal_data1)) # 75% of the dataset
# set the seed to make the partition reproducible
set.seed(123)
train_ind <- sample(seq_len(nrow(fatal_data1)), size = smp_size)
train <- fatal_data1[train_ind, ]
test <- fatal_data1[-train_ind, ]
Y.train <- train$race_cat
Y.test <- test$race_cat
X.train <- train[,-which(names(train)=='race_cat')]
X.test <- test[,-which(names(test)=='race_cat')]
# Train Gaussian SVM on full training set
cost = 95
gamma = 0.01
g.svm <- svm(race_cat ~., data = train, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.6148194
# Test Gaussian SVM on full test set
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.6073394

# POLY SVM
# Polynomial kernel
# Train Poly SVM on full training set
cost = 10
gamma = 0.01
degree = 3
coef0 = 2
g.svm <- svm(race_cat ~., data = train, 
             type = 'C-classification', kernel = 'polynomial', 
             cost = cost, gamma = gamma, coef0 = coef0, degree=degree)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.6074709
# Test Poly SVM on full test set
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5944954

# Linear kernel
# Train Gaussian SVM on full training set
cost = 100
g.svm <- svm(race_cat ~., data = train, 
             type = 'C-classification', kernel = 'linear', 
             cost = cost)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.5829761
# Test Gaussian SVM on full test set
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
#0.5944954

# Train Multinomial Logistic Regression on full training set
m.log.r <- multinom(race_cat~., data=train)
m.log.r.pred.train <- predict(m.log.r,newdata = X.train)
table(m.log.r.pred.train, Y.train)
print(sum(m.log.r.pred.train == Y.train)/length(Y.train))
# 0.5731782
# Test Multinomial Logistic Regression on full test set
m.log.r.pred <- predict(m.log.r, newdata = X.test)
table(m.log.r.pred, Y.test)
print(sum(m.log.r.pred == Y.test)/length(Y.test))
# 0.5944954


################ BY REGION ######################
# REGION 1 - NORTHEAST
reg.data <- fatal_data4[fatal_data4$region == 1,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 250
gamma = 0.01
g.svm <- svm(race_cat ~. -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.7235772
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5609756
#########################################################
# REGION 2 - MIDWEST
reg.data <- fatal_data4[fatal_data4$region == 2,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 220
gamma = 0.1
g.svm <- svm(race_cat ~. -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.9409594
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.6263736
################################################
# REGION 3 - SOUTH
reg.data <- fatal_data4[fatal_data4$region == 3,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 240
gamma = 0.05
g.svm <- svm(race_cat ~. -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.8308605
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5911111
#########################################################
# REGION 4 - WEST
reg.data <- fatal_data4[fatal_data4$region == 4,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 240
gamma = 0.05
g.svm <- svm(race_cat ~. -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.8120567
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5291005

################## FEATURE SELECTION ######################
# set the seed to make the partition reproducible
# EXCLUDE REGION FOR THIS PART
smp_size <- floor(0.75 * nrow(fatal_data1)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(fatal_data1)), size = smp_size)
train <- fatal_data1[train_ind, ]
test <- fatal_data1[-train_ind, ]
Y.train <- train$race_cat
X.train <- train[,-which(names(train)=='race_cat')]
Y.test <- test$race_cat
X.test <- test[,-which(names(test)=='race_cat')]
# X.train <- train[,-which(names(train)=='race_cat'|names(train)=='signs_of_mental_illness'|names(train)=='threat_level')]
blep <- function(x){
  if(x == 'B') return(as.factor(1))
  if(x == 'W') return(as.factor(2))
  if(x == 'O') return(as.factor(3))
}
Y.train <- sapply(Y.train, blep)
# define the control using a random forest selection function
control <- rfeControl(functions=rfFuncs, method="cv", number=10)
# run the RFE algorithm
results <- rfe(X.train, Y.train, sizes=c(1:8), rfeControl=control)
# summarize the results
print(results)
# list the chosen features
predictors(results)
# plot the results
plot(results, type=c("g", "o"))

# in light of the above let us only use lon, age, lat, mental illness, threat, gender, weapon_cat
set.seed(123)
train_ind <- sample(seq_len(nrow(fatal_data5)), size = smp_size)

train <- fatal_data5[train_ind, ]
test <- fatal_data5[-train_ind, ]
Y.train <- train$race_cat
Y.test <- test$race_cat
X.train <- train[,-which(names(train)=='race_cat')]
X.test <- test[,-which(names(test)=='race_cat')]
# RFE TRAIN
cost = 230
gamma = 0.02
g.svm <- svm(race_cat ~., data = train, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.6252296
# RFE TEST
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.6018349

######################## LAT - LONG INTERACTION TERM ###############
set.seed(123)
train_ind <- sample(seq_len(nrow(fatal_data5)), size = smp_size)

train <- fatal_data5[train_ind, ]
test <- fatal_data5[-train_ind, ]
Y.train <- train$race_cat
Y.test <- test$race_cat
X.train <- train[,-which(names(train)=='race_cat')]
X.test <- test[,-which(names(test)=='race_cat')]
# RFE TRAIN
cost = 230
gamma = 0.02
g.svm <- svm(race_cat ~. + lat*lon, data = train, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.679078
# RFE TEST
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5731103

################### COMBINE RFE WITH REGION STRATIFICATION ###############
to_drop <- c("manner_of_death","flee","body_camera")
all.reg.data <- fatal_data4[,!(names(fatal_data4) %in% to_drop)]
# REGION 1 - NORTHEAST
reg.data <- all.reg.data[all.reg.data$region == 1,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 250
gamma = 0.01
g.svm <- svm(race_cat ~ . -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.7235772
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.6097561
#########################################################
# REGION 2 - MIDWEST
reg.data <- all.reg.data[all.reg.data$region == 2,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 220
gamma = 0.1
g.svm <- svm(race_cat ~ . -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.8819188
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5384615
#########################################################
# REGION 3 - SOUTH
reg.data <- all.reg.data[all.reg.data$region == 3,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 240
gamma = 0.05
g.svm <- svm(race_cat ~ . -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.764095
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.56
#########################################################
# REGION 4 - WEST
reg.data <- all.reg.data[all.reg.data$region == 4,]
# split up our data into train and test set
smp_size <- floor(0.75 * nrow(reg.data)) # 75% of the dataset
set.seed(123)
train_ind <- sample(seq_len(nrow(reg.data)), size = smp_size)
train.reg <- reg.data[train_ind,]
test.reg <- reg.data[-train_ind,]
Y.train <- train.reg$race_cat
Y.test <- test.reg$race_cat
X.train <- train.reg[,-which(names(train.reg)=='race_cat')]
X.test <- test.reg[,-which(names(test.reg)=='race_cat')]
# Train Gaussian SVM on region
cost = 240
gamma = 0.05
g.svm <- svm(race_cat ~ . -region, data = train.reg, 
             type = 'C-classification', kernel = 'radial', 
             cost = cost, gamma = gamma)
g.svm.pred.train <- predict(g.svm,newdata = X.train)
table(g.svm.pred.train, Y.train)
print(sum(g.svm.pred.train == Y.train)/length(Y.train))
# 0.7287234
# Test Gaussian SVM on region
g.svm.pred <- predict(g.svm,newdata = X.test)
table(g.svm.pred, Y.test)
print(sum(g.svm.pred == Y.test)/length(Y.test))
# 0.5714286



############################################################################################## Laura
library(ggplot2)
library(ggmap)
library(maps)
library(cluster)
library(Rtsne)
library(plyr)
library(dplyr)
library(tidyr)            

df.fatal <- read.csv("~/filepath/fatal-police-shootings-data.csv")

############### Plot Maps

# Get lonlat data and frequency for map
df.fatal <- unite(data=df.fatal, city.state, c(city, state), sep = " ", remove = FALSE) # create variable city.state for better accuracy
df.loc <- as.data.frame(table(df.fatal$city.state)) # get freq
names(df.loc)[1] <- 'city.state'
lonlat <- geocode(as.character(df.loc$city.state), source = 'dsk') # get latitude and longitude
df.loc <- na.omit(cbind(df.loc, lonlat)) # remove NA
saveRDS(df.loc, "~/filepath/df.loc.RDS") # save df.loc if use google maps since it takes so long
# df.loc <- readRDS("~/filepath/df.loc.RDS") to load

# Plot using white US map without Alaska or Hawaii
US <- map_data("state") # get US map data, white map
ggplot(data=US, aes(x=long, y=lat, group=group)) +
  geom_polygon(fill="white", colour="black") +
  xlim(-160, 60) + ylim(25,75) +
  geom_point(data=df.loc, inherit.aes=F, aes(x=lon, y=lat, size=Freq), colour="blue",  alpha=.8) +
  coord_cartesian(xlim = c(-130, -50), ylim=c(20,55)) 

# Plot using google map 
# devtools::install_github("hadley/ggplot2@v2.2.0") need old version of ggplot2 to use google maps
df.loc$city.state <- as.character(df.loc$city.state)

# Separate noncontiguous states
df.loc$city.state <- as.character(df.loc$city.state) # change city.state to character to use grep
hawaii <- df.loc[grepl("HI$",df.loc$city.state),]
alaska <- df.loc[grepl("AK$",df.loc$city.state),]

# US contiguous
map <- get_map(location=c(lon = -96.35, lat = 39.70), zoom = 4, source="google",crop=TRUE)
ggmap(map, legend = "none") + 
  geom_point(aes(x = lon, y = lat, size=Freq), data = df.loc, alpha = .7, color = "darkblue") +
  theme(axis.title=element_blank(),
        axis.text=element_blank(),
        axis.ticks=element_blank())
# Alaska
map <- get_map(location = "alaska", zoom = 4)
ggmap(map, legend = "none") + 
  geom_point(aes(x = lon, y = lat, size=Freq), data = alaska, alpha = .7, color = "darkblue") +
  theme(axis.title=element_blank(),
        axis.text=element_blank(),
        axis.ticks=element_blank())
# Hawaii
map <- get_map(location = "hawaii", zoom = 7)
ggmap(map, legend = "none") + 
  geom_point(aes(x = lon, y = lat, size=Freq), data = hawaii, alpha = .7, color = "darkblue") +
  theme(axis.title=element_blank(),
        axis.text=element_blank(),
        axis.ticks=element_blank())

############### Clusterting

# Create df with lat and lon
lonlat <- geocode(as.character(df.fatal$city.state), source = 'dsk')
df.location <- cbind(df.fatal, latlon)
saveRDS(df.location, "~/filepath/df.location.RDS") 

# Use this data for df.fatal
df.fatal <- readRDS("~/filepath/df.location.RDS")
df.na <- df.fatal[rowSums(is.na(df.fatal)) > 0,] # see rows with missing values
df.fatal <- na.omit(df.fatal) # few NA, so just won't use them

# Create new variable minority
df.fatal$minority <- 'white'
df.fatal$minority[df.fatal$race =='B'] <- 'black'
df.fatal$minority[df.fatal$race =='H'] <- 'hispanic'
df.fatal$minority[df.fatal$race !='B' & df.fatal$race != 'W' & df.fatal$race != 'H'] <- 'other'
df.fatal$minority <- factor(df.fatal$minority)

# Create distance matrix for visualization, use Gower distance since mostly categorical data
drop <- c('name', 'date', 'city.state', 'city', 'state', 'race') 
df.fatal.clean <- df.fatal[ , !(names(df.fatal) %in% drop)]

gower_dist <- daisy(df.fatal.clean[, -1], metric = "gower")

# Check Gower dist works
gower_mat <- as.matrix(gower_dist)
# Output most similar pair
df.fatal.clean[which(gower_mat == min(gower_mat[gower_mat != min(gower_mat)]),
        arr.ind = TRUE)[1, ], ]
# Output most dissimilar pair
df.fatal.clean[which(gower_mat == max(gower_mat[gower_mat != max(gower_mat)]),
        arr.ind = TRUE)[1, ], ]

# Calculate silhouette width for many k using PAM
sil_width <- c(NA)

for(i in 2:10){
  pam_fit <- pam(gower_dist,
                 diss = TRUE,
                 k = i)
  sil_width[i] <- pam_fit$silinfo$avg.width
}

# Plot sihouette width (higher is better)
plot(1:10, sil_width,
     xlab = "Number of clusters",
     ylab = "Silhouette Width")
lines(1:10, sil_width)

# Looks like K = 2 is best
pam_fit <- pam(gower_dist, diss = TRUE, k = 2)

pam_results <- df.fatal.clean %>% dplyr::select(-id) %>%
  mutate(cluster = pam_fit$clustering) %>%
  group_by(cluster) %>%
  do(the_summary = summary(.))

# Look at numerics of clusters
pam_results$the_summary
# Looks to be clustered by threat level, race, and armed

# Look at medoids
df.fatal.clean[pam_fit$medoids, ]

############### Dimension reduction
# tSNE, t-distributed stochastic neighborhood embedding
tsne_obj <- Rtsne(gower_dist, is_distance = TRUE)

tsne_data <- tsne_obj$Y %>%
  data.frame() %>%
  setNames(c("X", "Y"))

# Lets look at some variables in 2D to see if anything separates well
tsne_data <-  data.frame(cluster = factor(pam_fit$clustering), df.fatal.clean, tsne_data, race=df.fatal$race)
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color = cluster))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=threat_level))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=manner_of_death))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=signs_of_mental_illness))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=body_camera))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=minority))
ggplot(aes(x = X, y = Y), data = tsne_data) + geom_point(aes(color=race))

# Can compare with MDS
# MDS
fit <- cmdscale(gower_dist, k=2) # k is the number of dim
fit # view results

# Plot MDS without coloring groups  
fit <- as.data.frame(fit)
ggplot() + geom_point(data=fit, aes(fit[,1], fit[,2]))
# Plot MDS, color by cluster
fit <- cbind(fit, df.fatal, cluster = factor(pam_fit$clustering))
ggplot() + geom_point(data=fit, aes(x=V1, y=V2, color=cluster))

############################################################################################## Zoe
library(ggplot2)
library(plot3D)
library(cluster)

file.dat <- read.csv(paste("/Users/zoerehnberg/Documents/UMich - First Year/STATS 601/",
                          "final project/database.csv", sep = ""))

# read in the data from Laura that includes longitude and latitude
fat.dat <- readRDS("/Users/zoerehnberg/Documents/UMich - First Year/STATS 601/final project/df.location.RDS")

# eliminate the rows with missing entries
miss.dat <- fat.dat[rowSums(is.na(fat.dat)) == 0,]
miss.dat <- miss.dat[miss.dat$id != c(2158),]
miss.dat <- miss.dat[miss.dat$id != c(2304),]

# discretize weapons
weapon_converter <- function(x){
  if(x %in% c('gun', 'guns and explosives', 'gun and knife', 'hatchet and gun',
              'machete and gun')) return(as.factor('gun'))
  if(x %in% c('knife','pole and knife','sword','machete')) return(as.factor('knife'))
  if(x %in% c('vehicle','motorcycle'))return(as.factor('vehicle'))
  if(x %in% c('','undetermined')) return(as.factor('undetermined'))
  if(x %in% c('toy weapon')) return(as.factor('toy weapon'))
  if(x == 'unarmed') return(as.factor('unarmed'))
  return(as.factor('other'))
}
weap.dat <- sapply(miss.dat$armed, weapon_converter)

use.dat <- miss.dat[,-c(1:3,9:11)]
use.dat[,2] <- weap.dat

#########################################################
### TRY CLASSICAL MDS -- GET DISTANCES BETWEEN PEOPLE

# Gower distance
# Euclidean distance doesn't make sense for categorical data
gower.dist <- daisy(use.dat, metric = "gower")

# try three dimensions
gower.mds3 <- cmdscale(gower.dist, k = 3, eig = TRUE)
gmds.res3 <- data.frame(gower.mds3$points)
scatter3D(x = gmds.res3$X1, y = gmds.res3$X2, z = gmds.res3$X3, colvar = as.numeric(use.dat$race),
          axis.ticks = T, ticktype = "detailed",pch = 19, cex = 0.5, bty = "g", theta = 85, phi = 15)

# try two dimensions
gower.mds <- cmdscale(gower.dist, k = 2, eig = TRUE)
gmds.res <- data.frame(gower.mds$points)

# plain MDS plot
ggplot(data = gmds.res, aes(x = X1, y = X2)) + geom_point(cex = 0.5) + labs(title = "Classical MDS")

# colored by mental illness
ggplot(data = gmds.res, aes(x = X1, y = X2)) +
  geom_point(aes(color = use.dat$signs_of_mental_illness), cex = 0.5) +
  labs(title = "Classical MDS: Mental Illness", color = "Mental Illness") +
  guides(colour = guide_legend(override.aes = list(size=2)))

# colored by threat level
ggplot(data = gmds.res, aes(x = X1, y = X2)) +
  geom_point(aes(color = use.dat$threat_level), cex = 0.5) +
  scale_color_hue(labels = c("Attack", "Other","Undet.")) + 
  labs(title = "Classical MDS: Threat Level", color = "Threat Level") +
  guides(colour = guide_legend(override.aes = list(size=2)))

# colored by race
ggplot(data = gmds.res, aes(x = X1, y = X2)) + geom_point(aes(color = use.dat$race), cex = 0.5) +
  labs(title = "Classical MDS: Race", color = "Race") +
  scale_color_hue(labels = c("Undet.", "Asian","Black", "Hispanic","Nat. Am.", "Other race","White")) + 
  guides(colour = guide_legend(override.aes = list(size=2)))

# colored by body camera
ggplot(data = gmds.res, aes(x = X1, y = X2)) +
  geom_point(aes(color = use.dat$body_camera), cex = 0.5) +
  labs(title = "Classical MDS: Body Camera", color = "Body Camera") +
  guides(colour = guide_legend(override.aes = list(size=2)))

#########################################################
# PLOTS INVOLVING RACE

### RACE IN FATAL SHOOTINGS
race.counts <- table(use.dat$race)
race.prop <- prop.table(race.counts)*100
rownames(race.prop) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))
race.prop <- data.frame(race.prop)

ggplot(data = race.prop, aes(x = Var1, y = Freq)) + geom_bar(aes(fill = Var1), stat = "identity") +
  labs(title = "Racial Breakdown: Fatal Police Shootings", y = "Percent", x = "") +
  theme(axis.text=element_text(size=12)) + guides(fill = FALSE) + ylim(c(0,100))

#########################################################

### RACE IN THE US
us.race <- c(0, 4.7, 12.2, 16.3, 0.9, 2.1, 63.7)
us.race <- data.frame(us.race,race.prop[,1])

ggplot(data = us.race, aes(x = race.prop[,1], y = us.race)) +
  geom_bar(aes(fill = race.prop[,1]),stat = "identity") +
  labs(title = "Racial Breakdown: U.S. Population", y = "Percent", x = "") +
  theme(axis.text=element_text(size=12)) + guides(fill = FALSE) + ylim(c(0,100))

#########################################################

### RACE AND WEAPON
rw.tab <- table(use.dat$race, use.dat$armed)
rownames(rw.tab) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))

rw.dat <- data.frame(prop.table(rw.tab,2)*100)
colnames(rw.dat)[1] <- "Race"

ggplot(data = rw.dat, aes(x = Race, y = Freq)) + facet_wrap(~Var2) +
  geom_bar(aes(fill = Race), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))

#########################################################

### RACE AND THREAT LEVEL
ra.tab <- table(use.dat$race, use.dat$threat_level)
rownames(ra.tab) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))

ra.dat <- data.frame(prop.table(ra.tab,2)*100)
colnames(ra.dat)[1] <- "Race"
colnames(ra.dat)[2] <- "Threat"

ggplot(data = ra.dat, aes(x = Race, y = Freq)) + facet_wrap(~Threat) +
  geom_bar(aes(fill = Race), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))

ra.dat2 <- data.frame(prop.table(ra.tab,1)*100)
colnames(ra.dat2)[1] <- "Race"
colnames(ra.dat2)[2] <- "Threat"

ggplot(data = ra.dat2, aes(x = Threat, y = Freq)) + facet_wrap(~Race) +
  geom_bar(aes(fill = Threat), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))

#########################################################

### RACE AND MENTAL ILLNESS
rmi.tab <- table(use.dat$race, use.dat$signs_of_mental_illness)
rownames(rmi.tab) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))
colnames(rmi.tab) <- factor(c("No Signs of Mental Illness", "Signs of Mental Illness"))

rmi.dat <- data.frame(prop.table(rmi.tab,2)*100)
colnames(rmi.dat)[1] <- "Race"

ggplot(data = rmi.dat, aes(x = Race, y = Freq)) + facet_wrap(~Var2) +
  geom_bar(aes(fill = Race), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))

#########################################################

### RACE AND BODY CAMERA
rbc.tab <- table(use.dat$race, use.dat$body_camera)
rownames(rbc.tab) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))
colnames(rbc.tab) <- factor(c("No Body Camera", "Body Camera"))

rbc.dat <- data.frame(prop.table(rbc.tab,2)*100)
colnames(rbc.dat)[1] <- "Race"

ggplot(data = rbc.dat, aes(x = Race, y = Freq)) + facet_wrap(~Var2) +
  geom_bar(aes(fill = Race), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))

#########################################################

### RACE AND FLEEING
rf.tab <- table(use.dat$race, use.dat$flee)
rownames(rf.tab) <- factor(c("Undet.", "Asian", "Black", "Hispanic", "Nat. Am.", "Other race", "White"))
colnames(rf.tab)[1] <- "Undetermined"

rf.dat <- data.frame(prop.table(rf.tab,2)*100)
colnames(rf.dat)[1] <- "Race"

ggplot(data = rf.dat, aes(x = Race, y = Freq)) + facet_wrap(~Var2) +
  geom_bar(aes(fill = Race), stat = "identity") + ylim(c(0,100)) + labs(y = "Percent", x = "") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank()) +
  theme(strip.text = element_text(size = 11))


                

############################################################################################## Ed
ps.data = readRDS(file.choose())
set.seed(414)
library(randomForest)

###################### Functions ############################

# Loss Function
loss = function(y, f.hat, c){
  a = sum(y == "True" & f.hat == "False")
  b = sum(y == "False" & f.hat == "True")
  
  out = a*c + b
  return(out)
}

# Performs the Random Forest. Returns the confusion matrix, 
# the class error rates, and the value of the loss function
rf = function(X.train, Y.train, X.test, Y.test, thres, c = 9) {
  rf = randomForest(X.train, Y.train)
  pred.rf = predict(rf, X.test, type = "prob")
  t.num = which(colnames(pred.rf) == "True")
  pred.table = unname(ifelse(pred.rf[,t.num] > thres, "True", "False"))
  pred.table = cbind(pred.table,as.character(Y.test))
  
  out = table(pred.table[,1],pred.table[,2])
  false.err = 1-sum(pred.table[,1] == "False" & pred.table[,2] == "False")/sum(pred.table[,2] == "False")
  true.err = 1-sum(pred.table[,1] == "True" & pred.table[,2] == "True")/sum(pred.table[,2] == "True")
  
  loss = loss(y = Y.test, f.hat = pred.table[,1], c)
  
  return(list(out,false.err,true.err,loss))
}

# Creates k folds. Used for the CV function
folds = function(n, k){
  size = round(n/k)
  out = list()
  start = 0
  indices = sample(1:n,n,replace = FALSE)
  for(i in 1:k) {
    if(i < k) out[[i]] = indices[(start+1):(start+size)]
    else out[[i]] = indices[(start+1):n]
    start = start+size
  }
  return(out)
}

# Up Sample the minority class
up = function(X.train, Y.train){
  bcam.t = which(Y.train == "True")
  bcam.f = which(Y.train == "False")
  
  up.t = sample(bcam.t,length(bcam.f),replace = TRUE)
  up.f = sample(bcam.f,length(bcam.f),replace = FALSE)
  Y.up = Y.train[c(up.t,up.f)]
  X.up = X.train[c(up.t,up.f),]
  
  return(list(X.up,Y.up))
}

# Down Sample the majority class
down = function(X.train, Y.train){
  bcam.t = which(Y.train == "True")
  bcam.f = which(Y.train == "False")
  
  down.t = sample(bcam.t,length(bcam.t),replace = FALSE)
  down.f = sample(bcam.f,length(bcam.t),replace = FALSE)
  Y.down = Y.train[c(down.t,down.f)]
  X.down = X.train[c(down.t,down.f),]
  
  return(list(X.down,Y.down))
}

# Perform k-fold cross validation r times. Returns the loss 
# along with the error rate for the "true" class
cv.rf = function(X, Y, thres, c = 9, k = 5, r = 1,
                 sample = c("none","up","down")){
  loss = 0
  true.err = 0
  for(j in 1:r) {
    n = length(Y)
    sets = folds(n, k)
    for(i in 1:k) {
      X.train = X[unlist(sets[-i]),]
      Y.train = Y[unlist(sets[-i])]
      X.test = X[sets[[i]],]
      Y.test = Y[sets[[i]]]
      
      if(sample == "up") {
        temp = up(X.train,Y.train)
        X.train = temp[[1]]
        Y.train = temp[[2]]
      } 
      if(sample == "down") {
        temp = down(X.train,Y.train)
        X.train = temp[[1]]
        Y.train = temp[[2]]
      }
      
      results = rf(X.train, Y.train, X.test, Y.test, thres, c)
      loss = loss + results[[4]]
      true.err = true.err + results[[3]]
    }
  }
  return(list(loss/(k*r),(true.err)/(k*r)))
}

###################### Data Cleaning ##############################
Y = as.factor(ps.data$body_camera)
X = as.data.frame(ps.data[,c(4:14,16,17)])

Y = Y[-c(1935,2050)]
X = X[-c(1935,2050),]

# omit missing data
Y = Y[complete.cases(X)]
X = X[complete.cases(X),]

# subset "Armed"
X$armed = as.character(X$armed)
gun = grep("gun", X$armed)
X$armed[gun] = "gun"
other = which(X$armed != "gun" & 
                X$armed != "unarmed" & 
                X$armed != "undetermined" &
                X$armed != "knife" &
                X$armed != "vehicle" &
                X$armed != "toy weapon")
X$armed[other] = "other"
X$armed = as.factor(X$armed)

# remove city/state variables
X = X[-c(6:8)]

# create a training/test set
testset = function(X, Y, size = 500) {
  draws = sample(0:length(Y),length(Y),replace = FALSE)
  test = draws[1:size]
  train = draws[(size+1):length(Y)]
  
  Y.test = Y[test]
  X.test = X[test,]
  Y.train = Y[train]
  X.train = X[train,]
  return(list(X.train,Y.train,X.test,Y.test))
}

test = testset(X, Y, 500)
X.train = test[[1]]
Y.train = test[[2]]
X.test = test[[3]]
Y.test = test[[4]]

#################### Data Analysis ############################

rf.train = randomForest(X.train,Y.train)

# construct the oversampled training set
bcam.t = which(Y.train == "True")
bcam.f = which(Y.train == "False")

up.t = sample(bcam.t,length(bcam.f),replace = TRUE)
up.f = sample(bcam.f,length(bcam.f),replace = FALSE)
Y.up = Y.train[c(up.t,up.f)]
X.up = X.train[c(up.t,up.f),]

# fit random forest and calculate cv error
rf.up = randomForest(X.up,Y.up)
cv.rf(X.train,Y.train,.5,sample = "up")

# same as above for undersampled training set
down.t = sample(bcam.t,length(bcam.t),replace = FALSE)
down.f = sample(bcam.f,length(bcam.t),replace = FALSE)
Y.down = Y.train[c(down.t,down.f)]
X.down = X.train[c(down.t,down.f),]

rf.down = randomForest(X.down,Y.down)
cv.rf(X.train,Y.train,.5,sample = "down")

# For regular training set, search for optimal k
thresholds = c(0.001, 0.01, 0.1, .25, .5)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9, sample = "none")[[1]]))
}

thresholds = 0.1+0.01*(0:10)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9, sample = "none")[[1]]))
}

rf(X.train,Y.train,X.test,Y.test,.10)
rf(X.train,Y.train,X.train,Y.train,.1)

# For oversampled training set, search for optimal k
thresholds = c(0.001, 0.01, 0.1, .25, .5)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9,sample = "up")[[1]]))
}

thresholds = 0.1+0.01*(0:10)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9, sample = "up")[[1]]))
}

rf(X.up,Y.up,X.test,Y.test,.17)
rf(X.up,Y.up,X.up,Y.up,.17)

# For undersampled training set, search for optimal k
thresholds = c(0.001, 0.01, 0.1, .25, .5)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9, sample = "down")[[1]]))
}

thresholds = 0.4+0.01*(0:10)

for(x in thresholds){
  print(c(x,cv.rf(X.train,Y.train,x, r = 5, c = 9, sample = "down")[[1]]))
}

rf(X.down,Y.down,X.test,Y.test,.5)
rf(X.down,Y.down,X.down,Y.down,.5)



