layout: post  
title: Indexing Kmers  
date: 2020-12-05  
author: Cameron Prybol  

---

- Assume that you have a known kmer length, k, and a known alphabet (either DNA nucleotides ACGT or Amino Acids)

There are serveral ways that we can store kmers.
The simplest way would be to just store the actual kmer.
One of the most convenient ways to store kmers is to have a hash, which enables quick and constant time lookups to see if a given kmer exists.
The hash method doesn't scale well though since it requires every kmer to remain in memory.
Keeping all kmers in memory is often do-able, but since I'd like to only write one method that works everywhere regardless of available memory resources (we are working under the assumption that there is sufficient disk storage to store and analyze the data), we'll focus on methods that allow memory-mapping to disk such that we can work with datasets that are larger than available RAM, but will remain entirely in RAM when they can.

When memory-mapping to disk, we must use fixed-size datatypes.
The two options that seem most practical are:
- immutable, fixed-length containers of nucleotides or amino acids
    - Tuples
    - [Static Arrays](https://github.com/JuliaArrays/StaticArrays.jl)
- integers
    - for a given k-length, there is a finite # of possible kmers
    - for a given biological alphabet of N characters, the value is N^k
    - given an ordering of these characters, we can deterministically solve for the index that a given kmer would occupy in a sorted list of all possible kmers of k-length
    - thus, we can unambiguously map between an integer index and a given kmer with a known alphabet
    - this only becomes an issue when the size of the possible kmers is larger than what can be stored in native integer datatypes
        - e.g. UInt32, 64
        
Since I also want to keep track of the number of occurances of each kmer in a given dataset, I THINK that the most concise way to keep track of kmers is a sparse count-vector of the # of times each kmer was observed, where:
- size of the sparse count vector = N^k where N = size of alphabet and k = length of kmer
- kmers are mapped to an integer, such that the i-th index of the count vector represents the i-th kmer in a hypothetical dense sorted list of all possible kmers
- any kmer with counts > 0 exists, and thus the counts vector is sufficient to store the kmers and their frequencies


```julia
import Pkg
pkgs = [
    "BenchmarkTools",
    "BioSequences",
    "BioSymbols",
    "DataFrames",
    "GLM",
    "Primes",
    "ProgressMeter",
    "StaticArrays",
    "Statistics",
    "StatsPlots",
    "Test"
]
Pkg.add(pkgs)
for pkg in pkgs
    eval(Meta.parse("import $pkg"))
end

Pkg.add("PlotlyJS")
StatsPlots.plotlyjs()
```

    [32m[1m   Updating[22m[39m registry at `~/.julia/registries/General`


    [?25l[2K

    [32m[1m   Updating[22m[39m git-repo `https://github.com/JuliaRegistries/General.git`


    [?25h

    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    [32m[1m  Resolving[22m[39m package versions...



<script>
// Immediately-invoked-function-expression to avoid global variables.
(function() {
    var warning_div = document.getElementById("webio-warning-7868345806734811546");
    var hide = function () {
        var script = document.getElementById("webio-setup-2424009860299011010");
        var parent = script && script.parentElement;
        var grandparent = parent && parent.parentElement;
        if (grandparent) {
            grandparent.style.display = "none";
        }
        warning_div.style.display = "none";
    };
    if (typeof Jupyter !== "undefined") {
        console.log("WebIO detected Jupyter notebook environment.");
        // Jupyter notebook.
        var extensions = (
            Jupyter
            && Jupyter.notebook.config.data
            && Jupyter.notebook.config.data.load_extensions
        );
        if (extensions && extensions["webio-jupyter-notebook"]) {
            // Extension already loaded.
            console.log("Jupyter WebIO nbextension detected; not loading ad-hoc.");
            hide();
            return;
        }
    } else if (window.location.pathname.includes("/lab")) {
        // Guessing JupyterLa
        console.log("Jupyter Lab detected; make sure the @webio/jupyter-lab-provider labextension is installed.");
        hide();
        return;
    }
})();

</script>
<p
    id="webio-warning-7868345806734811546"
    class="output_text output_stderr"
    style="padding: 1em; font-weight: bold;"
>
    Unable to load WebIO. Please make sure WebIO works for your Jupyter client.
    For troubleshooting, please see <a href="https://juliagizmos.github.io/WebIO.jl/latest/providers/ijulia/">
    the WebIO/IJulia documentation</a>.
    <!-- TODO: link to installation docs. -->
</p>



    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    ┌ Warning: Error requiring PlotlyJS from Plots:
    │ LoadError: LoadError: LoadError: UndefVarError: WebIO not defined
    │ Stacktrace:
    │  [1] top-level scope
    │  [2] #macroexpand#36 at ./expr.jl:108 [inlined]
    │  [3] macroexpand(::Module, ::Any) at ./expr.jl:107
    │  [4] @require(::LineNumberNode, ::Module, ::Any, ::Any) at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:90
    │  [5] include(::Function, ::Module, ::String) at ./Base.jl:380
    │  [6] include at ./Base.jl:368 [inlined]
    │  [7] include(::String) at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/Plots.jl:1
    │  [8] top-level scope at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/init.jl:61
    │  [9] eval at ./boot.jl:331 [inlined]
    │  [10] eval at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/Plots.jl:1 [inlined]
    │  [11] (::Plots.var"#323#356")() at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:97
    │  [12] err(::Any, ::Module, ::String) at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:42
    │  [13] (::Plots.var"#322#355")() at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:96
    │  [14] withpath(::Any, ::String) at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:32
    │  [15] (::Plots.var"#321#354")() at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:95
    │  [16] #invokelatest#1 at ./essentials.jl:710 [inlined]
    │  [17] invokelatest at ./essentials.jl:709 [inlined]
    │  [18] foreach at ./abstractarray.jl:2009 [inlined]
    │  [19] loadpkg(::Base.PkgId) at /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:22
    │  [20] #invokelatest#1 at ./essentials.jl:710 [inlined]
    │  [21] invokelatest at ./essentials.jl:709 [inlined]
    │  [22] require(::Base.PkgId) at ./loading.jl:931
    │  [23] require(::Module, ::Symbol) at ./loading.jl:923
    │  [24] top-level scope at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends.jl:472
    │  [25] eval at ./boot.jl:331 [inlined]
    │  [26] _initialize_backend(::Plots.PlotlyJSBackend) at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends.jl:471
    │  [27] backend at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends.jl:176 [inlined]
    │  [28] plotlyjs(; kw::Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{,Tuple{}}}) at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends.jl:33
    │  [29] plotlyjs() at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends.jl:33
    │  [30] top-level scope at In[1]:21
    │  [31] include_string(::Function, ::Module, ::String, ::String) at ./loading.jl:1091
    │  [32] softscope_include_string(::Module, ::String, ::String) at /home/jupyter-cjprybol/.julia/packages/SoftGlobalScope/u4UzH/src/SoftGlobalScope.jl:65
    │  [33] execute_request(::ZMQ.Socket, ::IJulia.Msg) at /home/jupyter-cjprybol/.julia/packages/IJulia/IDNmS/src/execute_request.jl:67
    │  [34] #invokelatest#1 at ./essentials.jl:710 [inlined]
    │  [35] invokelatest at ./essentials.jl:709 [inlined]
    │  [36] eventloop(::ZMQ.Socket) at /home/jupyter-cjprybol/.julia/packages/IJulia/IDNmS/src/eventloop.jl:8
    │  [37] (::IJulia.var"#15#18")() at ./task.jl:356
    │ in expression starting at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends/plotlyjs.jl:46
    │ in expression starting at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends/plotlyjs.jl:43
    │ in expression starting at /home/jupyter-cjprybol/.julia/packages/Plots/nHJea/src/backends/plotlyjs.jl:43
    └ @ Requires /home/jupyter-cjprybol/.julia/packages/Requires/Odp8W/src/require.jl:44
    ┌ Warning: ORCA.jl has been deprecated and all savefig functionality
    │ has been implemented directly in PlotlyBase itself.
    │ 
    │ By implementing in PlotlyBase.jl, the savefig routines are automatically
    │ available to PlotlyJS.jl also.
    └ @ ORCA /home/jupyter-cjprybol/.julia/packages/ORCA/U5XaN/src/ORCA.jl:8





    Plots.PlotlyJSBackend()



## Define the functions


```julia
"""
    index_to_kmer(index, k, alphabet)

Given an index equivalent to where a kmer would appear in a sorted list of all possible kmers
given the parameters k and the biological alphabet, return the kmer that exists in that index
"""
function index_to_kmer(index, K::Val{k}, alphabet) where k
    @assert k > 0 "invalid k: $k"
    N = length(alphabet)
    max_index = length(alphabet)^k
    @assert 0 < index <= max_index "invalid index: $index not within 1:$(max_index)"
    kmer = Vector{eltype(alphabet)}(undef, k)
    for i in k:-1:1
        divisor = N^(i-1)
        alphabet_index = Int(ceil(index/divisor))
        index = index % divisor
        if alphabet_index == 0
            alphabet_index = N
        end
        kmer[k-i+1] = alphabet[alphabet_index]
    end
    # https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-value-type
    return ntuple(i-> kmer[i], K)
end
```




    index_to_kmer




```julia
"""
    kmer_to_index(kmer, alphabet)

Given a kmer and an alphabet of all biological symbols under consideration,
return the index that kmer would occupy in the sorted list of all possible kmers
"""
function kmer_to_index(kmer, alphabet)
    index = 0
    k = length(kmer)
    for i in k:-1:2
        alphabet_index = Int(findfirst(x -> x == kmer[k-i+1], alphabet))
        index += (alphabet_index - 1) * length(alphabet)^(i-1)
    end
    index += Int(findfirst(x -> x == kmer[end], alphabet))
    return index
end
```




    kmer_to_index



## Here we will determine the largest possbile kmers that can be stored for a given alphabet and k-length


```julia
DNA_ALPHABET = filter(symbol -> BioSymbols.iscertain(symbol), BioSymbols.alphabet(BioSymbols.DNA))
AA_ALPHABET = filter(symbol -> BioSymbols.iscertain(symbol) && !BioSymbols.isterm(symbol), BioSymbols.alphabet(BioSymbols.AminoAcid))
```




    (AA_A, AA_R, AA_N, AA_D, AA_C, AA_Q, AA_E, AA_G, AA_H, AA_I, AA_L, AA_K, AA_M, AA_F, AA_P, AA_S, AA_T, AA_W, AA_Y, AA_V, AA_O, AA_U)




```julia
for ALPHABET in (DNA_ALPHABET, AA_ALPHABET)
    println(eltype(ALPHABET))
    for T in (Int32, Int64, Int128)
        k = 0
        println(T)
        while BigInt(length(ALPHABET))^k < typemax(T)
            k += 1
        end
        println(k)
    end
    println()
end
```

    BioSymbols.DNA
    Int32
    16
    Int64
    32
    Int128
    64
    
    BioSymbols.AminoAcid
    Int32
    7
    Int64
    15
    Int128
    29
    


## Test that they are correct


```julia
Test.@testset "Test kmer <=> index transformations" begin
    for ALPHABET in (DNA_ALPHABET, AA_ALPHABET)
        for k in 1:3
            for (index, kmer) in enumerate(sort!(vec(collect(Iterators.product([ALPHABET for i in 1:k]...)))))
                Test.@test index == kmer_to_index(kmer, ALPHABET)
                Test.@test kmer == index_to_kmer(index, Val(k), ALPHABET)
            end
        end
    end
end
```

    [37m[1mTest Summary:                       | [22m[39m[32m[1m Pass  [22m[39m[36m[1mTotal[22m[39m
    Test kmer <=> index transformations | [32m22476  [39m[36m22476[39m





    Test.DefaultTestSet("Test kmer <=> index transformations", Any[], 22476, false)



## Assess for type instability


```julia
@code_warntype kmer_to_index(Tuple(BioSequences.randdnaseq(3)), DNA_ALPHABET)
```

    Variables
      #self#[36m::Core.Compiler.Const(kmer_to_index, false)[39m
      kmer[36m::Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}[39m
      alphabet[36m::NTuple{4,BioSymbols.DNA}[39m
      #4[36m::var"#4#6"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}}[39m
      k[36m::Int64[39m
      @_6[33m[1m::Union{Nothing, Tuple{Int64,Int64}}[22m[39m
      index[36m::Int64[39m
      i[36m::Int64[39m
      #3[36m::var"#3#5"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA},Int64,Int64}[39m
      alphabet_index[36m::Int64[39m
    
    Body[36m::Int64[39m
    [90m1 ─[39m       Core.NewvarNode(:(#4))
    [90m│  [39m       (index = 0)
    [90m│  [39m       (k = Main.length(kmer))
    [90m│  [39m %4  = (k::Core.Compiler.Const(3, false):-1:2)[36m::Core.Compiler.Const(3:-1:2, false)[39m
    [90m│  [39m       (@_6 = Base.iterate(%4))
    [90m│  [39m %6  = (@_6::Core.Compiler.Const((3, 3), false) === nothing)[36m::Core.Compiler.Const(false, false)[39m
    [90m│  [39m %7  = Base.not_int(%6)[36m::Core.Compiler.Const(true, false)[39m
    [90m└──[39m       goto #4 if not %7
    [90m2 ┄[39m %9  = @_6::Tuple{Int64,Int64}[36m::Tuple{Int64,Int64}[39m
    [90m│  [39m       (i = Core.getfield(%9, 1))
    [90m│  [39m %11 = Core.getfield(%9, 2)[36m::Int64[39m
    [90m│  [39m %12 = Main.:(var"#3#5")[36m::Core.Compiler.Const(var"#3#5", false)[39m
    [90m│  [39m %13 = Core.typeof(kmer)[36m::Core.Compiler.Const(Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}, false)[39m
    [90m│  [39m %14 = Core.typeof(k::Core.Compiler.Const(3, false))[36m::Core.Compiler.Const(Int64, false)[39m
    [90m│  [39m %15 = Core.typeof(i)[36m::Core.Compiler.Const(Int64, false)[39m
    [90m│  [39m %16 = Core.apply_type(%12, %13, %14, %15)[36m::Core.Compiler.Const(var"#3#5"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA},Int64,Int64}, false)[39m
    [90m│  [39m %17 = k::Core.Compiler.Const(3, false)[36m::Core.Compiler.Const(3, false)[39m
    [90m│  [39m       (#3 = %new(%16, kmer, %17, i))
    [90m│  [39m %19 = #3::Core.Compiler.PartialStruct(var"#3#5"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA},Int64,Int64}, Any[Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}, Core.Compiler.Const(3, false), Int64])[36m::Core.Compiler.PartialStruct(var"#3#5"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA},Int64,Int64}, Any[Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}, Core.Compiler.Const(3, false), Int64])[39m
    [90m│  [39m %20 = Main.findfirst(%19, alphabet)[33m[1m::Union{Nothing, Int64}[22m[39m
    [90m│  [39m       (alphabet_index = Main.Int(%20))
    [90m│  [39m %22 = index[36m::Int64[39m
    [90m│  [39m %23 = (alphabet_index - 1)[36m::Int64[39m
    [90m│  [39m %24 = Main.length(alphabet)[36m::Core.Compiler.Const(4, false)[39m
    [90m│  [39m %25 = (i - 1)[36m::Int64[39m
    [90m│  [39m %26 = (%24 ^ %25)[36m::Int64[39m
    [90m│  [39m %27 = (%23 * %26)[36m::Int64[39m
    [90m│  [39m       (index = %22 + %27)
    [90m│  [39m       (@_6 = Base.iterate(%4, %11))
    [90m│  [39m %30 = (@_6 === nothing)[36m::Bool[39m
    [90m│  [39m %31 = Base.not_int(%30)[36m::Bool[39m
    [90m└──[39m       goto #4 if not %31
    [90m3 ─[39m       goto #2
    [90m4 ┄[39m %34 = index[36m::Int64[39m
    [90m│  [39m %35 = Main.:(var"#4#6")[36m::Core.Compiler.Const(var"#4#6", false)[39m
    [90m│  [39m %36 = Core.typeof(kmer)[36m::Core.Compiler.Const(Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}, false)[39m
    [90m│  [39m %37 = Core.apply_type(%35, %36)[36m::Core.Compiler.Const(var"#4#6"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}}, false)[39m
    [90m│  [39m       (#4 = %new(%37, kmer))
    [90m│  [39m %39 = #4[36m::var"#4#6"{Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}}[39m
    [90m│  [39m %40 = Main.findfirst(%39, alphabet)[33m[1m::Union{Nothing, Int64}[22m[39m
    [90m│  [39m %41 = Main.Int(%40)[36m::Int64[39m
    [90m│  [39m       (index = %34 + %41)
    [90m└──[39m       return index



```julia
k = 3
@code_warntype index_to_kmer(rand(1:length(DNA_ALPHABET)^k), Val(k), DNA_ALPHABET)
```

    Variables
      #self#[36m::Core.Compiler.Const(index_to_kmer, false)[39m
      index@_2[36m::Int64[39m
      K[36m::Core.Compiler.Const(Val{3}(), false)[39m
      alphabet[36m::NTuple{4,BioSymbols.DNA}[39m
      #1[36m::var"#1#2"{Array{BioSymbols.DNA,1}}[39m
      N[36m::Int64[39m
      max_index[36m::Int64[39m
      kmer[36m::Array{BioSymbols.DNA,1}[39m
      @_9[33m[1m::Union{Nothing, Tuple{Int64,Int64}}[22m[39m
      i[36m::Int64[39m
      divisor[36m::Int64[39m
      alphabet_index[36m::Int64[39m
      index@_13[36m::Int64[39m
      @_14[36m::Bool[39m
    
    Body[36m::Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}[39m
    [90m1 ──[39m       (index@_13 = index@_2)
    [90m│   [39m       Core.NewvarNode(:(#1))
    [90m│   [39m       Core.NewvarNode(:(N))
    [90m│   [39m       Core.NewvarNode(:(max_index))
    [90m│   [39m       Core.NewvarNode(:(kmer))
    [90m│   [39m       Core.NewvarNode(:(@_9))
    [90m│   [39m %7  = ($(Expr(:static_parameter, 1)) > 0)[36m::Core.Compiler.Const(true, false)[39m
    [90m│   [39m       %7
    [90m└───[39m       goto #3
    [90m2 ──[39m       Core.Compiler.Const(:(Base.getproperty(Base.Main, :Base)), false)
    [90m│   [39m       Core.Compiler.Const(:(Base.getproperty(%10, :string)), false)
    [90m│   [39m       Core.Compiler.Const(:(Base.string("invalid k: ", $(Expr(:static_parameter, 1)))), false)
    [90m│   [39m       Core.Compiler.Const(:((%11)(%12)), false)
    [90m│   [39m       Core.Compiler.Const(:(Base.AssertionError(%13)), false)
    [90m└───[39m       Core.Compiler.Const(:(Base.throw(%14)), false)
    [90m3 ┄─[39m       (N = Main.length(alphabet))
    [90m│   [39m %17 = Main.length(alphabet)[36m::Core.Compiler.Const(4, false)[39m
    [90m│   [39m       (max_index = %17 ^ $(Expr(:static_parameter, 1)))
    [90m│   [39m %19 = (0 < index@_13)[36m::Bool[39m
    [90m└───[39m       goto #5 if not %19
    [90m4 ──[39m       (@_14 = index@_13 <= max_index)
    [90m└───[39m       goto #6
    [90m5 ──[39m       (@_14 = false)
    [90m6 ┄─[39m       goto #8 if not @_14
    [90m7 ──[39m       goto #9
    [90m8 ──[39m %26 = Base.getproperty(Base.Main, :Base)[91m[1m::Any[22m[39m
    [90m│   [39m %27 = Base.getproperty(%26, :string)[91m[1m::Any[22m[39m
    [90m│   [39m %28 = Base.string("invalid index: ", index@_13, " not within 1:", max_index)[36m::String[39m
    [90m│   [39m %29 = (%27)(%28)[91m[1m::Any[22m[39m
    [90m│   [39m %30 = Base.AssertionError(%29)[36m::AssertionError[39m
    [90m└───[39m       Base.throw(%30)
    [90m9 ┄─[39m %32 = Main.eltype(alphabet)[36m::Core.Compiler.Const(BioSymbols.DNA, false)[39m
    [90m│   [39m %33 = Core.apply_type(Main.Vector, %32)[36m::Core.Compiler.Const(Array{BioSymbols.DNA,1}, false)[39m
    [90m│   [39m       (kmer = (%33)(Main.undef, $(Expr(:static_parameter, 1))))
    [90m│   [39m %35 = ($(Expr(:static_parameter, 1)):-1:1)[36m::Core.Compiler.Const(3:-1:1, false)[39m
    [90m│   [39m       (@_9 = Base.iterate(%35))
    [90m│   [39m %37 = (@_9::Core.Compiler.Const((3, 3), false) === nothing)[36m::Core.Compiler.Const(false, false)[39m
    [90m│   [39m %38 = Base.not_int(%37)[36m::Core.Compiler.Const(true, false)[39m
    [90m└───[39m       goto #14 if not %38
    [90m10 ┄[39m %40 = @_9::Tuple{Int64,Int64}[36m::Tuple{Int64,Int64}[39m
    [90m│   [39m       (i = Core.getfield(%40, 1))
    [90m│   [39m %42 = Core.getfield(%40, 2)[36m::Int64[39m
    [90m│   [39m %43 = N::Core.Compiler.Const(4, false)[36m::Core.Compiler.Const(4, false)[39m
    [90m│   [39m %44 = (i - 1)[36m::Int64[39m
    [90m│   [39m       (divisor = %43 ^ %44)
    [90m│   [39m %46 = (index@_13 / divisor)[36m::Float64[39m
    [90m│   [39m %47 = Main.ceil(%46)[36m::Float64[39m
    [90m│   [39m       (alphabet_index = Main.Int(%47))
    [90m│   [39m       (index@_13 = index@_13 % divisor)
    [90m│   [39m %50 = (alphabet_index == 0)[36m::Bool[39m
    [90m└───[39m       goto #12 if not %50
    [90m11 ─[39m       (alphabet_index = N::Core.Compiler.Const(4, false))
    [90m12 ┄[39m %53 = Base.getindex(alphabet, alphabet_index)[36m::BioSymbols.DNA[39m
    [90m│   [39m %54 = kmer[36m::Array{BioSymbols.DNA,1}[39m
    [90m│   [39m %55 = ($(Expr(:static_parameter, 1)) - i)[36m::Int64[39m
    [90m│   [39m %56 = (%55 + 1)[36m::Int64[39m
    [90m│   [39m       Base.setindex!(%54, %53, %56)
    [90m│   [39m       (@_9 = Base.iterate(%35, %42))
    [90m│   [39m %59 = (@_9 === nothing)[36m::Bool[39m
    [90m│   [39m %60 = Base.not_int(%59)[36m::Bool[39m
    [90m└───[39m       goto #14 if not %60
    [90m13 ─[39m       goto #10
    [90m14 ┄[39m %63 = Main.:(var"#1#2")[36m::Core.Compiler.Const(var"#1#2", false)[39m
    [90m│   [39m %64 = Core.typeof(kmer)[36m::Core.Compiler.Const(Array{BioSymbols.DNA,1}, false)[39m
    [90m│   [39m %65 = Core.apply_type(%63, %64)[36m::Core.Compiler.Const(var"#1#2"{Array{BioSymbols.DNA,1}}, false)[39m
    [90m│   [39m       (#1 = %new(%65, kmer))
    [90m│   [39m %67 = #1[36m::var"#1#2"{Array{BioSymbols.DNA,1}}[39m
    [90m│   [39m %68 = Main.ntuple(%67, K)[36m::Tuple{BioSymbols.DNA,BioSymbols.DNA,BioSymbols.DNA}[39m
    [90m└───[39m       return %68


## Kmer to Index

Observe that memory allocations and gc time are zero, while the indexing algorithm scales linearly with the size of k.
Linear scaling to size of k while the # of possible kmers increases exponentially means that this approach should scale better than 


```julia
ks = []
results = []
ProgressMeter.@showprogress for k in Primes.primes(3, 32)
    kmer = Tuple(BioSequences.randdnaseq(k))
    result = BenchmarkTools.@benchmark kmer_to_index($kmer, $DNA_ALPHABET)
    push!(ks, k)
    push!(results, result)
end
```

    [32mProgress: 100%|█████████████████████████████████████████| Time: 0:00:29[39m


assert that allocations and memory usage are zero


```julia
first(results)
```




    BenchmarkTools.Trial: 
      memory estimate:  0 bytes
      allocs estimate:  0
      --------------
      minimum time:     37.932 ns (0.00% GC)
      median time:      37.933 ns (0.00% GC)
      mean time:        38.424 ns (0.00% GC)
      maximum time:     328.004 ns (0.00% GC)
      --------------
      samples:          10000
      evals/sample:     992




```julia
Test.@testset "Test kmer <=> index transformations allocations" begin
    for result in results
        Test.@test result.allocs == 0
        Test.@test all(x -> x == 0, result.gctimes)
    end
end
```

    [37m[1mTest Summary:                                   | [22m[39m[32m[1mPass  [22m[39m[36m[1mTotal[22m[39m
    Test kmer <=> index transformations allocations | [32m  20  [39m[36m   20[39m





    Test.DefaultTestSet("Test kmer <=> index transformations allocations", Any[], 20, false)




```julia
xs = Float64[]
ys = Float64[]
subsampling_size = 10
for (k, result) in zip(ks, results)
    for time in rand(result.times, subsampling_size)
        push!(xs, k)
        push!(ys, time)
    end
end

p = StatsPlots.scatter(
    xs,
    ys,
    title = "kmer -> index conversion for DNA alphabet",
    ylabel="median nano-seconds per lookup",
    xlabel="k length",
    label="benchmark results",
    legend=:outertopright
)

linear_model = GLM.lm(GLM.@formula(y ~ x), DataFrames.DataFrame(x = xs, y = ys))
fit_xs = collect(minimum(xs):maximum(xs))
fit_ys = map(x -> GLM.coef(linear_model)[1] + GLM.coef(linear_model)[2] * x, fit_xs)

StatsPlots.plot!(p, 
    fit_xs,
    fit_ys,
    label="fit trendline"
)
```




<!DOCTYPE html>
<html>
    <head>
        <title>Plots.jl</title>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8">
        <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    </head>
    <body>
            <div id="f3701ce4-bb03-49f2-a61e-e4f167ea0eed" style="width:600px;height:400px;"></div>
    <script>
    PLOT = document.getElementById('f3701ce4-bb03-49f2-a61e-e4f167ea0eed');
    Plotly.plot(PLOT, [
    {
        "xaxis": "x1",
        "colorbar": {
            "title": ""
        },
        "yaxis": "y1",
        "x": [
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0
        ],
        "showlegend": true,
        "mode": "markers",
        "name": "benchmark results",
        "zmin": null,
        "legendgroup": "benchmark results",
        "marker": {
            "symbol": "circle",
            "color": "rgba(0, 154, 250, 1.000)",
            "line": {
                "color": "rgba(0, 0, 0, 1.000)",
                "width": 1
            },
            "size": 8
        },
        "zmax": null,
        "y": [
            37.93346774193548,
            41.108870967741936,
            37.93346774193548,
            37.93346774193548,
            37.93346774193548,
            37.943548387096776,
            37.93346774193548,
            37.93346774193548,
            37.93346774193548,
            37.934475806451616,
            59.45066124109868,
            58.84028484231943,
            59.45066124109868,
            115.24923702950153,
            58.85045778229908,
            58.84028484231943,
            59.15564598168871,
            64.48626653102747,
            63.05188199389624,
            59.461851475076294,
            85.82120582120582,
            85.82120582120582,
            85.8108108108108,
            85.82120582120582,
            85.8108108108108,
            85.82120582120582,
            85.82120582120582,
            85.8108108108108,
            85.82120582120582,
            86.72453222453223,
            135.83046964490262,
            143.4020618556701,
            135.84192439862542,
            137.9495990836197,
            135.81786941580756,
            135.81901489117985,
            135.81901489117985,
            135.83046964490262,
            135.83046964490262,
            135.82016036655213,
            161.58163265306123,
            163.69897959183675,
            161.8877551020408,
            161.59438775510205,
            161.58163265306123,
            161.59438775510205,
            161.58163265306123,
            165.48469387755102,
            161.59438775510205,
            161.58163265306123,
            218.29745596868884,
            226.34050880626222,
            218.29745596868884,
            224.0508806262231,
            218.29941291585126,
            219.51076320939336,
            218.61056751467711,
            225.2054794520548,
            224.0508806262231,
            224.0508806262231,
            248.91959798994975,
            244.39698492462313,
            244.39698492462313,
            253.69346733668343,
            294.3718592964824,
            244.3718592964824,
            245.57788944723617,
            245.60552763819095,
            244.39698492462313,
            261.93467336683415,
            301.7716535433071,
            302.003937007874,
            302.0472440944882,
            310.86614173228344,
            302.0472440944882,
            301.73228346456693,
            302.3622047244094,
            301.73228346456693,
            301.7716535433071,
            301.7716535433071,
            389.7029702970297,
            387.9207920792079,
            389.65346534653463,
            389.7029702970297,
            387.8712871287129,
            387.9207920792079,
            389.7029702970297,
            387.2277227722772,
            390.5940594059406,
            387.2772277227723,
            432.713567839196,
            424.8241206030151,
            423.36683417085425,
            440.6532663316583,
            424.8241206030151,
            424.8743718592965,
            424.8241206030151,
            432.713567839196,
            432.713567839196,
            424.8241206030151
        ],
        "type": "scatter"
    },
    {
        "xaxis": "x1",
        "colorbar": {
            "title": ""
        },
        "yaxis": "y1",
        "x": [
            3.0,
            4.0,
            5.0,
            6.0,
            7.0,
            8.0,
            9.0,
            10.0,
            11.0,
            12.0,
            13.0,
            14.0,
            15.0,
            16.0,
            17.0,
            18.0,
            19.0,
            20.0,
            21.0,
            22.0,
            23.0,
            24.0,
            25.0,
            26.0,
            27.0,
            28.0,
            29.0,
            30.0,
            31.0
        ],
        "showlegend": true,
        "mode": "lines",
        "name": "fit trendline",
        "zmin": null,
        "legendgroup": "fit trendline",
        "zmax": null,
        "line": {
            "color": "rgba(227, 111, 71, 1.000)",
            "shape": "linear",
            "dash": "solid",
            "width": 1
        },
        "y": [
            31.691860164570713,
            45.49325945481948,
            59.294658745068254,
            73.09605803531701,
            86.8974573255658,
            100.69885661581455,
            114.50025590606333,
            128.3016551963121,
            142.10305448656086,
            155.90445377680965,
            169.7058530670584,
            183.50725235730718,
            197.30865164755593,
            211.11005093780471,
            224.9114502280535,
            238.71284951830225,
            252.514248808551,
            266.3156480987998,
            280.11704738904854,
            293.9184466792973,
            307.71984596954604,
            321.52124525979485,
            335.3226445500436,
            349.12404384029236,
            362.92544313054117,
            376.7268424207899,
            390.5282417110387,
            404.3296410012874,
            418.13104029153624
        ],
        "type": "scatter"
    }
]
, {
    "showlegend": true,
    "xaxis": {
        "showticklabels": true,
        "gridwidth": 0.5,
        "tickvals": [
            5.0,
            10.0,
            15.0,
            20.0,
            25.0,
            30.0
        ],
        "visible": true,
        "ticks": "inside",
        "range": [
            2.16,
            31.84
        ],
        "domain": [
            0.07646908719743364,
            0.9934383202099737
        ],
        "tickmode": "array",
        "linecolor": "rgba(0, 0, 0, 1.000)",
        "showgrid": true,
        "title": "k length",
        "mirror": false,
        "tickangle": 0,
        "showline": true,
        "gridcolor": "rgba(0, 0, 0, 0.100)",
        "titlefont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 15
        },
        "tickcolor": "rgb(0, 0, 0)",
        "ticktext": [
            "5",
            "10",
            "15",
            "20",
            "25",
            "30"
        ],
        "zeroline": false,
        "type": "-",
        "tickfont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "zerolinecolor": "rgba(0, 0, 0, 1.000)",
        "anchor": "y1"
    },
    "paper_bgcolor": "rgba(255, 255, 255, 1.000)",
    "annotations": [
        {
            "yanchor": "top",
            "xanchor": "center",
            "rotation": -0.0,
            "y": 1.0,
            "font": {
                "color": "rgba(0, 0, 0, 1.000)",
                "family": "sans-serif",
                "size": 20
            },
            "yref": "paper",
            "showarrow": false,
            "text": "kmer -> index conversion for DNA alphabet",
            "xref": "paper",
            "x": 0.5349537037037038
        }
    ],
    "height": 400,
    "margin": {
        "l": 0,
        "b": 20,
        "r": 0,
        "t": 20
    },
    "plot_bgcolor": "rgba(255, 255, 255, 1.000)",
    "yaxis": {
        "showticklabels": true,
        "gridwidth": 0.5,
        "tickvals": [
            100.0,
            200.0,
            300.0,
            400.0
        ],
        "visible": true,
        "ticks": "inside",
        "range": [
            19.423017979558086,
            452.9221085166709
        ],
        "domain": [
            0.07581474190726165,
            0.9415463692038496
        ],
        "tickmode": "array",
        "linecolor": "rgba(0, 0, 0, 1.000)",
        "showgrid": true,
        "title": "median nano-seconds per lookup",
        "mirror": false,
        "tickangle": 0,
        "showline": true,
        "gridcolor": "rgba(0, 0, 0, 0.100)",
        "titlefont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 15
        },
        "tickcolor": "rgb(0, 0, 0)",
        "ticktext": [
            "100",
            "200",
            "300",
            "400"
        ],
        "zeroline": false,
        "type": "-",
        "tickfont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "zerolinecolor": "rgba(0, 0, 0, 1.000)",
        "anchor": "x1"
    },
    "legend": {
        "tracegroupgap": 0,
        "bordercolor": "rgba(0, 0, 0, 1.000)",
        "bgcolor": "rgba(255, 255, 255, 1.000)",
        "font": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "y": 1.0,
        "x": 1.0
    },
    "width": 600
}
);
    </script>

    </body>
</html>




## Index to Kmer


```julia
ks = []
results = []
ProgressMeter.@showprogress for k in Primes.primes(3, 32)
    index = rand(1:length(DNA_ALPHABET)^k)
    result = BenchmarkTools.@benchmark index_to_kmer($index, $(Val(k)), $DNA_ALPHABET)
    push!(ks, k)
    push!(results, result)
end
```

    [32mProgress: 100%|█████████████████████████████████████████| Time: 0:00:32[39m



```julia
first(results)
```




    BenchmarkTools.Trial: 
      memory estimate:  96 bytes
      allocs estimate:  1
      --------------
      minimum time:     109.483 ns (0.00% GC)
      median time:      111.470 ns (0.00% GC)
      mean time:        128.347 ns (10.70% GC)
      maximum time:     10.419 μs (98.80% GC)
      --------------
      samples:          10000
      evals/sample:     929




```julia
xs = Float64[]
ys = Float64[]
subsampling_size = 10
for (k, result) in zip(ks, results)
    for time in rand(result.times, subsampling_size)
        push!(xs, k)
        push!(ys, time)
    end
end

p = StatsPlots.scatter(
    xs,
    ys,
    title = "index -> kmer conversion for DNA alphabet",
    ylabel="median nano-seconds per conversion",
    xlabel="k length",
    label="benchmark results",
    legend=:outertopright
)

linear_model = GLM.lm(GLM.@formula(y ~ x), DataFrames.DataFrame(x = xs, y = ys))
fit_xs = collect(minimum(xs):maximum(xs))
fit_ys = map(x -> GLM.coef(linear_model)[1] + GLM.coef(linear_model)[2] * x, fit_xs)

StatsPlots.plot!(p, 
    fit_xs,
    fit_ys,
    label="fit trendline"
)
```




<!DOCTYPE html>
<html>
    <head>
        <title>Plots.jl</title>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8">
        <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    </head>
    <body>
            <div id="26a05790-bc03-49f7-b4a6-76b0a7fd1c1f" style="width:600px;height:400px;"></div>
    <script>
    PLOT = document.getElementById('26a05790-bc03-49f7-b4a6-76b0a7fd1c1f');
    Plotly.plot(PLOT, [
    {
        "xaxis": "x1",
        "colorbar": {
            "title": ""
        },
        "yaxis": "y1",
        "x": [
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            3.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            5.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            7.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            11.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            13.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            17.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            19.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            23.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            29.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0,
            31.0
        ],
        "showlegend": true,
        "mode": "markers",
        "name": "benchmark results",
        "zmin": null,
        "legendgroup": "benchmark results",
        "marker": {
            "symbol": "circle",
            "color": "rgba(0, 154, 250, 1.000)",
            "line": {
                "color": "rgba(0, 0, 0, 1.000)",
                "width": 1
            },
            "size": 8
        },
        "zmax": null,
        "y": [
            112.52960172228202,
            112.09903121636168,
            111.70075349838537,
            113.64908503767492,
            143.5091496232508,
            143.04736275565125,
            126.98600645855758,
            112.93864370290635,
            112.13132400430571,
            110.72120559741657,
            171.90666666666667,
            175.31866666666667,
            172.08,
            171.34666666666666,
            172.30533333333332,
            177.6,
            172.17333333333335,
            179.24133333333333,
            170.62666666666667,
            189.13333333333333,
            225.10162601626016,
            222.7459349593496,
            222.8861788617886,
            226.3617886178862,
            223.6382113821138,
            222.9491869918699,
            259.0650406504065,
            222.9878048780488,
            225.5487804878049,
            233.51626016260164,
            304.68503937007875,
            357.12598425196853,
            309.48818897637796,
            320.98425196850394,
            304.88188976377955,
            305.0787401574803,
            303.7795275590551,
            303.7795275590551,
            320.5511811023622,
            304.1732283464567,
            350.74766355140184,
            351.2616822429907,
            352.10280373831773,
            353.31775700934577,
            348.7383177570093,
            353.8317757009346,
            354.5327102803738,
            350.93457943925233,
            351.49532710280374,
            351.58878504672896,
            473.4848484848485,
            473.1818181818182,
            447.32323232323233,
            447.72222222222223,
            471.1111111111111,
            472.3787878787879,
            502.57575757575756,
            447.37373737373736,
            448.3838383838384,
            453.73737373737373,
            497.7783505154639,
            497.0103092783505,
            497.2680412371134,
            497.5257731958763,
            517.7835051546392,
            499.12371134020617,
            521.5979381443299,
            497.5773195876289,
            497.4742268041237,
            519.5360824742268,
            598.4269662921348,
            672.3595505617977,
            597.8089887640449,
            621.685393258427,
            600.3370786516854,
            592.3033707865169,
            598.370786516854,
            597.4157303370787,
            623.876404494382,
            630.7865168539325,
            750.5,
            779.25,
            755.25,
            750.5,
            785.0,
            754.6666666666666,
            779.3333333333334,
            778.0,
            755.0,
            868.3333333333334,
            818.8235294117648,
            852.0,
            819.4235294117647,
            848.5882352941177,
            819.4117647058823,
            820.4705882352941,
            822.1176470588235,
            819.5294117647059,
            868.0,
            838.4705882352941
        ],
        "type": "scatter"
    },
    {
        "xaxis": "x1",
        "colorbar": {
            "title": ""
        },
        "yaxis": "y1",
        "x": [
            3.0,
            4.0,
            5.0,
            6.0,
            7.0,
            8.0,
            9.0,
            10.0,
            11.0,
            12.0,
            13.0,
            14.0,
            15.0,
            16.0,
            17.0,
            18.0,
            19.0,
            20.0,
            21.0,
            22.0,
            23.0,
            24.0,
            25.0,
            26.0,
            27.0,
            28.0,
            29.0,
            30.0,
            31.0
        ],
        "showlegend": true,
        "mode": "lines",
        "name": "fit trendline",
        "zmin": null,
        "legendgroup": "fit trendline",
        "zmax": null,
        "line": {
            "color": "rgba(227, 111, 71, 1.000)",
            "shape": "linear",
            "dash": "solid",
            "width": 1
        },
        "y": [
            116.15862146444934,
            141.2906911441968,
            166.42276082394432,
            191.5548305036918,
            216.6869001834393,
            241.81896986318677,
            266.95103954293427,
            292.08310922268174,
            317.2151789024293,
            342.34724858217675,
            367.4793182619242,
            392.61138794167175,
            417.7434576214192,
            442.8755273011667,
            468.0075969809142,
            493.13966666066165,
            518.2717363404091,
            543.4038060201566,
            568.5358756999042,
            593.6679453796517,
            618.8000150593991,
            643.9320847391466,
            669.0641544188941,
            694.1962240986416,
            719.328293778389,
            744.4603634581366,
            769.5924331378841,
            794.7245028176316,
            819.856572497379
        ],
        "type": "scatter"
    }
]
, {
    "showlegend": true,
    "xaxis": {
        "showticklabels": true,
        "gridwidth": 0.5,
        "tickvals": [
            5.0,
            10.0,
            15.0,
            20.0,
            25.0,
            30.0
        ],
        "visible": true,
        "ticks": "inside",
        "range": [
            2.16,
            31.84
        ],
        "domain": [
            0.07646908719743364,
            0.9934383202099737
        ],
        "tickmode": "array",
        "linecolor": "rgba(0, 0, 0, 1.000)",
        "showgrid": true,
        "title": "k length",
        "mirror": false,
        "tickangle": 0,
        "showline": true,
        "gridcolor": "rgba(0, 0, 0, 0.100)",
        "titlefont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 15
        },
        "tickcolor": "rgb(0, 0, 0)",
        "ticktext": [
            "5",
            "10",
            "15",
            "20",
            "25",
            "30"
        ],
        "zeroline": false,
        "type": "-",
        "tickfont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "zerolinecolor": "rgba(0, 0, 0, 1.000)",
        "anchor": "y1"
    },
    "paper_bgcolor": "rgba(255, 255, 255, 1.000)",
    "annotations": [
        {
            "yanchor": "top",
            "xanchor": "center",
            "rotation": -0.0,
            "y": 1.0,
            "font": {
                "color": "rgba(0, 0, 0, 1.000)",
                "family": "sans-serif",
                "size": 20
            },
            "yref": "paper",
            "showarrow": false,
            "text": "index -> kmer conversion for DNA alphabet",
            "xref": "paper",
            "x": 0.5349537037037038
        }
    ],
    "height": 400,
    "margin": {
        "l": 0,
        "b": 20,
        "r": 0,
        "t": 20
    },
    "plot_bgcolor": "rgba(255, 255, 255, 1.000)",
    "yaxis": {
        "showticklabels": true,
        "gridwidth": 0.5,
        "tickvals": [
            200.0,
            400.0,
            600.0,
            800.0
        ],
        "visible": true,
        "ticks": "inside",
        "range": [
            87.99284176533907,
            891.0616971654109
        ],
        "domain": [
            0.07581474190726165,
            0.9415463692038496
        ],
        "tickmode": "array",
        "linecolor": "rgba(0, 0, 0, 1.000)",
        "showgrid": true,
        "title": "median nano-seconds per conversion",
        "mirror": false,
        "tickangle": 0,
        "showline": true,
        "gridcolor": "rgba(0, 0, 0, 0.100)",
        "titlefont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 15
        },
        "tickcolor": "rgb(0, 0, 0)",
        "ticktext": [
            "200",
            "400",
            "600",
            "800"
        ],
        "zeroline": false,
        "type": "-",
        "tickfont": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "zerolinecolor": "rgba(0, 0, 0, 1.000)",
        "anchor": "x1"
    },
    "legend": {
        "tracegroupgap": 0,
        "bordercolor": "rgba(0, 0, 0, 1.000)",
        "bgcolor": "rgba(255, 255, 255, 1.000)",
        "font": {
            "color": "rgba(0, 0, 0, 1.000)",
            "family": "sans-serif",
            "size": 11
        },
        "y": 1.0,
        "x": 1.0
    },
    "width": 600
}
);
    </script>

    </body>
</html>



