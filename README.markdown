rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Java多线程与高并发(六):高并发解决思路"]
rake preview

./push.sh "[blog] 号外号外"
