rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Docker in Docker"]
rake preview

./push.sh "[new blog]docker in docker"