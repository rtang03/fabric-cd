#!/bin/bash

. ./scripts/setup.sh
. "env.org1.sh"

SECONDS=0
TARGET=dev-0.0.1-b

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN1"
echo "#################################"
set -x
helm template ./argo-app --set ns=$NS1,rel=$REL_ORGADMIN1,file=values-$REL_ORGADMIN1.yaml,secret=secrets.$REL_ORGADMIN1.yaml,path=orgadmin,target=$TARGET | argocd app create -f -
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
helm template ./argo-app --set ns=$NS1,rel=$REL_TLSCA1,file=values-$REL_TLSCA1.yaml,secret=secrets.org1.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
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
helm template ./argo-app --set ns=$NS1,rel=$REL_RCA1,file=values-$REL_RCA1.yaml,secret=secrets.org1.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create apps: $REL_RCA1" $res

set -x
argocd app sync $REL_RCA1
res=$?
set +x
printMessage "$REL_RCA1 sync starts" $res

set -x
argocd app wait $REL_TLSCA1 $REL_RCA1 --timeout 240
res=$?
set +x
printMessage "$REL_TLSCA1 | $REL_RCA1 is healthy and sync" $res


echo "#################################"
echo "### Step 4: Workflow: crypto-$REL_TLSCA1"
echo "#################################"
set -x
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_TLSCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_TLSCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow cryptogen-$REL_TLSCA1" $res

echo "#################################"
echo "### Step 5: Workflow crypto-$REL_RCA1"
echo "#################################"
set -x
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --generate-name cryptogen-$REL_RCA1- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA1" $res

echo "#################################"
echo "### Step 6: Install $REL_ORGADMIN0"
echo "#################################"
set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_ORGADMIN0,file=values-$REL_ORGADMIN0.yaml,secret=secrets.$REL_ORGADMIN0.yaml,path=orgadmin,target=$TARGET | argocd app create -f -
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
helm template ./argo-app --set ns=$NS0,rel=$REL_TLSCA0,file=values-$REL_TLSCA0.yaml,secret=secrets.org0.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
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
helm template ./argo-app --set ns=$NS0,rel=$REL_RCA0,file=values-$REL_RCA0.yaml,secret=secrets.org0.yaml,path=hlf-ca,target=$TARGET | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_RCA0" $res

set -x
argocd app sync $REL_RCA0
res=$?
set +x
printMessage "$REL_RCA0 sync starts" $res

set -x
argocd app wait $REL_TLSCA0 $REL_RCA0 --timeout 240
res=$?
set +x
printMessage "$REL_TLSCA0 | $REL_RCA0 is healthy and sync" $res

echo "#################################"
echo "### Step 9: Workflow: crypto-$REL_TLSCA0"
echo "#################################"
set -x
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_TLSCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_TLSCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-tlsca0" $res

echo "#################################"
echo "### Step 10: Workflow: crypto-$REL_RCA0"
echo "#################################"
set -x
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_RCA0.yaml | argo -n $NS0 submit - --generate-name cryptogen-$REL_RCA0- --watch --request-timeout 120s
res=$?
set +x
printMessage "run workflow crypto-$REL_RCA0" $res

echo "#################################"
echo "### Step 11: Create secrets"
echo "#################################"
./scripts/create-secret.rca0.sh
printMessage "create secret rca0" $?

./scripts/create-secret.rca1.sh
printMessage "create secret rca1" $?

echo "#################################"
echo "### Step 12: Create genesis block and channeltx"
echo "#################################"
set -x
POD_CLI0=$(kubectl get pods -n $NS0 -l "app=orgadmin,release=$REL_ORGADMIN0" -o jsonpath="{.items[0].metadata.name}")
set +x
preventEmptyValue "pod unavailable" $POD_CLI0

sleep 30

######## 2. Create genesis.block / channel.tx / anchor.tx
set -x
kubectl -n $NS0 exec -it $POD_CLI0 -- sh -c "/var/hyperledger/bin/configtxgen -configPath /var/hyperledger/cli/configtx -profile OrgsOrdererGenesis -outputBlock /var/hyperledger/crypto-config/genesis.block -channelID ordererchannel"
res=$?
set +x
printMessage "create genesis block" $res
set -x
kubectl -n $NS0 exec -it $POD_CLI0 -- sh -c "/var/hyperledger/bin/configtxgen -configPath /var/hyperledger/cli/configtx -profile OrgsChannel -outputCreateChannelTx /var/hyperledger/crypto-config/channel.tx -channelID loanapp"
res=$?
set +x
printMessage "create channel.tx" $res

######## 3. Create configmap: genesis.block
set -x
kubectl -n $NS0 exec $POD_CLI0 -- cat /var/hyperledger/crypto-config/genesis.block > genesis.block
res=$?
set +x
printMessage "obtain genesis block" $res

kubectl -n $NS0 delete secret genesis
kubectl -n $NS0 create secret generic genesis --from-file=genesis=./genesis.block
printMessage "create secret genesis" $?

rm genesis.block

######## 4. Create configmap: channel.tx for $ORG1, with namespace $NS1
kubectl -n $NS0 exec $POD_CLI0 -- cat /var/hyperledger/crypto-config/channel.tx > channel.tx

kubectl -n $NS1 delete secret channeltx

kubectl -n $NS1 create secret generic channeltx --from-file=channel.tx=./channel.tx
printMessage "create secret channeltx" $?
rm channel.tx

echo "#################################"
echo "### Step 13: Install orderers"
echo "#################################"
set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_O0,file=values-$REL_O0.yaml,path=hlf-ord | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O0" $res

set -x
argocd app sync $REL_O0
res=$?
set +x
printMessage "$REL_O0 sync starts" $res

set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_O1,file=values-$REL_O1.yaml,path=hlf-ord | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O1" $res

set -x
argocd app sync $REL_O1
res=$?
set +x
printMessage "$REL_O1 sync starts" $res

set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_O2,file=values-$REL_O2.yaml,path=hlf-ord | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O2" $res

set -x
argocd app sync $REL_O2
res=$?
set +x
printMessage "$REL_O2 sync starts" $res

set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_O3,file=values-$REL_O3.yaml,path=hlf-ord | argocd app create -f -
res=$?
set +x
printMessage "create app: $REL_O3" $res

set -x
argocd app sync $REL_O3
res=$?
set +x
printMessage "$REL_O3 sync starts" $res

set -x
helm template ./argo-app --set ns=$NS0,rel=$REL_O4,file=values-$REL_O4.yaml,path=hlf-ord | argocd app create -f -
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
helm template ./argo-app --set ns=$NS1,rel=$REL_PEER,file=values-$REL_PEER.yaml,path=hlf-peer | argocd app create -f -
helm template ./argo-app --set ns=n1,rel=p0o1,file=values-p0o1.yaml,path=hlf-peer | argocd app create -f -
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
helm template ./argo-app --set ns=$NS1,rel=$REL_GUPLOAD,file=values-$REL_GUPLOAD.yaml,path=gupload | argocd app create -f -
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
#helm template ./bootstrap-flow | argo -n n1 submit -
#helm template ./bootstrap-flow | argo -n n1 submit - --watch

#echo "#################################"
#echo "### Step 17: Install chaincode"
#echo "#################################"
#
#echo "#################################"
#echo "### Step 18: Bootstrap part 2"
#echo "#################################"

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
