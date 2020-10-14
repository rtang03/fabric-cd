#!/bin/bash

kubectl -n argocd apply -f argocd-cm.yaml
kubectl -n argocd apply -f app-admin1.yaml
kubectl -n argocd apply -f app-ca1.yaml

argocd app sync admin1
argocd app sync tlsca1
argocd app sync rca1

kubectl -n argocd apply -f app-crypto-rca1.yaml

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
