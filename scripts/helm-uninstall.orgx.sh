#!/bin/bash
. ./env.orgx.sh

helm uninstall -n $NS $REL_ORGADMIN
helm uninstall -n $NS crypto-$REL_RCA
helm uninstall -n $NS crypto-$REL_TLSCA
helm uninstall -n $NS $REL_GUPLOAD
helm uninstall -n $NS $JOB_JOINCHANNEL
helm uninstall -n $NS $JOB_NEWORG
helm uninstall -n $NS $REL_PEER
helm uninstall -n $NS $REL_RCA
helm uninstall -n $NS $REL_TLSCA
helm uninstall -n $NS $JOB_INSTALL_CHAINCODE_A
helm uninstall -n $NS $JOB_INSTALL_CHAINCODE_B
helm uninstall -n $NS eventstore
