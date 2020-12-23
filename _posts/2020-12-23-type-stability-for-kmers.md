---
layout: post  
---

While working on [a previous post about kmer sizes, error rates, and coverage]({{ site.baseurl }}{% post_url 2020-12-19-observed-kmers-vs-error-rate %}), I found a type-stability issue in a function that I was writing.

The subject of the is described [here](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-value-type) in the Julia language manual.

The core of the issue is that Julia's compilation is centered around the _types_ of the inputs, not their values

Let's demonstrate this through a few examples


```julia
import Pkg
pkgs = [
    "BioSequences",
    "Random",
    "BenchmarkTools",
    "Primes"
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


Let's say we would like a kmer of length `3`


```julia
kmer = BioSequences.DNAMer("ACG")
```




    DNA 3-mer:
    ACG



While this kmer has a length of `3`, the actual data type of the kmer is something entirely different


```julia
typeof(kmer)
```




    BioSequences.Mer{BioSequences.DNAAlphabet{2},3}



As shown above, the type of this length `3` kmer is a composite type consisting of the alphabet `BioSequences.DNAAlphabet{2}` and the length `3`

If we want a function that will return every 3-mer in a sequence, passing an argument `kmer_size` of 3 is insufficient for the Julia language to unambiguously know the return type ahead of time, which would be `BioSequences.Mer{BioSequences.DNAAlphabet{2},3}`

The reason for this is that if we pass a _value_ of `k=3`, the datatype of 3 is an integer


```julia
typeof(3)
```




    Int64



An integer can hold any value between the minimum and maximum values that can be stored the datatype


```julia
typemin(Int):typemax(Int)
```




    -9223372036854775808:9223372036854775807



While changing the value of an integer does not change the datatype, changing the value of k _DOES_ change the datatype of a kmer (as it is currently designed and implemented in the BioSequences codebase in Julia)


```julia
println("Integers:")
@show type_1 = typeof(3);
@show type_2 = typeof(4);
@show type_1 == type_2;

println("")
println("Kmers:")
@show type_1 = typeof(BioSequences.DNAMer("ACG"));
@show type_2 = typeof(BioSequences.DNAMer("ACGT"));
@show type_1 != type_2;
```

    Integers:
    type_1 = typeof(3) = Int64
    type_2 = typeof(4) = Int64
    type_1 == type_2 = true
    
    Kmers:
    type_1 = typeof(BioSequences.DNAMer("ACG")) = BioSequences.Mer{BioSequences.DNAAlphabet{2},3}
    type_2 = typeof(BioSequences.DNAMer("ACGT")) = BioSequences.Mer{BioSequences.DNAAlphabet{2},4}
    type_1 != type_2 = true


Let's demonstrate how this plays out in terms of Julia type-inference and runtime

First, we will set our k parameter and generate a random sequence


```julia
k = 3
sequence = BioSequences.randdnaseq(Random.seed!(1), 10)
```




    10nt DNA Sequence:
    TCGTCCCAGG



Next we will define a function that takes the k-size and sequence as inputs, and returns the set of all kmers observed as the output


```julia
function assess_kmers_1(k, sequence)
    KMER_TYPE = BioSequences.DNAMer{k}
    kmers = Set{KMER_TYPE}()
    for kmer_set in BioSequences.each(KMER_TYPE, sequence)
        push!(kmers, BioSequences.canonical(kmer_set.fw))
    end
    return kmers
end
```




    assess_kmers_1 (generic function with 1 method)




```julia
assess_kmers_1(k, sequence)
```




    Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}} with 8 elements:
      ACG
      GAC
      CCC
      GGA
      CGA
      AGG
      CAG
      CCA



We can see that the function executed without error and returned our desired result, so there is no issue with correctness of this function

However, if we use Julia's built in `@code_warntype` to assess the type-inferring of the function, we can see the issue


```julia
@code_warntype assess_kmers_1(k, sequence)
```

    Variables
      #self#[36m::Core.Compiler.Const(assess_kmers_1, false)[39m
      k[36m::Int64[39m
      sequence[36m::BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}[39m
      KMER_TYPE[91m[1m::Type{BioSequences.Mer{BioSequences.DNAAlphabet{2},_A}} where _A[22m[39m
      kmers[91m[1m::Set{_A} where _A[22m[39m
      @_6[33m[1m::Union{Nothing, Tuple{BioSequences.MerIterResult,Tuple{Int64,Any,Any,Any}}}[22m[39m
      kmer_set[91m[1m::BioSequences.MerIterResult[22m[39m
    
    Body[91m[1m::Set{_A} where _A[22m[39m
    [90m1 ─[39m %1  = BioSequences.DNAMer[36m::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},K} where K, false)[39m
    [90m│  [39m       (KMER_TYPE = Core.apply_type(%1, k))
    [90m│  [39m %3  = Core.apply_type(Main.Set, KMER_TYPE)[91m[1m::Type{Set{_A}} where _A[22m[39m
    [90m│  [39m       (kmers = (%3)())
    [90m│  [39m %5  = BioSequences.each[36m::Core.Compiler.Const(BioSequences.each, false)[39m
    [90m│  [39m %6  = KMER_TYPE[91m[1m::Type{BioSequences.Mer{BioSequences.DNAAlphabet{2},_A}} where _A[22m[39m
    [90m│  [39m %7  = (%5)(%6, sequence)[91m[1m::BioSequences.EveryMerIterator{_A,BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}} where _A<:BioSequences.AbstractMer[22m[39m
    [90m│  [39m       (@_6 = Base.iterate(%7))
    [90m│  [39m %9  = (@_6 === nothing)[36m::Bool[39m
    [90m│  [39m %10 = Base.not_int(%9)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %10
    [90m2 ┄[39m %12 = @_6::Tuple{BioSequences.MerIterResult,Tuple{Int64,Any,Any,Any}}[91m[1m::Tuple{BioSequences.MerIterResult,Tuple{Int64,Any,Any,Any}}[22m[39m
    [90m│  [39m       (kmer_set = Core.getfield(%12, 1))
    [90m│  [39m %14 = Core.getfield(%12, 2)[91m[1m::Tuple{Int64,Any,Any,Any}[22m[39m
    [90m│  [39m %15 = kmers[91m[1m::Set{_A} where _A[22m[39m
    [90m│  [39m %16 = BioSequences.canonical[36m::Core.Compiler.Const(BioSequences.canonical, false)[39m
    [90m│  [39m %17 = Base.getproperty(kmer_set, :fw)[91m[1m::BioSequences.AbstractMer[22m[39m
    [90m│  [39m %18 = (%16)(%17)[91m[1m::BioSequences.AbstractMer[22m[39m
    [90m│  [39m       Main.push!(%15, %18)
    [90m│  [39m       (@_6 = Base.iterate(%7, %14))
    [90m│  [39m %21 = (@_6 === nothing)[36m::Bool[39m
    [90m│  [39m %22 = Base.not_int(%21)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %22
    [90m3 ─[39m       goto #2
    [90m4 ┄[39m       return kmers


On some displays, you may see red text coloration to help distinguish the areas of concern

We can see that the Body of the function has the return type `Body::Set{_A} where _A`

The function knows it will return a Set, but it isn't sure what datatype(s) will be stored inside

As a result, the function has given this unknown datatype a variable, `_A`

Let's review the memory utilization and runtime of this function as a benchmark to see if we can improve upon it


```julia
BenchmarkTools.@benchmark assess_kmers_1(k, sequence)
```




    BenchmarkTools.Trial: 
      memory estimate:  2.02 KiB
      allocs estimate:  54
      --------------
      minimum time:     5.303 μs (0.00% GC)
      median time:      5.698 μs (0.00% GC)
      mean time:        6.163 μs (2.37% GC)
      maximum time:     805.027 μs (98.12% GC)
      --------------
      samples:          10000
      evals/sample:     6



Here we can see that the function requires 54 individual allocations, requires 2 KiB of memory, and has a mean runtime of approximately 6 μs

To circumvent this issue, Julia has a built-in `Val` type that can be used to wrap integers to provide type-stability in functions. Let's try using it and seeing what happens


```julia
function assess_kmers_2(K::Val{k}, sequence) where k
    KMER_TYPE = BioSequences.DNAMer{k}
    kmers = Set{KMER_TYPE}()
    for kmer_set in BioSequences.each(KMER_TYPE, sequence)
        push!(kmers, BioSequences.canonical(kmer_set.fw))
    end
    return kmers
end
```




    assess_kmers_2 (generic function with 1 method)




```julia
result_1 = assess_kmers_1(k, sequence)
result_2 = assess_kmers_2(Val(k), sequence)
@show result_1 == result_2;
```

    result_1 == result_2 = true


We can confirm that the functions both generate the same outputs.

Let's look at whether the type inference has improved


```julia
@code_warntype assess_kmers_2(Val(k), sequence)
```

    Variables
      #self#[36m::Core.Compiler.Const(assess_kmers_2, false)[39m
      K[36m::Core.Compiler.Const(Val{3}(), false)[39m
      sequence[36m::BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}[39m
      KMER_TYPE[36m::Type{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
      kmers[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
      @_6[33m[1m::Union{Nothing, Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}}[22m[39m
      kmer_set[36m::BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    
    Body[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    [90m1 ─[39m %1  = BioSequences.DNAMer[36m::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},K} where K, false)[39m
    [90m│  [39m       (KMER_TYPE = Core.apply_type(%1, $(Expr(:static_parameter, 1))))
    [90m│  [39m %3  = Core.apply_type(Main.Set, KMER_TYPE::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},3}, false))[36m::Core.Compiler.Const(Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}, false)[39m
    [90m│  [39m       (kmers = (%3)())
    [90m│  [39m %5  = BioSequences.each[36m::Core.Compiler.Const(BioSequences.each, false)[39m
    [90m│  [39m %6  = KMER_TYPE::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},3}, false)[36m::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},3}, false)[39m
    [90m│  [39m %7  = (%5)(%6, sequence)[36m::BioSequences.EveryMerIterator{BioSequences.Mer{BioSequences.DNAAlphabet{2},3},BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}}[39m
    [90m│  [39m       (@_6 = Base.iterate(%7))
    [90m│  [39m %9  = (@_6 === nothing)[36m::Bool[39m
    [90m│  [39m %10 = Base.not_int(%9)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %10
    [90m2 ┄[39m %12 = @_6::Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}[36m::Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}[39m
    [90m│  [39m       (kmer_set = Core.getfield(%12, 1))
    [90m│  [39m %14 = Core.getfield(%12, 2)[36m::Tuple{Int64,Int64,UInt64,UInt64}[39m
    [90m│  [39m %15 = kmers[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    [90m│  [39m %16 = BioSequences.canonical[36m::Core.Compiler.Const(BioSequences.canonical, false)[39m
    [90m│  [39m %17 = Base.getproperty(kmer_set, :fw)[36m::BioSequences.Mer{BioSequences.DNAAlphabet{2},3}[39m
    [90m│  [39m %18 = (%16)(%17)[36m::BioSequences.Mer{BioSequences.DNAAlphabet{2},3}[39m
    [90m│  [39m       Main.push!(%15, %18)
    [90m│  [39m       (@_6 = Base.iterate(%7, %14))
    [90m│  [39m %21 = (@_6 === nothing)[36m::Bool[39m
    [90m│  [39m %22 = Base.not_int(%21)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %22
    [90m3 ─[39m       goto #2
    [90m4 ┄[39m       return kmers


Here we can see that the function body is able to properly infer the return type from the inputs, and knows that it will return a type `Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}` given the inputs


```julia
BenchmarkTools.@benchmark assess_kmers_2(Val(k), sequence)
```




    BenchmarkTools.Trial: 
      memory estimate:  496 bytes
      allocs estimate:  5
      --------------
      minimum time:     2.523 μs (0.00% GC)
      median time:      2.588 μs (0.00% GC)
      mean time:        2.712 μs (1.30% GC)
      maximum time:     359.264 μs (98.32% GC)
      --------------
      samples:          10000
      evals/sample:     9



The benchmarking results have also improved. Memory allocation is ~4x less, the number of allocations is down by > 10x, and the mean runtime is down by > 2x

While this improvement is nice, I'm not a particularly big fan of using the `Val` construct. It may not be very clear to someone unfamiliar with Julia why we are using it, and using k (the integer) in some places and K (the Val type) others could lead to confusion.

As an alternative, let's try creating a function that takes the desired kmer type directly


```julia
function assess_kmers_3(::Type{KMER_TYPE}, sequence) where KMER_TYPE
    kmers = Set{KMER_TYPE}()
    for kmer_set in BioSequences.each(KMER_TYPE, sequence)
        push!(kmers, BioSequences.canonical(kmer_set.fw))
    end
    return kmers
end
```




    assess_kmers_3 (generic function with 1 method)




```julia
@code_warntype assess_kmers_3(BioSequences.DNAMer{k}, sequence)
```

    Variables
      #self#[36m::Core.Compiler.Const(assess_kmers_3, false)[39m
      #unused#[36m::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},3}, false)[39m
      sequence[36m::BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}[39m
      kmers[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
      @_5[33m[1m::Union{Nothing, Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}}[22m[39m
      kmer_set[36m::BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    
    Body[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    [90m1 ─[39m %1  = Core.apply_type(Main.Set, $(Expr(:static_parameter, 1)))[36m::Core.Compiler.Const(Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}, false)[39m
    [90m│  [39m       (kmers = (%1)())
    [90m│  [39m %3  = BioSequences.each[36m::Core.Compiler.Const(BioSequences.each, false)[39m
    [90m│  [39m %4  = $(Expr(:static_parameter, 1))[36m::Core.Compiler.Const(BioSequences.Mer{BioSequences.DNAAlphabet{2},3}, false)[39m
    [90m│  [39m %5  = (%3)(%4, sequence)[36m::BioSequences.EveryMerIterator{BioSequences.Mer{BioSequences.DNAAlphabet{2},3},BioSequences.LongSequence{BioSequences.DNAAlphabet{4}}}[39m
    [90m│  [39m       (@_5 = Base.iterate(%5))
    [90m│  [39m %7  = (@_5 === nothing)[36m::Bool[39m
    [90m│  [39m %8  = Base.not_int(%7)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %8
    [90m2 ┄[39m %10 = @_5::Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}[36m::Tuple{BioSequences.MerIterResult{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}},Tuple{Int64,Int64,UInt64,UInt64}}[39m
    [90m│  [39m       (kmer_set = Core.getfield(%10, 1))
    [90m│  [39m %12 = Core.getfield(%10, 2)[36m::Tuple{Int64,Int64,UInt64,UInt64}[39m
    [90m│  [39m %13 = kmers[36m::Set{BioSequences.Mer{BioSequences.DNAAlphabet{2},3}}[39m
    [90m│  [39m %14 = BioSequences.canonical[36m::Core.Compiler.Const(BioSequences.canonical, false)[39m
    [90m│  [39m %15 = Base.getproperty(kmer_set, :fw)[36m::BioSequences.Mer{BioSequences.DNAAlphabet{2},3}[39m
    [90m│  [39m %16 = (%14)(%15)[36m::BioSequences.Mer{BioSequences.DNAAlphabet{2},3}[39m
    [90m│  [39m       Main.push!(%13, %16)
    [90m│  [39m       (@_5 = Base.iterate(%5, %12))
    [90m│  [39m %19 = (@_5 === nothing)[36m::Bool[39m
    [90m│  [39m %20 = Base.not_int(%19)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %20
    [90m3 ─[39m       goto #2
    [90m4 ┄[39m       return kmers


This function is also able to correctly infer the output type, but (for reasons I don't fully understand) is able to make even greater improvements in runtime


```julia
BenchmarkTools.@benchmark assess_kmers_3(BioSequences.DNAMer{k}, sequence)
```




    BenchmarkTools.Trial: 
      memory estimate:  496 bytes
      allocs estimate:  5
      --------------
      minimum time:     432.333 ns (0.00% GC)
      median time:      444.437 ns (0.00% GC)
      mean time:        500.236 ns (6.74% GC)
      maximum time:     19.114 μs (97.21% GC)
      --------------
      samples:          10000
      evals/sample:     198



Here we can see that the number of allocations has stayed the same as our previous method, but something about directly providing the desired return type has enabled us to further reduce our runtime by ~ 5x over the `assess_kmers_2` method, and by over 10x relative to our original `assess_kmers_1` method
