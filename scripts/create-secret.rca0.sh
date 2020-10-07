#!/bin/bash
. ./scripts/setup.sh

######## 1. secret: rca0-hlf-ca--ca is already set by secret manifest. Below command retrieves it.
# CA_ADMIN=$(kubectl -n n0 get secret rca0-hlf-ca--ca -o jsonpath=".data.CA_ADMIN" | base64)
# CA_PASSWORD=$(kubectl -n n0 get secret rca0-hlf-ca--ca -o jsonpath=".data.CA_PASSWORD" | base64)
POD_RCA0=$(kubectl get pods -n n0 -l "app=hlf-ca,release=rca0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA0

echo "######## 2. secret: cert and key"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/msp/signcerts/cert.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-cert
kubectl -n n0 create secret generic orderer0.org0.com-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-cert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-key
kubectl -n n0 create secret generic orderer0.org0.com-key --from-literal=key.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-key" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/msp/signcerts/cert.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-cert
kubectl -n n0 create secret generic orderer1.org0.com-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-cert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-key
kubectl -n n0 create secret generic orderer1.org0.com-key --from-literal=key.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-key" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/msp/signcerts/cert.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-cert
kubectl -n n0 create secret generic orderer2.org0.com-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-cert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-key
kubectl -n n0 create secret generic orderer2.org0.com-key --from-literal=key.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-key" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/msp/signcerts/cert.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-cert
kubectl -n n0 create secret generic orderer3.org0.com-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-cert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-key
kubectl -n n0 create secret generic orderer3.org0.com-key --from-literal=key.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-key" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/msp/signcerts/cert.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-cert
kubectl -n n0 create secret generic orderer4.org0.com-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-cert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-key
kubectl -n n0 create secret generic orderer4.org0.com-key --from-literal=key.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-key" $?

echo "######## 3. secret: CA cert"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-cacert
kubectl -n n0 create secret generic orderer0.org0.com-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-cacert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-cacert
kubectl -n n0 create secret generic orderer1.org0.com-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-cacert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-cacert
kubectl -n n0 create secret generic orderer2.org0.com-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-cacert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-cacert
kubectl -n n0 create secret generic orderer3.org0.com-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-cacert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/msp/cacerts/rca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-cacert
kubectl -n n0 create secret generic orderer4.org0.com-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-cacert" $?

echo "######## 4. secret: tls cert and key"
CERT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/tls-msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-tls
kubectl -n n0 create secret generic orderer0.org0.com-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret orderer0.org0.com-tls" $?

CERT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/tls-msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/tls-msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-tls
kubectl -n n0 create secret generic orderer1.org0.com-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret orderer1.org0.com-tls" $?

CERT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/tls-msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/tls-msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-tls
kubectl -n n0 create secret generic orderer2.org0.com-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret orderer2.org0.com-tls" $?

CERT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/tls-msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/tls-msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-tls
kubectl -n n0 create secret generic orderer3.org0.com-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret orderer3.org0.com-tls" $?

CERT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

KEY=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/tls-msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/tls-msp/keystore/key.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-tls
kubectl -n n0 create secret generic orderer4.org0.com-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret orderer4.org0.com-tls" $?

echo "######## 5. secret: tls root CA cert for both n0 and n1"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-tlsrootcert
kubectl -n n0 create secret generic orderer0.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-tlsrootcert for n0" $?

kubectl -n n1 delete secret orderer0.org0.com-tlsrootcert
kubectl -n n1 create secret generic orderer0.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-tlsrootcert for n1" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-tlsrootcert
kubectl -n n0 create secret generic orderer1.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-tlsrootcert for n0" $?

kubectl -n n1 delete secret orderer1.org0.com-tlsrootcert
kubectl -n n1 create secret generic orderer1.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-tlsrootcert for n1" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-tlsrootcert
kubectl -n n0 create secret generic orderer2.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-tlsrootcert for n0" $?

kubectl -n n1 delete secret orderer2.org0.com-tlsrootcert
kubectl -n n1 create secret generic orderer2.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-tlsrootcert for n1" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-tlsrootcert
kubectl -n n0 create secret generic orderer3.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-tlsrootcert for n0" $?

kubectl -n n1 delete secret orderer3.org0.com-tlsrootcert
kubectl -n n1 create secret generic orderer3.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-tlsrootcert for n1" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/tls-msp/tlscacerts/tls-tlsca0-hlf-ca-7054.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-tlsrootcert
kubectl -n n0 create secret generic orderer4.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-tlsrootcert for n0" $?

kubectl -n n1 delete secret orderer4.org0.com-tlsrootcert
kubectl -n n1 create secret generic orderer4.org0.com-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-tlsrootcert for n1" $?

echo "######## 6. create secret for org0.com-admin-cert.pem"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/orderer0.org0.com/msp/admincerts/org0.com-admin-cert.pem")
preventEmptyValue "./Org0MSP/orderer0.org0.com/msp/admincerts/org0.com-admin-cert.pem" $CONTENT

kubectl -n n0 delete secret orderer0.org0.com-admincert
kubectl -n n0 create secret generic orderer0.org0.com-admincert --from-literal=org0.com-admin-cert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-admincert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/orderer1.org0.com/msp/admincerts/org0.com-admin-cert.pem")
preventEmptyValue "./Org0MSP/orderer1.org0.com/msp/admincerts/org0.com-admin-cert.pem" $CONTENT

kubectl -n n0 delete secret orderer1.org0.com-admincert
kubectl -n n0 create secret generic orderer1.org0.com-admincert --from-literal=org0.com-admin-cert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-admincert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/orderer2.org0.com/msp/admincerts/org0.com-admin-cert.pem")
preventEmptyValue "./Org0MSP/orderer2.org0.com/msp/admincerts/org0.com-admin-cert.pem" $CONTENT

kubectl -n n0 delete secret orderer2.org0.com-admincert
kubectl -n n0 create secret generic orderer2.org0.com-admincert --from-literal=org0.com-admin-cert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-admincert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/orderer3.org0.com/msp/admincerts/org0.com-admin-cert.pem")
preventEmptyValue "./Org0MSP/orderer3.org0.com/msp/admincerts/org0.com-admin-cert.pem" $CONTENT

kubectl -n n0 delete secret orderer3.org0.com-admincert
kubectl -n n0 create secret generic orderer3.org0.com-admincert --from-literal=org0.com-admin-cert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-admincert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/orderer4.org0.com/msp/admincerts/org0.com-admin-cert.pem")
preventEmptyValue "./Org0MSP/orderer4.org0.com/msp/admincerts/org0.com-admin-cert.pem" $CONTENT

kubectl -n n0 delete secret orderer4.org0.com-admincert
kubectl -n n0 create secret generic orderer4.org0.com-admincert --from-literal=org0.com-admin-cert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-admincert" $?

echo "######## 7. create secret from orderer's tls signcert - used configtx.yaml to generate genesis block"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer0.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

kubectl -n n1 delete secret orderer0.org0.com-tlssigncert
kubectl -n n1 create secret generic orderer0.org0.com-tlssigncert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer0.org0.com-tlssigncert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer1.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer1.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

kubectl -n n1 delete secret orderer1.org0.com-tlssigncert
kubectl -n n1 create secret generic orderer1.org0.com-tlssigncert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer1.org0.com-tlssigncert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer2.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer2.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

kubectl -n n1 delete secret orderer2.org0.com-tlssigncert
kubectl -n n1 create secret generic orderer2.org0.com-tlssigncert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer2.org0.com-tlssigncert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer3.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer3.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

kubectl -n n1 delete secret orderer3.org0.com-tlssigncert
kubectl -n n1 create secret generic orderer3.org0.com-tlssigncert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer3.org0.com-tlssigncert" $?

CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- cat ./Org0MSP/orderer4.org0.com/tls-msp/signcerts/cert.pem)
preventEmptyValue "./Org0MSP/orderer4.org0.com/tls-msp/signcerts/cert.pem" $CONTENT

kubectl -n n1 delete secret orderer4.org0.com-tlssigncert
kubectl -n n1 create secret generic orderer4.org0.com-tlssigncert --from-literal=cert.pem="$CONTENT"
printMessage "create secret orderer4.org0.com-tlssigncert" $?

echo "######## 8. create secret for org0.com-tlscacert"
CONTENT=$(kubectl -n n0 exec $POD_RCA0 -c ca -- sh -c "cat ./Org0MSP/msp/tlscacerts/tls-ca-cert.pem")
preventEmptyValue "./Org0MSP/msp/tlscacerts/tls-ca-cert.pem" $CONTENT

kubectl -n n1 delete secret org0.com-tlscacert
kubectl -n n1 create secret generic org0.com-tlscacert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret org0.com-tlscacert" $?

echo "######## 9. Create secret for tls for tlsca, used by ingress controller"
POD_TLSCA0=$(kubectl get pods -n n0 -l "app=hlf-ca,release=tlsca0" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_TLSCA0

CERT=$(kubectl -n n0 exec ${POD_TLSCA0} -c ca -- cat ./Org0MSP/tls/server/ca-cert.pem)
preventEmptyValue "./Org0MSP/tls/server/ca-cert.pem" $CERT

KEY=$(kubectl -n n0 exec ${POD_TLSCA0} -c ca -- cat ./Org0MSP/tls/server/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/tls/server/msp/keystore/key.pem" $KEY

kubectl -n n0 delete secret tlsca0-tls
kubectl -n n0 create secret generic tlsca0-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret tlsca0-tls" $?

echo "######## 10. Create secret for tls for rca, used by ingress controller"
CERT=$(kubectl -n n0 exec ${POD_RCA0} -c ca -- cat ./Org0MSP/ca/server/ca-cert.pem)
preventEmptyValue "./Org0MSP/ca/server/ca-cert.pem" $CERT

KEY=$(kubectl -n n0 exec ${POD_RCA0} -c ca -- cat ./Org0MSP/ca/server/msp/keystore/key.pem)
preventEmptyValue "./Org0MSP/ca/server/msp/keystore/key.pem" $KEY

kubectl -n n0 delete secret rca0-tls
kubectl -n n0 create secret generic rca0-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret rca0-tls" $?
