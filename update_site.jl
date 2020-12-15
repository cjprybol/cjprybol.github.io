begin_codeblock_regex = r"^```(.+)$"
end_codeblock_regex = r"^```$"

for target_directory in ("_posts", "_drafts")
    notebooks_directory = target_directory[1:end-1] * "_notebooks"
    notebooks = filter(x -> occursin(r".+\.ipynb$", x), readdir(notebooks_directory))
    for notebook in notebooks
        target_file = "$target_directory/" * replace(notebook, r"\.ipynb$" => ".md")
        open(target_file, "w") do io
            for line in eachline(`jupyter nbconvert --to markdown $notebooks_directory/$notebook --stdout`)
                if occursin(begin_codeblock_regex, line)
                    line = "{% highlight " * match(begin_codeblock_regex, line).captures[1] * " %}"
                elseif occursin(end_codeblock_regex, line)
                    line = "{% endhighlight %}"
                end
#                 display(line)
                println(io, line)
            end  
        end
    end
end

run(`jupyter nbconvert --to script update_site.ipynb`)
