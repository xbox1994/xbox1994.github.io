rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Java高并发系列三：对象的安全发布与共享策略"]
rake preview

./push.sh "[blog] Java高并发系列三：对象的安全发布与共享策略"