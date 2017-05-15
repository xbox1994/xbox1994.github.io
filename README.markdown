rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["[译][Microservies 4]在微服务架构中的服务发现机制"]
rake preview

./push.sh "[blog] post Microservies 4"