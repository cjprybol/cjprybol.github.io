layout: post  
title:  Using Overlaps to Assemble Sequences  
date:   2019-08-19  
author: Cameron Prybol  

---

If we want to use DNA to identify species and their relative quantities, we need to be be able to read the species genomes and count how many of each genome we find in each sample. Ideally, we would have the technology to read entire genomes from beginning to end without making any errors. While our technology is rapidly approaching this level of capability, we are not there yet.

Because we can't read genomes from beginning to end, we need to be able to take the short fragments that we can read and stitch them together into the original, full length genome. We do this by looking for sequences of DNA that are the same or nearly the same and join them together via the overlap. We'll ignore the possibility of errors for now.

To begin, we can import some helpful libraries for working with DNA sequences


```julia
using BioSequences
using BioAlignments
using Random
Random.seed!(3);
```

Let's simulate a genome of 10 DNA base-pairs


```julia
genome = randdnaseq(10)
```




    10nt DNA Sequence:
    TTTTAGAATG



Now, let's pretend that, with our best technology, we can only read DNA sequences 7 nucleotides at a time. And to keep the example super simple, we'll pretend we first read from the beginning to the 7th base, and from the 4rd base until the end. We're living in a very idealized world.


```julia
fragment_1 = genome[1:7]
```




    7nt DNA Sequence:
    TTTTAGA




```julia
fragment_2 = genome[4:end]
```




    7nt DNA Sequence:
    TAGAATG



We can see that these fragments overlap at the end of fragment_1 and the beginning of fragment_2 with the nucleotides 'TAGA'


```julia
pairalign(OverlapAlignment(), fragment_1, fragment_2, AffineGapScoreModel(match=1, mismatch=-1, gap_open=-1, gap_extend=-1))
```




    PairwiseAlignmentResult{Int64,BioSequence{DNAAlphabet{4}},BioSequence{DNAAlphabet{4}}}:
      score: 4
      seq: 1 TTTTAGA--- 7
                ||||   
      ref: 0 ---TAGAATG 7




If we are confident in the overlap, we can merge the two fragments into one via the overlap


```julia
fragment_1 * fragment_2[end-2:end] == genome
```




    true



This overly simplistic example shows the key idea of assembling shorter fragments into longer genomes. We look for overlaps that allow us to continue reading from one sequence of DNA into another sequence of DNA and stitch together the original full length DNA molecule.

The key question to decide with this approach is how long the overlaps between sequences need to be before we feel confident that the overlap isn't due to random chance.

If we are sequencing a single organism, the minimum length $l$ of an overlap that may be desired before being confident enough to merge overlapping fragments could be $l = log_4(\text{genome length})$. The idea is that if there are 4 nucleotides, A C G & T, then the combinatorial likelihood that two fragments of unrelated DNA overlap by chance is inversely proportional to $4^l$. If $4^l$ is greater than the length of the genome, then the fragments wouldn't be expected to be the same by chance.

So for example, if we have a genome of 1,000 DNA nucleotides and we don't expect long repeats, then the minimum DNA overlap length that we would want would be


```julia
genome_length = 1000
minimum_overlap = Int(ceil(log(4, genome_length)))
```




    5




```julia
println(4^minimum_overlap)
```

    1024



```julia
println(4^minimum_overlap > genome_length)
```

    true


If we are sequence a novel genome then we probably do not know how long the genome is. If we don't know how large the genome is then we can't estimate a minimum overlap based on the $l = log_4(\text{genome length})$ concept. Fortunately, well equipped research labs that routinely sequence and assemble genomes can use physical measures such as the mass of DNA obtained per cell, the genome copy number information from a [karyotype](https://en.wikipedia.org/wiki/Karyotype), and an estimate of the number of cells in a sample to get an accurate approximation of genome size before sequencing and genome assembly begins.

[Earth may have up to one trillion species](https://www.pnas.org/content/113/21/5970). If we are sequencing and trying to assemble genomes in mixed communities of organisms, then we would ideally have DNA segments long enough that they can be identified to a unique species and to a unique location in the genome of that species. If we assume an average genome size of 1Gb (one billion DNA basepairs) we would want overlaps of:


```julia
genome_size = 1_000_000_000
number_of_species = 1_000_000_000_000
minimum_overlap = Int(ceil(log(4, genome_size * number_of_species)))
```




    31



This length of 31 is routinely used for purposes of DNA assembly with high-accuracy Illumina reads of prokaryotic organisms and for identifying DNA reads to species using tools like [Kraken2](https://ccb.jhu.edu/software/kraken2/)

Now that we've reviewed our simplified and idealized hypothetical world of genome sequencing and assembly, let's talk about the two major problems that come up during the sequence assembly process:

1. Exact repeats within eukaryotic genomes can be several thousand DNA bases in length making a length of 31 insufficient to uniquely identify every segment of DNA in every organism. These long repeats necessitate the use of DNA reads that span the entire length of the repeats and include uniquely identifying sequences on both sides of the repeat.
2. No sequencing technology is error free. Illumina sequencing technology is often so accurate that errors can be readily corrected or simply removed and ignored from datasets without too much of an issue. This allows us to assemble sequences by finding exact overlaps between sequences, as shown in the example. Less accurate sequencing technologies that generate longer reads that allow us to span long repeat regions are not accurate enough to utilize exact overlaps in most cases, and therefor we need to utilize DNA alignment approaches that allow for and account for mismatches to find long stretches of approximate overlaps that we feel confident are so closely related that they are not overlapping due to random chance.
