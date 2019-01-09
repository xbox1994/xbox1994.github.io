#!/usr/bin/env bash
bundle exec rake generate
bundle exec rake deploy
git add .
git commit -m "$1"
git push origin source