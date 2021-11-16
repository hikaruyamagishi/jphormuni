# Info --------------------------------------------------------------------
# 20180515, Hikaru Yamagishi
#
# This code scrapes soumushou website, saves it as excel files,
# imports the data into one combined data frame.
#
# Final product:
# df_smd_scrape_exported20180517.RData, df_smd_scrape_exported20180517.csv
# are the final products. These contain every excel file (SMD1 to SMD47)
# and every sheet within each.
#

# 00. Data Scraping from somusho website ----------------------------------

# 00-00. Explanation ------------------------------------------------------

# House of Representative election 46th
# Votes by municipalities
#
# Download .xls files from
# http://www.soumu.go.jp/senkyo/senkyo_s/data/shugiin46/shikuchouson.html
#
# NOTE
# Excel file is binary, so the mode should be wb.
# Sys.sleep(1) stops the system for a second no to be regarded as 不正アクセス


# 00-01. Setup ------------------------------------------------------------

setwd("/Users/hikaruyamagishi/Dropbox/git/jphormuni/")

#install.packages("rvest")
#install.packages("pathological")
# rm(list=ls())

library(lubridate)
library(pathological)
library(rvest)
library(stringr)
library(tidyverse)
library(XML)
library(readxl)
library(reshape2)


# 00-02. Set up directory folders -----------------------------------------

# Create dir path by naming folders/subfolders where you will place the data
# This one will be HOR 48
dir_path <- "./02_Scraped_Electoral_Data/HOR48/SMD"
# Create folders and subfolders
create_dirs(dir_path)


# 00-03. Scraping ---------------------------------------------------------

# Website for HOR 48 results:
# http://www.soumu.go.jp/senkyo/senkyo_s/data/shugiin48/shikuchouson.html

# Function (change election number)
for(i in 1:47){
  
  writeLines(paste("Now downloading ...",as.character(i)))
  
  if(i < 10){
    no <- paste("0",as.character(i),sep = "")
  }else{
    no <- as.character(i)  
  }  
  # change this for the election number
  url <- paste("http://www.soumu.go.jp/senkyo/senkyo_s/data/shugiin48/shikuchouson_",no,".html",sep="")
  webpage <- read_html(url, encoding = "SHIFT-JIS")
  pagelist  <- webpage %>%
    html_nodes("a") %>%    ## find all links
    html_attr("href")%>%
    str_subset("/main_content/")
  
  link <- paste("http://www.soumu.go.jp",pagelist[1],sep="")
  download.file(link, destfile = paste(dir_path, "/SMD", as.character(i), 
                                       ".xls",sep=""), quiet = T,mode="wb")
  Sys.sleep(1)
}



# 00-04. Read data from xls files -----------------------------------------

# Toy example first, then make it into a function.
# Load this function -- will use in the larger function to read in data.

# Function: Pass in a data frame, return columns except those that
#           have all NA's or 0's
delete_NA0 <- function(dataframe){
  dataframe[, (colSums(is.na(dataframe)) +  # return number of NAs
                 colSums(dataframe == 0, na.rm = TRUE))  # return number of 0s
            < nrow(dataframe)]  # returns cols where nrow is larger than NAs
  # and zeros
}


# 00-04. Part I: Toy example to figure out function in part II ---------------

# Test with toy function
# read in excel sheet (first tab)
df <- read_xls(path = "02_Scraped_Electoral_Data/HOR48/SMD/SMD1.xls", 
               sheet = 1, trim_ws = TRUE, col_types = "text", skip = 3, )
# 1. delete columns with all NAs
df2 <- df %>% delete_NA0()
# 2. delete tokuhyosu col.
#    which cols have tokuhyosu in colname?
tokuhyosu_cols <- str_detect(colnames(df2), "得票数計")
#    return cols with tokuhyosu_cols as FALSE, i.e. return non-tokuhyosu cols
df3 <- df2[, tokuhyosu_cols == FALSE]
# 3. delete very bottom row, the one that is the sum (goukei).
#    which rows have goukei in the name?
goukei_rows <- str_detect(df3$候補者名, "合計")
#    return rows that have goukei_rows as FALSE, i.e. return non-goukei rows
df4 <- df3[goukei_rows == FALSE, ]

# Now all we have left is to delete row 1 describing candidate's party, but
# before this, let's take row 2 and down and melt
df5 <- df4[2:5,]
df_melted <- melt(df5, id.vars = 1)

# Now add row for candidate party
df_melted <- df_melted %>% 
  mutate(party = NA)

# Get party information from df4, row1, and put it in new df `df_partyname`
df_partyname <- data_frame(
  # colnames of df4
  colnames = colnames(df4),
  # row1 of df4
  partyrow = as.vector(as.matrix(df4)[1,])
)

# For each row in df_melted, add the candidate's party name by pulling it
# from df_partyname that we just created
for (i in 1:nrow(df_melted)) {
  partyname <- df_partyname$partyrow[str_which(df_partyname$colnames, 
                                            as.matrix(df_melted$variable)[i,1])]
  df_melted$party[i] <- partyname
}


# 00-04. Part II: Read in xls data ---------------------------

# make a list of the excel file names in the folder
xlsfilenames <- list.files(path = "02_Scraped_Electoral_Data/HOR48/SMD/", 
                           pattern="*.xls")
# make a list of the path names that lead to these excel files
dir_path <- "./02_Scraped_Electoral_Data/HOR48/SMD"
xls_path <- paste(dir_path, "/", xlsfilenames, sep="")

# read_munivote_xls function
read_munivote_xls <- function(nth_pref, xlsfile_pref, nth_sheet) {
  # read in excel sheet (first tab)
  df <- read_xls(path = xlsfile_pref, 
                 sheet = nth_sheet, trim_ws = TRUE, col_types = "text", skip = 3, )
  # 1. delete columns with all NAs
  df2 <- df %>% delete_NA0()
  # 2. delete tokuhyosu col.
  #    which cols have tokuhyosu in colname?
  tokuhyosu_cols <- str_detect(colnames(df2), "得票数計")
  #    return cols with tokuhyosu_cols as FALSE, i.e. return non-tokuhyosu cols
  df3 <- df2[, tokuhyosu_cols == FALSE]
  # 3. delete very bottom row, the one that is the sum (goukei).
  #    which rows have goukei in the name?
  goukei_rows <- str_detect(df3$候補者名, "合計")
  #    return rows that have goukei_rows as FALSE, i.e. return non-goukei rows
  df4 <- df3[goukei_rows == FALSE, ]
  
  # Now all we have left is to delete row 1 describing candidate's party, but
  # before this, let's take row 2 and down and melt
  nrow_df4 <- nrow(df4)
  df5 <- df4[2:nrow_df4,]
  df_melted <- melt(df5, id.vars = 1)
  
  # Now add row for candidate party
  df_melted <- df_melted %>% 
    mutate(party = NA)
  
  # Get party information from df4, row1, and put it in new df `df_partyname`
  df_partyname <- data_frame(
    # colnames of df4
    colnames = colnames(df4),
    # row1 of df4
    partyrow = as.vector(as.matrix(df4)[1,])
  )
  
  # For each row in df_melted, add the candidate's party name by pulling it
  # from df_partyname that we just created
  for (j in 1:nrow(df_melted)) {
    partyname <- df_partyname$partyrow[str_which(df_partyname$colnames, 
                                                 as.matrix(df_melted$variable)[j,1])]
    df_melted$party[j] <- partyname
  }
  
  # rename colnames
  colnames(df_melted) <- c("muni_j", "name_j", "muni_vote", "party_j")
  
  # how many rows from this sheet? (ku)
  n_newrows <- nrow(df_melted)
  
  # add kucode
  df_melted <- df_melted %>% 
    mutate(kucode = rep(nth_sheet, n_newrows)) %>% 
    mutate(ken = rep(nth_pref, n_newrows))
  
  return(df_melted)
}

# create empty df
# rm(df_all)
df_all <- data_frame(
  muni_j = as.character(NA), # keeping j so we can distinguish when merging later
  name_j = as.character(NA), # name of cand, corresponds to RS name_jp
  muni_vote = as.character(NA),
  party_j = as.character(NA),
  ken = NA,
  kucode = NA
)

# function
for (i in 1:47) {
  xls_file <- xls_path[i]
  # how many tabs (sheets) in this excel file?
  n_sheets <- length(excel_sheets(xls_file))
  # loop the function over the number of sheets
  for (k in 1:n_sheets) {
    # run read_munivote_xls function for one sheet
    df_melted <- read_munivote_xls(nth_pref = i, xlsfile_pref = xls_file, 
                                   nth_sheet = k)
    df_all <- full_join(df_all, df_melted)
  }
}

# First row is NA, so delete
dim(df_all)
df_smd_scrape <- df_all[2:6184, ]

# Make vote value numeric
df_smd_scrape$muni_vote <- as.numeric(df_smd_scrape$muni_vote)

# Check to see if data is complete
# All ken?
str(df_smd_scrape)
df_smd_scrape %>% 
  distinct(ken) %>% 
  .$ken
# Yes.
# Any NAs?
colSums(is.na(df_smd_scrape))
# Yes. Which ones?

# Which muni_vote are NAs?
df_smd_munivoteNA <- df_smd_scrape %>% 
  mutate(vote_NA = is.na(muni_vote)) 
# how many are NA? 12
df_smd_munivoteNA %>% 
  count(vote_NA)
# which ones?
df_smd_munivoteNA %>% 
  filter(vote_NA == TRUE)
# These are the ones with muji_j NA as well.

# What are the row numbers of these NA rows?
na <- is.na(df_smd_scrape$muni_j)
rownums <- which(na == TRUE)
df_smd_scrape[rownums,]
# Go to ken 2, 3ku and see what is wrong
# What does it look like in data?
aomori3 <- df_smd_scrape %>% 
  filter(ken == 2) %>% 
  filter(kucode == 3)
# Lookd like every cand just has 3 extra rows
# Try deleting NA rows
df_smd_scrape_2 <- df_smd_scrape %>% 
  filter(is.na(muni_vote)==FALSE)
aomori3_new <- df_smd_scrape_2 %>% 
  filter(ken == 2) %>% 
  filter(kucode == 3)
# Looked at it manually against original xls file, looks good!
df_smd_scrape <- df_smd_scrape_2
# Once again--Any NAs?
colSums(is.na(df_smd_scrape))
# No, great.

# Make sure party names aren't duplicated
df_smd_scrape %>% 
  distinct(party_j) %>% 
  .$party_j

# Get rid of duplicated party names
party_j_new <- df_smd_scrape %>% 
  mutate(party_j_2 = ifelse(test = party_j == "（幸福実現党）", 
                            yes = "幸福実現党", no = party_j)) %>% 
  mutate(party_j_3 = ifelse(test = party_j_2 == "（無所属）", yes = "無所属", 
                            no = party_j_2)) %>% 
  mutate(party_j_4 = ifelse(test = party_j_3 == "(幸福実現党)", 
                            yes = "幸福実現党", no = party_j_3)) %>% 
  mutate(party_j_5 = ifelse(test = party_j_4 == "(無所属)", 
                            yes = "無所属", no = party_j_4)) %>% 
  mutate(party_j_6 = ifelse(test = party_j_5 == "（世界経済共同体党）", 
                            yes = "世界経済共同体党", no = party_j_5)) %>% 
  mutate(party_j_7 = ifelse(test = party_j_6 == "（犬丸勝子と共和党）", 
                            yes = "犬丸勝子と共和党", no = party_j_6)) %>% 
  mutate(party_j_8 = ifelse(test = party_j_7 == "（都政を改革する会）", 
                            yes = "都政を改革する会", no = party_j_7)) %>% 
  mutate(party_j_9 = ifelse(test = party_j_8 == "（議員報酬ゼロを実現する会）", 
                            yes = "議員報酬ゼロを実現する会", no = party_j_8)) %>%
  mutate(party_j_10 = ifelse(test = party_j_9 == "（新党憲法９条）", 
                            yes = "新党憲法９条", no = party_j_9)) %>%
  mutate(party_j_11 = ifelse(test = party_j_10 == "（フェア党）", 
                            yes = "フェア党", no = party_j_10)) %>%
  mutate(party_j_12 = ifelse(test = party_j_11 == "（労働者党）", 
                            yes = "労働者党", no = party_j_11)) %>%
  mutate(party_j_13 = ifelse(test = party_j_12 == "(長野県を日本一好景気にする会)", 
                            yes = "長野県を日本一好景気にする会", no = party_j_12)) %>%
  mutate(party_j_14 = ifelse(test = party_j_13 == "(日本新党)", 
                            yes = "日本新党", no = party_j_13)) %>%
  .$party_j_14

# CHeck party names, good.
unique(party_j_new)
# Replace
df_smd_scrape$party_j <- party_j_new
# Check. Good
df_smd_scrape %>% 
  distinct(party_j) %>% 
  .$party_j
df_smd_scrape_HOR48 <- df_smd_scrape

save(df_smd_scrape_HOR48, file = "df_smd_scrape_HOR48_exported20180530.RData")
write_csv(df_smd_scrape_HOR48, path = "df_smd_scrape_HOR48_exported20180530.csv")

# 00-05. Fixing bug for previous function ---------------------------------

# Case 1. When we run 47 prefectures, row 663 onwards has NA for party
df_all[660:670,]
# read in excel sheet (first tab)
df <- read_xls(path = "02_Scraped_Electoral_Data/HOR48/SMD/SMD03.xls", 
               sheet = 2, trim_ws = TRUE, col_types = "text", skip = 3, )
# 1. delete columns with all NAs
df2 <- df %>% delete_NA0()
# Super weird muni names to the gray area to the right (see SMD03 orig.xls)
# deleted manually, try again:
df <- read_xls(path = "02_Scraped_Electoral_Data/HOR48/SMD/SMD03.xls", 
               sheet = 2, trim_ws = TRUE, col_types = "text", skip = 3, )
df2 <- df %>% delete_NA0()
# Great
rm(df, df2)

# Case 2. Where did it stop?
dim(df_all)
# Look at the end
df_all[2660:2670,]
# try running code on 15th pref, 5th ku
# read in excel sheet (first tab)
df <- read_xls(path = "02_Scraped_Electoral_Data/HOR48/SMD/SMD15.xls", 
               sheet = 6, trim_ws = TRUE, col_types = "text", skip = 3, )
# 1. delete columns with all NAs
df2 <- df %>% delete_NA0()
# 2. delete tokuhyosu col.
#    which cols have tokuhyosu in colname?
tokuhyosu_cols <- str_detect(colnames(df2), "得票数計")
#    return cols with tokuhyosu_cols as FALSE, i.e. return non-tokuhyosu cols
df3 <- df2[, tokuhyosu_cols == FALSE]
# 3. delete very bottom row, the one that is the sum (goukei).
#    which rows have goukei in the name?
goukei_rows <- str_detect(df3$候補者名, "合計")
#    return rows that have goukei_rows as FALSE, i.e. return non-goukei rows
df4 <- df3[goukei_rows == FALSE, ]

# Now all we have left is to delete row 1 describing candidate's party, but
# before this, let's take row 2 and down and melt
df5 <- df4[2:5,]
df_melted <- melt(df5, id.vars = 1)

# Now add row for candidate party
df_melted <- df_melted %>% 
  mutate(party = NA)

# Get party information from df4, row1, and put it in new df `df_partyname`
df_partyname <- data_frame(
  # colnames of df4
  colnames = colnames(df4),
  # row1 of df4
  partyrow = as.vector(as.matrix(df4)[1,])
)

# This next step is the problem. Delete (mushozoku) from name cell, all good
df_partyname$partyrow[str_which(df_partyname$colnames, 
                                as.matrix(df_melted$variable)[5,1])]


# 00–05. Clean compiled df ------------------------------------------------
rm(list = ls())
load("df_smd_scrape_HOR48_exported20180530.RData")
