#!/bin/bash

# $1 - list of orgs ("org1 org2 org3")

. ./scripts/env.orgx.sh

#kubectl -n $NS delete secret $PEER-admincert
#kubectl -n $NS delete secret $PEER-adminkey
#kubectl -n $NS delete secret $PEER-cacert
#kubectl -n $NS delete secret $PEER-cert
#kubectl -n $NS delete secret $PEER-key
#kubectl -n $NS delete secret $PEER-tls
#kubectl -n $NS delete secret $PEER-tlsrootcert
#kubectl -n $NS delete secret $REL_TLSCA-tls
kubectl -n $NS delete secret $REL_RCA-tls

#kubectl -n $NS delete secret org0.com-tlscacert
#kubectl -n $NS delete secret org1.net-tlscacert
#kubectl -n $NS delete secret org2.net-tlscacert
#kubectl -n $NS delete secret org3.net-tlscacert

## created via out-of-band process
#for ORG in $1; do
#  kubectl -n $NS delete secret $ORG-tlscacert
#done
