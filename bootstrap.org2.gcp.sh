#!/bin/bash
. ./scripts/setup.sh

SECONDS=0

./scripts/rm-secret.n2.sh
rm ./download/*.crt

helm install admin2 -n n2 -f ./releases/org2/admin2-orgadmin.gcp.yaml ./orgadmin
printMessage "install admin2" $?

set -x
kubectl wait --for=condition=Available --timeout 60s deployment/admin2-orgadmin-cli -n n2
res=$?
set +x
printMessage "deployment/admin2-orgadmin-cli" $res

set -x
export POD_PSQL2=$(kubectl get pods -n n2 -l "app.kubernetes.io/name=postgresql-0,app.kubernetes.io/instance=admin2" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_PSQL2 -n n2
res=$?
set +x
printMessage "pod/$POD_PSQL2" $res

sleep 30

helm install tlsca2 -n n2 -f ./releases/org2/tlsca2-hlf-ca.gcp.yaml ./hlf-ca
printMessage "install tlsca2" $?

set -x
export POD_TLSCA2=$(kubectl get pods -n n2 -l "app=hlf-ca,release=tlsca2" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_TLSCA2 -n n2
res=$?
set +x
printMessage "pod/$POD_TLSCA2" $res

sleep 5

helm install rca2 -n n2 -f ./releases/org2/rca2-hlf-ca.gcp.yaml ./hlf-ca

set -x
export POD_RCA2=$(kubectl get pods -n n2 -l "app=hlf-ca,release=rca2" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_RCA2 -n n2
res=$?
set +x
printMessage "pod/$POD_RCA2" $res

sleep 30

helm install crypto-tlsca2 -n n2 -f ./releases/org2/tlsca2-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-tlsca2" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-tlsca2-cryptogen -n n2
res=$?
set +x
printMessage "job/crypto-tlsca2-cryptogen" $res

helm install crypto-rca2 -n n2 -f ./releases/org2/rca2-cryptogen.gcp.yaml ./cryptogen
printMessage "install crypto-rca2" $?

set -x
kubectl wait --for=condition=complete --timeout 180s job/crypto-rca2-cryptogen -n n2
res=$?
set +x
printMessage "job/crypto-rca2-cryptogen" $res

./scripts/create-secret.rca2.sh
printMessage "create secret rca2" $?

#helm install p0o2db -n n2 -f ./releases/org2/p0o2db-hlf-couchdb.gcp.yaml ./hlf-couchdb
#set -x
#export POD_P0O2DB=$(kubectl get pods -n n2 -l "app=hlf-couchdb,release=p0o2db" -o jsonpath="{.items[0].metadata.name}")
#kubectl wait --for=condition=Ready --timeout 180s pod/$POD_P0O2DB -n n2
#res=$?
#set +x
#printMessage "deployment/p0o2db-hlf-couchdb" $res

export POD_CLI2=$(kubectl get pods -n n2 -l "app=orgadmin,release=admin2" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI2

sleep 5

helm install g2 -n n2 -f ./releases/org2/g2-gupload.gcp.yaml ./gupload

#####################################################################
### OUT OF BAND
#####################################################################
echo "# ORG1: Out-of-band process: Manually send p0o1.crt from org2 to org1"
export POD_RCA2=$(kubectl get pods -n n2 -l "app=hlf-ca,release=rca2" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA2

set -x
kubectl -n n2 exec $POD_RCA2 -c ca -- cat ./Org2MSP/peer0.org2.net/tls-msp/signcerts/cert.pem > ./download/p0o2.crt
res=$?
set +x
printMessage "download /Org2MSP/peer0.org2.net/tls-msp/signcerts/cert.pem from n2" $res

set -x
kubectl -n n1 create secret generic peer0.org2.net-tls --from-file=tls.crt=./download/p0o2.crt
res=$?
set +x
printMessage "create secret peer0.org2.net-tls for n1" $res

####
echo "# ORG2: Out-of-band process: Manually send p0o2.crt from org1 to org2"
export POD_RCA1=$(kubectl get pods -n n1 -l "app=hlf-ca,release=rca1" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA1

#set -x
#kubectl -n n1 exec $POD_RCA1 -c ca -- cat ./Org1MSP/peer0.org1.net/tls-msp/signcerts/cert.pem > ./download/p0o1.crt
#res=$?
#set +x
#printMessage "download Org1MSP/peer0.org1.net/tls-msp/signcerts/cert.pem from n1" $res
#
#set -x
#kubectl -n n2 create secret generic peer0.org1.net-tls --from-file=tls.crt=./download/p0o1.crt
#res=$?
#set +x
#printMessage "create secret peer0.org1.net-tls for n2" $res

export POD_RCA0=$(kubectl get pods -n n0 -l "app=hlf-ca,release=rca0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA0

set -x
kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem > ./download/orderer0.crt
res=$?
set +x
printMessage "download Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem from n0" $res

set -x
kubectl -n n2 create secret generic orderer0.org0.com-tlssigncert --from-file=cert.pem=./download/orderer0.crt
res=$?
set +x
printMessage "create secret orderer0.org0.com-tlssigncert for n2" $res

set -x
kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem > ./download/orderer0-tlsroot.crt
res=$?
set +x
printMessage "download Org0MSP/orderer0.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-n0-svc-cluster-local-7054.pem from n0" $res

set -x
kubectl -n n2 create secret generic orderer0.org0.com-tlsrootcert --from-file=tlscacert.pem=./download/orderer0-tlsroot.crt
res=$?
set +x
printMessage "create secret orderer0.org0.com-tlsrootcert for n2" $res

set -x
kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/msp/tlscacerts/tls-ca-cert.pem" > ./download/org0tlscacert.crt
res=$?
set +x
printMessage "download Org0MSP/msp/tlscacerts/tls-ca-cert.pem from n0" $res

set -x
kubectl -n n2 create secret generic org0-tls-ca-cert --from-file=tlscacert.pem=./download/org0tlscacert.crt
res=$?
set +x
printMessage "create secret org0-tls-ca-cert for n2" $res

set -x
kubectl -n n1 exec $POD_RCA1 -c ca -- cat ./Org1MSP/msp/tlscacerts/tls-ca-cert.pem > ./download/org1tlscacert.crt
res=$?
set +x
printMessage "download Org1MSP/msp/tlscacerts/tls-ca-cert.pem from n1" $res

set -x
kubectl -n n2 create secret generic org1-tls-ca-cert --from-file=tlscacert.pem=./download/org1tlscacert.crt
res=$?
set +x
printMessage "create secret org1-tls-ca-cert for n2" $res
#####################################################################
### END: OUT OF BAND
#####################################################################

# After all secrets are available
helm install p0o2 -n n2 -f ./releases/org2/p0o2-hlf-peer.gcp.yaml ./hlf-peer

set -x
export POD_P0O2=$(kubectl get pods -n n2 -l "app=hlf-peer,release=p0o2" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_P0O2 -n n2
res=$?
set +x
printMessage "pod/p0o2-hlf-peer" $res

sleep 10

### MULTIPLE ORGS WORKFLOW
## org1 admin tasks
helm install fetch1 -n n1 -f ./releases/org1/fetchsend-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/fetch1-hlf-operator--fetch-send -n n1
res=$?
set +x
printMessage "job/fetch1-hlf-operator" $res

sleep 10

## org2 admin tasks
helm install neworg2 -n n2 -f ./releases/org2/neworgsend-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/neworg2-hlf-operator--neworg-send -n n2
res=$?
set +x
printMessage "job/neworg2-hlf-operator" $res

sleep 10

## org1 admin tasks
helm install upch1 -n n1 -f ./releases/org1/upch1-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/upch1-hlf-operator--updatechannel -n n1
res=$?
set +x
printMessage "job/upch1-hlf-operator" $res

sleep 10

## org2 admin tasks
helm install joinch2 -n n2 -f ./releases/org2/joinch2-hlf-operator.yaml ./hlf-operator

set -x
kubectl wait --for=condition=complete --timeout 120s job/joinch2-hlf-operator--joinchannel -n n2
res=$?
set +x
printMessage "job/joinch2-hlf-operator" $res

export POD_CLI2=$(kubectl get pods --namespace n2 -l "app=orgadmin,release=admin2" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_CLI1

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

helm install eventstore -n n2 --set ccid=$CCID -f ./releases/org2/eventstore-hlf-cc.gcp.yaml ./hlf-cc
set -x
export POD_CC2=$(kubectl get pods -n n2 -l "app=hlf-cc,release=eventstore" -o jsonpath="{.items[0].metadata.name}")
kubectl wait --for=condition=Ready --timeout 180s pod/$POD_CC2 -n n2
res=$?
set +x
printMessage "pod/eventstore chaincode" $res

sleep 10

helm install installcc2b -n n2 -f ./releases/org2/installcc-b.hlf-operator.yaml ./hlf-operator
set -x
kubectl wait --for=condition=complete --timeout 180s job/installcc2b-hlf-operator--bootstrap -n n2
res=$?
set +x
printMessage "job/install chaincode part2" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
