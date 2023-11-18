# use
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

nvm install 12

npm install -g hexo-cli

npm install

hexo server

hexo clean && hexo deploy

hexo new post "2023-11-18-分布式事务与seata/DTM"