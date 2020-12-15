Do research in jupyter notebooks in `_draft_notebooks`

Run `julia udpate_site.jl` to export notebooks in `_draft_notebooks` to jekyll compatable markdown files for the site

Run `jekyll serve --watch --drafts --future` locally to review draft posts for formatting and content

After confirming that the draft post is suitable for publishing,
move the notebook from `_draft_notebooks` into `_post_notebooks`
and give it a date!

Run `julia update_site.jl` to update `_posts` and `_drafts`

Git commit && git push and check it live!
