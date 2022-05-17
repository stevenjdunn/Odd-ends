#### Oneliners to accomplish micellananeous tasks #####

# Query gene ontology (GO) database with list of GO-terms
# GO terms assigned to annotation using eggnog mapper
# Unique GO terms extracted from output and stored to file "go_uniq.csv"
# Loop looks for GO term ID, returns an additional line which encodes function, and encodes it next to the ID for parsing
# go.obo can be downloaded here: http://purl.obolibrary.org/obo/go.obo
# Note that the database needs to be preprocessed to prevent spurious matches to alt_ids:
# grep -v 'alt_id:' go.obo > go.obo2
while read -r line; do grep -m1 --after-context 1 'id: '$line go.obo2 | sed 'N;s/\nname:/,/g' ; done < go_uniq.csv > go_terms_resolved.csv

# Shovill assembly loop
# Assumes directory containing forward and reverse reads that encode sample ID
for f in *_1.fastq.gz; do shovill --trim --outdir ${f%_1.fastq.gz} --R1 $f --R2 ${f/_1.fastq.gz/_2.fastq.gz}; done

# File copying from subdirectories
# Example shown is .gff, e.g. collecting annotationsfollowing prokka annotation
for f in */; do echo cp “${f}${f//\//.gff}” . ; done

# Replace first line of a fasta file with the filename
for i in *.fasta; do perl -i -pe 's/.*/>$ARGV/ if $.==1' $i; done
sed -i 's/.fasta//' *.fasta
