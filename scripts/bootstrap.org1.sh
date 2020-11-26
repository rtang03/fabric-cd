#!/bin/bash

. ./setup.sh
. "env.org1.sh"

SECONDS=0
# IMPORTANT NOTE: TARGET is the Release Branch. Make sure correct TARGET for each deployment
TARGET=dev-0.2

echo "#################################"
echo "### Step 1: Install WorkflowTemplates ($NS0)"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,path=argo-wf,target=$TARGET,rel=argo-template-$ORG0,file=values-$ORG0.yaml | argocd app create -f -
res=$?
set +x
printMessage "install wfTemplate" $res

set -x
argocd app sync argo-template-$ORG0
res=$?
set +x
printMessage "app sync" $res

set -x
argocd app wait argo-template-$ORG0
res=$?
set +x
printMessage "wait wfTemplate" $res


echo "#################################"
echo "### Step 2: Install WorkflowTemplates ($NS1)"
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
echo "### Step 3: App-of-apps ($NS0)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=$TARGET,rel=apps-$ORG0,file=values-$ORG0.yaml | argocd app create -f -
res=$?
set +x
printMessage "install $ORG0 manifests" $res

echo "#################################"
echo "### Step 4: App-of-apps ($NS1)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=$TARGET,rel=apps-$ORG1,file=values-$ORG1.yaml | argocd app create -f -
res=$?
set +x
printMessage "install $ORG1 manifests" $res

echo "#################################"
echo "### Step 5: App sync - $ORG0"
echo "#################################"
set -x
argo submit -n $NS0 ../workflow/aoa-sync-1.$NS0.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG0 sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" $NS0

echo "#################################"
echo "### Step 6: App sync - $ORG1"
echo "#################################"
set -x
argo submit -n $NS1 ../workflow/aoa-sync-1.$NS1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG1 sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" $NS1

echo "#################################"
echo "### Step 7: Workflow: crypto-$REL_TLSCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_TLSCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA1" $res
checkArgoWfSucceeded "cryptogen-$REL_TLSCA1" $NS1

echo "#################################"
echo "### Step 8: Workflow crypto-$REL_RCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_RCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA1" $res
checkArgoWfSucceeded "cryptogen-$REL_RCA1" $NS1

echo "#################################"
echo "### Step 9: Workflow: crypto-$REL_TLSCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_TLSCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-tlsca0" $res
checkArgoWfSucceeded "cryptogen-$REL_TLSCA0" $NS0

echo "#################################"
echo "### Step 10: Workflow: crypto-$REL_RCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_RCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA0" $res
checkArgoWfSucceeded "cryptogen-$REL_RCA0" $NS0

echo "#################################"
echo "### Step 11: Create secrets"
echo "#################################"
# Note:
# 1. It will not detect if the gcs bucket has genesis. If already exist, this workflow will fail.
# 2. intentionally split, to avoid too many pods running parallel
# 3. should not use --watch
set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA0-a.yaml | argo -n $NS0 submit - --wait
res=$?
set +x
printMessage "create secret rca0 - Step 1 to Step 4" $res
checkArgoWfSucceeded "secret-$REL_RCA0" $NS0

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA0-b.yaml | argo -n $NS0 submit - --wait
res=$?
set +x
printMessage "create secret rca0 - Step 5 to Step 10" $res
checkArgoWfSucceeded "secret-$REL_RCA0" $NS0

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA1.yaml | argo -n $NS1 submit - --wait
res=$?
set +x
printMessage "create secret rca1" $res
checkArgoWfSucceeded "secret-$REL_RCA1" $NS1

echo "#################################"
echo "### Step 12: Create genesis block and channeltx"
echo "#################################"
# Note: It will not detect if the gcs bucket has genesis. If already exist, this workflow will fail.
set -x
helm template ../workflow/genesis | argo -n $NS0 submit - --watch --request-timeout 120s
res=$?
set +x
printMessage "create genesis.block in $NS0" $res
checkArgoWfSucceeded "genesis" $NS0

######## 3. Create configmap: genesis.block
POD_CLI0=$(kubectl get pods -n $NS0 -l "app=orgadmin,release=$REL_ORGADMIN0" -o jsonpath="{.items[0].metadata.name}")
set -x
kubectl -n $NS0 exec $POD_CLI0 -- cat /var/hyperledger/crypto-config/genesis.block > ../download/genesis.block
res=$?
set +x
printMessage "obtain genesis block" $res

kubectl -n $NS0 delete secret genesis
kubectl -n $NS0 create secret generic genesis --from-file=genesis=../download/genesis.block
printMessage "create secret genesis" $?

rm ../download/genesis.block

#### MAKE tlscacert.pem PUBLIC
# Make you have "gsutil" installed from gcloud; can run gcloud components list
set -x
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/$NS0/$ORG0.com-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make $ORG0.com-tlscacert public" $?

set -x
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/$NS1/$ORG1.net-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make $ORG1.net-tlscacert public" $?
sleep 1

echo "#################################"
echo "### Step 13: app sync $ORG0: part 2"
echo "#################################"
set -x
argo submit -n $NS0 ../workflow/aoa-sync-2.$NS0.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit sync request - part2" $res
checkArgoWfSucceeded "aoa-sync-2" $NS0

echo "#################################"
echo "### Step 14: bootstrap-channel"
echo "#################################"
set -x
argo submit -n $NS1 ../workflow/bootstrap-channel.$NS1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "bootstrap-channel" $res
checkArgoWfSucceeded "bootstrap-channel-$ORG1" $NS1

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
