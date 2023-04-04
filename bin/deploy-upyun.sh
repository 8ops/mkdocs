#!/bin/bash

[ `dirname $0` == "./bin" ] || exit 1

upx switch jesse-8ops-docs
upx sync --delete docs/ /
upx switch jesse-8ops-normal

