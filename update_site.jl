begin_codeblock_regex = r"^```(.+)$"
end_codeblock_regex = r"^```$"

problem_lines = [
#     "Unable to load WebIO. Please make sure WebIO works for your Jupyter client.",
#     "<!DOCTYPE html>",
#     "For troubleshooting, please see <a href=\"https://juliagizmos.github.io/WebIO.jl/latest/providers/ijulia/\">",
#     "the WebIO/IJulia documentation</a>."
#     "display(p)"
]

target_directory = "_posts"
# clear out any existing content
rm(target_directory, recursive=true)
mkpath(target_directory)

notebooks_directory = target_directory[1:end-1] * "_notebooks"

notebooks = filter(x -> occursin(r".+\.ipynb$", x), readdir(notebooks_directory))
for notebook in notebooks
    target_file = "$target_directory/" * replace(notebook, r"\.ipynb$" => ".md")
    open(target_file, "w") do io
        for line in eachline(`jupyter nbconvert --to markdown $notebooks_directory/$notebook --stdout`)
            if !any(x -> occursin(x, line), problem_lines)
                println(io, line)                
            end
        end  
    end
end
if isinteractive()
    run(`jupyter nbconvert --to script update_site.ipynb`)
end
