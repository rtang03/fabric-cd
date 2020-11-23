#!/bin/bash

# $1 = org2 or org3 .... etc

. ./setup.sh
. "env.$1.sh"

SECONDS=0
TARGET=dev-0.1

echo "#################################"
echo "### Step 1: Install WorkflowTemplates $NS"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS,path=argo-wf,target=dev-0.1,rel=argo-template-$ORG,file=values-$ORG.yaml | argocd app create -f -
res=$?
set +x
printMessage "install wfTemplate" $res

set -x
argocd app sync argo-template-$ORG
res=$?
set +x
printMessage "app sync" $res

set -x
argocd app wait argo-template-$ORG
res=$?
set +x
printMessage "wait wfTemplate" $res

echo "#################################"
echo "### Step 2: App-of-apps $ORG"
echo "#################################"
set -x
helm template ../argo-app --set ns=argocd,path=app-of-app,target=dev-0.1,rel=apps-$ORG,file=values-$ORG.yaml | argocd app create -f -
res=$?
set +x
printMessage "install $ORG manifests" $res

echo "#################################"
echo "### Step 3: App sync - $ORG"
echo "#################################"
set -x
argo submit -n $NS ../workflow/aoa-sync-1.$NS.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG sync request - part1" $res
checkArgoWfSucceeded "aoa-sync-1" $NS

echo "#################################"
echo "### Step 4: Workflow: crypto-$REL_TLSCA"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA.yaml | argo -n $NS submit - --generate-name cryptogen-$REL_TLSCA- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA" $res
checkArgoWfSucceeded "cryptogen-$REL_TLSCA" $NS

echo "#################################"
echo "### Step 5: Workflow crypto-$REL_RCA"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA.yaml | argo -n $NS submit - --generate-name cryptogen-$REL_RCA- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA" $res
checkArgoWfSucceeded "cryptogen-$REL_RCA" $NS

echo "#################################"
echo "### Step 6: Create secrets"
echo "#################################"
set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA.yaml | argo -n $NS submit - --wait
res=$?
set +x
printMessage "create secret $REL_RCA" $res

#### MAKE tlscacert.pem PUBLIC. This command requires installation of gcloud in local dev machine
set -x
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/n2/org2.net-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make org2.net-tlscacert public" $?

echo "#####################################################################"
echo "### Step 7: bootstrap-channel"
echo "#####################################################################"
set -x
argo submit -n $NS ../workflow/bootstrap-channel.$NS.yaml --watch --request-timeout 600s
res=$?
set +x
printMessage "bootstrap-channel" $res
checkArgoWfSucceeded "boostrap-channel" $NS

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
