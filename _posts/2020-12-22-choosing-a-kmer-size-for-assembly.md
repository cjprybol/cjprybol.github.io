---
layout: post  
---

When performing kmer-based analyses, the choice of k is a critical.

When setting the lower k-limit, the key parameter that I'm interested in is the error rate.

If the accuracy of a sequencer is 90%, then we expect to see an error for every 1 in 10 bases.

While the actual error process is a [Poisson distribution](https://en.wikipedia.org/wiki/Poisson_distribution), if we assume the simplest possible scenario that errors are evenly spaced and thus a 90% accuracy guarantees that an error occurs every 10th base, we would expect that every intervening 9 base-pairs would be correct.

We can use these accurate 9mers as our kmers.

If we sequence deeply enough to ensure that we have high redundancy of sample coverage, we can use the count information of the kmers to infer which kmers are likely to be correct[^1] and which are likely to erroneous[^2]

[^1]: Those that appear most frequently
[^2]: Those that appear least frequently, potentially only once

If we know our sequencing platform is no better than random, and makes an error 50% of the time, then we would expect that every other, or every 2nd, observed base is a mistake.

Choosing a k-length of 1 would result in 50% of your data being reliable, whereas if we went with the next odd k-length of 3, it's possible that we wouldn't observe any instances of the true original sequence.

$$ \text{lower_bound_k} = 1/\text{error rate} - 1 $$

$$ (\text{lower_bound_k} + 1) * \text{error rate} = 1 $$

$$ \text{error rate} = 1/(\text{lower_bound_k} + 1) $$


```julia
import Primes
for lower_bound_k in Primes.primes(3, 101)
    error_rate = round(1/(lower_bound_k + 1), digits=2)
    println("k: " * rpad("$(lower_bound_k)", 3) * lpad("error_rate = $(error_rate)", 20))
end
```

    k: 3     error_rate = 0.25
    k: 5     error_rate = 0.17
    k: 7     error_rate = 0.12
    k: 11    error_rate = 0.08
    k: 13    error_rate = 0.07
    k: 17    error_rate = 0.06
    k: 19    error_rate = 0.05
    k: 23    error_rate = 0.04
    k: 29    error_rate = 0.03
    k: 31    error_rate = 0.03
    k: 37    error_rate = 0.03
    k: 41    error_rate = 0.02
    k: 43    error_rate = 0.02
    k: 47    error_rate = 0.02
    k: 53    error_rate = 0.02
    k: 59    error_rate = 0.02
    k: 61    error_rate = 0.02
    k: 67    error_rate = 0.01
    k: 71    error_rate = 0.01
    k: 73    error_rate = 0.01
    k: 79    error_rate = 0.01
    k: 83    error_rate = 0.01
    k: 89    error_rate = 0.01
    k: 97    error_rate = 0.01
    k: 101   error_rate = 0.01


In order to determine a suitable upper limit for k, let's work under these assumptions:
1. Every species has a genome equal in size to the largest currently known genome
    - 150-680 gigabases [^3]
1. We accept that there are as many species as whatever the largest estimate in the literature exists
    - 1 trillion species [^4]
   
    
[^3]: https://blogs.biomedcentral.com/on-biology/2014/03/20/worlds-largest-sequenced-genome-unlocking-the-loblolly-pine/
[^4]: https://www.pnas.org/content/113/21/5970


```julia
largest_known_genome = 680_000_000_000
```




    680000000000




```julia
# round up to the next power
largest_known_genome = nextpow(10, largest_known_genome)
```




    1000000000000




```julia
highest_diversity_estimate = 1_000_000_000_000
```




    1000000000000




```julia
unique_base_potential = 
    BigInt(largest_known_genome) * 
    BigInt(highest_diversity_estimate)
```




    1000000000000000000000000



If our sequences have 4 unique bases that can occur anywhere in the genome, we can take a logarithm to the 4th power to estimate what k-length we would need to never have a kmer repeat if the genome did not have repetitive elements.


```julia
round(log(4, unique_base_potential))
```




    40.0



According to these worst case estimates (that don't account for genomic repeats), $$k > 40$$ should be have sufficient precision to identify sub-sequences unique to each organism

Let's assume that most of our working conditions will not be that worst-case scenario, and use a kmer of length 31.

kmers of length 31 are still precise enough to cover a very large number of very large genomes


```julia
4^31
```




    4611686018427387904



Using kmers of length 31 also coincides nicely with the fact that if we encode kmers as vectors of 2 bits, where the 2 bits can represent:
- `00 => A`
- `01 => C`
- `10 => G`
- `11 => T`

and as such we can chain up to 32 set of 2 bits into an unsigned 64 bit integer.

The 64 bit integer coincides nicely with the current 64bit CPU architecture that works with 64 bit integers as the native datatype

If we take these two pieces together:
1. the lower bound
    - depends on accuracy of the sequencing instrument
2. upper uniqueness bound
    - depends on the total genetic diversity in our global pool of consideration
    
Then we arrive at a lower k-length baseline that we can use to begin iterative rounds of correction and k-extension until we reach our upper bound of k=31. BioSequences also provides `BigMer`s based on UInt128 that can handle kmers up to 63bp.

After reaching our upper bound, it is likely that we can resolve the remaining structure of the graph by tracing long-read data through the graph. I'll explain the read threading as a path disambiguation strategy in a future post
