## ---------------------------------------------------------------------
knitr::purl("housing.rmd")


## ---------------------------------------------------------------------
pacman::p_load(tidyverse, janitor, skimr, DataExplorer, caret, xgboost, tictoc)


## ---------------------------------------------------------------------
housing <- read_csv("./data/housing_raw.csv")
housing


## ---------------------------------------------------------------------
summary(housing$price)


## ---------------------------------------------------------------------
price_org <- ggplot(housing, aes(price)) + 
  geom_histogram(fill = "lightgreen") + 
  labs(y = "", x = "Price of house") + 
  scale_x_continuous(breaks =seq(1e06, 2e07,1e06),
                     labels = scales::dollar_format()) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        axis.text.y = element_blank())

price_log <- ggplot(housing, aes(log(price) )) + 
  geom_histogram(fill = "lightgreen") + 
  labs(y = "", x = "Log of Price of house") + 
  scale_x_log10(breaks =seq(log(1e06), log(2e07),.3 ),
                     labels = scales::dollar_format()) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        axis.text.y = element_blank())

log_org_price <- cowplot::plot_grid(price_org, price_log)

ggsave(filename = "./images/distribution.png")


## ---------------------------------------------------------------------
skim(housing)


## ---------------------------------------------------------------------
housing |> 
  select(where(is.numeric), where(is.character))


## ---------------------------------------------------------------------
housing_df <- housing |> 
  clean_names() |> 
  mutate(across(where(is.character), as.factor)) |> 
  rename("square_footage" = "area") |> 
  mutate(price_log = log(price)) |> 
  select(-price) |> 
  select(price_log, everything())



## ---------------------------------------------------------------------
housing_df02 <- model.matrix(price_log~., data = housing_df)[,-1] |> 
  data.frame() |> 
  cbind(housing_df[,1]) |> 
  select(price_log, everything())
  


## ---------------------------------------------------------------------
set.seed(1)
index <- caret::createDataPartition(housing_df02$price_log, p = .7,list = FALSE)
train <- housing_df02[index,]
test <- housing_df02[-index,]


## ---------------------------------------------------------------------
hist(train$price_log)
hist(test$price_log)
summary(train$price)
summary(test$price)

# skim(test)


## ---------------------------------------------------------------------
train$price_log |> exp() |> head(5)
test$price_log |> exp()|> head(5)


## ---------------------------------------------------------------------
dtrain <- xgb.DMatrix(as.matrix(train), label = train$price_log)
dtest <- xgb.DMatrix(as.matrix(test), label = test$price_log)


## ---------------------------------------------------------------------
set.seed(1)
params <- list(
  objective = "reg:squarederror",
  eta = 0.01,
  booster = "dart",
  # nthread = 8,
  eval_metric = "mae",
  max_depth = 4,
  alpha = 0,
  lambda = 0)
  # colsample_bytree = 0.8,
  # subsample = 0.8)

early_stopping_round <- 50

tic()

cv_results <-  xgb.cv(
  params = params,
  data = dtrain,
  nrounds = 100000,  # Number of boosting rounds / iterations
  nfold = 5,    # Number of folds
  stratified = TRUE,
  early_stopping_rounds = early_stopping_round,
  verbose = TRUE
)

(train_elapsed <- toc())


## ---------------------------------------------------------------------
optimal_rounds <- which.min(cv_results$evaluation_log$test_mae_mean)
# optimal_rounds


## ---------------------------------------------------------------------
set.seed(1)
tic()

final_xgboost <- xgboost(params = params,
                         data = dtrain,
                         nrounds = optimal_rounds,
                         early_stopping_rounds = early_stopping_round,
                         verbose = TRUE)

final_model_elapsed <- toc()


## ---------------------------------------------------------------------
# xgb.save(final_xgboost, "./model/model_10/xgboost_JAN_24_2024_ver_01")


#
final_xgboost <- xgb.load("./model/model_06/xgboost_JAN_24_2024_ver_01")


## ---------------------------------------------------------------------
pred_xgboost <- predict(final_xgboost, newdata = dtest)
pred_xgboost

# original response
exp(pred_xgboost)

# log-response 
log_rmse <- Metrics::rmse(test$price, pred_xgboost)
log_mae <- Metrics::mae(test$price, pred_xgboost)

#original
original_rmse <- Metrics::rmse(exp(test$price), exp(pred_xgboost))
original_mae <- Metrics::mae(exp(test$price), exp(pred_xgboost))

metric <- data.frame(log_response_metric = c(log_rmse, log_mae), original_response_metric = c(original_rmse, original_mae))
rownames(metric) <- c("RMSE", "MAE")          
metric


df_actual_pred <- data.frame(exp(test$price), exp(pred_xgboost))
colnames(df_actual_pred) <- c("Acutal price", "Prediction Price")

head(df_actual_pred)



## ---------------------------------------------------------------------
# write.csv(df_actual_pred, "./model/model_10/dataframe_results/metric.csv", row.names = FALSE)
# 
# save(df_actual_pred, file =  "./model/model_10/dataframe_results/metric.csv.RData")
# 
# 
# write.csv(df_actual_pred, "./model/model_10/dataframe_results/df_actual_pred.csv", row.names = FALSE)
# 
# save(df_actual_pred, file =  "./model/model_10/dataframe_results/df_actual_pred.RData")


# load(  "./model/model_04/dataframe_results/df_actual_pred.RData")

