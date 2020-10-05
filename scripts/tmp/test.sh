#!/bin/bash
cat ../../download/index.txt | grep -v index.txt | grep -v org1.net-tlscacert | while read line
do
  CERT=$(echo $line | sed -En 's/(.*)[.]pem$/\1/gp')
  echo $CERT
done
