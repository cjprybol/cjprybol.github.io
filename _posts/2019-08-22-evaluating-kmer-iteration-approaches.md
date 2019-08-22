---
layout: post  
title: Evaluating Kmer Iteration Approaches  
date: 2019-08-22  
author: Cameron Prybol  

---

A kmer is a k-length subsequence of DNA (or RNA). Kmers are ubiquitously useful in genomics and assembly in particular. Checkout the [wikipedia page](https://en.wikipedia.org/wiki/K-mer) and [this amazing post](https://bioinfologics.github.io/post/2018/09/17/k-mer-counting-part-i-introduction/) for more details and use cases.

I like to work with unix command line tools. There are many kmer counters out there ([Jellyfish](https://github.com/gmarcais/Jellyfish) and [KMC](https://github.com/refresh-bio/KMC) are the first two that come to mind), but require pre-existing knowledge about how many kmers are expected (when setting up hash tables) or complex setups. Wouldn't it be great if we could just dump all kmers to STDOUT and then use unix tools to sort and count the kmers? I think so too.

There are three approaches for iterating over kmers using the [BioSequences](https://github.com/BioJulia/BioSequences.jl) package in Julia that jumped out to me. The first, most naive solution would be to take a k-length slice from the sequence. The second is to take a k-length view of the sequence, which avoids creating a copy and should be more efficient than the slice. The third is to use the Kmer iterators in the BioJulia package.

Kmers can be useful in both their observed and canonical (alphabetically first orientation) forms, so we'll evaluate both to see if different approaches are faster for different orientations.

For the benchmarking, we'll be comparing the speed of prime k-lengths between 7 and 31, using both as-observed and canonical orientations. Note that all forms are written to /dev/null to simulate writing to STDOUT for piping to other unix commands.


```julia
using BioSequences
using BenchmarkTools
using Random

function kmer_slice(sequence, k)
    for i in 1:length(sequence)-k+1
        println(devnull, sequence[i:i+k-1])
    end
end

function kmer_view(sequence, k)
    for i in 1:length(sequence)-k+1
        println(devnull, view(sequence, i:i+k-1))
    end
end

function kmer_iteration(sequence, k)
    for (index, kmer) in each(DNAMer{k}, sequence)
        println(devnull, kmer)
    end
end

function canonical_kmer_slice(sequence, k)
    for i in 1:length(sequence)-k+1
        seq = sequence[i:i+k-1]
        rc_seq = reverse_complement(seq)
        if seq < rc_seq
            println(devnull, seq)
        else
            println(devnull, rc_seq)
        end
    end
end

function canonical_kmer_view(sequence, k)
    for i in 1:length(sequence)-k+1
        seq = view(sequence, i:i+k-1)
        rc_seq = reverse_complement(seq)
        if seq < rc_seq
            println(devnull, seq)
        else
            println(devnull, rc_seq)
        end
    end
end

function canonical_kmer_iteration(sequence, k)
    for (index, kmer) in each(DNAMer{k}, sequence)
        println(devnull, canonical(kmer))
    end
end

Random.seed!(3);
```


```julia
seq = randdnaseq(100)
for k in (7, 11, 13, 17, 19, 23, 29, 31)
    @show k
    @btime kmer_slice(seq, $k)
    @btime kmer_view(seq, $k)
    @btime kmer_iteration(seq, $k)
    @btime canonical_kmer_slice(seq, $k)
    @btime canonical_kmer_view(seq, $k)
    @btime canonical_kmer_iteration(seq, $k)
end
```

    k = 7
      9.304 μs (188 allocations: 7.34 KiB)
      9.475 μs (188 allocations: 7.34 KiB)
      64.823 μs (847 allocations: 27.94 KiB)
      20.377 μs (376 allocations: 20.56 KiB)
      23.517 μs (376 allocations: 20.56 KiB)
      78.327 μs (941 allocations: 29.41 KiB)
    k = 11
      10.295 μs (180 allocations: 7.03 KiB)
      10.421 μs (180 allocations: 7.03 KiB)
      67.974 μs (811 allocations: 26.75 KiB)
      21.710 μs (360 allocations: 19.69 KiB)
      20.999 μs (360 allocations: 19.69 KiB)
      69.784 μs (901 allocations: 28.16 KiB)
    k = 13
      10.307 μs (176 allocations: 6.88 KiB)
      10.880 μs (176 allocations: 6.88 KiB)
      64.383 μs (793 allocations: 26.16 KiB)
      21.985 μs (352 allocations: 19.25 KiB)
      22.123 μs (352 allocations: 19.25 KiB)
      70.945 μs (881 allocations: 27.53 KiB)
    k = 17
      12.013 μs (168 allocations: 6.56 KiB)
      11.650 μs (168 allocations: 6.56 KiB)
      65.936 μs (757 allocations: 24.97 KiB)
      21.273 μs (336 allocations: 18.38 KiB)
      22.414 μs (336 allocations: 18.38 KiB)
      68.220 μs (841 allocations: 26.28 KiB)
    k = 19
      12.964 μs (164 allocations: 6.41 KiB)
      12.513 μs (164 allocations: 6.41 KiB)
      62.490 μs (739 allocations: 24.38 KiB)
      23.177 μs (328 allocations: 17.94 KiB)
      23.459 μs (328 allocations: 17.94 KiB)
      66.422 μs (821 allocations: 25.66 KiB)
    k = 23
      12.449 μs (156 allocations: 6.09 KiB)
      12.589 μs (156 allocations: 6.09 KiB)
      66.175 μs (703 allocations: 23.19 KiB)
      23.607 μs (312 allocations: 17.06 KiB)
      23.881 μs (312 allocations: 17.06 KiB)
      66.400 μs (781 allocations: 24.41 KiB)
    k = 29
      13.707 μs (144 allocations: 5.63 KiB)
      14.428 μs (144 allocations: 5.63 KiB)
      59.746 μs (649 allocations: 21.41 KiB)
      22.295 μs (288 allocations: 15.75 KiB)
      23.558 μs (288 allocations: 15.75 KiB)
      62.913 μs (721 allocations: 22.53 KiB)
    k = 31
      13.306 μs (140 allocations: 5.47 KiB)
      14.003 μs (140 allocations: 5.47 KiB)
      63.354 μs (631 allocations: 20.81 KiB)
      24.079 μs (280 allocations: 15.31 KiB)
      24.374 μs (280 allocations: 15.31 KiB)
      68.099 μs (701 allocations: 21.91 KiB)



```julia
seq = randdnaseq(1_000)
for k in (7, 11, 13, 17, 19, 23, 29, 31)
    @show k
    @btime kmer_slice(seq, $k)
    @btime kmer_view(seq, $k)
    @btime kmer_iteration(seq, $k)
    @btime canonical_kmer_slice(seq, $k)
    @btime canonical_kmer_view(seq, $k)
    @btime canonical_kmer_iteration(seq, $k)
end
```

    k = 7
      107.194 μs (1988 allocations: 77.66 KiB)
      114.112 μs (1988 allocations: 77.66 KiB)
      831.594 μs (8947 allocations: 295.13 KiB)
      255.508 μs (3976 allocations: 217.44 KiB)
      270.847 μs (3976 allocations: 217.44 KiB)
      911.427 μs (9941 allocations: 310.66 KiB)
    k = 11
      135.098 μs (1980 allocations: 77.34 KiB)
      144.551 μs (1980 allocations: 77.34 KiB)
      1.002 ms (8911 allocations: 293.94 KiB)
      300.446 μs (3960 allocations: 216.56 KiB)
      302.021 μs (3960 allocations: 216.56 KiB)
      974.567 μs (9901 allocations: 309.41 KiB)
    k = 13
      151.162 μs (1976 allocations: 77.19 KiB)
      153.427 μs (1976 allocations: 77.19 KiB)
      1.001 ms (8893 allocations: 293.34 KiB)
      306.594 μs (3952 allocations: 216.13 KiB)
      325.868 μs (3952 allocations: 216.13 KiB)
      1.010 ms (9881 allocations: 308.78 KiB)
    k = 17
      169.526 μs (1968 allocations: 76.88 KiB)
      181.104 μs (1968 allocations: 76.88 KiB)
      982.725 μs (8857 allocations: 292.16 KiB)
      334.879 μs (3936 allocations: 215.25 KiB)
      358.731 μs (3936 allocations: 215.25 KiB)
      1.025 ms (9841 allocations: 307.53 KiB)
    k = 19
      178.535 μs (1964 allocations: 76.72 KiB)
      180.751 μs (1964 allocations: 76.72 KiB)
      967.457 μs (8839 allocations: 291.56 KiB)
      348.274 μs (3928 allocations: 214.81 KiB)
      369.494 μs (3928 allocations: 214.81 KiB)
      1.062 ms (9821 allocations: 306.91 KiB)
    k = 23
      196.424 μs (1956 allocations: 76.41 KiB)
      198.717 μs (1956 allocations: 76.41 KiB)
      1.054 ms (8803 allocations: 290.38 KiB)
      367.278 μs (3912 allocations: 213.94 KiB)
      389.736 μs (3912 allocations: 213.94 KiB)
      1.029 ms (9781 allocations: 305.66 KiB)
    k = 29
      222.913 μs (1944 allocations: 75.94 KiB)
      237.618 μs (1944 allocations: 75.94 KiB)
      1.029 ms (8749 allocations: 288.59 KiB)
      413.838 μs (3888 allocations: 212.63 KiB)
      416.544 μs (3888 allocations: 212.63 KiB)
      1.134 ms (9721 allocations: 303.78 KiB)
    k = 31
      231.639 μs (1940 allocations: 75.78 KiB)
      233.928 μs (1940 allocations: 75.78 KiB)
      1.113 ms (8731 allocations: 288.00 KiB)
      423.346 μs (3880 allocations: 212.19 KiB)
      425.503 μs (3880 allocations: 212.19 KiB)
      1.090 ms (9701 allocations: 303.16 KiB)



```julia
seq = randdnaseq(10_000)
for k in (7, 11, 13, 17, 19, 23, 29, 31)
    @show k
    @btime kmer_slice(seq, $k)
    @btime kmer_view(seq, $k)
    @btime kmer_iteration(seq, $k)
    @btime canonical_kmer_slice(seq, $k)
    @btime canonical_kmer_view(seq, $k)
    @btime canonical_kmer_iteration(seq, $k)
end
```

    k = 7
      1.323 ms (19988 allocations: 780.78 KiB)
      1.346 ms (19988 allocations: 780.78 KiB)
      13.607 ms (89947 allocations: 2.90 MiB)
      2.958 ms (39976 allocations: 2.13 MiB)
      3.003 ms (39976 allocations: 2.13 MiB)
      14.268 ms (99941 allocations: 3.05 MiB)
    k = 11
      1.522 ms (19980 allocations: 780.47 KiB)
      1.542 ms (19980 allocations: 780.47 KiB)
      14.152 ms (89911 allocations: 2.90 MiB)
      3.173 ms (39960 allocations: 2.13 MiB)
      3.333 ms (39960 allocations: 2.13 MiB)
      14.405 ms (99901 allocations: 3.05 MiB)
    k = 13
      1.620 ms (19976 allocations: 780.31 KiB)
      1.648 ms (19976 allocations: 780.31 KiB)
      13.831 ms (89893 allocations: 2.90 MiB)
      3.258 ms (39952 allocations: 2.13 MiB)
      3.497 ms (39952 allocations: 2.13 MiB)
      12.074 ms (99881 allocations: 3.05 MiB)
    k = 17
      1.822 ms (19968 allocations: 780.00 KiB)
      1.842 ms (19968 allocations: 780.00 KiB)
      14.227 ms (89857 allocations: 2.89 MiB)
      3.583 ms (39936 allocations: 2.13 MiB)
      3.815 ms (39936 allocations: 2.13 MiB)
      25.497 ms (99841 allocations: 3.05 MiB)
    k = 19
      2.473 ms (19964 allocations: 779.84 KiB)
      2.505 ms (19964 allocations: 779.84 KiB)
      24.142 ms (89839 allocations: 2.89 MiB)
      5.177 ms (39928 allocations: 2.13 MiB)
      6.672 ms (39928 allocations: 2.13 MiB)
      23.719 ms (99821 allocations: 3.05 MiB)
    k = 23
      2.551 ms (19956 allocations: 779.53 KiB)
      2.829 ms (19956 allocations: 779.53 KiB)
      22.361 ms (89803 allocations: 2.89 MiB)
      4.734 ms (39912 allocations: 2.13 MiB)
      6.368 ms (39912 allocations: 2.13 MiB)
      26.882 ms (99781 allocations: 3.05 MiB)
    k = 29
      2.918 ms (19944 allocations: 779.06 KiB)
      3.147 ms (19944 allocations: 779.06 KiB)
      25.791 ms (89749 allocations: 2.89 MiB)
      5.452 ms (39888 allocations: 2.13 MiB)
      8.598 ms (39888 allocations: 2.13 MiB)
      27.366 ms (99721 allocations: 3.04 MiB)
    k = 31
      3.243 ms (19940 allocations: 778.91 KiB)
      3.341 ms (19940 allocations: 778.91 KiB)
      23.201 ms (89731 allocations: 2.89 MiB)
      7.745 ms (39880 allocations: 2.13 MiB)
      6.378 ms (39880 allocations: 2.13 MiB)
      25.797 ms (99701 allocations: 3.04 MiB)


So it turns out that it doesn't matter whether we take slices or views. This could be because a copy of the sequence has to be made to print it to STDOUT anyway, negating the memory allocation savings of the view approach. Both approaches are 3x-10x faster than using the Kmer iterations provided in BioJulia. For this particular use case, I think it makes the most sense to go with the simplest, the slice.
