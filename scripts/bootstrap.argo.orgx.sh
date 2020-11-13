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

#### MAKE tlscacert.pem PUBLIC
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/n2/org2.net-tlscacert/tlscacert.pem

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

echo "#################################"
echo "### Step 8: Create tlscacert"
echo "#################################"
# STEP 1: send org1.net-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
# STEP 2: send org0.com-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
set -x
argo -n n2 submit ../workflow/create-tlscacert.n2.yaml --watch --request-timeout 60s
res=$?
set +x
printMessage "create tlscacerts" $res

echo "#################################"
echo "### Step 9: Out-of-band process"
echo "#################################"
# IMPORTANT NOTE: ARGO_TOKEN is supposed to pass to org2, via out-of-band process
SECRET=$(kubectl -n n1 get sa guest -o=jsonpath='{.secrets[0].name}')
TOKEN="Bearer $(kubectl -n n1 get secret $SECRET -o=jsonpath='{.data.token}' | base64 --decode)"

set -x
curl http://argo.server/api/v1/events/n1/pull-tlscacert -H "Authorization: $TOKEN" -d '{"file":"org2.net-tlscacert.pem","secret":"org2.net-tlscacert","url":"https://storage.googleapis.com/fabric-cd-dev/workflow/secrets/n2/org2.net-tlscacert/tlscacert.pem","key":"tlscacert.pem"}'
res=$?
set +x
printMessage "pull-tlscacert" $res

echo "#################################"
echo "### Step 10: Install $REL_PEER"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,rel=$REL_PEER,file=values-$REL_PEER.yaml,path=hlf-peer,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_PEER" $res

set -x
argocd app sync $REL_PEER
res=$?
set +x
printMessage "$REL_PEER sync starts" $res

set -x
argocd app wait $REL_PEER $REL_GUPLOAD --timeout 120
res=$?
set +x
printMessage "$REL_PEER are healthy and sync" $res

echo "#####################################################################"
echo "### MULTIPLE ORGS WORKFLOW"
echo "#####################################################################"

set -x
curl http://argo.server/api/v1/events/n1/fetch-upload -H "Authorization: $TOKEN" -d '{"outfile":"channel_config--config.json","cacert":"org2.net-tlscacert","url":"gupload.org2.net:15443"}'
res=$?
set +x
printMessage "fetch-upload" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
