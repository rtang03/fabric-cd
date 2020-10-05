#!/bin/bash
NS=n2
REL_TLSCA=tlsca2
REL_RCA=rca2
JOB_JOINCHANNEL=joinch2
JOB_NEWORG=neworg2
JOB_INSTALL_CHAINCODE_A=installcc2a
JOB_INSTALL_CHAINCODE_B=installcc2b

helm uninstall crypto-$REL_TLSCA -n $NS
helm uninstall crypto-$REL_RCA -n $NS
helm uninstall $JOB_INSTALL_CHAINCODE_A -n $NS
helm uninstall $JOB_INSTALL_CHAINCODE_B -n $NS
helm uninstall $JOB_JOINCHANNEL -n $NS
helm uninstall $JOB_NEWORG -n $NS
