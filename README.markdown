rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["[译]How HTTPS Secures Connections"]
rake preview

./push.sh "[new blog]docker with iptables"