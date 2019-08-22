---
layout: post  
title: A Generalized Probabilistic Approach to Assembly  
date: 2019-08-22  
author: Cameron Prybol  

---

In [a previous post](the-two-approach-problem-in-assembly.html) I laid out the two approaches in sequence assembly. My goal here is to layout the logic for a general approach that could be superior in both situations.

The steps are as follows:
1. Sequence a DNA sample of interest
2. Create a De Bruijn assembly graph from the reads
3. Convert the De Bruijn graph into a probabilistic hidden markov model
4. Run each read through the hidden markov model, replacing the observed sequence with the most likely hidden state sequence using the [viterbi algorithm](https://en.wikipedia.org/wiki/Viterbi_algorithm), under the assumption this maximum likelihood sequence is the one that actually went through the sequencer
5. Repeat steps 2-4 until convergence
6. Increment k
7. Repeat 2-6 until convergence (in practice, I define this as 2 successive k increments yielding no changes)

And that's all there is for constructing the maximum likelihood assembly graph. No read aligning or graph cleaning heuristics, less time fretting over the optimal k parameter (use the minimal k with a monotonically decreasing FFP, I'll follow up on this in the future to see if I'm correct or not on this), and if there are any doubts about the accuracy of the final assembly, you can always sequence more and increase the probabilistic power of the approach.

The only tunable parameters in this approach are the optimal starting value of k, which can be inferred from the data, and the error rate, which can be measured empirically before the assembly process.

With the final assembly graph, the next steps are:
1. Partition the graph into it's connected components using existing graph theory approaches
2. Find the maximum flow path through each connected component, which presumably are individual chromosomes in individual genomes (or individual transcripts in individual transcriptomes, if the input is RNA)
3. Call all branches off of these maximum flow paths as variants to be reported in a VCF file (or alternate transcripts for RNA)
4. Use sample-by-sample coverage information to determine relative frequencies in each sample

And with that information I think you have the base information needed to perform just about any genomic analysis. I think co-assembly with a reference genome using this approach would be superior as a clinically-accurate variant-calling methodology compared to current read-mapping approaches as well, but that too is something that needs to be demonstrated.

Another way to look at this approach is that it is an iterative expectation maximization approach. The inputs are the reads, empirical error rates, and a rationally chosen initial k value and the output is the maximum likelihood sequence assembly graph and associated coverage and variation information. 

As an aside, I've always been turned off by the heuristics in traditional de Bruijn graph assemblers (that remove low frequency kmers within the graph and at the ends of the graph based on arbitrary criteria) and overlap-layout-consensus approaches (because sequence alignment is a heuristic given the arbitrary costs assigned to matches, mismatches, insertions, and deletions). With this approach, the probability model makes all of the graph cleaning and alignment decisions. If anyone has a problem with the results, they either need to take it up with mathematicians, statisticians, and information theory researchers who designed the algorithms or just keep sequencing until they become convinced themselves about the accuracy of the output.

The biggest weakness of this approach that I can foresee is that the Viterbi algorithm considers every possible state and can be impractically slow on problems with as many unique states as a de Bruijn graph. This is partially addressed by the incremental nature of the approach. We start with the smallest k-length appropriate to limit the number of erroneous kmers early. We then iteratively apply the Viterbi algorithm to correct those erroneous kmers to bound the search space early, before increasing k to fix errors that require more sequence context for the algorithm to correct. The other reason I'm not worried this approach is intractable is ubiquity of cheap compute and the availability of faster architecture like GPUs and FGPAs. At a certain point, we need to decide if we'd rather have the fast, good enough solution or the most correct solution. As faster, cheaper compute resources become more available, both heuristic and maximum likelihood approaches will become so rapid and affordable that I don't see how the heuristic-based approaches will still be reasonable to consider.
