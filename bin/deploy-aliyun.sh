#!/bin/bash

[ `dirname $0` == "./bin" ] || exit 1
set -e

grep -r wuxingdev docs && exit 2

mkdocs build
rsync -av site/ a.8ops.top:/opt/site/books.8ops.top/

printf "\nCompleted.\n\n"
