---
layout: post  
title: Caenorhabditis elegans Kmer Distributions  
date: 2019-08-16  
author: Cameron Prybol  

---

- part 1: [Selecting Genomes by Taxonomy](/selecting-genomes-by-taxonomy.html)
- part 2: [Norwalk Virus Kmer Distributions](/norwalk-virus-kmer-distributions.html)
- part 3: [Chlamydia Phage Chp2 Kmer Distributions](/chlamydia-phage-chp2-kmer-distributions.html)
- part 4: [Flavobacterium psychrophilum Kmer Distributions](/flavobacterium-psychrophilum-kmer-distributions.html)
- part 5: [Saccharomyces cerevisiae Kmer Distributions](/saccharomyces-cerevisiae-kmer-distributions.html)
- part 6: [Arabidopsis thaliana Kmer Distributions](/arabidopsis-thaliana-kmer-distributions.html)

```bash
FASTA=GCF_000002985.6_WBcel235_genomic.fna
K_RANGE="7 11 13 17 19 23 29 31"
parallel Eisenia\ stream-kmers\ --k\ \{1\}\ --fasta\ $FASTA.gz\ \|\ LC_ALL=C\ sort\ --temporary-directory\ \.\ --compress-program\ gzip \|\ uniq\ --count\ \| gzip\ \>\ $FASTA.K\{1\}.counts.gz ::: $K_RANGE
parallel gzip\ --decompress\ --stdout\ $FASTA.K\{1\}.counts.gz\ \|\ awk\ \'\{print\ \$1\}\'\ \|\ LC_ALL=C\ sort\ --numeric\ \|\ uniq\ --count\ \>\ $FASTA.K\{1\}.counts.histogram ::: $K_RANGE
parallel Eisenia\ plot\ histogram\ --histogram\ $FASTA.K\{1\}.counts.histogram ::: $K_RANGE
mv $FASTA.K*.counts.histogram.svg ../../assets/images/
```

![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K7.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K11.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K13.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K17.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K19.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K23.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K29.counts.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K31.counts.histogram.svg)

With C. elegans we're not seeing the interesting 7-mer pattern seen in A. thaliana, and k >= 17 results in a stable kmer frequency/count relationship
