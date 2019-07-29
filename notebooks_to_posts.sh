if [ "$(ls -A _posts)" ]; then
		rm _posts/*
fi

jupyter nbconvert --output-dir _posts --to markdown post_notebooks/*
