#!/bin/bash
NS=n0
REL_TLSCA=tlsca0
REL_RCA=rca0

helm uninstall crypto-$REL_TLSCA -n $NS
helm uninstall crypto-$REL_RCA -n $NS
