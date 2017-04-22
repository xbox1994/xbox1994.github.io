rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["[译][Microservies 2]Building Microservices: Using an API Gateway"]
rake preview

./push.sh "[blog] post Microservies 2"