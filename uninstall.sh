#!/bin/bash

# $1 = "org1" "org2" or "org3"

. "env.$1.sh"

if [ $1 == "org1" ]
then
  helm ls -n $NS0 -q | while read RELEASE
  do
    helm uninstall -n $NS0 $RELEASE
  done
  helm ls -n $NS1 -q | while read RELEASE
  do
    helm uninstall -n $NS1 $RELEASE
  done
else
  helm ls -n $NS -q | while read RELEASE
  do
    helm uninstall -n $NS $RELEASE
  done
fi
