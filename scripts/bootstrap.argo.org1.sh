#!/bin/bash

. ./setup.sh
. "env.org1.sh"

SECONDS=0
TARGET=dev-0.1

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN1"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=$REL_ORGADMIN1,file=values-$REL_ORGADMIN1.yaml,secret=secrets.$REL_ORGADMIN1.yaml,path=orgadmin,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_ORGADMIN1" $res

set -x
argocd app sync $REL_ORGADMIN1
res=$?
set +x
printMessage "$REL_ORGADMIN1 sync starts" $res

set -x
argocd app wait $REL_ORGADMIN1 --timeout 120
res=$?
set +x
printMessage "$REL_ORGADMIN1 is healthy and sync" $res

echo "#################################"
echo "### Step 2: Install $REL_TLSCA1"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=$REL_TLSCA1,file=values-$REL_TLSCA1.yaml,secret=secrets.org1.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create apps: $REL_TLSCA1" $res

set -x
argocd app sync $REL_TLSCA1
res=$?
set +x
printMessage "$REL_TLSCA1 sync starts" $res

echo "#################################"
echo "### Step 3: Install $REL_RCA1"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=$REL_RCA1,file=values-$REL_RCA1.yaml,secret=secrets.org1.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create apps: $REL_RCA1" $res

set -x
argocd app sync $REL_RCA1
res=$?
set +x
printMessage "$REL_RCA1 sync starts" $res

set -x
argocd app wait $REL_TLSCA1 $REL_RCA1 --timeout 300
res=$?
set +x
printMessage "$REL_TLSCA1 | $REL_RCA1 is healthy and sync" $res


echo "#################################"
echo "### Step 4: Workflow: crypto-$REL_TLSCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_TLSCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA1" $res

echo "#################################"
echo "### Step 5: Workflow crypto-$REL_RCA1"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_RCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA1" $res

echo "#################################"
echo "### Step 6: Install $REL_ORGADMIN0"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_ORGADMIN0,file=values-$REL_ORGADMIN0.yaml,secret=secrets.$REL_ORGADMIN0.yaml,path=orgadmin,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_ORGADMIN0" $res

set -x
argocd app sync $REL_ORGADMIN0
res=$?
set +x
printMessage "$REL_ORGADMIN0 sync starts" $res

set -x
argocd app wait $REL_ORGADMIN0 --timeout 120
res=$?
set +x
printMessage "$REL_ORGADMIN0 is healthy and sync" $res

echo "#################################"
echo "### Step 7: Install $REL_TLSCA0"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_TLSCA0,file=values-$REL_TLSCA0.yaml,secret=secrets.org0.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_TLSCA0" $res

set -x
argocd app sync $REL_TLSCA0
res=$?
set +x
printMessage "$REL_TLSCA0 sync starts" $res

echo "#################################"
echo "### Step 8: Install $REL_RCA0"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_RCA0,file=values-$REL_RCA0.yaml,secret=secrets.org0.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_RCA0" $res

set -x
argocd app sync $REL_RCA0
res=$?
set +x
printMessage "$REL_RCA0 sync starts" $res

set -x
argocd app wait $REL_TLSCA0 $REL_RCA0 --timeout 300
res=$?
set +x
printMessage "$REL_TLSCA0 | $REL_RCA0 is healthy and sync" $res

echo "#################################"
echo "### Step 9: Workflow: crypto-$REL_TLSCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_TLSCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_TLSCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-tlsca0" $res

echo "#################################"
echo "### Step 10: Workflow: crypto-$REL_RCA0"
echo "#################################"
set -x
helm template ../workflow/cryptogen -f ../workflow/cryptogen/values-$REL_RCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_RCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA0" $res

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

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA0-b.yaml | argo -n $NS0 submit - --wait
res=$?
set +x
printMessage "create secret rca0 - Step 5 to Step 10" $res

set -x
helm template ../workflow/secrets -f ../workflow/secrets/values-$REL_RCA1.yaml | argo -n $NS1 submit - --wait
res=$?
set +x
printMessage "create secret rca1" $res

echo "#################################"
echo "### Step 12: Create genesis block and channeltx"
echo "#################################"
# Note: It will not detect if the gcs bucket has genesis. If already exist, this workflow will fail.
set -x
helm template ../workflow/genesis | argo -n $NS0 submit - --watch --request-timeout 120s
res=$?
set +x
printMessage "create genesis.block in $NS0" $res

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

echo "#################################"
echo "### Step 13: Install orderers"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_O0,file=values-$REL_O0.yaml,path=hlf-ord,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O0" $res

set -x
argocd app sync $REL_O0
res=$?
set +x
printMessage "$REL_O0 sync starts" $res

set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_O1,file=values-$REL_O1.yaml,path=hlf-ord,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O1" $res

set -x
argocd app sync $REL_O1
res=$?
set +x
printMessage "$REL_O1 sync starts" $res

set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_O2,file=values-$REL_O2.yaml,path=hlf-ord,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O2" $res

set -x
argocd app sync $REL_O2
res=$?
set +x
printMessage "$REL_O2 sync starts" $res

set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_O3,file=values-$REL_O3.yaml,path=hlf-ord,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O3" $res

set -x
argocd app sync $REL_O3
res=$?
set +x
printMessage "$REL_O3 sync starts" $res

set -x
helm template ../argo-app --set ns=$NS0,rel=$REL_O4,file=values-$REL_O4.yaml,path=hlf-ord,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O4" $res

set -x
argocd app sync $REL_O4
res=$?
set +x
printMessage "$REL_O4 sync starts" $res

set -x
argocd app wait $REL_O0 $REL_O1 $REL_O2 $REL_O3 $REL_O4 --timeout 300
res=$?
set +x
printMessage "$REL_O0 | $REL_O1 | $REL_O2 | $REL_O3 | $REL_O4 are healthy and sync" $res

echo "#################################"
echo "### Step 14: Install $REL_PEER"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=$REL_PEER,file=values-$REL_PEER.yaml,path=hlf-peer,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_PEER" $res

set -x
argocd app sync $REL_PEER
res=$?
set +x
printMessage "$REL_PEER sync starts" $res

echo "#################################"
echo "### Step 15: Install $REL_GUPLOAD"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=$REL_GUPLOAD,file=values-$REL_GUPLOAD.yaml,path=gupload,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_GUPLOAD" $res

set -x
argocd app sync $REL_GUPLOAD
res=$?
set +x
printMessage "$REL_GUPLOAD sync starts" $res

set -x
argocd app wait $REL_PEER $REL_GUPLOAD --timeout 120
res=$?
set +x
printMessage "$REL_PEER | $REL_GUPLOAD are healthy and sync" $res

echo "#################################"
echo "### Step 16: Bootstrap part 1"
echo "#################################"
set -x
helm template ../workflow/bootstrap -f ../workflow/bootstrap/values-org1-a.yaml | argo -n $NS1 submit - --watch --request-timeout 300s
res=$?
set +x
printMessage "bootstrap part 1" $res

echo "#################################"
echo "### Step 17: Install chaincode"
echo "#################################"
set -x
helm template ../argo-app --set ns=$NS1,rel=eventstore,file=values-org1.yaml,path=hlf-cc,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: eventstore" $res

set -x
argocd app sync eventstore
res=$?
set +x
printMessage "eventstore sync starts" $res

set -x
argocd app wait eventstore --timeout 120
res=$?
set +x
printMessage "eventstore is healthy and sync" $res

echo "#################################"
echo "### Step 18: Bootstrap part 2"
echo "#################################"
set -x
helm template ../workflow/bootstrap -f ../workflow/bootstrap/values-org1-b.yaml | argo -n $NS1 submit - --watch --request-timeout 300s
res=$?
set +x
printMessage "bootstrap part 2" $res

echo "#################################"
echo "### Step 19: Create"
echo "#################################"

#### Run wow-bootstrap.n1.yaml

#### MAKE tlscacert.pem PUBLIC


# NOT WORKING
#export POD_RCA=$(kubectl get pods -n n1 -l "app=hlf-ca,release=rca1" -o jsonpath="{.items[0].metadata.name}")
#export CERT=$(kubectl -n n1 exec $POD_RCA -c ca -- cat ./Org1MSP/peer0.org1.net/tls-msp/signcerts/cert.pem)
#export KEY=$(kubectl -n n1 exec $POD_RCA -c ca -- cat ./Org1MSP/peer0.org1.net/tls-msp/keystore/key.pem)
#kubectl -n istio-system delete secret argo-tls
#kubectl -n istio-system create secret generic argo-tls --from-literal=cert="$CERT" --from-literal=key="$KEY"

# Don't work because pvc-org1 cannot be mount to istio-system
#helm template ../workflow/secrets -f ../workflow/secrets/values-istio-org1.yaml | argo -n istio-system submit - --wait

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
