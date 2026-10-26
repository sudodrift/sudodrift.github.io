# Going live on GitHub Pages

Nothing below has been done yet. The site only exists in /workspace/site.

1. In the `sudodrift` GitHub organization, create a new **public** repository named exactly `sudodrift.github.io`. Leave it empty (no README, license or .gitignore).
2. Push this folder to it:

   ```sh
   cd /workspace/site
   git remote add origin https://github.com/sudodrift/sudodrift.github.io.git
   git push -u origin main
   ```
3. In the repo go to **Settings > Pages**. Under "Build and deployment" set Source to **Deploy from a branch**, branch **main**, folder **/ (root)**, then Save. GitHub builds it with its own Jekyll and the plugins this site uses (jekyll-feed, jekyll-sitemap, jekyll-seo-tag) are all on its allowed list, so no GitHub Actions workflow is needed.
4. Wait for the "pages build and deployment" run under the **Actions** tab to go green, then open https://sudodrift.github.io. Tick **Enforce HTTPS** in Settings > Pages if it isn't already on.
5. Optional: submit `https://sudodrift.github.io/sitemap.xml` in Google Search Console and Bing Webmaster Tools.

## Medium and canonical links

Every page on this site already declares itself as the canonical copy.

- **New posts from now on:** publish on this site first. Then on Medium open your profile menu > Stories > **Import a story** (or go to https://medium.com/p/import), paste the post URL from this site and import. Medium copies the text and sets the story's canonical link to your site URL automatically, so search engines treat the site as the original. Check the images came across, then publish.
- **The three posts already on Medium:** for each one, open the story, choose ... > **Story settings** > **Advanced settings**, turn on the custom canonical link, and paste the matching URL:
  - https://sudodrift.github.io/posts/litellm-key-nobody-revoked/
  - https://sudodrift.github.io/posts/ai-keys-hosting-platforms/
  - https://sudodrift.github.io/posts/ovhcloud-cli-swap/
- Substack does not offer a canonical link setting, so the newsletter copy stays as is. That's normal for a newsletter and not a problem.

## Analytics (not added)

The site has no analytics and no third-party scripts. If you want numbers later, a cookie-free option such as GoatCounter (free for personal sites) is one script tag added to `_includes/head.html`.
