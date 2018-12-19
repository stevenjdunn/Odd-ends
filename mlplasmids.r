# Ensure mlplasmids and its dependencies are installed.
# You'll also need the libxml2-dev package if on Ubuntu 16, and Bioconductor.
# In a new terminal session:
# apt-get install libxml2-dev
# In R:
# install.packages("BiocManager")
# BiocManager::install()
# BiocManager::install(c("Biostrings"))
# install.packages("devtools")
# devtools::install_git("https://gitlab.com/sirarredondo/mlplasmids")
# Check install exit status and test loading of mlplasmids.

# Load mlplasmids and set WD
library(mlplasmids)
setwd("/home/user/Desktop/my_wd")
# Gather list of fasta files present in specified path
path = "/home/user/Desktop/my_fasta_files"
file.names <- dir(path, pattern =".fasta")
# Iterate through fasta list using mlplasmids and save files
for(files in file.names){
  input <- files
  names <- gsub(".fasta",".csv", files)
  prediction <-plasmid_classification(path_input_file = input, species = 'Enterococcus faecium')
  write.csv(prediction, file=names, quote=FALSE)}
# NB files contain plasmid predictions only, to get information on chromosomal contigs add full_output=TRUE
