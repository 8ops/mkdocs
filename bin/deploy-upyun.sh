#!/bin/bash

[ `dirname $0` == "./bin" ] || exit 1
set -e

grep -r wuxingdev docs && exit 2

mkdocs build
CTX_NAME=jesse-8ops-mkdocs
upx switch ${CTX_NAME}
[ "X${CTX_NAME}Y" == "X`upx sessions | awk '/^>/{printf $2}'`Y" ] || exit 1
upx sync --delete site/ / || /usr/bin/true
upx switch jesse-8ops-normal

printf "\nCompleted.\n\n"
