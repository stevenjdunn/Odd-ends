# Basecalling with Guppy

Perhaps it's just me, but I found it really awkward to get Guppy to work optimally with my non-recommended CUDA GPU. I have a Quadro P600. It feeds my display with minimal power draw, and was mostly ignored before Guppy arrived. 

## Invoking Guppy

Here's the command I use for our P600:

`guppy_basecaller --flowcell FLO-MIN106 --kit SQK-LSK109 --barcode_kits "EXP-NBD104 EXP-NBD114" --input_path data --recursive --save_path data_basecalls -x auto --chunks_per_runner 500 --num_callers 2 --gpu_runners_per_device 1`

### Flags
Flags are defined by `--` and hand user definable options to guppy_basecaller. Here's a runthrough of all flags used in the command above. Product SKUs can be found on the ONT packaging, or on their store. 

 * --flowcell
   * The SKU of your flowcell.
 * --kit
 The SKU of your library prep kit.
 *--barcode_kits
   * Enables within-workflow demultiplexing of a barcoded library. If using more than 1 kit, you will need to space separate the SKUs within speech marks.
 * --input_path
   * The path to the raw signal data, transferred from your sequencing platform. 
 * --recursive
   * Searches all subdirectories for fast5 files. 
 * --save_path
   * Where you want your basecalled data to go.
 * -x
   * Automatically chooses the basecalling device, can be manually specified. Note the single dash.  
 * --chunks_per_runner
   * The number of chunks handed to the basecaller queue
 * --num_callers
   * The number of active basecalling processes per *batch*
 * --gpu_runners_per_device
   * The number of basecalling *batches*

Note that the `--num_callers` and `--gpu_runners_per_device` are linked and will multiply. For example, `--num_callers 4` and `--gpu_runners_per_device 2` would use 8 threads. It would also increase the required VRAM as more chunks are allocated at a given time.

### Guppy optimised GPUs

There are four cards that are recommended for use with Guppy, they are listed below with their current retail price on Amazon (15/7/19), and the number of CUDA cores.

* NVIDIA Tesla V100
  * £7,400
  * 5120

* NVIDIA GTX 1080
  * £425
  * 2560

* NVIDIA GTX 1080Ti
  * £1020
  * 3284

* NVIDIA Jetson TX2
  * £700
  * 256

The Tesla is a datacentre class GPU. The GridION has one built in, and the PromethION has FOUR! It's not really worth it as a standalone card unless you have other workflows that rely heavily on CUDA, or a particularly beefy grant budget and a burning desire for speed. The Jetson is the platform the MinIT and presumably the MK1c will be built on - I expect they will heavily optimise their basecaller for use with this platform, but it's not really something you can just stick in a workstation. The 10XX series of cards is the previous generation of gaming cards, and availability is problematic. Poor manufacturing yield, and the cryptomining rush had previously made these cards notoriously expensive, and scarce. 

The guppy GPU market is not really consumer friendly at the moment, so personally I wouldn't think about it too much.  If you have a purchasing system that would allow you to buy a used 1080, then that's probably the sweet spot, it not then a new 1050Ti comes recommended on the community portal. Most CUDA 6.0+ enabled GPUs can be used with guppy_basecaller, provided there are suitable drivers for your operating system. When speccing a new workstation, go for the latest generation of compatible cards with the best ratio of CUDA cores/VRAM/Price, or check out the community for recommendations.

Our workstation came with a Quadro P600 by default, costing a mere ~£160, with 384 CUDA cores. It's slow (~4Gb per day with HAC model, aka ~5-6 days per flowcell...). But it's a lot faster than CPU basecalling across our very expensive Xeon W2175's 28 cores (too slow to count).

Using your CUDA GPU with guppy will require some parameter titration - hand your GPU too many chunks across too many callers and you'll get a CUDA memory error. Hand it too little, and you'll have sub-optimal basecalling speed. Let's take a look at what you want to tweak.

## Basecalling performance
#### Chunks per runner
To optimise the command for your 'best' available basecalling speed, you first need to figure out the maximum `--chunks_per_runner` that your VRAM will allow. Our card has 2GB for comparison.

It's a bit hacky, but I did this by repeatedly changing the parameter until I no longer got a CUDA memory error. I'm sure there's probably a way to calculate which value to use, but this took <5 minutes. I haven't found clear documentation on figuring out the number after 30 minutes+ of reading. The max number I could squeeze is 620. 625 pushed quite far, but received an out of memory error around 60%. Oddly, there isn't much difference between 620, and 500, though the latter is faster. 200 is far slower. 

* --num_callers 2 --chunks_per_runner 620
  * samples/s: 321321  

* --num_callers 2 --chunks_per_runner 500
  * samples/s: 321482  

* --num_callers 2 --chunks_per_runner 200
  * samples/s: 283946

#### GPU runners per device
Let's test whether we can allocate a greater number of gpu_runners_per_device with any success. This will require lowering of the `--chunks_per_runner` because the total VRAM usage is a function of chunk_size, chunks_per_runner and gpu_runners_per_device. 

The total number chunks_per_runner will effectively be chunks_per_runner * gpu_runners_per_device, shown in brackets below.   

 * --num_callers  1 --gpu_runners_per_device 2 --chunk_size 300 (600)
   * samples/s: 293662  

 * --num_callers  1 --gpu_runners_per_device 2 --chunk_size 250 (500)
   * samples/s: 320813  

 * --num_callers  1 --gpu_runners_per_device 2 --chunk_size 100 (200)
   * samples/s: 279243

Playing around with this option is worse for my memory poor card, but only just. I have a feeling that more powerful cards (in terms of GPU clock rate and num. CUDA cores) would benefit from playing around with this, but I don't have access to a card for testing.

#### Number of callers

Now let's show the optimisisation for the `--num_callers`. We'll keep the `--chunks_per_runner` at 500, and `--gpu_runners_per_device` at 1. From my testing, it seems changing the num_callers is purely GPU limited, i.e. more powerful GPUs (with more CUDA cores) will perform better. 

 * --num_callers 1
   * samples/s: 318278
 * --num_callers 2
   * samples/s: 321482
 * --num_callers 3
   * samples/s: 319214
 * --num_callers 4
   * samples/s: 318201

2 callers is best for my card. Again, I think this will vary card to card depending on GPU clock and # CUDA cores. 

## Final Thoughts
I think everyone's best config option will be completely different, so it's important to play around with these variables to identify your optimal set up. 

Ideally, ONT would release a calibration tool that runs through the various options, catching CUDA errors, and spiting out a set of variables that's best tuned to your card. It wouldn't be too difficult at all, and take all of this leg work out of it for the end user. 
