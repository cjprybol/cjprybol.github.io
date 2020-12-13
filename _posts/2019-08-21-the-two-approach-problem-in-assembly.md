layout: post  
title: The Two Approach Problem in Assembly  
date: 2019-08-21  
author: Cameron Prybol  

---

When trying to read DNA there are two fundamental problems. The first is reading DNA sequences from beginning to end without any breaks in the sequence. The second is ensuring the unbroken segments of DNA are read without error. Collectively, these two problems are sufficiently complex to support an entire domain of sequence assembly research and development.

When sequencing DNA, our goal is to sequence the DNA contiguously, accurately, and efficiently. However, our current DNA sequencing technologies allow us to achieve two of these three goals at a time. The earliest form of DNA sequencing, known as [Sanger sequencing](https://en.wikipedia.org/wiki/Sanger_sequencing), is very accurate and can sequence DNA in relatively long stretches up to thousands of base-pairs, however it is low throughput and can be expensive at scale. The next major breakthrough in DNA sequencing, [Illumina sequencing](https://en.wikipedia.org/wiki/Illumina_dye_sequencing), allows for very accurate and high throughput sequencing but cannot read more than a few hundred bases at a time. Newer forms of sequencing, such as [nanopore sequencing](https://en.wikipedia.org/wiki/Nanopore_sequencing), are able to read very long stretches of DNA and with high throughput, however they can be 1 to 2 orders of magnitude less accurate then either Sanger or Illumina sequencing.

The predominant methodology of DNA sequence assembly used for Sanger and Illumina sequencing utilizes [De Bruijn graphs](https://en.wikipedia.org/wiki/De_Bruijn_graph). Some relevant links:
- [Ben Langmead's notes](https://www.cs.jhu.edu/~langmea/resources/lecture_notes/assembly_dbg.pdf)
- [Velvet Assembler](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2336801/)
- [Velvet Wikipedia page](https://en.wikipedia.org/wiki/Velvet_assembler)
- [Pevzner's Euler Paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC55524/)
- [How to apply de Bruijn graphs to genome assembly](https://sci-hub.tw/10.1038/nbt.2023)
- [Stanford Course Notes](https://data-science-sequencing.github.io/Win2018/lectures/lecture7/)
- [My favorite genome assembly paper, Medvedev & Brudno 2009](https://www.ncbi.nlm.nih.gov/pubmed/19645596)
- [Colored De Bruijn Graphs](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3272472/)
- [Extensive tutorial @ homolog.us](https://homolog.us/Tutorials/book4/p1.1.html)

Techniques developed for the newer, longer, lower accuracy reads generally utilize an overlap-layout-consensus type approach. Some relevant links:
- [Ben Langmead's notes](https://www.cs.jhu.edu/~langmea/resources/lecture_notes/assembly_olc.pdf)
- [Flye](https://sci-hub.tw/https://www.nature.com/articles/s41587-019-0072-8)
- [Canu](https://genome.cshlp.org/content/27/5/722)
- [Ra](https://github.com/lbcb-sci/ra)

Without getting into too much detail but how either of these approaches work and differ in how they utilize overlapping stretches of DNA (follow the above links to learn more), De Bruijn graph assembly requires highly accurate reads, restricting applicability to the shorter Illumina data which (generally) lack the long-range sequence information necessary to properly resolve repetitive regions, whereas the overlap-layout-consensus approach can tolerate the higher error rates of long-read sequencing technology which enables resolving repetitive regions to achieve accurate long-range structure but can result in lots of minor errors that have a big impact on important details like gene prediction. See some great articles by Mick Watson on this issue:
- [Mind the gaps – ignoring errors in long read assemblies critically affects protein prediction](https://www.biorxiv.org/content/10.1101/285049v1)
- [A simple test for uncorrected insertions and deletions (indels) in bacterial genomes](http://www.opiniomics.org/a-simple-test-for-uncorrected-insertions-and-deletions-indels-in-bacterial-genomes/)
- [On stuck records and indel errors; or “stop publishing bad genomes”](http://www.opiniomics.org/on-stuck-records-and-indel-errors-or-stop-publishing-bad-genomes/).

Some links discussing the head-to-head comparisons of the two approaches in more detail:
- [wikipedia page on assemblers](https://en.wikipedia.org/wiki/De_novo_sequence_assemblers)
- [Comparison of the two major classes of assembly algorithms: overlap–layout–consensus and de-bruijn-graph](https://academic.oup.com/bfg/article/11/1/25/191455)

Papers on the theoretical goals of assembly:
- [Optimal Assembly for High Throughput Shotgun Sequencing](https://arxiv.org/pdf/1301.0068.pdf)
- [Do Read Errors Matter for Genome Assembly?](https://arxiv.org/abs/1301.0068)

Depending on context, the relative strengths and weaknesses of these approaches may make one significantly more preferable to the other. For example, when trying to assemble a genome from scratch, long reads with higher error rates tend to produce more complete drafts that can be improved with statistical approaches and the addition of higher-accuracy short-reads (sometimes called "polishing"). In the context of clinical medicine, we often care much more about the accuracy of our genome assembly within protein coding genes, and specifically genetic variations in protein coding genes that may impair the gene function and cause disease. Therefor, we are willing to forgo the long-range information necessary to span repetitive, non-protein coding regions of the genome in exchange for very accurate results in these protein coding regions of interest.

Ideally, we could have a generalized, probabilistic approach to generating accurate and contiguous DNA sequence assemblies that works with any input sequencing technology (although my strong bias is towards nanopore sequencing as the most promising technology going forward). By utilizing modern hi-throughput sequencing technologies that retain long-range sequence information and time-tested information theory approaches that allow us to find the signal in the noise, we can produce genomes with both long-range continuity and clinical accuracy. More on this in future posts.
