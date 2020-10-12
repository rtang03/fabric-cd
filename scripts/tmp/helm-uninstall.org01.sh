#!/bin/bash

helm uninstall -n n0 crypto-rca0
helm uninstall -n n0 crypto-tlsca0
helm uninstall -n n0 rca0
helm uninstall -n n0 tlsca0
helm uninstall -n n0 admin0
helm uninstall o0 -n n0
helm uninstall o1 -n n0
helm uninstall o2 -n n0
helm uninstall o3 -n n0
helm uninstall o4 -n n0
helm uninstall -n n1 b1
helm uninstall -n n1 b2
helm uninstall -n n1 crypto-rca1
helm uninstall -n n1 crypto-tlsca1
helm uninstall -n n1 fetch1
helm uninstall -n n1 g1
helm uninstall -n n1 rca1
helm uninstall -n n1 tlsca1
helm uninstall -n n1 admin1
# helm uninstall -n n1 p0o1db
helm uninstall -n n1 p0o1
helm uninstall -n n1 upch1
helm uninstall -n n1 eventstore