#!/bin/bash

argocd app list -o name | while read APP
do
  set -x
  argocd app delete $APP
  set +x
done

argo -n n0 list -o name | while read APP
do
  set -x
  argo -n n0 delete $APP
  set +x
done

argo -n n1 list -o name | while read APP
do
  set -x
  argo -n n1 delete $APP
  set +x
done

argo -n n2 list -o name | while read APP
do
  set -x
  argo -n n2 delete $APP
  set +x
done
