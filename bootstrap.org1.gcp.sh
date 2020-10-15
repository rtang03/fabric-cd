#!/bin/bash

. ./scripts/setup.sh
. "env.org1.sh"

SECONDS=0

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN1"
echo "#################################"
helm install $REL_ORGADMIN1 -n $NS1 -f ./orgadmin/values-$REL_ORGADMIN1.yaml ./orgadmin
printMessage "install $REL_ORGADMIN1" $?

set -x
kubectl wait --for=condition=Available --timeout 180s deployment/$REL_ORGADMIN1-orgadmin-cli -n $NS1
res=$?
set +x
printMessage "deployment/$REL_ORGADMIN1-orgadmin-cli" $res

set -x
POD_PSQL1=$(kubectl get pods -n $NS1 -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=$REL_ORGADMIN1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL1 -n $NS1
res=$?
set +x
printMessage "pod/$POD_PSQL1" $res

sleep 30

echo "#################################"
echo "### Step 2: Install $REL_TLSCA1"
echo "#################################"
helm install $REL_TLSCA1 -n $NS1 -f ./hlf-ca/values-$REL_TLSCA1.yaml ./hlf-ca
printMessage "install $REL_TLSCA1" $?

set -x
POD_TLSCA1=$(kubectl get pods -n $NS1 -l "app=hlf-ca,release=$REL_TLSCA1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA1 -n $NS1
res=$?
set +x
printMessage "pod/$POD_TLSCA1" $res

echo "#################################"
echo "### Step 3: Install $REL_RCA1"
echo "#################################"
helm install $REL_RCA1 -n $NS1 -f ./hlf-ca/values-$REL_RCA1.yaml ./hlf-ca
printMessage "install $REL_RCA1" $?

set -x
POD_RCA1=$(kubectl get pods -n $NS1 -l "app=hlf-ca,release=$REL_RCA1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA1 -n $NS1
res=$?
set +x
printMessage "pod/$POD_RCA1" $res

sleep 30

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

sleep 30

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

echo "#################################"
echo "### Step 6: Install $REL_ORGADMIN0"
echo "#################################"
helm install $REL_ORGADMIN0 -n $NS0 -f ./orgadmin/values-$REL_ORGADMIN0.yaml ./orgadmin
printMessage "install $REL_ORGADMIN0" $?

set -x
POD_PSQL0=$(kubectl get pods -n $NS0 -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=$REL_ORGADMIN0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL0 -n $NS0
res=$?
set +x
printMessage "pod/$POD_PSQL0" $res

sleep 30

echo "#################################"
echo "### Step 7: Install $REL_TLSCA0"
echo "#################################"
helm install $REL_TLSCA0 -n $NS0 -f ./hlf-ca/values-$REL_TLSCA0.yaml ./hlf-ca
printMessage "install $REL_TLSCA0" $?

set -x
POD_TLSCA0=$(kubectl get pods -n $NS0 -l "app=hlf-ca,release=$REL_TLSCA0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA0 -n $NS0
res=$?
set +x
printMessage "pod/$POD_TLSCA0" $res

sleep 30

echo "#################################"
echo "### Step 8: Install $REL_RCA0"
echo "#################################"
helm install $REL_RCA0 -n $NS0 -f ./hlf-ca/values-$REL_RCA0.yaml ./hlf-ca
printMessage "install $REL_RCA0" $?

set -x
POD_RCA0=$(kubectl get pods -n $NS0 -l "app=hlf-ca,release=$REL_RCA0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA0 -n $NS0
res=$?
set +x
printMessage "pod/$POD_RCA0" $res

sleep 30

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

sleep 5

echo "#################################"
echo "### Step 11: Create secrets"
echo "#################################"
./scripts/create-secret.rca0.sh
printMessage "create secret rca0" $?

./scripts/create-secret.rca1.sh
printMessage "create secret rca1" $?

sleep 30

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

echo "#################################"
echo "### Step 13: Install orderers"
echo "#################################"

helm install o1 -f ./hlf-ord/values-$REL_O1.yaml -n $NS0 ./hlf-ord
sleep 3
helm install o2 -f ./hlf-ord/values-$REL_O2.yaml -n $NS0 ./hlf-ord
sleep 3
helm install o3 -f ./hlf-ord/values-$REL_O3.yaml -n $NS0 ./hlf-ord
sleep 3
helm install o4 -f ./hlf-ord/values-$REL_O4.yaml -n $NS0 ./hlf-ord
sleep 3
helm install o0 -f ./hlf-ord/values-$REL_O0.yaml -n $NS0 ./hlf-ord
sleep 3

set -x
POD_O0=$(kubectl get pods -n $NS0 -l "app=hlf-ord,release=$REL_O0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_O0 -n $NS0
res=$?
set +x
printMessage "pod/$REL_O0-hlf-ord" $res

echo "#################################"
echo "### Step 14: Install $REL_PEER"
echo "#################################"
helm install $REL_PEER -n $NS1 -f ./hlf-peer/values-$REL_PEER.yaml ./hlf-peer

set -x
POD_P0O1=$(kubectl get pods -n $NS1 -l "app=hlf-peer,release=$REL_PEER" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_P0O1 -n $NS1
res=$?
set +x
printMessage "pod/$REL_PEER-hlf-peer" $res

echo "#################################"
echo "### Step 15: Install $REL_GUPLOAD"
echo "#################################"
helm install $REL_GUPLOAD -n $NS1 -f ./gupload/values-$REL_GUPLOAD.yaml ./gupload

POD_CLI1=$(kubectl get pods -n $NS1 -l "app=orgadmin,release=$REL_ORGADMIN1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

sleep 10s
echo "#################################"
echo "### Step 16: Bootstrap part 1"
echo "#################################"
helm install $JOB_BOOTSTRAP_A -n $NS1 -f $RELEASE_DIR1/bootstrap-a.$CLOUD.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/$JOB_BOOTSTRAP_A-hlf-operator--bootstrap -n $NS1
res=$?
set +x
printMessage "job/bootstrap part1" $res

echo "#################################"
echo "### Step 17: Install chaincode"
echo "#################################"
set -x
CCID=$(kubectl -n $NS1 exec $POD_CLI1 -- cat /var/hyperledger/crypto-config/channel-artifacts/packageid.txt)
res=$?
set +x
printMessage "retrieve CCID" $res

helm install eventstore -n $NS1 --set ccid=$CCID -f ./hlf-cc/values-$ORG1.yaml ./hlf-cc

set -x
POD_CC1=$(kubectl get pods -n $NS1 -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC1 -n $NS1
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

sleep 10s

echo "#################################"
echo "### Step 18: Bootstrap part 2"
echo "#################################"
helm install $JOB_BOOTSTRAP_B -n $NS1 -f $RELEASE_DIR1/bootstrap-b.$CLOUD.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/$JOB_BOOTSTRAP_B-hlf-operator--bootstrap -n $NS1
res=$?
set +x
printMessage "job/bootstrap part2" $res

echo "#################################"
echo "### Step 19: Upload $ORG1 - tls root certs"
echo "#################################"
# download $ORG1 root cert
set -x
kubectl -n $NS1 exec $POD_CLI1 -- cat ./$MSPID1/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT1.pem
res=$?
set +x
printMessage "download $MSPID1/msp/tlscacerts/tls-ca-cert.pem from n1" $res

POD_G1=$(kubectl get pods -n $NS1 -l "app=gupload,release=$REL_GUPLOAD" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_G1

# send $ORG1 root cert to 'public' folder of gupload
set -x
kubectl -n $NS1 cp ./download/$TLSCACERT1.pem $POD_G1:/var/gupload/fileserver/public/ -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT1.pem to g1-gupload" $res

echo "#################################"
echo "### Step 20: Upload $ORG0 - tls root certs"
echo "#################################"
POD_CLI0=$(kubectl get pods -n $NS0 -l "app=orgadmin,release=$REL_ORGADMIN0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

# download $ORG0 root cert
set -x
kubectl -n $NS0 exec $POD_CLI0 -- cat ./$MSPID0/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT0.pem
res=$?
set +x
printMessage "download $MSPID0/msp/tlscacerts/tls-ca-cert.pem from $NS0" $res

# send $ORG1 root cert to 'public' folder of gupload
set -x
kubectl -n $NS1 cp ./download/$TLSCACERT0.pem $POD_G1:/var/gupload/fileserver/public/ -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT0.pem to $REL_GUPLOAD" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
