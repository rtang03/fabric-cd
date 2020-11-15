#!/bin/bash

. ./setup.sh
. "env.org1.sh"

SECONDS=0
TARGET=dev-0.1

# Argo WorkflowTemplate
helm template ../argo-app --set ns=n1,path=argo-wf,target=dev-0.1,rel=argo-org1,file=values-org1.yaml | argocd app create -f -

# App-of-apps org1
helm template ../argo-app --set ns=argocd,path=app-of-app,target=dev-0.1,rel=apps-org1,file=values-org1.yaml | argocd app create -f -

argocd app sync apps-org1

argocd app wait apps-org1 --timeout 120

# Steps
argocd app sync $REL_ORGADMIN1

argocd app wait $REL_ORGADMIN1 --timeout 120

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
