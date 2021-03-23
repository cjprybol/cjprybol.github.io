---
layout: post  
---

The goal of this post is to re-create the NCBI taxonomy database in Neo4J. The overall end-goal is to build a pan-genome database in Neo4J that allows for rapid (re) generation of various pan-genomes

First we'll make sure that the cypher-shell command is in my path to enable scripted interaction with my local neo4j database


```julia
if !occursin("cypher-shell", ENV["PATH"])
    ENV["PATH"] = "/Users/cameronprybol/Software/cypher-shell:$(ENV["PATH"])"
end
```




    "/Users/cameronprybol/Software/cypher-shell:/Applications/Julia-1.5.app/Contents/Resources/julia/bin:/Applications/Julia-1.5.app/Contents/Resources/julia/bin:/Users/cameronprybol/miniconda/bin:/Users/cameronprybol/.gem/ruby/2.6.0/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"



Next we'll import some helpful packages


```julia
import Pkg
pkgs = [
    "DataFrames",
    "ProgressMeter",
    "LightGraphs",
    "MetaGraphs",
    "uCSV"
]

for pkg in pkgs
    try
        Pkg.add(pkg)
    catch
#         # tried to install an unregistered local package
    end
    eval(Meta.parse("import $pkg"))
end
```

    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`
    [32m[1m  Resolving[22m[39m package versions...
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Project.toml`
    [32m[1mNo Changes[22m[39m to `~/.julia/environments/v1.5/Manifest.toml`


Here we'll create a local folder to hold the NCBI taxonomy information that we'll download


```julia
TASK = "ncbi-taxonomy"
DATE = "2021-03-21"
DIR = "$(homedir())/$(DATE)-$(TASK)"
if !isdir(DIR)
    mkdir(DIR)
end
cd(DIR)
```

In this next set of steps we will download the NCBI taxonomy .tar.gz archive and expand out the contents


```julia
taxdump_url = "https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz"
```




    "https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz"




```julia
taxdump_local_tarball = "$(DIR)/$(basename(taxdump_url))"
```




    "/Users/cameronprybol/2021-03-21-ncbi-taxonomy/taxdump.tar.gz"




```julia
if !isfile(taxdump_local_tarball)
    download(taxdump_url, taxdump_local_tarball)
end
```


```julia
taxdump_out = replace(taxdump_local_tarball, ".tar.gz" => "")
if !isdir(taxdump_out)
    mkpath(taxdump_out)
    run(`tar -xvzf $(taxdump_local_tarball) -C $(taxdump_out)`)
end
```


```julia
readdir(taxdump_out)
```




    10-element Array{String,1}:
     ".ipynb_checkpoints"
     "citations.dmp"
     "delnodes.dmp"
     "division.dmp"
     "gc.prt"
     "gencode.dmp"
     "merged.dmp"
     "names.dmp"
     "nodes.dmp"
     "readme.txt"



Here we will create an in-memory dataframe to capture the contents of the names.dmp file


```julia
# Taxonomy names file (names.dmp):
# 	tax_id					-- the id of node associated with this name
# 	name_txt				-- name itself
# 	unique name				-- the unique variant of this name if name not unique
# 	name class				-- (synonym, common name, ...)

names_dmp = DataFrames.DataFrame(
    tax_id = Int[],
    name_txt = String[],
    unique_name = String[],
    name_class = String[]
)
ProgressMeter.@showprogress for line in split(read(open("$(taxdump_out)/names.dmp"), String), "\t|\n")
    if isempty(line)
        continue
    else
        (tax_id_string, name_txt, unique_name, name_class) = split(line, "\t|\t")
        tax_id = parse(Int, tax_id_string)
        row = (;tax_id, name_txt, unique_name, name_class)
        push!(names_dmp, row)
    end
end
names_dmp
```

    [32mProgress: 100%|█████████████████████████████████████████| Time: 0:00:16[39m39m





<table class="data-frame"><thead><tr><th></th><th>tax_id</th><th>name_txt</th></tr><tr><th></th><th>Int64</th><th>String</th></tr></thead><tbody><p>3,389,140 rows × 4 columns (omitted printing of 2 columns)</p><tr><th>1</th><td>1</td><td>all</td></tr><tr><th>2</th><td>1</td><td>root</td></tr><tr><th>3</th><td>2</td><td>Bacteria</td></tr><tr><th>4</th><td>2</td><td>bacteria</td></tr><tr><th>5</th><td>2</td><td>eubacteria</td></tr><tr><th>6</th><td>2</td><td>Monera</td></tr><tr><th>7</th><td>2</td><td>Procaryotae</td></tr><tr><th>8</th><td>2</td><td>Prokaryotae</td></tr><tr><th>9</th><td>2</td><td>Prokaryota</td></tr><tr><th>10</th><td>2</td><td>prokaryote</td></tr><tr><th>11</th><td>2</td><td>prokaryotes</td></tr><tr><th>12</th><td>6</td><td>Azorhizobium Dreyfus et al. 1988 emend. Lang et al. 2013</td></tr><tr><th>13</th><td>6</td><td>Azorhizobium</td></tr><tr><th>14</th><td>7</td><td>ATCC 43989</td></tr><tr><th>15</th><td>7</td><td>Azorhizobium caulinodans Dreyfus et al. 1988</td></tr><tr><th>16</th><td>7</td><td>Azorhizobium caulinodans</td></tr><tr><th>17</th><td>7</td><td>Azotirhizobium caulinodans</td></tr><tr><th>18</th><td>7</td><td>CCUG 26647</td></tr><tr><th>19</th><td>7</td><td>DSM 5975</td></tr><tr><th>20</th><td>7</td><td>IFO 14845</td></tr><tr><th>21</th><td>7</td><td>JCM 20966</td></tr><tr><th>22</th><td>7</td><td>LMG 6465</td></tr><tr><th>23</th><td>7</td><td>LMG:6465</td></tr><tr><th>24</th><td>7</td><td>NBRC 14845</td></tr><tr><th>25</th><td>7</td><td>ORS 571</td></tr><tr><th>26</th><td>9</td><td>Acyrthosiphon pisum symbiont P</td></tr><tr><th>27</th><td>9</td><td>Buchnera aphidicola Munson et al. 1991</td></tr><tr><th>28</th><td>9</td><td>Buchnera aphidicola</td></tr><tr><th>29</th><td>9</td><td>primary endosymbiont of Schizaphis graminum</td></tr><tr><th>30</th><td>10</td><td>Cellvibrio (ex Winogradsky 1929) Blackall et al. 1986 emend. Humphry et al. 2003</td></tr><tr><th>&vellip;</th><td>&vellip;</td><td>&vellip;</td></tr></tbody></table>



We can see that there are sometimes multiple entries for each tax_id, the unique identifier that we will be using


```julia
unique_tax_ids = unique(names_dmp[!, "tax_id"])
```




    2317173-element Array{Int64,1}:
           1
           2
           6
           7
           9
          10
          11
          13
          14
          16
          17
          18
          19
           ⋮
     2820007
     2820021
     2820040
     2820056
     2820085
     2820136
     2820147
     2820189
     2820209
     2820263
     2820280
     2820281



Here we will group the names.dmp data by tax_id, create a node in the graph for each tax_id, and sanitize and merge information appropriately


```julia
ncbi_taxonomy = MetaGraphs.MetaDiGraph(length(unique_tax_ids))
ProgressMeter.@showprogress for (index, group) in enumerate(collect(DataFrames.groupby(names_dmp, "tax_id")))
    MetaGraphs.set_prop!(ncbi_taxonomy, index, :tax_id, group[1, "tax_id"])
    for row in DataFrames.eachrow(group)
        unique_name = isempty(row["unique_name"]) ? row["name_txt"] : row["unique_name"]
        # remove quotes since neo4j doesn't like them
        unique_name = replace(unique_name, '"' => "")
        # replace spaces and dashes with underscores
        name_class = Symbol(replace(replace(row["name_class"], r"\s+" => "-"), "-" => "_"))
#         name_class = Symbol(row["name_class"])
        if haskey(MetaGraphs.props(ncbi_taxonomy, index), name_class)
            current_value = MetaGraphs.get_prop(ncbi_taxonomy, index, name_class)
            if (current_value isa Array) && !(unique_name in current_value)
                new_value = [current_value..., unique_name]
                MetaGraphs.set_prop!(ncbi_taxonomy, index, name_class, new_value)
            elseif !(current_value isa Array) && (current_value != unique_name)
                new_value = [current_value, unique_name]
                MetaGraphs.set_prop!(ncbi_taxonomy, index, name_class, new_value)
            else
                continue
            end
        else
            MetaGraphs.set_prop!(ncbi_taxonomy, index, name_class, unique_name)
        end
    end
end
```

    [32mProgress: 100%|█████████████████████████████████████████| Time: 0:04:04[39m
    [32mProgress: 100%|█████████████████████████████████████████| Time: 0:01:49[39m


Here we can see that there are divisions projected onto the tree that will allow easy grouping by taxonomic "group"s such as primates, viruses, phages, etc.


```julia
divisions = Dict()
for line in split(read(open("$(taxdump_out)/division.dmp"), String), "\t|\n")
    if !isempty(line)
        (id_string, shorthand, full_name, notes) = split(line, "\t|\t")
        id = parse(Int, id_string)
        divisions[id] = Dict(:division_cde => shorthand, :division_name => full_name)
    end
end
divisions
```




    Dict{Any,Any} with 12 entries:
      2  => Dict{Symbol,SubString{String}}(:division_name=>"Mammals",:division_cde=…
      11 => Dict{Symbol,SubString{String}}(:division_name=>"Environmental samples",…
      0  => Dict{Symbol,SubString{String}}(:division_name=>"Bacteria",:division_cde…
      7  => Dict{Symbol,SubString{String}}(:division_name=>"Synthetic and Chimeric"…
      9  => Dict{Symbol,SubString{String}}(:division_name=>"Viruses",:division_cde=…
      10 => Dict{Symbol,SubString{String}}(:division_name=>"Vertebrates",:division_…
      8  => Dict{Symbol,SubString{String}}(:division_name=>"Unassigned",:division_c…
      6  => Dict{Symbol,SubString{String}}(:division_name=>"Rodents",:division_cde=…
      4  => Dict{Symbol,SubString{String}}(:division_name=>"Plants and Fungi",:divi…
      3  => Dict{Symbol,SubString{String}}(:division_name=>"Phages",:division_cde=>…
      5  => Dict{Symbol,SubString{String}}(:division_name=>"Primates",:division_cde…
      1  => Dict{Symbol,SubString{String}}(:division_name=>"Invertebrates",:divisio…



And finally for the data import, here we will read in the nodes.dmp file which contains lots of other metadata about each node in the NCBI taxonomic tree. We will cross-reference the division information above to add the rest of the division information. It could be helpful to make divisions their own nodes and then create relationships between taxonomic nodes and division nodes, but we'll go with the metadata in the taxonomic nodes for now


```julia
node_2_taxid_map = map(index -> ncbi_taxonomy.vprops[index][:tax_id], LightGraphs.vertices(ncbi_taxonomy))
ProgressMeter.@showprogress for line in split(read(open("$(taxdump_out)/nodes.dmp"), String), "\t|\n")
    if isempty(line)
        continue
    else
        (tax_id_string, parent_tax_id_string, rank, embl_code, division_id_string) = split(line, "\t|\t")
        
        
        division_id = parse(Int, division_id_string)
        
        tax_id = parse(Int, tax_id_string)
        lightgraphs_tax_ids = searchsorted(node_2_taxid_map, tax_id)
        @assert length(lightgraphs_tax_ids) == 1
        lightgraphs_tax_id = first(lightgraphs_tax_ids)
        
        parent_tax_id = parse(Int, parent_tax_id_string)
        lightgraphs_parent_tax_ids = searchsorted(node_2_taxid_map, parent_tax_id)
        @assert length(lightgraphs_parent_tax_ids) == 1
        lightgraphs_parent_tax_id = first(lightgraphs_parent_tax_ids)
        
        LightGraphs.add_edge!(ncbi_taxonomy, lightgraphs_tax_id, lightgraphs_parent_tax_id)
        MetaGraphs.set_prop!(ncbi_taxonomy, lightgraphs_tax_id, :rank, rank)
        # these should probably be broken out as independent nodes!
        MetaGraphs.set_prop!(ncbi_taxonomy, lightgraphs_tax_id, :division_id, division_id)
        MetaGraphs.set_prop!(ncbi_taxonomy, lightgraphs_tax_id, :division_cde, divisions[division_id][:division_cde])
        MetaGraphs.set_prop!(ncbi_taxonomy, lightgraphs_tax_id, :division_name, divisions[division_id][:division_name])
    end
end
```

Here we can see that there are an equal number of edges as their are nodes


```julia
collect(LightGraphs.edges(ncbi_taxonomy))
```




    2317173-element Array{LightGraphs.SimpleGraphs.SimpleEdge{Int64},1}:
     Edge 1 => 1
     Edge 2 => 100805
     Edge 3 => 280007
     Edge 4 => 3
     Edge 5 => 14946
     Edge 6 => 1384594
     Edge 7 => 1338
     Edge 8 => 165190
     Edge 9 => 8
     Edge 10 => 14787
     Edge 11 => 10
     Edge 12 => 174307
     Edge 13 => 2314073
     ⋮
     Edge 2317162 => 2184961
     Edge 2317163 => 76865
     Edge 2317164 => 41358
     Edge 2317165 => 1334851
     Edge 2317166 => 1480
     Edge 2317167 => 598527
     Edge 2317168 => 145805
     Edge 2317169 => 120969
     Edge 2317170 => 48151
     Edge 2317171 => 16034
     Edge 2317172 => 166094
     Edge 2317173 => 2317172



Here we'll produce a list of all of the metadata fields that are associated with our taxonomic nodes. Not every node will have all of these values, but this will allow us to write our in-memory graph to .tsv files for importing into neo4j


```julia
column_names = Set(k for vertex in LightGraphs.vertices(ncbi_taxonomy) for k in keys(ncbi_taxonomy.vprops[vertex]))
column_names = sort(collect(column_names))
# column_names = filter(x -> string(x) != "in-part", column_names)
```




    18-element Array{Symbol,1}:
     :acronym
     :authority
     :blast_name
     :common_name
     :division_cde
     :division_id
     :division_name
     :equivalent_name
     :genbank_acronym
     :genbank_common_name
     :genbank_synonym
     :in_part
     :includes
     :rank
     :scientific_name
     :synonym
     :tax_id
     :type_material



Here in the next 2 steps we write out .tsv files for our nodes + metadata and our edges


```julia
open("$(DIR)/ncbi_taxonomy.nodes.tsv", "w") do io
    header = ["node", string.(column_names)...]
    println(io, join(header, '\t'))
    for vertex in collect(LightGraphs.vertices(ncbi_taxonomy))
        fields = String[]
        for k in column_names
            field = get(ncbi_taxonomy.vprops[vertex], k, "")
            field = string.(field)
            if field isa Array
                field = join(field, ';')
            end
            push!(fields, field)
        end
        row = ["$(vertex)", fields...]
        println(io, join(row, '\t'))
    end
end
```


```julia
open("$(DIR)/ncbi_taxonomy.edges.tsv", "w") do io
    header = ["src", "dst"]
    println(io, join(header, '\t'))
    for edge in collect(LightGraphs.edges(ncbi_taxonomy))
        src_tax_id = ncbi_taxonomy.vprops[edge.src][:tax_id]
        dst_tax_id = ncbi_taxonomy.vprops[edge.dst][:tax_id]
        println(io, join(string.([src_tax_id, dst_tax_id]), "\t"))
    end
end
```


```julia
function list_databases()
    io = open(`cypher-shell --address neo4j://localhost:7687 --username neo4j --password password --database system --format auto "show databases"`)
    return DataFrames.DataFrame(uCSV.read(io, header=1, quotes='"', encodings=Dict("FALSE" => false, "TRUE" => true))...)
end
```




    list_databases (generic function with 1 method)




```julia
function create_database(database_id)
    current_databases = list_databases()
    if database_id in current_databases[!, "name"]
        return
    else
        run(`cypher-shell --address neo4j://localhost:7687 --username neo4j --password password --database system --format auto "create database $(database_id)"`)
    end
end
```




    create_database (generic function with 1 method)




```julia
function cypher(database_id, cmd)
    run(`cypher-shell --address neo4j://localhost:7687 --username neo4j --password password --database $(database_id) --format auto $(cmd)`)
end
```




    cypher (generic function with 1 method)



Here we can see a list of databases that we already have


```julia
list_databases()
```




<table class="data-frame"><thead><tr><th></th><th>name</th><th> address</th><th> role</th><th> requestedStatus</th><th> currentStatus</th><th> error</th></tr><tr><th></th><th>String</th><th>String</th><th>String</th><th>String</th><th>String</th><th>String</th></tr></thead><tbody><p>7 rows × 7 columns (omitted printing of 1 columns)</p><tr><th>1</th><td>dataset</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>2</th><td>ncbitaxonomy</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>3</th><td>neo4j</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>4</th><td>panmetagenome</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>5</th><td>system</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>6</th><td>taxid230604</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr><tr><th>7</th><td>test</td><td>localhost:7687</td><td>standalone</td><td>online</td><td>online</td><td></td></tr></tbody></table>



The neo4j database name that we will use for this ncbi taxonomic tree is:


```julia
database_id = "ncbitaxonomy"
```




    "ncbitaxonomy"



Here we will create the database if it doesn't exist


```julia
create_database(database_id)
```




    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4msystem[24m [4m--format[24m [4mauto[24m [4m'create database ncbitaxonomy'[24m`, ProcessExited(0))



Here we will set constrains that no two nodes have the same taxonomic id and no two nodes have the same scientific name


```julia
@time cypher(database_id, "CREATE CONSTRAINT ON (t:Taxonomy) ASSERT t.tax_id IS UNIQUE")
@time cypher(database_id, "CREATE CONSTRAINT ON (t:Taxonomy) ASSERT t.`scientific name` IS UNIQUE")
```

      1.245018 seconds (134 allocations: 7.984 KiB)
      1.235412 seconds (251 allocations: 17.656 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m'CREATE CONSTRAINT ON (t:Taxonomy) ASSERT t.\`scientific name\` IS UNIQUE'[24m`, ProcessExited(0))



Here we will create the nodes


```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
MERGE (t:Taxonomy {tax_id: row.tax_id})
"""
@time cypher(database_id, cmd)
```

     70.661302 seconds (2.24 k allocations: 69.344 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.tax_id IS NOT NULL[24m
    [4mMERGE (t:Taxonomy {tax_id: row.tax_id})[24m
    [4m"[24m`, ProcessExited(0))



In the following commands, we will add metadata to the nodes in a piece-meal (column by column) fashion that will allow us to skip over null fields. Storing null pointers in Neo4j is discouraged (impossible?) and we will get errors if we try and set metadata properties to null values.

I tried to do this all in one command on the initial import by handling all of the nulls using the technique in [this post](https://markhneedham.com/blog/2014/08/22/neo4j-load-csv-handling-empty-columns/) but I kept getting Java errors


```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.scientific_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.scientific_name = row.scientific_name
"""
@time cypher(database_id, cmd)
```

     50.739977 seconds (1.63 k allocations: 51.844 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.scientific_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.scientific_name = row.scientific_name[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.division_cde IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.division_cde = row.division_cde
"""
@time cypher(database_id, cmd)
```

     47.722319 seconds (1.54 k allocations: 49.016 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.division_cde IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.division_cde = row.division_cde[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.division_id IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.division_id = row.division_id
"""
@time cypher(database_id, cmd)
```

     48.413401 seconds (1.57 k allocations: 49.812 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.division_id IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.division_id = row.division_id[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.division_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.division_name = row.division_name
"""
@time cypher(database_id, cmd)
```

     50.492626 seconds (1.63 k allocations: 51.359 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.division_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.division_name = row.division_name[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.rank IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.rank = row.rank
"""
@time cypher(database_id, cmd)
```

     49.657106 seconds (1.60 k allocations: 50.828 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.rank IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.rank = row.rank[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.acronym IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.acronym = row.acronym
"""
@time cypher(database_id, cmd)
```

     24.969174 seconds (852 allocations: 28.781 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.acronym IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.acronym = row.acronym[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.in_part IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.in_part = row.in_part
"""
@time cypher(database_id, cmd)
```

     22.704195 seconds (783 allocations: 27.047 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.in_part IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.in_part = row.in_part[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.includes IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.includes = row.includes
"""
@time cypher(database_id, cmd)
```

     41.095390 seconds (1.34 k allocations: 42.953 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.includes IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.includes = row.includes[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.common_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.common_name = row.common_name
"""
@time cypher(database_id, cmd)
```

     32.695385 seconds (1.09 k allocations: 35.859 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.common_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.common_name = row.common_name[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.genbank_common_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.genbank_common_name = row.genbank_common_name
"""
@time cypher(database_id, cmd)
```

     39.209667 seconds (1.28 k allocations: 41.469 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.genbank_common_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.genbank_common_name = row.genbank_common_name[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.blast_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.blast_name = row.blast_name
"""
@time cypher(database_id, cmd)
```

     20.754020 seconds (726 allocations: 25.234 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.blast_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.blast_name = row.blast_name[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.synonym IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.synonym = row.synonym
"""
@time cypher(database_id, cmd)
```

     42.617695 seconds (1.39 k allocations: 44.516 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.synonym IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.synonym = row.synonym[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.genbank_synonym IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.genbank_synonym = row.genbank_synonym
"""
@time cypher(database_id, cmd)
```

     24.485144 seconds (837 allocations: 28.469 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.genbank_synonym IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.genbank_synonym = row.genbank_synonym[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.type_material IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.type_material = row.type_material
"""
@time cypher(database_id, cmd)
```

     41.317321 seconds (1.35 k allocations: 43.406 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.type_material IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.type_material = row.type_material[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.authority IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.authority = row.authority
"""
@time cypher(database_id, cmd)
```

     44.953062 seconds (1.46 k allocations: 46.312 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.authority IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.authority = row.authority[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.genbank_acronym IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.genbank_acronym = row.genbank_acronym
"""
@time cypher(database_id, cmd)
```

     22.311734 seconds (774 allocations: 26.859 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.genbank_acronym IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.genbank_acronym = row.genbank_acronym[24m
    [4m"[24m`, ProcessExited(0))




```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.nodes.tsv")' AS row
FIELDTERMINATOR '\t'
WITH row WHERE row.equivalent_name IS NOT NULL
MATCH (t:Taxonomy {tax_id: row.tax_id})
SET t.equivalent_name = row.equivalent_name
"""
@time cypher(database_id, cmd)
```

     39.837954 seconds (1.31 k allocations: 41.938 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.nodes.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mWITH row WHERE row.equivalent_name IS NOT NULL[24m
    [4mMATCH (t:Taxonomy {tax_id: row.tax_id})[24m
    [4mSET t.equivalent_name = row.equivalent_name[24m
    [4m"[24m`, ProcessExited(0))



And here in the final step we create the relationships between taxa and their parent nodes


```julia
cmd = 
"""
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM
'file://$("$(DIR)/ncbi_taxonomy.edges.tsv")' AS row
FIELDTERMINATOR '\t'
MATCH (src:Taxonomy {tax_id: row.src})
MATCH (dst:Taxonomy {tax_id: row.dst})
MERGE (src)-[p:PARENT]->(dst)
"""
@time cypher(database_id, cmd)
```

     95.787084 seconds (2.99 k allocations: 91.219 KiB)





    Process(`[4mcypher-shell[24m [4m--address[24m [4mneo4j://localhost:7687[24m [4m--username[24m [4mneo4j[24m [4m--password[24m [4mpassword[24m [4m--database[24m [4mncbitaxonomy[24m [4m--format[24m [4mauto[24m [4m"USING PERIODIC COMMIT[24m
    [4mLOAD CSV WITH HEADERS FROM[24m
    [4m'file:///Users/cameronprybol/2021-03-21-ncbi-taxonomy/ncbi_taxonomy.edges.tsv' AS row[24m
    [4mFIELDTERMINATOR '	'[24m
    [4mMATCH (src:Taxonomy {tax_id: row.src})[24m
    [4mMATCH (dst:Taxonomy {tax_id: row.dst})[24m
    [4mMERGE (src)-[p:PARENT]->(dst)[24m
    [4m"[24m`, ProcessExited(0))



And that is it! We've just rebuilt the NCBI taxonomy in neo4j to allow us to do downstream work in a taxonomy-aware way
