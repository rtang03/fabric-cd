#!/bin/bash

# $1 = org2 or org3 .... etc

. ./setup.sh
. "env.$1.sh"

SECONDS=0
TARGET=dev-0.1

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,rel=$REL_ORGADMIN,file=values-$REL_ORGADMIN.yaml,secret=secrets.$REL_ORGADMIN.yaml,path=orgadmin,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_ORGADMIN" $res

set -x
argocd app sync $REL_ORGADMIN
res=$?
set +x
printMessage "$REL_ORGADMIN sync starts" $res

set -x
argocd app wait $REL_ORGADMIN --timeout 120
res=$?
set +x
printMessage "$REL_ORGADMIN is healthy and sync" $res

echo "#################################"
echo "### Step 2: Install $REL_TLSCA"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,rel=$REL_TLSCA,file=values-$REL_TLSCA.yaml,secret=secrets.$ORG.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create apps: $REL_TLSCA" $res

set -x
argocd app sync $REL_TLSCA
res=$?
set +x
printMessage "$REL_TLSCA sync starts" $res

echo "#################################"
echo "### Step 3: Install $REL_RCA"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,rel=$REL_RCA,file=values-$REL_RCA.yaml,secret=secrets.$ORG.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create apps: $REL_RCA" $res

set -x
argocd app sync $REL_RCA
res=$?
set +x
printMessage "$REL_RCA sync starts" $res

set -x
argocd app wait $REL_TLSCA $REL_RCA --timeout 300
res=$?
set +x
printMessage "$REL_TLSCA | $REL_RCA is healthy and sync" $res

echo "#################################"
echo "### Step 4: Workflow: crypto-$REL_TLSCA"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA.yaml | argo -n $NS submit - --generate-name cryptogen-$REL_TLSCA- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA" $res

echo "#################################"
echo "### Step 5: Workflow crypto-$REL_RCA"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA.yaml | argo -n $NS submit - --generate-name cryptogen-$REL_RCA- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA" $res

echo "#################################"
echo "### Step 6: Create secrets"
echo "#################################"
set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA.yaml | argo -n $NS submit - --wait
res=$?
set +x
printMessage "create secret $REL_RCA" $res

echo "#################################"
echo "### Step 7: Install $REL_GUPLOAD"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,rel=$REL_GUPLOAD,file=values-$REL_GUPLOAD.yaml,path=gupload,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_GUPLOAD" $res

set -x
argocd app sync $REL_GUPLOAD
res=$?
set +x
printMessage "$REL_RCA sync starts" $res

set -x
argocd app wait $REL_GUPLOAD --timeout 300
res=$?
set +x
printMessage "$REL_GUPLOAD is healthy and sync" $res

#echo "#################################"
#echo "### Step 8: Out-of-band process"
#echo "#################################"

#### MAKE tlscacert.pem PUBLIC

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
