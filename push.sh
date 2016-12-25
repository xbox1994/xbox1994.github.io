#!/usr/bin/env bash
rake deploy
git commit -am "$1"
git push origin source