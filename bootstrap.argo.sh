#!/bin/bash

. ./scripts/setup.sh
. "env.org1.sh"

kubectl -n argocd apply -f ./argocd/app-admin1.yaml

argocd app sync admin1

argocd app wait admin1 --timeout 120

kubectl -n argocd apply -f ./argocd/app-ca1.yaml

argocd app sync tlsca1

argocd app sync rca1

argocd app wait tlsca1 rca1 --timeout 120

echo "#################################"
echo "### Step 4: Job: crypto-$REL_TLSCA1"
echo "#################################"
helm install crypto-$REL_TLSCA1 -n $NS1 -f $RELEASE_DIR1/tlsca-cryptogen.$CLOUD.yaml ./cryptogen
printMessage "install crypto-tlsca1" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_TLSCA1-cryptogen -n $NS1
res=$?
set +x
printMessage "job/crypto-$REL_TLSCA1-cryptogen" $res

echo "#################################"
echo "### Step 5: Job crypto-$REL_RCA1"
echo "#################################"
helm install crypto-$REL_RCA1 -n $NS1 -f $RELEASE_DIR1/rca-cryptogen.$CLOUD.yaml ./cryptogen
printMessage "install crypto-$REL_RCA1" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_RCA1-cryptogen -n $NS1
res=$?
set +x
printMessage "job/crypto-$REL_RCA1-cryptogen" $res


kubectl -n argocd apply -f ./argocd/app-admin0.yaml

argocd app sync admin0

kubectl -n argocd apply -f ./argocd/app-ca0.yaml

argocd app sync tlsca0 --timeout 60

argocd app sync rca0 --timeout 60

echo "#################################"
echo "### Step 9: crypto-$REL_TLSCA0"
echo "#################################"
helm install crypto-$REL_TLSCA0 -n $NS0 -f $RELEASE_DIR0/tlsca-cryptogen.$CLOUD.yaml ./cryptogen
printMessage "install crypto-tlsca0" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_TLSCA0-cryptogen -n $NS0
res=$?
set +x
printMessage "job/crypto-$REL_TLSCA0-cryptogen" $res

sleep 30

echo "#################################"
echo "### Step 10: crypto-$REL_RCA0"
echo "#################################"
helm install crypto-$REL_RCA0 -n $NS0 -f $RELEASE_DIR0/rca-cryptogen.$CLOUD.yaml ./cryptogen
printMessage "install crypto-$REL_RCA0" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_RCA0-cryptogen -n $NS0
res=$?
set +x
printMessage "job/crypto-$REL_RCA0-cryptogen" $res

./scripts/create-secret.rca0.sh
printMessage "create secret rca0" $?

./scripts/create-secret.rca1.sh
printMessage "create secret rca1" $?

echo "#################################"
echo "### Step 12: Create genesis block and channeltx"
echo "#################################"
######## post-install notes for admin0/orgadmin
######## Objective: These steps create geneis.block, and secret "genesis" and "channel.tx"
######## 1. Get the name of the pod running rca:
set -x
POD_CLI0=$(kubectl get pods -n $NS0 -l "app=orgadmin,release=$REL_ORGADMIN0" -o jsonpath="{.items[0].metadata.name}")
set +x
preventEmptyValue "pod unavailable" $POD_CLI0

sleep 2

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

kubectl -n argocd apply -f ./argocd/app-orderers.yaml

argocd app sync o0

argocd app sync o1

argocd app sync o2

argocd app sync o3

argocd app sync o4

#helm template ./bootstrap-flow | argo -n n1 submit - --watch
