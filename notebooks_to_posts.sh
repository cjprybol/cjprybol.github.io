# remove any existing files in posts such that we can repopulate the posts with updated versions
if [ "$(ls -A _posts)" ]; then
		rm _posts/*
fi

# convert all jupyter notebooks in the post_notebooks directory into markdown files in the _posts directory
jupyter nbconvert --output-dir _posts --to markdown post_notebooks/*

# converting jupyter notebooks to markdown files leaves an extra blank line at the top of the markdown file
# which messes with the header metadata used by Jekyll. We can fix this by removing the first line of each
# markdown file in place
for filename in _posts/*; do
	echo $filename
	# sed -i '1d' "$filename"
	tail -n+2 "$filename" > "$filename.tmp" && mv "$filename.tmp" "$filename"
done