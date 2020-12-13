layout: post  
title: Caenorhabditis elegans Kmer Distributions  
date: 2019-09-10  
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
K_RANGE="3 5 7 11 13 17 19 23 29 31"
parallel jellyfish\ count\ --disk --canonical\ --mer-len\ \{\}\ --threads\ 1\ --size\ 100M\ --output\ $FASTA.K\{\}.jf\ \<\(gzip\ -dc\ $FASTA.gz\) ::: $K_RANGE
parallel jellyfish\ histo\ --high\ \$\(jellyfish\ dump\ $FASTA.K\{\}.jf\ \|\ grep\ \"\^\>\"\ \|\ sed\ \'s/\>//\'\ \|\ awk\ \'BEGIN\{max\=0\}\;\{if\(\$1\>max\)\ max\=\$1\}\;END\{print\ max\}\'\)\ $FASTA.K\{\}.jf\ \>\ $FASTA.K\{1\}.jf.histogram ::: $K_RANGE
parallel Eisenia\ plot\ histogram\ --histogram\ $FASTA.K\{1\}.jf.histogram ::: $K_RANGE
mv $FASTA.K*.jf.histogram.svg ../../assets/images/
```

![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K3.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K5.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K7.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K11.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K13.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K17.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K19.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K23.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K29.jf.histogram.svg)
![](../assets/images/GCF_000002985.6_WBcel235_genomic.fna.K31.jf.histogram.svg)

With C. elegans k >= 13 results in a stable kmer frequency/count relationship
