#!/bin/bash

[ `dirname $0` == "./bin" ] || exit 1

upx switch jesse-8ops-mkdocs
upx sync --delete site/ /
upx switch jesse-8ops-normal

