rake install
rake setup_github_pages 
rake generate
rake deploy

rake new_page[about]
rake new_post["Java多线程与高并发(五):线程池"]
rake preview

./push.sh "[blog] Java多线程与高并发(五):线程池"
