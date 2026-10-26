# How to add a new post

The site is plain Jekyll, built by GitHub Pages itself. Adding a post means adding one Markdown file to `_posts/` (plus its images) and pushing. No build step on your machine is needed.

## The one-command way

1. Write the post as Markdown, the same way as the Medium drafts: a `# Title` line, then a one-line summary, then the body. Name it `YYYY-MM-DD-short-slug.md` and keep its images next to it, linked like `![alt text](my-image.png)`.
2. Copy the draft and its images into `drafts/` (this folder is never published), then run:

   ```sh
   scripts/new-post.sh drafts/2026-10-27-short-slug.md
   ```

   This writes `_posts/2026-10-27-short-slug.md` with the title, date, description and social image filled in, copies the images to `assets/posts/short-slug/`, and fixes the image links. The post URL will be `https://sudodrift.github.io/posts/short-slug/`.
3. Publish:

   ```sh
   git add _posts assets/posts
   git commit -m "Post: short title"
   git push
   ```

   GitHub Pages rebuilds the site in a minute or two. The home page, the articles list, the RSS feed and the sitemap update on their own.

The subscribe box for Weekly Breach Notes is added to the end of every post by the layout, so you don't need to paste it in.

## The file-drop way (no script, works in the GitHub web editor)

Create `_posts/YYYY-MM-DD-short-slug.md` that starts like this:

```markdown
---
title: "Your title here"
date: 2026-10-27
description: "One or two sentences. Shows under the title, in search results and in link previews."
image: /assets/posts/short-slug/first-image.png
---

Body in Markdown...

![Alt text](/assets/posts/short-slug/first-image.png)
```

Upload images to `assets/posts/short-slug/`. `image:` is optional; without it, link previews use the site's social card.

## Preview locally (optional)

Needs Ruby. One time: `bundle config set --local path vendor/bundle && bundle install`. Then:

```sh
bundle exec jekyll serve
# open http://127.0.0.1:4000
```

## Then cross-post to Medium

Use Medium's "Import a story" with the post's URL on this site so Medium points its canonical link back here. See GO-LIVE.md.
