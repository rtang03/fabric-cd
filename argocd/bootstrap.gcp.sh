#!/bin/bash

kubectl -n argocd apply -f app-admin1.yaml

argocd app sync admin1
