#!/bin/bash

sed -i '' \
    -e 's/mypassword/'${MAIL_PASS}'/' \
    -e 's/mysecret/'${WECHAT_API_SECRET}'/' \
    prometheus-alertmanager.yaml 


