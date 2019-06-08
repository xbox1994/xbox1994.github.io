bundle exec rake install
bundle exec rake setup_github_pages

bundle exec rake new_page[about]
bundle exec rake new_post
bundle exec rake preview

bundle exec rake generate
bundle exec rake deploy
git add .
git commit -m "[文章]架构 prometheus"
git push origin source
