rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Java高并发系列二：线程安全性"]
rake preview

./push.sh "[blog] Java高并发系列二：线程安全性"