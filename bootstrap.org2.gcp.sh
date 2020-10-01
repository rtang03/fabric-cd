#!/bin/bash
. ./scripts/setup.sh
. ./scripts/env.org2.sh

ORDERER_URL=orderer0.org0.com
MSPID=Org0MSP

SECONDS=0

./scripts/rm-secret.n2.sh
mkdir -p ./download
rm ./download/*.crt

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


# Out of band process may be replaced by other manual arrangement, instead of using kubectl commands
# Below steps require kubectl commands to access corresponding orgs'.
echo "#################################"
echo "### Step 8: Out-of-band process"
echo "#################################"
# Sub-step 1 to 3 below are common to newly added orgs:
# org0.com-tlscacert, ord-tlsrootcert are required to connect to orderer0
# Step 4 an 5 are only required for join channel, install/approve cc.

export POD_CLI=$(kubectl get pods -n $NS -l "app=orgadmin,release=$REL_ORGADMIN" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI

# IMPORTANT NOTE: require kubectl connect to $NS0. If not, need to do it offline, for sub-step 1 - 3.
export POD_RCA0=$(kubectl get pods -n $NS0 -l "app=hlf-ca,release=$REL_RCA0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA0

# TODO: This may not require. Double check it.
echo "########  1. create $ORDERER_URL-tlssigncert for $NS"
set -x
kubectl -n $NS0 exec $POD_RCA0 -c ca -- cat ./$MSPID/$ORDERER_URL/tls-msp/signcerts/cert.pem > ./download/$ORDERER_URL-tlssigncert.crt
res=$?
set +x
printMessage "download Org0MSP/$ORDERER_URL/tls-msp/signcerts/cert.pem from $NS0" $res
set -x
kubectl -n $NS create secret generic "$ORDERER_URL-tlssigncert" --from-file=cert.pem=./download/$ORDERER_URL-tlssigncert.crt
res=$?
set +x
printMessage "create secret $ORDERER_URL-tlssigncert for $NS" $res

echo "########  2. create $ORDERER_URL-tlsrootcert for $NS"
set -x
kubectl -n $NS0 exec $POD_RCA0 -c ca -- cat ./$MSPID/$ORDERER_URL/tls-msp/tlscacerts/tls-$REL_TLSCA0-hlf-ca-7054.pem > ./download/$ORDERER_URL-tlsrootcert.crt
res=$?
set +x
printMessage "download $MSPID/$ORDERER_URL/tls-msp/tlscacerts/tls-$REL_TLSCA0-hlf-ca-7054.pem from $NS" $res
set -x
kubectl -n $NS create secret generic "$ORDERER_URL-tlsrootcert" --from-file=tlscacert.pem=./download/$ORDERER_URL-tlsrootcert.crt
res=$?
set +x
printMessage "create secret $ORDERER_URL-tlsrootcert for $NS" $res

echo "######## 3. create secret org0.com-tlscacert for $NS"
set -x
kubectl -n $NS0 exec $POD_RCA0 -c ca -- sh -c "cat ./$MSPID/msp/tlscacerts/tls-ca-cert.pem" > ./download/org0tlscacert.crt
res=$?
set +x
printMessage "download $MSPID/msp/tlscacerts/tls-ca-cert.pem from $NS0" $res
set -x
kubectl -n $NS create secret generic org0.com-tlscacert --from-file=tlscacert.pem=./download/org0tlscacert.crt
res=$?
set +x
printMessage "create secret org0.com-tlscacert for $NS" $res

####### RESUME FROM HERE

# IMPORTANT NOTE: require kubectl connect to all org's. If not, need to do it offline, for sub-step 4 - 5.
echo "# ORG1: Out-of-band process: Manually send p0o1.crt from org2 to org1"
export POD_RCA2=$(kubectl get pods -n n2 -l "app=hlf-ca,release=rca2" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA2
echo "# ORG2: Out-of-band process: Manually send p0o2.crt from org1 to org2"
export POD_RCA1=$(kubectl get pods -n n1 -l "app=hlf-ca,release=rca1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA1

echo "######## 4. create org1.net-tlscacert for $NS"
set -x
kubectl -n n1 exec $POD_RCA1 -c ca -- cat ./Org1MSP/msp/tlscacerts/tls-ca-cert.pem > ./download/org1tlscacert.crt
res=$?
set +x
printMessage "download Org1MSP/msp/tlscacerts/tls-ca-cert.pem from n1" $res
set -x
kubectl -n $NS create secret generic org1-tls-ca-cert --from-file=tls.crt=./download/org1tlscacert.crt
res=$?
set +x
printMessage "create secret org1-tls-ca-cert for n2" $res

echo "######## 5. create org2-tls-ca-cert for n2"
set -x
kubectl -n n2 exec $POD_RCA2 -c ca -- cat ./Org2MSP/msp/tlscacerts/tls-ca-cert.pem > ./download/org2tlscacert.crt
res=$?
set +x
printMessage "download Org2MSP/msp/tlscacerts/tls-ca-cert.pem from n2" $res
set -x
kubectl -n n1 create secret generic org2-tls-ca-cert --from-file=tls.crt=./download/org2tlscacert.crt
res=$?
set +x
printMessage "create secret org2-tls-ca-cert for n1" $res
set -x
kubectl -n n2 create secret generic org2-tls-ca-cert --from-file=tls.crt=./download/org2tlscacert.crt
res=$?
set +x
printMessage "create secret org2-tls-ca-cert for n2" $res
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

sleep 10

echo "###### MULTIPLE ORGS WORKFLOW ###"
echo "### Org1 fetch current block"
helm install fetch1 -n n1 -f ./releases/org1/fetchsend-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/fetch1-hlf-operator--fetch-send -n n1
res=$?
set +x
printMessage "job/fetch1-hlf-operator" $res

sleep 10

echo "### Org2 prepares add-org update-channel-envelope"
helm install neworg2 -n n2 -f ./releases/org2/neworgsend-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/neworg2-hlf-operator--neworg-send -n n2
res=$?
set +x
printMessage "job/neworg2-hlf-operator" $res

sleep 10

echo "### Org1 sign the updatechannel block"
helm install upch1 -n n1 -f ./releases/org1/upch1-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/upch1-hlf-operator--updatechannel -n n1
res=$?
set +x
printMessage "job/upch1-hlf-operator" $res

sleep 10

echo "### Org2 join channel"
helm install joinch2 -n n2 -f ./releases/org2/joinch2-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/joinch2-hlf-operator--joinchannel -n n2
res=$?
set +x
printMessage "job/joinch2-hlf-operator" $res

export POD_CLI2=$(kubectl get pods --namespace n2 -l "app=orgadmin,release=admin2" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

echo "### Update anchor peer; package & install chaincode"
helm install installcc2a -n n2 -f ./releases/org2/installcc-a.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/installcc2a-hlf-operator--bootstrap -n n2
res=$?
set +x
printMessage "job/install chaincode part1" $res

set -x
export CCID=$(kubectl -n n2 exec $POD_CLI2 -- cat /var/hyperledger/crypto-config/channel-artifacts/packageid.txt)
res=$?
set +x
printMessage "retrieve CCID" $res

echo "### Launch chaincode container"
helm install eventstore -n n2 --set ccid=$CCID -f ./releases/org2/eventstore-hlf-cc.gcp.yaml ./hlf-cc
set -x
export POD_CC2=$(kubectl get pods -n n2 -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC2 -n n2
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

sleep 10

echo "### Approach chaincode and run smoke test"
helm install installcc2b -n n2 -f ./releases/org2/installcc-b.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 180s job/installcc2b-hlf-operator--bootstrap -n n2
res=$?
set +x
printMessage "job/install chaincode part2" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
