#!/bin/bash

kubectl -n n3 delete secret org0.com-tlscacert
kubectl -n n3 delete secret org1.net-tlscacert
kubectl -n n3 delete secret org2.net-tlscacert
kubectl -n n3 delete secret org3.net-tlscacert
kubectl -n n3 delete secret peer0.org3.net-admincert
kubectl -n n3 delete secret peer0.org3.net-adminkey
kubectl -n n3 delete secret peer0.org3.net-cacert
kubectl -n n3 delete secret peer0.org3.net-cert
kubectl -n n3 delete secret peer0.org3.net-key
kubectl -n n3 delete secret peer0.org3.net-tls
kubectl -n n3 delete secret peer0.org3.net-tlsrootcert
kubectl -n n3 delete secret rca3-tls
kubectl -n n3 delete secret tlsca3-tls
