rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["[译][Microservies 6]选择一个微服务部署策略"]
rake preview

./push.sh "[blog] post microservice 6"