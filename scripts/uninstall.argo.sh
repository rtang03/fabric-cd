#!/bin/bash

argocd app list -o name | while read APP
do
  argocd app delete $APP
done

argo -n n0 list -o name | while read APP
do
  argo -n n0 delete $APP
done

argo -n n1 list -o name | while read APP
do
  argo -n n1 delete $APP
done

argo -n n2 list -o name | while read APP
do
  argo -n n2 delete $APP
done
