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

#### MAKE tlscacert.pem PUBLIC
set -x
gsutil acl ch -u AllUsers:R gs://fabric-cd-dev/workflow/secrets/n2/org2.net-tlscacert/tlscacert.pem
res=$?
set +x
printMessage "make org2.net-tlscacert public" $?

echo "#################################"
echo "### Step 7: Create tlscacert"
echo "#################################"
# STEP 1: send org1.net-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
# STEP 2: send org2.net-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
# STEP 3: send org0.com-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
set -x
argo -n $NS submit ../workflow/create-tlscacert.$NS.yaml --watch --request-timeout 60s
res=$?
set +x
printMessage "create tlscacerts" $res

echo "#################################"
echo "### Step 8: (Out-of-band) obtain auth token to Argo Server"
echo "#################################"
echo "IMPORTANT NOTE: ARGO_TOKEN is supposed to pass to org2, via out-of-band process, during member onboarding"
set -x
SECRET=$(kubectl -n n1 get sa guest -o=jsonpath='{.secrets[0].name}')
res=$?
set +x
printMessage "get n1 guest-secretname" $res

set -x
TOKEN="Bearer $(kubectl -n n1 get secret $SECRET -o=jsonpath='{.data.token}' | base64 --decode)"
res=$?
set +x
printMessage "get n1 guest-token" $res

set -x
curl http://argo.server/api/v1/events/n1/pull-tlscacert -H "Authorization: $TOKEN" -d '{"file":"org2.net-tlscacert.pem","secret":"org2.net-tlscacert","url":"https://storage.googleapis.com/fabric-cd-dev/workflow/secrets/n2/org2.net-tlscacert/tlscacert.pem","key":"tlscacert.pem"}'
res=$?
set +x
printMessage "pull-tlscacert" $res

echo "#################################"
echo "### Step 9: app sync $ORG: part 2"
echo "#################################"
set -x
argo submit -n $NS ../workflow/aoa-sync-2.$NS.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "submit $ORG sync request - part2" $res
checkArgoWfSucceeded "aoa-sync-2" $NS

echo "#####################################################################"
echo "### Multi-organization workflow"
echo "#####################################################################"
echo "### Step 10: Fetch block at n1, and gupload fileserver of $NS "
echo "#####################################################################"
set -x
curl http://argo.server/api/v1/events/n1/fetch-upload -H "Authorization: $TOKEN" -d '{"outfile":"channel_config--config.json","cacert":"org2.net-tlscacert","url":"gupload.org2.net:15443"}'
res=$?
set +x
printMessage "fetch-upload" $res

echo "#####################################################################"
echo "### Step 11: prepares $NS's config_update_in_envelope.pb"
echo "#####################################################################"
set -x
argo submit -n $NS ../workflow/neworg-config-update.$NS.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "gupload config_update_in_envelope.pb to org1" $res
checkArgoWfSucceeded "neworg-update-config" $NS

echo "#####################################################################"
echo "### Step 12: request n1 to update-channel"
echo "#####################################################################"
set -x
curl http://argo.server/api/v1/events/n1/update-channel -H "Authorization: $TOKEN" \
  -d '{"channel":"loanapp","envelope":"o2_neworg_update--config_update_in_envelope.pb","cacert":"org2.net-tlscacert","url":"gupload.org2.net:15443"}'
res=$?
set +x
printMessage "" $res

echo "#####################################################################"
echo "### Step 13: bootstrap-channel"
echo "#####################################################################"
set -x
argo submit -n $NS ../workflow/bootstrap-channel.$NS.yaml --watch --request-timeout 600s
res=$?
set +x
printMessage "bootstrap-channel" $res
checkArgoWfSucceeded "boostrap-channel" $NS

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
