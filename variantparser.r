# SNP Processing - Count occurances of mutation types on a gene by gene basis.
# Load requisite libraries
library(plyr)

# Single iteration:
# Load file and name columns
data <- read.table(file = '~/Danai/genes/gyrA.txt', sep = '\t', header = FALSE)
names(data) <- c('Count','Position','SNP','Ref','Alt','Type','NT','AA')

# Check for multialleleic positions
data.s <- data[order(data$Position),]
data.d <- data.s[duplicated(data.s$Position) | duplicated(data.s$Position, fromLast=TRUE),]

# Sum variant types
ddply(data, c("Type"), summarise, sum_values = sum(Count))

# Loop iteration
# Set working directory to folder containing output from allelefinder.sh
setwd('~/Danai/genes')

# Set path as variable
path = getwd()

# Fetch filenames of all .txt files.
file.names <- dir(path, pattern =".txt")

# Iterate through loop
for(files in file.names){
  input <- files
  names <- gsub(".txt","_summary.txt", files)
  dupes <- gsub(".txt","_dupes.txt", files)
  df <- read.table(file = input, sep = '\t', header = FALSE)
  names(data) <- c('Count','Position','SNP','Ref','Alt','Type','NT','AA')
  data.s <- data[order(data$Position),]
  data.d <- data.s[duplicated(data.s$Position) | duplicated(data.s$Position, fromLast=TRUE),]
  summary <- ddply(data, c("Type"), summarise, sum_values = sum(Count))
  write.csv(x = data.d, file = dupes, row.names = FALSE, quote=FALSE)
  write.csv(x = summary, file= names, row.names = FALSE, quote=FALSE)
}

# Outputs files with '_summary' and '_dupes' appended to filename with total types of variants observed, and multiallelic positions respectively.
