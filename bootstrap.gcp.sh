. ./scripts/setup.sh

SECONDS=0

echo "#################################"
echo "### Step 0: remove secret: n0, n1"
echo "#################################"
./scripts/rm-secret.n0.sh
./scripts/rm-secret.n1.sh

echo "#################################"
echo "### Step 1: Install Admin1"
echo "#################################"
helm install admin1 -n n1 -f ./releases/org1/admin1-orgadmin.gcp.yaml ./orgadmin
printMessage "install admin1" $?

set -x
kubectl wait --for=condition=Available --timeout 180s deployment/admin1-orgadmin-cli -n n1
res=$?
set +x
printMessage "deployment/admin1-orgadmin-cli" $res

set -x
export POD_PSQL1=$(kubectl get pods -n n1 -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=admin1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL1 -n n1
res=$?
set +x
printMessage "pod/$POD_PSQL1" $res

sleep 30

echo "#################################"
echo "### Step 2: Install tlsca1"
echo "#################################"
helm install tlsca1 -n n1 -f ./releases/org1/tlsca1-hlf-ca.gcp.yaml ./hlf-ca
printMessage "install tlsca1" $?

set -x
export POD_TLSCA1=$(kubectl get pods -n n1 -l "app=hlf-ca,release=tlsca1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA1 -n n1
res=$?
set +x
printMessage "pod/$POD_TLSCA1" $res

echo "#################################"
echo "### Step 3: Install rca1"
echo "#################################"
helm install rca1 -n n1 -f ./releases/org1/rca1-hlf-ca.gcp.yaml ./hlf-ca
printMessage "install rca1" $?

set -x
export POD_RCA1=$(kubectl get pods -n n1 -l "app=hlf-ca,release=rca1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA1 -n n1
res=$?
set +x
printMessage "pod/$POD_RCA1" $res

sleep 30

echo "#################################"
echo "### Step 4: Job: crypto-tlsca1"
echo "#################################"
helm install crypto-tlsca1 -n n1 -f ./releases/org1/tlsca1-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-tlsca1" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-tlsca1-cryptogen -n n1
res=$?
set +x
printMessage "job/crypto-tlsca1-cryptogen" $res

sleep 30

echo "#################################"
echo "### Step 5: Job crypto-rca1"
echo "#################################"
helm install crypto-rca1 -n n1 -f ./releases/org1/rca1-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-rca1" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-rca1-cryptogen -n n1
res=$?
set +x
printMessage "job/crypto-rca1-cryptogen" $res

echo "#################################"
echo "### Step 6: Install admin0"
echo "#################################"
helm install admin0 -n n0 -f ./releases/org0/admin0-orgadmin.gcp.yaml ./orgadmin
printMessage "install admin0" $?

set -x
export POD_PSQL0=$(kubectl get pods -n n0 -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=admin0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL0 -n n0
res=$?
set +x
printMessage "pod/$POD_PSQL0" $res

sleep 30

echo "#################################"
echo "### Step 7: Install tlsca0"
echo "#################################"
helm install tlsca0 -n n0 -f ./releases/org0/tlsca0-hlf-ca.gcp.yaml ./hlf-ca
printMessage "install tlsca0" $?

set -x
export POD_TLSCA0=$(kubectl get pods -n n0 -l "app=hlf-ca,release=tlsca0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA0 -n n0
res=$?
set +x
printMessage "pod/$POD_TLSCA0" $res

sleep 30

echo "#################################"
echo "### Step 8: Install rca0"
echo "#################################"
helm install rca0 -n n0 -f ./releases/org0/rca0-hlf-ca.gcp.yaml ./hlf-ca
printMessage "install rca0" $?

set -x
export POD_RCA0=$(kubectl get pods -n n0 -l "app=hlf-ca,release=rca0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA0 -n n0
res=$?
set +x
printMessage "pod/$POD_RCA0" $res

sleep 30

echo "#################################"
echo "### Step 9: crypto-tlsca0"
echo "#################################"
helm install crypto-tlsca0 -n n0 -f ./releases/org0/tlsca0-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-tlsca0" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-tlsca0-cryptogen -n n0
res=$?
set +x
printMessage "job/crypto-tlsca0-cryptogen" $res

sleep 30

echo "#################################"
echo "### Step 10: crypto-rca0"
echo "#################################"
helm install crypto-rca0 -n n0 -f ./releases/org0/rca0-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-rca0" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-rca0-cryptogen -n n0
res=$?
set +x
printMessage "job/crypto-rca0-cryptogen" $res

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
export POD_CLI0=$(kubectl get pods -n n0 -l "app=orgadmin,release=admin0" -o jsonpath="{.items[0].metadata.name}")
set +x
preventEmptyValue "pod unavailable" $POD_CLI0

sleep 2

######## 2. Create genesis.block / channel.tx / anchor.tx
set -x
kubectl -n n0 exec -it $POD_CLI0 -- sh -c "/var/hyperledger/bin/configtxgen -configPath /var/hyperledger/cli/configtx -profile OrgsOrdererGenesis -outputBlock /var/hyperledger/crypto-config/genesis.block -channelID ordererchannel"
res=$?
set +x
printMessage "create genesis block" $res
set -x
kubectl -n n0 exec -it $POD_CLI0 -- sh -c "/var/hyperledger/bin/configtxgen -configPath /var/hyperledger/cli/configtx -profile OrgsChannel -outputCreateChannelTx /var/hyperledger/crypto-config/channel.tx -channelID loanapp"
res=$?
set +x
printMessage "create channel.tx" $res

######## 3. Create configmap: genesis.block
kubectl -n n0 exec $POD_CLI0 -- cat /var/hyperledger/crypto-config/genesis.block > genesis.block
kubectl -n n0 create secret generic genesis --from-file=genesis=./genesis.block
printMessage "create secret genesis" $?
rm genesis.block

######## 4. Create configmap: channel.tx for org1, with namespace n1
kubectl -n n0 exec $POD_CLI0 -- cat /var/hyperledger/crypto-config/channel.tx > channel.tx
kubectl -n n1 create secret generic channeltx --from-file=channel.tx=./channel.tx
printMessage "create secret channeltx" $?
rm channel.tx

echo "#################################"
echo "### Step 13: Install orderers"
echo "#################################"

helm install o1 -f ./releases/org0/o1-hlf-ord.gcp.yaml -n n0 ./hlf-ord
sleep 3
helm install o2 -f ./releases/org0/o2-hlf-ord.gcp.yaml -n n0 ./hlf-ord
sleep 3
helm install o3 -f ./releases/org0/o3-hlf-ord.gcp.yaml -n n0 ./hlf-ord
sleep 3
helm install o4 -f ./releases/org0/o4-hlf-ord.gcp.yaml -n n0 ./hlf-ord
sleep 3
helm install o0 -f ./releases/org0/o0-hlf-ord.gcp.yaml -n n0 ./hlf-ord

set -x
export POD_O0=$(kubectl get pods -n n0 -l "app=hlf-ord,release=o0" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_O0 -n n0
res=$?
set +x
printMessage "pod/o0-hlf-ord" $res

echo "#################################"
echo "### Step 14: Install p0o1"
echo "#################################"
helm install p0o1 -n n1 -f ./releases/org1/p0o1-hlf-peer.gcp.yaml ./hlf-peer

set -x
export POD_P0O1=$(kubectl get pods -n n1 -l "app=hlf-peer,release=p0o1" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_P0O1 -n n1
res=$?
set +x
printMessage "pod/p0o1-hlf-peer" $res

echo "#################################"
echo "### Step 15: Install g1"
echo "#################################"
helm install g1 -n n1 -f ./releases/org1/g1-gupload.gcp.yaml ./gupload

export POD_CLI1=$(kubectl get pods --namespace n1 -l "app=orgadmin,release=admin1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

sleep 10s
echo "#################################"
echo "### Step 16: Bootstrap part 1"
echo "#################################"
helm install b1 -n n1 -f ./releases/org1/bootstrap-a.gcp.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/b1-hlf-operator--bootstrap -n n1
res=$?
set +x
printMessage "job/bootstrap part1" $res

echo "#################################"
echo "### Step 17: Install chaincode"
echo "#################################"
set -x
export CCID=$(kubectl -n n1 exec $POD_CLI1 -- cat /var/hyperledger/crypto-config/channel-artifacts/packageid.txt)
res=$?
set +x
printMessage "retrieve CCID" $res

helm install eventstore -n n1 --set ccid=$CCID -f ./releases/org1/eventstore-hlf-cc.gcp.yaml ./hlf-cc
set -x
export POD_CC1=$(kubectl get pods -n n1 -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC1 -n n1
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

sleep 10s

echo "#################################"
echo "### Step 18: Bootstrap part 2"
echo "#################################"
helm install b2 -n n1 -f ./releases/org1/bootstrap-b.gcp.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 300s job/b2-hlf-operator--bootstrap -n n1
res=$?
set +x
printMessage "job/bootstrap part2" $res

echo "#################################"
echo "### Step 19: Upload org1 - tls root certs"
echo "#################################"
export POD_CLI1=$(kubectl get pods --namespace n1 -l "app=orgadmin,release=admin1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

# download org1 root cert
set -x
kubectl -n n1 exec $POD_CLI1 -- cat ./Org1MSP/msp/tlscacerts/tls-ca-cert.pem > ./download/org1.net--tlscacert.pem
res=$?
set +x
printMessage "download Org1MSP/msp/tlscacerts/tls-ca-cert.pem from n1" $res

export POD_G1=$(kubectl get pods --namespace n1 -l "app=gupload,release=g1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_G1

# send org1 root cert to 'public' folder of gupload
set -x
kubectl -n n1 cp ./download/org1.net--tlscacert.pem $POD_G1:/var/gupload/fileserver/public -c gupload
res=$?
set +x
printMessage "cp org1.net-tlscacert.pem to g1-gupload" $res

echo "#################################"
echo "### Step 20: Upload org0 - tls root certs"
echo "#################################"
export POD_CLI0=$(kubectl get pods --namespace n0 -l "app=orgadmin,release=admin0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

# download org0 root cert
set -x
kubectl -n n0 exec $POD_CLI0 -- cat ./Org0MSP/msp/tlscacerts/tls-ca-cert.pem > ./download/org0.com--tlscacert.pem
res=$?
set +x
printMessage "download Org0MSP/msp/tlscacerts/tls-ca-cert.pem from n0" $res

# send org1 root cert to 'public' folder of gupload
set -x
kubectl -n n1 cp ./download/org0.com--tlscacert.pem $POD_G1:/var/gupload/fileserver/public -c gupload
res=$?
set +x
printMessage "cp org0.com-tlscacert.pem to g1-gupload" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
