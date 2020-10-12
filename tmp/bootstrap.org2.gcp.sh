#!/bin/bash
. ./scripts/setup.sh
. ./scripts/env.org2.sh

# Non-org2 variables
ORDERER_URL=orderer0.org0.com
MSPID_0=Org0MSP
MSPID_1=Org1MSP
G1_URL=gupload.org1.net:15443
TLSCACERT_0=org0.com-tlscacert
TLSCACERT_1=org1.net-tlscacert
TLSCACERT_2=org2.net-tlscacert
REL_GUPLOAD1=g1

SECONDS=0

./scripts/rm-secret.n2.sh
mkdir -p ./download
rm ./download/*.pem

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN"
echo "#################################"
helm install $REL_ORGADMIN -n $NS -f $RELEASE_DIR/orgadmin.$CLOUD.yaml ./orgadmin
printMessage "install $REL_ORGADMIN" $?
set -x
export POD_PSQL=$(kubectl get pods -n $NS -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=$REL_ORGADMIN" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL -n $NS
res=$?
set +x
printMessage "pod/$POD_PSQL" $res

sleep 10

echo "#################################"
echo "### Step 2: Install $REL_TLSCA"
echo "#################################"
helm install $REL_TLSCA -n $NS -f $RELEASE_DIR/tlsca-hlf-ca.$CLOUD.yaml ./hlf-ca
printMessage "install $REL_TLSCA" $?
set -x
export POD_TLSCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_TLSCA" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA -n $NS
res=$?
set +x
printMessage "pod/$POD_TLSCA" $res

sleep 10

echo "#################################"
echo "### Step 3: Install $REL_RCA"
echo "#################################"
helm install $REL_RCA -n $NS -f $RELEASE_DIR/rca-hlf-ca.$CLOUD.yaml ./hlf-ca
set -x
export POD_RCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_RCA" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA -n $NS
res=$?
set +x
printMessage "pod/$POD_RCA" $res

sleep 10

echo "#################################"
echo "### Step 4: Job: $REL_TLSCA"
echo "#################################"
helm install crypto-$REL_TLSCA -n $NS -f $RELEASE_DIR/tlsca-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-$REL_TLSCA" $?
set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_TLSCA-cryptogen -n $NS
res=$?
set +x
printMessage "job/crypto-$REL_TLSCA-cryptogen" $res


echo "#################################"
echo "### Step 5: Job: $REL_RCA"
echo "#################################"
helm install crypto-$REL_RCA -n $NS -f $RELEASE_DIR/rca-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-$REL_RCA" $?
set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-$REL_RCA-cryptogen -n $NS
res=$?
set +x
printMessage "job/crypto-$REL_RCA-cryptogen" $res

echo "#################################"
echo "### Step 6: Create secrets"
echo "#################################"
./scripts/create-secret.rca2.sh
printMessage "create secret rca2" $?

sleep 5

echo "#################################"
echo "### Step 7: Install gupload $REL_GUPLOAD"
echo "#################################"
helm install $REL_GUPLOAD -n $NS -f $RELEASE_DIR/gupload.$CLOUD.yaml ./gupload
set -x
export POD_GUPLOAD=$(kubectl get pods -n $NS -l "app=gupload,release=$REL_GUPLOAD" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_GUPLOAD -n $NS
res=$?
set +x
printMessage "pod/$REL_GUPLOAD" $res


echo "#################################"
echo "### Step 8: Out-of-band process"
echo "#################################"

echo "# IMPORTANT NOTE: THIS SUB-STEP REQUIRING MANUAL INTERRUPTION"
# Below step may be replaced by manual step, to obtain org1 root cert
echo "######## 0. [$NS1] ==> obtain $TLSCACERT_1.pem from out-of-band process"
export POD_RCA1=$(kubectl get pods -n $NS1 -l "app=hlf-ca,release=$REL_RCA1" -o jsonpath="{.items[0].metadata.name}")
set -x
kubectl -n $NS1 exec $POD_RCA1 -c ca -- cat ./$MSPID_1/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT_1.pem
res=$?
set +x
printMessage "download $TLSCACERT_1.pem from n1" $res

# org1 root cert is used to connect to G1 with "gupload" cli in sequent steps
echo "######## 1. [$NS] ==> cp $TLSCACERT_1.pem to $REL_GUPLOAD"
set -x
kubectl -n $NS cp ./download/$TLSCACERT_1.pem $POD_GUPLOAD:/var/gupload/fileserver/ -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT_1.pem to $REL_GUPLOAD" $res

echo "######## 2. [$NS] ==> create secret $TLSCACERT_1"
set -x
kubectl -n $NS create secret generic $TLSCACERT_1 --from-file=tlscacert.pem=./download/$TLSCACERT_1.pem
res=$?
set +x
printMessage "create secret $TLSCACERT_1 for $NS" $res

# $TLSCACERT_0 will be saved in 'fileserver' directory of pvc-gupload2
# also, need to use correct --cacert
echo "######## 3. [$NS] ==> obtain $TLSCACERT_0.pem using Gupload"
set -x
kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cd fileserver && ./gupload download --cacert $TLSCACERT_1.pem --file $TLSCACERT_0.pem --address $G1_URL"
res=$?
set +x
printMessage "obtain $TLSCACERT_0.pem using Gupload" $res

echo "######## 4. [$NS] ==> create secret $TLSCACERT_0"
CONTENT=$(kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cat ./fileserver/$TLSCACERT_0.pem")
preventEmptyValue "$TLSCACERT_0" $CONTENT
kubectl -n $NS create secret generic $TLSCACERT_0 --from-literal=tlscacert.pem="$CONTENT"
res=$?
printMessage "create secret $TLSCACERT_0 for $NS" $res

# Below step cp $TLSCACERT_2 to 'fileserver/public' directory pvc-gupload2 for later sharing
echo "######## 5. [$NS] ==> cp $TLSCACERT_2 to $REL_GUPLOAD"
POD_RCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_RCA" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA
set -x
kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT_2.pem
res=$?
set +x
printMessage "download $TLSCACERT_2.pem from $NS" $res
set -x
kubectl -n $NS cp ./download/$TLSCACERT_2.pem $POD_GUPLOAD:/var/gupload/fileserver/public -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT_2.pem to $REL_GUPLOAD" $res

# Below step gupload $TLSCACERT_2 to 'fileserver/public' directory pvc-gupload1 for later sharing
# note that --cacert is located under fileserver, by step 4 above.
echo "######## 6. [$NS] ==> gupload $TLSCACERT_2 to $G1_URL"
set -x
kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cd fileserver && ./gupload upload --cacert $TLSCACERT_1.pem --infile ./public/$TLSCACERT_2.pem --public=true --outfile $TLSCACERT_2.pem  --address $G1_URL"
res=$?
set +x
printMessage "gupload $TLSCACERT_2 to $G1_URL" $res

echo "######## 7. [$NS] ==> create secret $TLSCACERT_2"
set -x
kubectl -n $NS create secret generic $TLSCACERT_2 --from-file=tlscacert.pem=./download/$TLSCACERT_2.pem
res=$?
set +x
printMessage "create secret $TLSCACERT_2 for $NS" $res

# NOTE: Below step 8 - 9 is performed by $NS1
echo "# [Org1] IMPORTANT NOTE: THIS SUB-STEP REQUIRING MANUAL INTERRUPTION"
echo "######## 8. [$NS1] obtain $TLSCACERT_2"
export POD_GUPLOAD1=$(kubectl get pods -n $NS1 -l "app=gupload,release=$REL_GUPLOAD1" -o jsonpath="{.items[0].metadata.name}")
set -x
kubectl -n $NS1 exec $POD_GUPLOAD1 -c gupload -- cat ./fileserver/public/$TLSCACERT_2.pem > ./download/$TLSCACERT_2.upload.pem
res=$?
set +x
printMessage "obtain $TLSCACERT_2" $res

echo "######## 9. [$NS1] create secret $TLSCACERT_2"
set -x
kubectl -n $NS1 create secret generic $TLSCACERT_2 --from-file=tlscacert.pem=./download/$TLSCACERT_2.upload.pem
res=$?
set +x
printMessage "create secret $TLSCACERT_2 for $NS1" $res

echo "#####################################################################"
echo "### END: OUT OF BAND"
echo "#####################################################################"

# step 9 requires out-of-band process to start; requiring below secrets
echo "#################################"
echo "### Step 9: Install peer: $REL_PEER"
echo "#################################"
helm install $REL_PEER -n $NS -f $RELEASE_DIR/hlf-peer.$CLOUD.yaml ./hlf-peer
set -x
export POD_PEER=$(kubectl get pods -n $NS -l "app=hlf-peer,release=$REL_PEER" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PEER -n $NS
res=$?
set +x
printMessage "pod/$REL_PEER" $res

sleep 5

echo "#####################################################################"
echo "### MULTIPLE ORGS WORKFLOW"
echo "#####################################################################"
echo "######## [Org1] ==> fetch current block"
helm install $JOB_FETCH_BLOCK -n $NS1 -f ./releases/org1/fetch-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_FETCH_BLOCK-hlf-operator--fetch -n $NS1
res=$?
set +x
printMessage "job/fetch block" $res

sleep 5

echo "######## [Org2] ==> prepares add-org update-channel-envelope"
helm install $JOB_NEWORG -n $NS -f ./releases/org2/neworg-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_NEWORG-hlf-operator--neworg -n $NS
res=$?
set +x
printMessage "job/new org" $res

sleep 5

echo "######## [Org1] ==> sign the updatechannel block"
helm install $JOB_UPDATE_CHANNEL -n $NS1 -f ./releases/org1/upch1-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_UPDATE_CHANNEL-hlf-operator--updatechannel -n $NS1
res=$?
set +x
printMessage "job/update channel" $res

sleep 5

echo "######## [Org2] ==> join channel"
helm install $JOB_JOINCHANNEL -n $NS -f ./releases/org2/joinch2-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_JOINCHANNEL-hlf-operator--joinchannel -n $NS
res=$?
set +x
printMessage "job/join channel" $res

export POD_CLI=$(kubectl get pods --namespace $NS -l "app=orgadmin,release=$REL_ORGADMIN" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI

sleep 10

echo "######## [Org2] ==> Update anchor peer; package & install chaincode"
helm install $JOB_INSTALL_CHAINCODE_A -n $NS -f ./releases/org2/installcc-a.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/$JOB_INSTALL_CHAINCODE_A-hlf-operator--bootstrap -n $NS
res=$?
set +x
printMessage "job/install chaincode part1" $res

sleep 10

set -x
export CCID=$(kubectl -n $NS exec $POD_CLI -- cat /var/hyperledger/crypto-config/channel-artifacts/packageid.txt)
res=$?
set +x
printMessage "retrieve CCID" $res
preventEmptyValue "chaincodeId" $CCID

echo "######## [Org2] ==> Launch chaincode container"
helm install eventstore -n $NS --set ccid=$CCID -f ./releases/org2/eventstore-hlf-cc.gcp.yaml ./hlf-cc
set -x
export POD_CC2=$(kubectl get pods -n $NS -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC2 -n $NS
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

# NOTE: there is an unknonw timeslapse between the chaincode server starts, and container.
# TODO: research how to use readiness probe for chaincode server.
sleep 30

echo "######## [Org2] ==> Approve chaincode and run smoke test"
helm install $JOB_INSTALL_CHAINCODE_B -n $NS -f ./releases/org2/installcc-b.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 180s job/$JOB_INSTALL_CHAINCODE_B-hlf-operator--bootstrap -n $NS
res=$?
set +x
printMessage "job/install chaincode part2" $res

echo "#####################################################################"
echo "### END: MULTIPLE ORGS WORKFLOW"
echo "#####################################################################"

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
