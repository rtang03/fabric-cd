#!/bin/bash

argocd app list -o name | while read APP
do
  argocd app delete $APP
done

# uninstall jobs, created by helm-install
./uninstall.sh org1
