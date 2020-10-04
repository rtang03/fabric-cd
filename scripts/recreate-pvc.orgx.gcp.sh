#!/bin/bash
NS=n3
ORG=org3
CLOUD=gcp

kubectl -n $NS delete -f ../releases/$ORG/volumes/pvc-$ORG.$CLOUD.yaml --wait=true
kubectl -n $NS create -f ../releases/$ORG/volumes/pvc-$ORG.$CLOUD.yaml
