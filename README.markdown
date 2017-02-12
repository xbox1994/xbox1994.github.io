rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Docker port与iptables"]
rake preview

./push.sh "[new blog]docker with iptables"