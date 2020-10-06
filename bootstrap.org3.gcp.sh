#!/bin/bash
. ./scripts/setup.sh

## Org3
CLOUD=gcp
DOMAIN=org3.net
MSPID=Org3MSP
NS=n3
REL_GUPLOAD=g3
REL_ORGADMIN=admin3
REL_PEER=p0o3
REL_RCA=rca3
REL_TLSCA=tlsca3
RELEASE_DIR=releases/org3
PEER=peer0.org3.net
TLSCACERT=org3.net-tlscacert

## Non-org3
G1_URL=gupload.org1.net:15443
JOB_FETCH_BLOCK=fetch1
JOB_INSTALL_CHAINCODE_A=installcc_a
JOB_INSTALL_CHAINCODE_B=installcc_b
JOB_JOINCHANNEL=joinch
JOB_NEWORG=neworg
JOB_UPDATE_CHANNEL=upch1
MSPID_1=Org1MSP
NS1=n1
RELEASE_DIR1=releases/org1
REL_GUPLOAD1=g1
REL_RCA1=rca1
TLSCACERT_0=org0.com-tlscacert
TLSCACERT_1=org1.net-tlscacert

SECONDS=0

#./scripts/rm-secret.nx.sh
mkdir -p ./download
rm ./download/*.pem

echo "#################################"
echo "### Step 1: Install $REL_ORGADMIN"
echo "#################################"
helm install $REL_ORGADMIN -n $NS -f $RELEASE_DIR/orgadmin.$CLOUD.yaml ./orgadmin
printMessage "install $REL_ORGADMIN" $?
set -x
POD_PSQL=$(kubectl get pods -n $NS -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=$REL_ORGADMIN" -o jsonpath="{.items[0].metadata.name}")
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
POD_TLSCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_TLSCA" -o jsonpath="{.items[0].metadata.name}")
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
POD_RCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_RCA" -o jsonpath="{.items[0].metadata.name}")
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
echo "######## 0. peer msp - cert"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/signcerts/cert.pem)
preventEmptyValue "$MSPID/$PEER/msp/signcerts/cert.pem" $CONTENT

kubectl -n $NS delete secret $PEER-cert
kubectl -n $NS create secret generic "$PEER-cert" --from-literal=cert.pem="$CONTENT"
printMessage "create secret $PEER-cert" $?

echo "######## 1. peer msp - key"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/keystore/key.pem)
preventEmptyValue "$MSPID/$PEER/msp/keystore/key.pem" $CONTENT

kubectl -n $NS delete secret $PEER-key
kubectl -n $NS create secret generic "$PEER-key" --from-literal=key.pem="$CONTENT"
printMessage "create secret $PEER-key" $?

echo "######## 2. secret: CA cert"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/cacerts/$REL_RCA-hlf-ca-7054.pem)
preventEmptyValue "$MSPID/$PEER/msp/cacerts/$REL_RCA-hlf-ca-7054.pem" $CONTENT

kubectl -n $NS delete secret $PEER-cacert
kubectl -n $NS create secret generic "$PEER-cacert" --from-literal=cacert.pem="$CONTENT"
printMessage "create secret $PEER-cacert" $?

echo "######## 3. secret: tls cert and key"
CERT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/signcerts/cert.pem)
preventEmptyValue "$MSPID/$PEER/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/keystore/key.pem)
preventEmptyValue "$MSPID/$PEER/tls-msp/keystore/key.pem" $CONTENT

kubectl -n $NS delete secret $PEER-tls
# NOTE: tls.crt and tls.key is k8 ingress's tls naming convention. Keep the nameing convention
kubectl -n $NS create secret generic "$PEER-tls" --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $PEER-tls" $?

echo "######## 4. secret: tls root CA cert"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/tlscacerts/tls-$REL_TLSCA-hlf-ca-7054.pem)
preventEmptyValue "$MSPID/$PEER/tls-msp/tlscacerts/tls-$REL_TLSCA-hlf-ca-7054.pem" $CONTENT

kubectl -n $NS delete secret $PEER-tlsrootcert
kubectl -n $NS create secret generic "$PEER-tlsrootcert" --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret $PEER-tlsrootcert" $?

echo "######## 5. create secret for $DOMAIN-admin-cert.pem"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/admin/msp/admincerts/$DOMAIN-admin-cert.pem)
preventEmptyValue "$MSPID/admin/msp/admincerts/$DOMAIN-admin-cert.pem" $CONTENT

kubectl -n $NS delete secret $PEER-admincert
kubectl -n $NS create secret generic $PEER-admincert --from-literal=$DOMAIN-admin-cert.pem="$CONTENT"
printMessage "create secret $PEER-admincert" $?

echo "######## 6. create secret for $DOMAIN-admin-key.pem"
CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/admin/msp/keystore/key.pem)
preventEmptyValue "$MSPID/admin/msp/keystore/key.pem" $CONTENT

kubectl -n $NS delete secret $PEER-adminkey
kubectl -n $NS create secret generic "$PEER-adminkey" --from-literal=$DOMAIN-admin-key.pem="$CONTENT"
printMessage "create secret $PEER-adminkey" $?

#### OPTIONAL: NOT CURRENTLY USED
echo "######## 7. Create secret for tls for tlsca, used by ingress controller"
POD_TLSCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_TLSCA" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" POD_TLSCA

CERT=$(kubectl -n $NS exec ${POD_TLSCA} -c ca -- cat ./$MSPID/tls/server/ca-cert.pem)
preventEmptyValue "./$MSPID/tls/server/ca-cert.pem" $CERT

KEY=$(kubectl -n $NS exec ${POD_TLSCA} -c ca -- cat ./$MSPID/tls/server/msp/keystore/key.pem)
preventEmptyValue "./$MSPID/tls/server/msp/keystore/key.pem" $KEY

kubectl -n $NS delete secret $REL_TLSCA-tls
kubectl -n $NS create secret generic $REL_TLSCA-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $REL_TLSCA-tls" $?

#### OPTIONAL: NOT CURRENTLY USED
echo "######## 8. Create secret for tls for rca, used by ingress controller"
CERT=$(kubectl -n $NS exec ${POD_RCA} -c ca -- cat ./$MSPID/ca/server/ca-cert.pem)
preventEmptyValue "./$MSPID/ca/server/ca-cert.pem" $CERT

KEY=$(kubectl -n $NS exec ${POD_RCA} -c ca -- cat ./$MSPID/ca/server/msp/keystore/key.pem)
preventEmptyValue "./$MSPID/ca/server/msp/keystore/key.pem" $KEY

kubectl -n $NS delete secret $REL_RCA-tls
kubectl -n $NS create secret generic $REL_RCA-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $REL_RCA-tls" $?


echo "#################################"
echo "### Step 7: Install gupload $REL_GUPLOAD"
echo "#################################"
helm install $REL_GUPLOAD -n $NS -f $RELEASE_DIR/gupload.$CLOUD.yaml ./gupload
set -x
POD_GUPLOAD=$(kubectl get pods -n $NS -l "app=gupload,release=$REL_GUPLOAD" -o jsonpath="{.items[0].metadata.name}")
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
POD_RCA1=$(kubectl get pods -n $NS1 -l "app=hlf-ca,release=$REL_RCA1" -o jsonpath="{.items[0].metadata.name}")
set -x
kubectl -n $NS1 exec $POD_RCA1 -c ca -- cat ./$MSPID_1/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT_1.pem
res=$?
set +x
printMessage "download $TLSCACERT_1.pem from n1" $res

# org1 root cert is used to connect to G1 with "gupload" cli in sequent steps
echo "######## 1. [$NS] ==> cp $TLSCACERT_1.pem to $REL_GUPLOAD"
POD_GUPLOAD=$(kubectl get pods -n $NS -l "app=gupload,release=$REL_GUPLOAD" -o jsonpath="{.items[0].metadata.name}")
set -x
kubectl -n $NS cp ./download/$TLSCACERT_1.pem $POD_GUPLOAD:/var/gupload/fileserver -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT_1.pem to $REL_GUPLOAD" $res

echo "######## 2. [$NS] ==> create secret $TLSCACERT_1"
kubectl -n $NS delete secret $TLSCACERT_1
set -x
kubectl -n $NS create secret generic $TLSCACERT_1 --from-file=tlscacert.pem=./download/$TLSCACERT_1.pem
res=$?
set +x
printMessage "create secret $TLSCACERT_1 for $NS" $res


echo "######## 3. [$NS] ==> gupload download Index.txt from $NS1"
set -x
kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cd fileserver && ./gupload download --cacert $TLSCACERT_1.pem --file index.txt --address $G1_URL"
res=$?
set +x
printMessage "download index.txt using Gupload" $res
set -x
kubectl -n $NS exec $POD_GUPLOAD -c gupload -- cat /var/gupload/fileserver/index.txt > ./download/index.txt
res=$?
set +x
printMessage "cp index.txt to local folder" $res

echo "######## 4. [$NS] ==> Looping Index.txt to create secret"
cat ./download/index.txt | grep -v index.txt | grep -v $TLSCACERT_1 | while read CERT_FILE
do
  # CERT_FILE, e.g. org0.com-tlscacert.pem
  echo "### [$NS] .... $CERT_FILE"

  # CERT_NAME, e.g. org0.com-tlscacert
  CERT_NAME=$(echo $CERT_FILE | sed -En 's/(.*)[.]pem$/\1/gp')

  # Gupload download from gupload.org1.net
  set -x
  kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cd fileserver && ./gupload download --cacert $TLSCACERT_1.pem --file $CERT_FILE --address $G1_URL"
  res=$?
  set +x
  printMessage "gupload download $CERT_FILE" $res

  # retrieve certicate content
  CONTENT=$(kubectl -n $NS exec $POD_GUPLOAD -c gupload -- cat ./fileserver/$CERT_FILE)
  preventEmptyValue "$CERT_FILE" $CONTENT

  # delete pre-existing secret
  kubectl -n $NS delete secret $CERT_NAME

  # create new tlscacert
  kubectl -n $NS create secret generic $CERT_NAME --from-literal=tlscacert.pem="$CONTENT"
  res=$?
  printMessage "create secret $TLSCACERT_0 for $NS" $res
done

# Below step cp $TLSCACERT to 'fileserver/public' directory pvc-gupload2 for later sharing
echo "######## 5. [$NS] ==> cp $TLSCACERT to $REL_GUPLOAD"
POD_RCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_RCA" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA
set -x
kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/msp/tlscacerts/tls-ca-cert.pem > ./download/$TLSCACERT.pem
res=$?
set +x
printMessage "download $TLSCACERT.pem from $NS" $res
set -x
kubectl -n $NS cp ./download/$TLSCACERT.pem $POD_GUPLOAD:/var/gupload/fileserver/public -c gupload
res=$?
set +x
printMessage "cp $TLSCACERT.pem to $REL_GUPLOAD" $res

# Below step gupload $TLSCACERT to 'fileserver/public' directory pvc-gupload1 for later sharing
# note that --cacert is located under fileserver, by step 4 above.
echo "######## 6. [$NS] ==> gupload $TLSCACERT to $G1_URL"
set -x
kubectl -n $NS exec $POD_GUPLOAD -c gupload -- sh -c "cd fileserver && ./gupload upload --cacert $TLSCACERT_1.pem --infile ./public/$TLSCACERT.pem --public=true --outfile $TLSCACERT.pem  --address $G1_URL"
res=$?
set +x
printMessage "gupload $TLSCACERT to $G1_URL" $res

echo "######## 7. [$NS] ==> create secret $TLSCACERT"
kubectl -n $NS delete secret $TLSCACERT
kubectl -n $NS create secret generic $TLSCACERT --from-file=tlscacert.pem=./download/$TLSCACERT.pem
res=$?
printMessage "create secret $TLSCACERT for $NS" $res

# NOTE: Below step 8 - 9 is performed by $NS1
echo "# [$NS1] IMPORTANT NOTE: THIS SUB-STEP REQUIRING MANUAL INTERRUPTION"
echo "######## 8. [$NS1] obtain $TLSCACERT"
POD_GUPLOAD1=$(kubectl get pods -n $NS1 -l "app=gupload,release=$REL_GUPLOAD1" -o jsonpath="{.items[0].metadata.name}")
set -x
CONTENT=$(kubectl -n $NS1 exec $POD_GUPLOAD1 -c gupload -- cat ./fileserver/public/$TLSCACERT.pem)
res=$?
set +x
printMessage "obtain $TLSCACERT" $res
preventEmptyValue "$TLSCACERT" $CONTENT

echo "######## 9. [$NS1] create secret $TLSCACERT"
kubectl -n $NS1 delete secret $TLSCACERT
kubectl -n $NS1 create secret generic $TLSCACERT --from-literal=tlscacert.pem="$CONTENT"
res=$?
printMessage "create secret $TLSCACERT for $NS1" $res

echo "#####################################################################"
echo "### END: OUT OF BAND"
echo "#####################################################################\n"


echo "#################################"
echo "### Step 9: Install peer"
echo "#################################"
helm install $REL_PEER -n $NS -f $RELEASE_DIR/hlf-peer.$CLOUD.yaml ./hlf-peer
set -x
POD_PEER=$(kubectl get pods -n $NS -l "app=hlf-peer,release=$REL_PEER" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PEER -n $NS
res=$?
set +x
printMessage "pod/$REL_PEER" $res


echo "#####################################################################"
echo "### MULTIPLE ORGS WORKFLOW"
echo "#####################################################################"
echo "######## [$MSPID_1] ==> fetch current block"
helm install $JOB_FETCH_BLOCK-$NS -n $NS1 -f $RELEASE_DIR1/fetch-$NS-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_FETCH_BLOCK-$NS-hlf-operator--fetch -n $NS1
res=$?
set +x
printMessage "job/fetch block" $res

sleep 5

echo "######## [$MSPID] ==> prepares add-org update-channel-envelope"
helm install $JOB_NEWORG -n $NS -f $RELEASE_DIR/neworg-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_NEWORG-hlf-operator--neworg -n $NS
res=$?
set +x
printMessage "job/new org" $res

sleep 5

echo "######## [$MSPID_1] ==> sign the updatechannel block"
helm install $JOB_UPDATE_CHANNEL-$NS -n $NS1 -f $RELEASE_DIR1/upch1-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_UPDATE_CHANNEL-hlf-operator--updatechannel -n $NS1
res=$?
set +x
printMessage "job/update channel" $res

sleep 5

echo "######## [$MSPID] ==> join channel"
helm install $JOB_JOINCHANNEL -n $NS -f $RELEASE_DIR/joinch-hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 120s job/$JOB_JOINCHANNEL-hlf-operator--joinchannel -n $NS
res=$?
set +x
printMessage "job/join channel" $res

POD_CLI=$(kubectl get pods --namespace $NS -l "app=orgadmin,release=$REL_ORGADMIN" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI

sleep 10

echo "######## [$MSPID] ==> Update anchor peer; package & install chaincode"
helm install $JOB_INSTALL_CHAINCODE_A -n $NS -f $RELEASE_DIR/installcc-a.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/$JOB_INSTALL_CHAINCODE_A-hlf-operator--bootstrap -n $NS
res=$?
set +x
printMessage "job/install chaincode part1" $res

sleep 10

set -x
CCID=$(kubectl -n $NS exec $POD_CLI -- cat /var/hyperledger/crypto-config/channel-artifacts/packageid.txt)
res=$?
set +x
printMessage "retrieve CCID" $res
preventEmptyValue "chaincodeId" $CCID

echo "######## [$MSPID] ==> Launch chaincode container"
helm install eventstore -n $NS --set ccid=$CCID -f $RELEASE_DIR/eventstore-hlf-cc.yaml ./hlf-cc
set -x
POD_CC=$(kubectl get pods -n $NS -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC -n $NS
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

## NOTE: there is an unknonw timeslapse between the chaincode server starts, and container.
## TODO: research how to use readiness probe for chaincode server.
sleep 30

echo "######## [$MSPID] ==> Approve chaincode and run smoke test"
helm install $JOB_INSTALL_CHAINCODE_B -n $NS -f $RELEASE_DIR/installcc-b.hlf-operator.yaml ./hlf-operator
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
