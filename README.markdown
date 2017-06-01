rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["[译][Microservies 7]将巨无霸重构成微服务"]
rake preview

./push.sh "[blog] post microservice 7 and change the theme"