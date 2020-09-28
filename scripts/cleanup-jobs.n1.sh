#!/bin/bash
NS=n1
REL_TLSCA=tlsca1
REL_RCA=rca1
JOB_UPDATECHANNEL=upch1
JOB_FETCH=fetch1
JOB_BOOTSTRAP_1=b1
JOB_BOOTSTRAP_2=b2

helm uninstall crypto-$REL_TLSCA -n $NS
helm uninstall crypto-$REL_RCA -n $NS
helm uninstall $JOB_BOOTSTRAP_1 -n $NS
helm uninstall $JOB_BOOTSTRAP_2 -n $NS
helm uninstall $JOB_UPDATECHANNEL -n $NS
helm uninstall $JOB_FETCH -n $NS
