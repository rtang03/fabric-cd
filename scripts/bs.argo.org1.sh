#!/bin/bash

. ./setup.sh
. "env.org1.sh"

SECONDS=0
TARGET=dev-0.1
echo "#################################"
echo "### Step 1: Install WorkflowTemplates (n0)"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,path=argo-wf,target=dev-0.1,rel=argo-template-org0,file=values-org0.yaml | argocd app create -f -
res=$?
set +x
printMessage "install wfTemplate" $res

set -x
argocd app sync argo-template-org0
res=$?
set +x
printMessage "app sync" $res

set -x
argocd app wait argo-template-org0
res=$?
set +x
printMessage "wait wfTemplate" $res


echo "#################################"
echo "### Step 2: Install WorkflowTemplates (n1)"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,path=argo-wf,target=dev-0.1,rel=argo-template-org1,file=values-org1.yaml | argocd app create -f -
res=$?
set +x
printMessage "install wfTemplate" $res

set -x
argocd app sync argo-template-org1
res=$?
set +x
printMessage "app sync" $res

set -x
argocd app wait argo-template-org1
res=$?
set +x
printMessage "wait wfTemplate" $res

echo "#################################"
echo "### Step 3: App-of-apps (n0)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=dev-0.1,rel=apps-org0,file=values-org0.yaml | argocd app create -f -
res=$?
set +x
printMessage "install org0 manifests" $res

echo "#################################"
echo "### Step 4: App-of-apps (n1)"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=dev-0.1,rel=apps-org1,file=values-org1.yaml | argocd app create -f -
res=$?
set +x
printMessage "install org1 manifests" $res

echo "#################################"
echo "### Step 5: App sync - org0"
echo "#################################"
set -x
argo submit -n n0 ../workflow/aoa-sync-1.n0.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit org0 sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" n0

echo "#################################"
echo "### Step 6: App sync - org1"
echo "#################################"
set -x
argo submit -n n1 ../workflow/aoa-sync-1.n1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit org1 sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" n1

echo "#################################"
echo "### Step 7: Workflow: crypto-$REL_TLSCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_TLSCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA1" $res
checkArgoWfSucceeded "cryptogen-$REL_TLSCA1" n1

echo "#################################"
echo "### Step 8: Workflow crypto-$REL_RCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_RCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA1" $res
checkArgoWfSucceeded "cryptogen-$REL_RCA1" n1

echo "#################################"
echo "### Step 9: Workflow: crypto-$REL_TLSCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_TLSCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-tlsca0" $res
checkArgoWfSucceeded "cryptogen-$REL_TLSCA0" n0

echo "#################################"
echo "### Step 10: Workflow: crypto-$REL_RCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_RCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA0" $res
checkArgoWfSucceeded "cryptogen-$REL_RCA0" n0

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
checkArgoWfSucceeded "secret-$REL_RCA0" n0

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA0-b.yaml | argo -n $NS0 submit - --wait
res=$?
set +x
printMessage "create secret rca0 - Step 5 to Step 10" $res
checkArgoWfSucceeded "secret-$REL_RCA0" n0

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA1.yaml | argo -n $NS1 submit - --wait
res=$?
set +x
printMessage "create secret rca1" $res
checkArgoWfSucceeded "secret-$REL_RCA1" n1

echo "#################################"
echo "### Step 12: Create genesis block and channeltx"
echo "#################################"
# Note: It will not detect if the gcs bucket has genesis. If already exist, this workflow will fail.
set -x
helm template ../workflow/genesis | argo -n $NS0 submit - --watch --request-timeout 120s
res=$?
set +x
printMessage "create genesis.block in $NS0" $res
checkArgoWfSucceeded "genesis" n0

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
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/n0/org0.com-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make org0.com-tlscacert public" $?

set -x
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/n1/org1.net-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make org1.net-tlscacert public" $?
sleep 1

echo "#################################"
echo "### Step 13: app sync org0: part 2"
echo "#################################"
set -x
argo submit -n n0 ../workflow/aoa-sync-2.n0.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit sync request - part2" $res
checkArgoWfSucceeded "aoa-sync-2" n0

echo "#################################"
echo "### Step 14: bootstrap-channel"
echo "#################################"
set -x
argo submit -n n1 ../workflow/bootstrap-channel.n1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "bootstrap-channel" $res
checkArgoWfSucceeded "bootstrap-channel-org1" n1

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
