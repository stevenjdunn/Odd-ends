# tl;dr 
Full details below, commands:

`guppy_basecaller --flowcell FLO-MIN106 --kit SQK-LSK109 --recursive -x auto --barcode_kits "EXP-NBD104 EXP-NBD114" --input_path test --save_path test_basecalls --chunk_size 1000 --chunks_per_runner 500 --num_callers 2 --gpu_runners_per_device 1`

`NanoStat --summary sequencing_summary.txt > run_stats.txt`

`for f in barcode*/; do echo "cat $f*.fastq > ${f/\//.fastq}"; done > commands.txt`

`parallel -j 14 < commands.txt`

`for f in barcode*.fastq; do mv $f ${f/barcode/NB}; done`

`for f in NB*.fastq; do echo NanoPlot --fastq $f -t 4 -o ${f/.fastq/_plots}; done > commands.txt`

`parallel -j 7 < commands.txt`

`for f in NB*.fastq; do echo porechop -i $f -b ${f/.fastq/} -t 2; done > commands.txt`





# MinION read processing
Due to the limitations of our hardware, we sequence without live basecalling. With live basecalling enabled, the run finishes and basecalling would continue for several days afterwards. 

The first step is to transfer the raw signal data to a server capable of basecalling. This would ideally include a CUDA enabled NVidia GPU, and preferably one of the cards optimised for the guppy_basecaller workflow.

We sequence on a Windows based system, so we use WinSCP to transfer the entire data output directory (configured when starting your sequencing run) to our workstation. 
The default data directory on windows is:

`~/data`

On Ubuntu/MacOS, you can use the native SCP:

`scp -r ~/data/ user@server.ip.adress.here:/home/user/path/to/directory`

### Basecalling
Next, we call guppy_basecaller. There's a whole section on Guppy below, it took me a fair chunk of time to get it optimised for our system. For now, here's the command I use to basecall a standard ligation prep with 14 barcodes:

`guppy_basecaller --flowcell FLO-MIN106 --kit SQK-LSK109 --recursive -x auto --barcode_kits "EXP-NBD104 EXP-NBD114" --input_path test --save_path test_basecalls --chunk_size 1000 --chunks_per_runner 500 --num_callers 1 --gpu_runners_per_device 1`


### Summary Statistics
After that's finished, you can get a quick overview of the run metrics using Wouter De Coster's excellent Nano suite, starting with NanoStat. This gives you an overview of yield, stats on the read length and quality distributions, and a list of the longest reads.

`NanoStat --summary sequencing_summary.txt > run_stats.txt`

### Read Concatenation
By default, Guppy creates several output fastq files (4000 reads per file). I leave it as default because I've had issues with restarting the basecaller in the case of a powerloss when configured to write to a single fastq file. This means I have to concatenate these separate files into one. I use a for loop to generate a list of commands, and then GNU parallel to quickly execute them. Cat will use a single thread per command, so the number you pass to -j will depend on the number of threads you have available.

`for f in barcode*/; do echo "cat $f*.fastq > ${f/\//.fastq}"; done > commands.txt
parallel -j 14 < commands.txt`

### File Renaming
I then rename the files to neaten them up, and make tab-completing in terminal a little friendlier:

`for f in barcode*.fastq; do mv $f ${f/barcode/NB}; done`

### Sample QC
To get an idea of performance on a per-sample basis, I use Nano's NanoPlot. I have 28 cores, I allocate 4 cores per NanoPlot job, and execute using 7 iterations of parallel.  

`for f in NB*.fastq; do echo NanoPlot --fastq $f -t 4 -o ${f/.fastq/_plots}; done > commands.txt
parallel -j 7 < commands.txt`

If I have samples with huge coverage, I use these plots to inform filter parameters. If you normalised according to concentration, often higher coverage samples have a greater number of short reads, which would have caused an increased molality of DNA in the input library and thus impacted normalisation. Using NanoPlot, stuff like this sticks out, and it's a nice, quick way of getting a feel for your data.

### Consensus Demultiplexing & Adapter Trimming
To confirm the barcodes assigned by Guppy, and to trim adaptor sequences, I use Ryan Wick's Porechop. It's worth noting that this is no longer in development, so newer barcodes are not included by default. You can actually hack it a bit to get faster run times by including only the kits you are using, and add custom/newer barcodes, but that's beyond the scope of this for now. Again I use parallel to speed this up.

`for f in NB*.fastq; do echo porechop -i $f -b ${f/.fastq/} -t 2; done > commands.txt
parallel -j 14 < commands.txt`

Porechop creates subdirectories (NBXX/) with fastq's sorted by detected barcode. Porechop's output changes the NB prefix to BC. I like this, because it's obvious moving forward in my file structure which data is the raw basecalled data (barcodeXX), which is concatenated (NBXX) and which is adapter trimmed (BCXX). You will have many files, hopefully with the largest, and majority file size relating to the input barcode (i.e. in NB01, BC01 is the largest file). Also by doing things this way, you get a consensus barcode call between Guppy, and Porechop, increasing the confidence in correct barcode binning.

### Filtering
Based on the output of NanoPlot, you may wish to trim your files. I'd recommend NanoFilt, or FiltLong. To trim bases below 2000 bp for example:

`filtong --min_length 2000 BC01.fastq | gzip > BC01_trimmed.fastq.gz`

### Assembly
For an overview of assembly methods, check out Ryan Wick's comparison. I use Uniycler to produce hybrid assemblies from ONT and Illumina data, or Flye+Racon on MinION only data. 

Again with Unicycler it's wise to use Parallel. Whilst some steps are highly scalable with the number of threads, some of the longest steps (e.g. loading large read sets) are single threaded. I tend to allocate 6 threads per assembly, but it will largely depend on your socket's performance and available RAM.

Example assembly:

`unicycler -l BC01_trimmed.fastq.gz -1 BC01_Illumina_R1.fastq.gz -2 BC01_Illumina_R2.fastq.gz -t 6 -o BC01_assembly`
