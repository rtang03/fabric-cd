#!/bin/bash
. ./scripts/setup.sh
. ./scripts/env.org2.sh

ORDERER_URL=orderer0.org0.com

######## 1. secret: rca2-hlf-ca--ca is already set by secret manifest. Below command retrieves it.
# export CA_ADMIN=$(kubectl -n $NS get secret rca2-hlf-ca--ca -o jsonpath=".data.CA_ADMIN" | base64)
# export CA_PASSWORD=$(kubectl -n $NS get secret rca2-hlf-ca--ca -o jsonpath=".data.CA_PASSWORD" | base64)
echo "Get POD_RCA pod id"
export POD_RCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_RCA" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" $POD_RCA

echo "######## 2. secret: cert and key"
export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/signcerts/cert.pem)
preventEmptyValue "./$MSPID/$PEER/msp/signcerts/cert.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-cert --from-literal=cert.pem="$CONTENT"
printMessage "create secret $PEER-cert" $?

export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/keystore/key.pem)
preventEmptyValue "./$MSPID/$PEER/msp/keystore/key.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-key --from-literal=key.pem="$CONTENT"
printMessage "create secret $PEER-key" $?

echo "######## 3. secret: CA cert"
export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/msp/cacerts/$REL_RCA-hlf-ca-7054.pem)
preventEmptyValue "./$MSPID/$PEER/msp/cacerts/$REL_RCA-hlf-ca-7054.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-cacert --from-literal=cacert.pem="$CONTENT"
printMessage "create secret $PEER-cacert" $?

echo "######## 4. secret: tls cert and key"
export CERT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/signcerts/cert.pem)
preventEmptyValue "./$MSPID/$PEER/tls-msp/signcerts/cert.pem" $CONTENT

export KEY=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/keystore/key.pem)
preventEmptyValue "./$MSPID/$PEER/tls-msp/keystore/key.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $PEER-tls" $?

echo "######## 5. secret: tls root CA cert"
export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- cat ./$MSPID/$PEER/tls-msp/tlscacerts/tls-$REL_TLSCA-hlf-ca-7054.pem)
preventEmptyValue "./$MSPID/$PEER/tls-msp/tlscacerts/tls-$REL_TLSCA-hlf-ca-7054.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-tlsrootcert --from-literal=tlscacert.pem="$CONTENT"
printMessage "create secret $PEER-tlsrootcert" $?

echo "######## 6. create secret for $DOMAIN-admin-cert.pem"
export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- sh -c "cat ./$MSPID/admin/msp/admincerts/$DOMAIN-admin-cert.pem")
preventEmptyValue "./$MSPID/admin/msp/admincerts/$DOMAIN-admin-cert.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-admincert --from-literal=$DOMAIN-admin-cert.pem="$CONTENT"
printMessage "create secret $PEER-admincert" $?

echo "######## 7. create secret for $DOMAIN-admin-key.pem"
export CONTENT=$(kubectl -n $NS exec $POD_RCA -c ca -- sh -c "cat ./$MSPID/admin/msp/keystore/key.pem")
preventEmptyValue "./$MSPID/admin/msp/keystore/key.pem" $CONTENT

kubectl -n $NS create secret generic $PEER-adminkey --from-literal=$DOMAIN-admin-key.pem="$CONTENT"
printMessage "create secret $PEER-adminkey" $?

echo "######## 8. Create secret for tls for tlsca, used by ingress controller"
export POD_TLSCA=$(kubectl get pods -n $NS -l "app=hlf-ca,release=$REL_TLSCA" -o jsonpath="{.items[0].metadata.name}")
preventEmptyValue "pod unavailable" POD_TLSCA

export CERT=$(kubectl -n $NS exec ${POD_TLSCA} -c ca -- cat ./$MSPID/tls/server/ca-cert.pem)
preventEmptyValue "./$MSPID/tls/server/ca-cert.pem" $CERT

export KEY=$(kubectl -n $NS exec ${POD_TLSCA} -c ca -- cat ./$MSPID/tls/server/msp/keystore/key.pem)
preventEmptyValue "./$MSPID/tls/server/msp/keystore/key.pem" $KEY

kubectl -n $NS create secret generic $REL_TLSCA-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $REL_TLSCA-tls" $?

echo "######## 9. Create secret for tls for rca, used by ingress controller"
export CERT=$(kubectl -n $NS exec ${POD_RCA} -c ca -- cat ./$MSPID/ca/server/ca-cert.pem)
preventEmptyValue "./$MSPID/ca/server/ca-cert.pem" $CERT

export KEY=$(kubectl -n $NS exec ${POD_RCA} -c ca -- cat ./$MSPID/ca/server/msp/keystore/key.pem)
preventEmptyValue "./$MSPID/ca/server/msp/keystore/key.pem" $KEY

kubectl -n $NS create secret generic $REL_RCA-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"
printMessage "create secret $REL_RCA-tls" $?
