#!/bin/bash

argocd app list -o name | while read APP
do
  argocd app delete $APP
done
