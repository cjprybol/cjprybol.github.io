---
layout: post  
---

What are the memory/speed trade-offs of using an ordered dictionary to store kmers and their respective counts as opposed to using sorted vectors?

Initially, I would expect that the ordered dictionary would have an additional memory overhead of storing the hash table (cost) in order to increase the rate of lookup (benefit).

The flip side of this is that the sorted vector would have little to no memory overhead beyond the actual kmers themselves (benefit), but our best-case search time should be slower (cost) with an expected runtime proportional to $$log2(\text{K}) \text{ where K = # of kmers}$$

Another potential benefit of using the sorted vectors is that they can be memory mapped onto disk, which would allow us to work with kmer datasets that are larger than the available RAM of the machine

So.... let's benchmark them and see if using the extra memory overhead (and losing the easy disk backing) is worth it


```julia
import Pkg
pkgs = [
    "BenchmarkTools",
    "DataStructures",
    "Random",
    "BioSequences",
    "Primes",
    "StatsBase",
    "Statistics"
]
Pkg.add(pkgs)
for pkg in pkgs
    eval(Meta.parse("import $pkg"))
end
```

    [32m[1m   Updating[22m[39m registry at `~/.julia/registries/General`


    [?25l    

    [32m[1m   Updating[22m[39m git-repo `https://github.com/JuliaRegistries/General.git`


    [2K[?25h[1mFetching:[22m[39m [========================================>]  100.0 %

    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`



```julia
k = 3
KMER_TYPE = BioSequences.DNAMer{k}
```




    BioSequences.Mer{BioSequences.DNAAlphabet{2},3}




```julia
sequence = BioSequences.randdnaseq(Random.seed!(1), 10)
```




    10nt DNA Sequence:
    TCGTCCCAGG



We'll use a counting function available in StatsBase as a quick and dirty kmer counter


```julia
kmer_counts = StatsBase.countmap(
    BioSequences.canonical(kmer.fw)
        for kmer in BioSequences.each(KMER_TYPE, sequence))

sorted_kmer_counts = collect(sort(kmer_counts))
```




    8-element Array{Pair{Any,Int64},1}:
     ACG => 1
     AGG => 1
     CAG => 1
     CCA => 1
     CCC => 1
     CGA => 1
     GAC => 1
     GGA => 1



Now create a sorted version that we can use for the dictionary


```julia
kmer_counts_dict = 
    DataStructures.OrderedDict(
        kmer => (index = i, count = c) for (i, (kmer, c)) in enumerate(sorted_kmer_counts)
)
```




    OrderedCollections.OrderedDict{BioSequences.Mer{BioSequences.DNAAlphabet{2},3},NamedTuple{(:index, :count),Tuple{Int64,Int64}}} with 8 entries:
      ACG => (index = 1, count = 1)
      AGG => (index = 2, count = 1)
      CAG => (index = 3, count = 1)
      CCA => (index = 4, count = 1)
      CCC => (index = 5, count = 1)
      CGA => (index = 6, count = 1)
      GAC => (index = 7, count = 1)
      GGA => (index = 8, count = 1)



Note here I am also including the index of the kmer

If I'm going to have a quick kmer lookup function, I want to be able to quickly look up the index as well as the count

The index is relevant because I intend to utilize the kmers as nodes in a graph, and the nodes are numbered numerically from i:N

I also want the reverse to be true; Given an index, I want a rapid lookup of the kmer at that index. Because the OrderedDict datastructure stores the order of the keys, we're able to lookup kmers by their index which is not possible in a standard Dict


```julia
kmer_counts_dict.keys
```




    8-element Array{BioSequences.Mer{BioSequences.DNAAlphabet{2},3},1}:
     ACG
     AGG
     CAG
     CCA
     CCC
     CGA
     GAC
     GGA



When searching a vector for the kmers, we will be returning the index as the result of the search, eliminating the need to store it. That index can then be used to access the counts in another vector.

Below, we can see away that the dictionary data structure is ~2x larger to store. This additional memory compounds the issue that we can't disk-back the dictionary in the event that the data set is larger than our available RAM


```julia
kmers = first.(sorted_kmer_counts)
counts = last.(sorted_kmer_counts)

@show Base.summarysize(kmer_counts_dict)
@show Base.summarysize(kmers) + Base.summarysize(counts);
```

    Base.summarysize(kmer_counts_dict) = 416
    Base.summarysize(kmers) + Base.summarysize(counts) = 208



```julia
function generate_kmer(k)
    BioSequences.canonical(BioSequences.DNAMer(BioSequences.randdnaseq(k)))
end
```




    generate_kmer (generic function with 1 method)



In the following, we can see that the runtime on this very small test case is effectively equivalent. Neither function requires memory allocation during the lookup


```julia
# time to see if something is in the list
BenchmarkTools.@benchmark get($kmer_counts_dict, $(generate_kmer(k)), $(index = 0, count = 0))
```




    BenchmarkTools.Trial: 
      memory estimate:  0 bytes
      allocs estimate:  0
      --------------
      minimum time:     8.712 ns (0.00% GC)
      median time:      8.980 ns (0.00% GC)
      mean time:        9.540 ns (0.00% GC)
      maximum time:     57.404 ns (0.00% GC)
      --------------
      samples:          10000
      evals/sample:     999




```julia
BenchmarkTools.@benchmark searchsorted($kmers, $(generate_kmer(k)))
```




    BenchmarkTools.Trial: 
      memory estimate:  0 bytes
      allocs estimate:  0
      --------------
      minimum time:     8.963 ns (0.00% GC)
      median time:      8.975 ns (0.00% GC)
      mean time:        9.142 ns (0.00% GC)
      maximum time:     52.988 ns (0.00% GC)
      --------------
      samples:          10000
      evals/sample:     999



Now that we've setup our steps for how to assess runtime for a given sequence and kmer length, let's wrap the above code into a function that we can run across several combinations of sequence length and kmer size.


```julia
function assess_dict_vs_vectors(sequence, ::Type{KMER_TYPE}) where KMER_TYPE
    kmer_counts = convert(Dict{KMER_TYPE, Int}, 
                    StatsBase.countmap(alg = :Dict, BioSequences.canonical(kmer.fw) for kmer in BioSequences.each(KMER_TYPE, sequence)))
    sorted_kmer_counts = collect(sort(kmer_counts))
    
    kmer_counts_dict = 
        DataStructures.OrderedDict(
            kmer => (index = i, count = c) for (i, (kmer, c)) in enumerate(sorted_kmer_counts)
    )
    
    kmers = convert(Vector{KMER_TYPE}, first.(sorted_kmer_counts))
    counts = convert(Vector{Int}, last.(sorted_kmer_counts))

    println("\t\ttotal kmers = $(length(kmers))\n")

    vector_size = Base.summarysize(kmers) + Base.summarysize(counts)

    dict_size = Base.summarysize(kmer_counts_dict)

    relative_size = dict_size / vector_size
    println("\t\tDict size relative to vectors\t\t: ", round(dict_size / vector_size, digits=1))

    vector_results = (BenchmarkTools.@benchmark searchsorted($kmers, $(generate_kmer(length(first(kmers))))))::BenchmarkTools.Trial
    dict_results = (BenchmarkTools.@benchmark get($kmer_counts_dict, $(generate_kmer(length(first(kmers)))), $(index = 0, count = 0)))::BenchmarkTools.Trial

    relative_performance = Statistics.median(vector_results).time / Statistics.median(dict_results).time
    println("\t\tDict performance relative to vectors\t: ", round(relative_performance, digits=1))
    println("\t\tSize-normalized performance\t\t: ", round(relative_performance / relative_size, digits=1))
end
```




    assess_dict_vs_vectors (generic function with 1 method)




```julia
@show sequence_length = 10^5
sequence = BioSequences.randdnaseq(Random.seed!(sequence_length), sequence_length)
for k in Primes.primes(3, 19)
    println("\tk = $k")
    KMER_TYPE = BioSequences.DNAMer{k}
    assess_dict_vs_vectors(sequence, KMER_TYPE)
end
```

    sequence_length = 10 ^ 5 = 100000
    	k = 3
    		total kmers = 32
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.3
    		Size-normalized performance		: 0.7
    	k = 5
    		total kmers = 512
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.7
    		Size-normalized performance		: 0.8
    	k = 7
    		total kmers = 8192
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 2.2
    		Size-normalized performance		: 1.1
    	k = 11
    		total kmers = 97510
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 2.0
    		Size-normalized performance		: 0.9
    	k = 13
    		total kmers = 99848
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 1.7
    		Size-normalized performance		: 0.8
    	k = 17
    		total kmers = 99982
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 2.1
    		Size-normalized performance		: 1.0
    	k = 19
    		total kmers = 99981
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 1.5
    		Size-normalized performance		: 0.7


Here we can see that the performance of the dictionary lookup appears to be ~2x the performance of the sorted search on the vector.

However, given the 2x storage size, when we normalize this performance gain against the memory increase, the costs and benefits neutralize one another.

Let's see if it get's any better as we continue to increase the number of kmers via larger sequences and kmer lengths.


```julia
@show sequence_length = 10^6
sequence = BioSequences.randdnaseq(Random.seed!(sequence_length), sequence_length)
for k in Primes.primes(3, 19)
    println("\tk = $k")
    KMER_TYPE = BioSequences.DNAMer{k}
    assess_dict_vs_vectors(sequence, KMER_TYPE)
end
```

    sequence_length = 10 ^ 6 = 1000000
    	k = 3
    		total kmers = 32
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.2
    		Size-normalized performance		: 0.6
    	k = 5
    		total kmers = 512
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.7
    		Size-normalized performance		: 0.9
    	k = 7
    		total kmers = 8192
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.8
    		Size-normalized performance		: 0.9
    	k = 11
    		total kmers = 795474
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 2.3
    		Size-normalized performance		: 1.1
    	k = 13
    		total kmers = 985285
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 2.4
    		Size-normalized performance		: 1.2
    	k = 17
    		total kmers = 999941
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 2.3
    		Size-normalized performance		: 1.1
    	k = 19
    		total kmers = 999980
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 2.0
    		Size-normalized performance		: 1.0



```julia
@show sequence_length = 10^7
sequence = BioSequences.randdnaseq(Random.seed!(sequence_length), sequence_length)
for k in Primes.primes(3, 29)
    println("\tk = $k")
    KMER_TYPE = BioSequences.DNAMer{k}
    assess_dict_vs_vectors(sequence, KMER_TYPE)
end
```

    sequence_length = 10 ^ 7 = 10000000
    	k = 3
    		total kmers = 32
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.5
    		Size-normalized performance		: 0.8
    	k = 5
    		total kmers = 512
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.8
    		Size-normalized performance		: 0.9
    	k = 7
    		total kmers = 8192
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.5
    		Size-normalized performance		: 0.7
    	k = 11
    		total kmers = 2079555
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 3.0
    		Size-normalized performance		: 1.5
    	k = 13
    		total kmers = 8646404
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 3.3
    		Size-normalized performance		: 1.7
    	k = 17
    		total kmers = 9994063
    
    		Dict size relative to vectors		: 1.9
    		Dict performance relative to vectors	: 2.6
    		Size-normalized performance		: 1.4
    	k = 19
    		total kmers = 9999601
    
    		Dict size relative to vectors		: 1.9
    		Dict performance relative to vectors	: 2.2
    		Size-normalized performance		: 1.1
    	k = 23
    		total kmers = 9999974
    
    		Dict size relative to vectors		: 1.9
    		Dict performance relative to vectors	: 2.5
    		Size-normalized performance		: 1.3
    	k = 29
    		total kmers = 9999972
    
    		Dict size relative to vectors		: 1.9
    		Dict performance relative to vectors	: 2.6
    		Size-normalized performance		: 1.4



```julia
@show sequence_length = 10^8
sequence = BioSequences.randdnaseq(Random.seed!(sequence_length), sequence_length)
for k in Primes.primes(3, 31)
    println("\tk = $k")
    KMER_TYPE = BioSequences.DNAMer{k}
    assess_dict_vs_vectors(sequence, KMER_TYPE)
end
```

    sequence_length = 10 ^ 8 = 100000000
    	k = 3
    		total kmers = 32
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.5
    		Size-normalized performance		: 0.8
    	k = 5
    		total kmers = 512
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 1.7
    		Size-normalized performance		: 0.9
    	k = 7
    		total kmers = 8192
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 2.0
    		Size-normalized performance		: 1.0
    	k = 11
    		total kmers = 2097152
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 3.2
    		Size-normalized performance		: 1.6
    	k = 13
    		total kmers = 31849943
    
    		Dict size relative to vectors		: 2.0
    		Dict performance relative to vectors	: 3.5
    		Size-normalized performance		: 1.7
    	k = 17
    		total kmers = 99419602
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 3.1
    		Size-normalized performance		: 1.4
    	k = 19
    		total kmers = 99963714
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 3.3
    		Size-normalized performance		: 1.5
    	k = 23
    		total kmers = 99999836
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 2.6
    		Size-normalized performance		: 1.2
    	k = 29
    		total kmers = 99999972
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 2.6
    		Size-normalized performance		: 1.2
    	k = 31
    		total kmers = 99999970
    
    		Dict size relative to vectors		: 2.2
    		Dict performance relative to vectors	: 3.0
    		Size-normalized performance		: 1.4


Here it seems like at best we get a 3x speed improvement for querying a specific kmer in a Dictionary as compared to searching for it in a sorted vector.

Normalizing that speed up relative to the size increase of using a dictionary, we're able to get a slight boost in overall performance (according to this subjective view of rating performance) that I ultimately don't think is worth it.

I'll be utilizing sorted vectors for my kmer work going forward
