#!/bin/bash

argocd app list -o name | while read APP
do
  argo app delete $APP
done
