#!/bin/bash

. ./setup.sh
. "env.$ORG1.sh"

SECONDS=0
# IMPORTANT NOTE: TARGET is the Release Branch. Make sure correct TARGET for each deployment
TARGET=dev-0.2

echo "#################################"
echo "### Step 1: Install WorkflowTemplates ($NS1)"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,path=argo-wf,target=$TARGET,rel=argo-template-$ORG1,file=values-$ORG1.yaml | argocd app create -f -
res=$?
set +x
printMessage "install wfTemplate" $res

set -x
argocd app sync argo-template-$ORG1
res=$?
set +x
printMessage "app sync" $res

set -x
argocd app wait argo-template-$ORG1
res=$?
set +x
printMessage "wait wfTemplate" $res

echo "#################################"
echo "### Step 2: App-of-apps ($NS1)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=$TARGET,rel=apps-$ORG1,file=values-redis.yaml | argocd app create -f -
res=$?
set +x
printMessage "install $ORG1 manifests" $res

echo "#################################"
echo "### Step 3: App sync - $ORG1"
echo "#################################"
set -x
argo submit -n $NS1 ../workflow/sync-redis.n1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG1 sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" $NS1

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
