#!/bin/bash

# $1 = "org1", "org2" or "org3"

. "env.$1.sh"

if [ $1 == "org1" ]
then
  kubectl -n $NS0 delete -f manifest/pvc-$ORG0.$CLOUD.yaml --wait=true
  kubectl -n $NS1 delete -f manifest/pvc-$ORG1.$CLOUD.yaml --wait=true
  kubectl -n $NS0 create -f manifest/pvc-$ORG0.$CLOUD.yaml
  kubectl -n $NS1 create -f manifest/pvc-$ORG1.$CLOUD.yaml
else
  kubectl -n $NS delete  -f manifest/pvc-$ORG.$CLOUD.yaml --wait=true
  kubectl -n $NS create  -f manifest/pvc-$ORG.$CLOUD.yaml
fi
