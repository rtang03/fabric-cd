#!/bin/bash
kubectl -n n2 delete secret peer0.org2.net-admincert
kubectl -n n2 delete secret peer0.org2.net-adminkey
kubectl -n n2 delete secret peer0.org2.net-cacert
kubectl -n n2 delete secret peer0.org2.net-cert
kubectl -n n2 delete secret peer0.org2.net-key
kubectl -n n2 delete secret peer0.org2.net-tls
kubectl -n n2 delete secret peer0.org2.net-tlsrootcert
kubectl -n n2 delete secret tlsca2-tls
kubectl -n n2 delete secret rca2-tls
kubectl -n n2 delete secret org0.com-tlscacert
kubectl -n n2 delete secret org1.net-tlscacert
kubectl -n n2 delete secret org2.net-tlscacert
