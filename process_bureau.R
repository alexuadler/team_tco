library(dplyr)
library(data.table)

## Read data
bureau <- readRDS("dat/bureau.RDS")
bureau_balance <- readRDS("dat/bureau_balance.RDS")

### The bureau_balance dataframe has multiple entries for each SK_ID_BUREAU indicating the STATUS of the credit bureau loan during each month prior to the loan application. Larger numbers indicate more recent data (MONTHS_BALANCE). Let's only keep the most recent entry for each SK_ID_BUREAU.

bureau_balance <- group_by(bureau_balance, SK_ID_BUREAU) %>% 
      filter(MONTHS_BALANCE == max(MONTHS_BALANCE))

### Bureau dataframe: drop the columns that are probably not useful
# Get min, max, and mean for each remaining column
bureau <- left_join(bureau, bureau_balance, by = "SK_ID_BUREAU") %>% 
      select(-c(CREDIT_ACTIVE, CREDIT_CURRENCY, DAYS_CREDIT_UPDATE, 
                CREDIT_TYPE)) %>%
      group_by(SK_ID_CURR)

# Do one-hot encoding for factor variable STATUS
mm <- tbl_df(model.matrix(~ SK_ID_CURR + STATUS-1, data = bureau))
mm$SK_ID_CURR <- as.integer(mm$SK_ID_CURR)
mm <- group_by(mm, SK_ID_CURR) %>%
      summarize_all(sum)

newFeatures <- bureau %>% 
  distinct(SK_ID_CURR) %>%
  left_join(mm, by="SK_ID_CURR")


# Rename columns to denote that they came from the "bureau" dataframe (some column names are the same in different files)
colNames <- names(bureau) %>% 
      .[3:length(.)] %>%
      sapply(function(name) paste0(name, "_BUREAU"))

names(bureau) <- c("SK_ID_CURR", "SK_ID_BUREAU", colNames)

bureau$SK_ID_BUREAU <- as.factor(bureau$SK_ID_BUREAU)
bureau <- bureau %>% 
      summarize_if(is.numeric, funs(max, min, mean), na.rm = T)

# The summarize_if function will cause -Inf and Inf values when a particular SK_ID_CURR has only NA values for a feature. So, find all of those and set them equal to NA.
for (i in 1:length(bureau)) {
      theCol <- bureau[i]
      infs <- which(theCol == -Inf | theCol == Inf)
      bureau[infs, i] <- NA
}
rm(theCol, infs)

# Rename and add the STATUS columns
colNames <- names(newFeatures) %>% 
      .[2:length(.)] %>%
      sapply(function(name) paste0(name, "_BUREAU"))

names(newFeatures) <- c("SK_ID_CURR", colNames)
bureau <- left_join(bureau, newFeatures, by = "SK_ID_CURR")



# Join the aggregated bureau df to the training set
df <- left_join(df, bureau, by = "SK_ID_CURR")

rm(newFeatures, bureau, bureau_balance, mm, colNames)
