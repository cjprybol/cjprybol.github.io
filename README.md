Do research in jupyter notebooks in `_draft_notebooks`

Run `julia udpate_site.jl` to export notebooks in `_draft_notebooks` to jekyll compatable markdown files for the site

Run `bundle exec jekyll serve --watch --drafts --future` locally to review draft posts for formatting and content

After confirming that the draft post is suitable for publishing,
move the notebook from `_draft_notebooks` into `_post_notebooks`
and give it a date!

Run `julia update_site.jl` to update `_posts` and `_drafts`

Git commit && git push and check it live!

Very important add-on
```
jupyter labextension install @ijmbarr/jupyterlab_spellchecker
```

Relevant old posts to grab:
https://github.com/cjprybol/static-demo/blob/master/iterative-assembly.ipynb
https://github.com/cjprybol/Thesis/blob/master/manuscript/manuscript.md
https://github.com/cjprybol/Thesis/blob/master/dev/notes/thesis.md

Convert from GFA to cytoscape.js
https://github.com/cjprybol/sequence-graphs/blob/master/src/old/gfa2cyto-js.jl

Convert from simplified graph to GFA
https://github.com/cjprybol/sequence-graphs/blob/master/src/write-GFA.jl

TODO:
- Add functions to simplify graph
- Add function to write kmer graph to GFA
- Add function to write simplified graph to GFA
- Add function to call Bandage and show output