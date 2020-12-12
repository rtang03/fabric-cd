#!/bin/bash

# $1 = org2 or org3 .... etc

. ./setup.sh
. "env.$1.sh"

SECONDS=0
# IMPORTANT NOTE: TARGET is the Release Branch. Make sure correct TARGET for each deployment
TARGET=dev-0.2

echo "#################################"
echo "### Step 1: App-of-apps ($NS)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=$TARGET,rel=apps-$ORG,file=values-gateway-$ORG.yaml | argocd app create -f -
res=$?
set +x
printMessage "install $ORG manifests" $res

echo "#################################"
echo "### Step 1: App sync - $ORG"
echo "#################################"
set -x
argo submit -n $NS ../workflow/aoa-sync-2.$NS.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG sync - gateway" $res
checkArgoWfSucceeded "aoa-sync-2" $NS

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
