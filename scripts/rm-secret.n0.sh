#!/bin/bash
# delete secret used for orderer

kubectl -n n0 delete secret orderer0.org0.com-admincert
kubectl -n n0 delete secret orderer0.org0.com-cacert
kubectl -n n0 delete secret orderer0.org0.com-cert
kubectl -n n0 delete secret orderer0.org0.com-key
kubectl -n n0 delete secret orderer0.org0.com-tls
kubectl -n n0 delete secret orderer0.org0.com-tlsrootcert
kubectl -n n0 delete secret orderer1.org0.com-admincert
kubectl -n n0 delete secret orderer1.org0.com-cacert
kubectl -n n0 delete secret orderer1.org0.com-cert
kubectl -n n0 delete secret orderer1.org0.com-key
kubectl -n n0 delete secret orderer1.org0.com-tls
kubectl -n n0 delete secret orderer1.org0.com-tlsrootcert
kubectl -n n0 delete secret orderer2.org0.com-admincert
kubectl -n n0 delete secret orderer2.org0.com-cacert
kubectl -n n0 delete secret orderer2.org0.com-cert
kubectl -n n0 delete secret orderer2.org0.com-key
kubectl -n n0 delete secret orderer2.org0.com-tls
kubectl -n n0 delete secret orderer2.org0.com-tlsrootcert
kubectl -n n0 delete secret orderer3.org0.com-admincert
kubectl -n n0 delete secret orderer3.org0.com-cacert
kubectl -n n0 delete secret orderer3.org0.com-cert
kubectl -n n0 delete secret orderer3.org0.com-key
kubectl -n n0 delete secret orderer3.org0.com-tls
kubectl -n n0 delete secret orderer3.org0.com-tlsrootcert
kubectl -n n0 delete secret orderer4.org0.com-admincert
kubectl -n n0 delete secret orderer4.org0.com-cacert
kubectl -n n0 delete secret orderer4.org0.com-cert
kubectl -n n0 delete secret orderer4.org0.com-key
kubectl -n n0 delete secret orderer4.org0.com-tls
kubectl -n n0 delete secret orderer4.org0.com-tlsrootcert
kubectl -n n0 delete secret tlsca0-tls
kubectl -n n0 delete secret rca0-tls
kubectl -n n0 delete secret genesis

# Below certs are created by rca1's secret.sh procedure
kubectl -n n0 delete secret org1.net-admincert
kubectl -n n0 delete secret org1.net-tlscacert
kubectl -n n0 delete secret org1.net-cacert
