# These snippets are for reproducibility. I find it helpful to write things as if I'm explaining them to someone else.
# That way, when I come back to it, my comments make more sense (at least to me), and I can also share what I've done with collaborators.

# The purpose of this analysis was to find significantly different DGE amongst ST's/Clades of E. coli
# The input data was output from Degust. The original RNAseq data was from biological triplicates analysed using Kallisto
# [That part of the analysis is covered here](https://github.com/stevenjdunn/Odd-ends/blob/master/RNAseq_Analysis)
# My final file contained 4465 genes.

# This data was compiled with the ST/Clade information for each isolate to form our groups for the ANOVA
# For example:
# Isolate, Group, Gene1, Gene2, Gene3
# MG1665, ST10, 0.4, -0.4, -0.8
# F047, Clade A, 2, 1.4, 1.8

# I then used bash to create individual files containing the Group and Gene column on a per-gene basis.
# Due to the number of bash operations required, it'll be much faster to use parallel
# This executes one command per thread (specified with -j n)
for f in {3..4465}; do echo "cut -f 2,$f -d, DGE_NA.csv > $f.csv"; done > commands.txt
parallel -j 28 < commands.txt

# I matched the gene names to the sequential column numbers, and renamed the files according to gene name.
# Using excel with our example, I copied the gene names, transposed them, and then adding sequential numbers from 3:4465
# Example:
#Gene1, 3
#Gene2, 4
#Gene3, 5
# I created a command list by using =CONCATENATE to append ".csv" to the genes and numbers, and executed that in parallel. 
# Example:
head -n 1 cmds.txt 
mv 3.csv Gene1.csv
parallel -j 28 < cmds.txt

# Let's check a file to make sure it is what we're expecting:
cat Gene1
  Group, Gene1
  ST10, 0,4
  Clade A, 2rm

# We're now ready to move to R and perform the ANOVA + post-hoc tests.

# First, let's look at running one.
# Our first gene is called aaeA Load the csv:
setwd("whatever/you/want")
gene <- read.csv("path/to/aaeA.csv")

# Example
print(gene)
  Group        aaeA
  1    ST10 -0.04933475
  2   ST394 -0.26829336
  3  ST1122 -0.80656230
  4 Clade A -0.77029579
  5 Clade C -0.35539626
  6 Clade C  0.04575001
  7 Clade B  0.26781225
  8 Clade B  0.04189902
  9 Clade B -0.42783247

# Run the ANOVA
summary(aov(aaeA ~ Group, data=gene))
  Df Sum Sq Mean Sq F value Pr(>F)
  Group        5   0.80 0.16000   3.429   0.17
  Residuals    3   0.14 0.04666 

# Now we know what we're looking for in terms of output, we can write this as a loop.
# I've provided it as is for readability, and again as a commented section for explanation of each step
for(files in file.names){
  input <- files
  names <- gsub(".csv","_anova.txt", files)
  tag <- gsub(".csv","", files)
  df <- read.csv(input)
  sink(names)
  try(print(summary(aov(get(tag) ~ Group, data=df))))
  sink()}
  
# Path where our gene csvs are stored:
path = "/Users/Steven/Desktop/RNA_Stats/Iteration/RNA"
# Gather a list of all filenames for use in the loop:
file.names <- dir(path, pattern =".csv")

# Iterating through file list above.
for(files in file.names){
  # Loads first file as variable input
  input <- files
  # Creates neatly formatted output names:
  names <- gsub(".csv","_anova.txt", files)
  # Loads gene DGE data
  df <- read.csv(input)
  # Gene name variable for anova
  tag <- gsub(".csv","", files)
  # Allows us to capture std out to file
  sink(names)
  # Runs the ANOVA, specifies that we want output to stdout so we can redirect with sink.
  # As ANOVA will fail if there are N/A values, it'll spit out an error.
  # I use try() here to print the error and continue with the loop.
  # Any gene that produced an error will have an empty ANOVA output. 
  try(print(summary(aov(get(tag) ~ Group, data=df))))
  # Ends sink function and writes file.
  sink()}

# This created a list of gene_ANOVA.txt files in our working directory. 
# Now we can use bash to search for significant results.
grep "*" *.txt

# One of our genes that shows a significance is yqhC
cat yqhC_anova.txt
  Df Sum Sq Mean Sq F value  Pr(>F)
  Group        5 1.6782  0.3356   39.56 0.00612 **
  Residuals    3 0.0255  0.0085
  ---
  Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

# To find which groups are responsible for the significance, we need to run a post-hoc test
# I use TukeyHSD implemented in R base.
# Again, to run one would be as simple as:
gene <- read.csv("yqhC.csv")
aov <- aov(yqhC ~ Group, data=gene)
TukeyHSD(x=aov, 'Group', conf.level=0.95)

  diff        lwr         upr     p adj
  Clade B-Clade A  0.19778971 -0.4066406  0.80222004 0.5417983
  Clade C-Clade A  0.25469496 -0.3864002  0.89579014 0.4059999
  ST10-Clade A     1.30866845  0.5683955  2.04894139 0.0100625
  ST1122-Clade A  -0.32637293 -1.0666459  0.41390001 0.3385983
  ST394-Clade A   -0.15752755 -0.8978005  0.58274539 0.8140675
  Clade C-Clade B  0.05690525 -0.4209389  0.53474938 0.9731984
  ST10-Clade B     1.11087874  0.5064484  1.71530906 0.0089865
  ST1122-Clade B  -0.52416264 -1.1285930  0.08026768 0.0729617
  ST394-Clade B   -0.35531726 -0.9597476  0.24911307 0.1882030
  ST10-Clade C     1.05397349  0.4128783  1.69506866 0.0124146
  ST1122-Clade C  -0.58106789 -1.2221631  0.06002728 0.0649853
  ST394-Clade C   -0.41222251 -1.0533177  0.22887266 0.1532924
  ST1122-ST10     -1.63504138 -2.3753143 -0.89476844 0.0052258
  ST394-ST10      -1.46619600 -2.2064689 -0.72592306 0.0072191
  ST394-ST1122     0.16884538 -0.5714276  0.90911832 0.7778918

# This shows we have a significant difference between several groups, e.g. ST10 and Clade A.
# It's worth noting that the Tukey and ANOVA are independent measures. The Tukey test is naive to the input analysis type.
# This means you may not see a significant result from the tukey, despite having one via ANOVA.

# To get this working in a loop format is a little more complex.
# I can't find a way to load the output from anova back into R in a format readable by TukeyHSD.
# Instead, I'm going to create a new DGE list, only including genes with significant differences.

# To get a list of all genes with a stat. sig. difference, in bash:
grep "*" *.txt | cut -f1 -d: | sed 's/_anova.txt//g' | sort -u > genes.txt

# This returns 602 genes.
# I process the next bit in excel, using the COUNTIF formula to determine whether a given gene is in the list of significant genes.
# Briefly, I take the DGE_NA.csv file mentioned earlier, transpose it, create a new column, paste in the list of significant genes, and use the following formula:
=IF(COUNTIF($M$1:$M$941,A2)>0, "KEEP", "DELETE")
# I sort by our new keep/delete column, and remove anything listed as delete. This leaves the DGE values for our 602 genes.
# I transpose this back and save as DGE_sig.csv.

# I also take the significant gene list, append .csv to it with CONCATENATE, and then copy all sig genes to a new directory uniq.

# Now back to R, where we can iterate over our loop, but this time output the TukeyHSD results.
setwd("/Users/Steven/Desktop/RNA_Stats/Iteration/RNA/uniq")
path = "/Users/Steven/Desktop/RNA_Stats/Iteration/RNA/uniq"
file.names <- dir(path, pattern =".csv")

# Iterate through fasta list using mlplasmids and save files
for(files in file.names){
  input <- files
  names <- gsub(".csv","_anova.txt", files)
  tag <- gsub(".csv","", files)
  df <- read.csv(input)
  y <- aov(get(tag) ~ Group, data=df)
  sink(names)
  print(TukeyHSD(x=y, 'Group', conf.level=0.95))
  sink()}

# I want to remove all of the headers, leaving only the group information. I do this with tail:
for f in *_anova.txt; do echo "tail -n 17 $f > ${f/_anova/_filt}"; done > commands.txt
parallel -j 2 < commands.txt

# Note that I moved from a workstation to my laptop, so the maximum cores I have available dropped from 28 to 2 :(

# To make parsing easier, I also want to write the filename to the file itself. 
# I left in an extra line at the top of our data to replace. I'm going to append the filename with a > character for easy searching
# You can also use this oneliner for fasta files!
for i in *filt.txt; do perl -i -pe 's/.*/>$ARGV/ if $.==1' $i; done

# I need to replace the white space so we can parse with cut. 
# I also messed up by leaving a space in our group names. 
# Sure, no spaces is like rule 1 in bioinformatics, but I've been at this for 11 hours and I'm stupid.
# Let's use sed to replace the spades in 'Clade A/B' groups:
sed -i -e 's/Clade /Clade-/g' *.txt

# Now lets change those whitespaces for a tab.
for f in *filt*; do echo "tr -s ' ' < $f > ${f/filt/trimmed}"; done > commands.txt
parallel -j 2 < commands.txt

# Our results are now in an easily parsable format. For example, I can look at all of the P values listed with filenames by doing:
cut -f 1,5 -d ' ' *trimmed*

# I want to get a final data frame with column 1 as the group names, and each subsequent column representing a gene and the P-values for each group. 
# First, I need to filter the trimmed files to only include the gene name, and final column containing the P-values.
for f in *_trimmed.txt; do echo "cut -f 5 -d ' ' $f > ${f/_trimmed/_final}"; done > commands.txt
parallel -j 2 < commands.txt

cat zraP_final.txt
  >zraP_filt.txt
  0.9999997
  0.9993142
  0.1296095
  0.9181742
  0.2912156
  0.9990111
  0.0754983
  0.8699759
  0.1984198
  0.0771342
  0.9569820
  0.2664837
  0.0764317
  0.0327328
  0.5673864

# Now to undo some work I did earlier... and remove the > sign and _filt.txt from the files. 
# To make things a little easier I'll move the files to a new directory
mkdir final
mv *_final.txt final/
cd final
for f in *_final.txt; do echo "sed 's/>//g' $f | sed 's/_filt.txt//g' > ${f/_final/}"; done > commands.txt
parallel -j 2 < commands.txt
mkdir Tukey
mv *.txt Tukey
cd Tukey
mv *_final.txt ../
rm commands.txt

cat zraP.txt
  zraP
  0.9999997
  0.9993142
  0.1296095
  0.9181742
  0.2912156
  0.9990111
  0.0754983
  0.8699759
  0.1984198
  0.0771342
  0.9569820
  0.2664837
  0.0764317
  0.0327328
  0.5673864

# I also want to prepare a .csv containing the group interaction names.
# It was quicker for me just to copy this into a text file manually.

# Now back to R. The set up for this loop is largely similar to the previous ones.
# Set up variables
setwd("/Users/Steven/Desktop/RNA_Stats/Iteration/RNA/uniq/final/Tukey")
path = ("/Users/Steven/Desktop/RNA_Stats/Iteration/RNA/uniq/final/Tukey")
file.names <- dir(path, pattern =".txt")

# Load group names into output dataframe
df <- read.csv("/Users/Steven/Desktop/Groups.csv")

# Iterate through data and combine with output dataframe.
for(files in file.names){
  input <- files
  dv <- read.csv(input)
  df <- cbind(df, dv)}

# As mentioned before, you can get non-sig results from the Tukey despite having sig results via ANOVA.
# My dataset contains ~200 such instances, and so I want to filter our Tukey results to only include significantly different genes.
# Copy our dataframe and drop the groups column.
dft <- df[,-1]

# Get all columns with no values less than 0.05.
dfu <- dft[,apply(dft,2,function(x) all(x>=0.05))]

# Get the names of those columns
dropList <- colnames(dfu)

# Remove columns that don't have any value lower than 0.05.
dft2 <- dft[, !colnames(dft) %in% dropList]

# Now let's look at plotting the data. I want to create a heatmap, so first we need to transform the data using melt.
data.m <- melt(dft2)

# I want to bin the data according to whether values are significant or not. This will give a two colour scale on the heatmap.
data.m$bins <- cut(data.m$value, c(0.05, Inf),
                   labels=c("P<0.05"))
                   
# You can then plot it using something like the following:
p <- ggplot(data.m, aes(x=variable, y=Groups, fill=bins)) + geom_tile() +
  scale_fill_manual(values=c("#b2182b","#2166ac")) +
  theme_minimal() + theme(axis.text.x = element_text(angle = 90))
print(p)


# Due to the number of datapoints, it takes around a decade for my laptop to render the graph in R.
# If I want to make a slight change, that's another decade. Suddenly I'm 80, my retirement party is in 15 minutes and I'm still looking at a white screen in R-studio.
# Instead, I subset the dataframes into as-equal-as-possible chunks and load the data into Prism 7.
# I have 362 genes. I want the lowest common denominator. That's 4 dataframes that I need to subset and save:
df1 <- dft2[1:89]
df2 <- dft2[90:181]
df3 <- dft2[182:273]
df4 <- dft2[274:362]
write.csv(df1, file="~/Desktop/df1.csv", row.names=FALSE)
write.csv(df2, file="~/Desktop/df2.csv", row.names=FALSE)
write.csv(df3, file="~/Desktop/df3.csv", row.names=FALSE)
write.csv(df4, file="~/Desktop/df4.csv", row.names=FALSE)


# Then prep them for Prism.
# Prism has a lot of drawbacks to R, and a lot of useful stuff too. That works both ways. Typically, I like to use Prism for larger heatmaps.
# This provides fine-scale adjustments in real time, ease of formatting and sizing, and overall a quicker end result.
# [Here's a graph I made with Prism previously plotting the raw DGE data of FDR-significant genes.](https://github.com/stevenjdunn/Odd-ends/blob/master/Figures/DGE_fdr.pdf)

# To briefly go over how I generated the plot:
# I opened each csv in excel. Created a new prism project under grouped.
# Copied over the gene groups from df1, duplicated that sheet 6 times (df1-7)
# Copied over the genes + values to each respective sheet. 
# Set colour to categorical, with two categories (P>0.05 and P<0.05). Non sig in light grey. 
# Removed chart border, added cell borders in a very light grey 1.25pt
# Removed legend, transposed values.
# Set columns to titles, rotate 90. 
# Reduce font size, change font, set to mid grey.
# Set size ratio at 1:1. 
# Resize to A4. 

# Then I composite the graphs using Photoshop/Illustrator, and create a unified legend. 

# [Here's the end result for now.](https://github.com/stevenjdunn/Odd-ends/blob/master/Figures/Significant%20Groups%20copy.pdf) 
# This is still a rough copy - I need a way of combining this with the DGE values (earlier graph)
# Or perhaps neatening up the groups to make it more informative. 
# I might try graphing the DGE for the Tukey genes, and then drawing borders around isolates that belong to significantly different groups.

