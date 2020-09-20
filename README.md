# fabric-cd
continuous deployment

### Getting Started
```shell script
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-b --zone us-central1-c

kubectl create namespace n0
kubectl create namespace n1
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled
```

*Useful Command*
```shell script
curl -d '{"spec":"grpc=debug:debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec
curl -d '{"spec":"debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec
```

### Reference Info
https://medium.com/swlh/how-to-implement-hyperledger-fabric-external-chaincodes-within-a-kubernetes-cluster-fd01d7544523
https://github.com/vanitas92/fabric-external-chaincodes
https://istio.io/latest/docs/setup/platform-setup/gke/


${BIN}/peer channel create -o ${ORDERER_URL} -c ${CHANNEL_NAME} -f $DIR/channeltx/channel.tx --outputBlock $DIR/${CHANNEL_NAME}.block --tls --cafile ${ORDERER_CA}

${BIN}/peer channel fetch 0 -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA} -o orderer0.org0.com:15443 $DIR/${CHANNEL_NAME}.block

${BIN}/peer lifecycle chaincode commit \
-o ${ORDERER_URL} -C ${CHANNEL_NAME} \
--tls --cafile ${ORDERER_CA} \
--name eventstore \
--version 1 \
--init-required \
--sequence 1 \
--peerAddresses "peer0.org1.net:15443" \
--tlsRootCertFiles /var/hyperledger/crypto-config/Org1MSP/peer0.org1.net/tls-msp/tlscacerts/tls-tlsca1-hlf-ca-7054.pem \
--waitForEvent

${BIN}/peer lifecycle chaincode querycommitted \
-o ${ORDERER_URL} -C ${CHANNEL_NAME} \
--tls --cafile ${ORDERER_CA} \
--peerAddresses "peer0.org1.net:15443"  \
--tlsRootCertFiles /var/hyperledger/crypto-config/Org1MSP/peer0.org1.net/tls-msp/tlscacerts/tls-tlsca1-hlf-ca-7054.pem \
--name eventstore

panic: Failed validating bootstrap block: initializing channelconfig failed: could not create channel Consortiums sub-group config: setting up the MSP manager failed: administrators must be declared when no admin ou classification is set

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 TARGET_ARCH=x86_64 sh -

${BIN}/peer lifecycle chaincode commit \
-o ${ORDERER_URL} -C ${CHANNEL_NAME} \
--tls --cafile ${ORDERER_CA} \
--name eventstore \
--version 1 \
--init-required \
--sequence 1 \
--peerAddresses peer0.org1.net:15443 \
--tlsRootCertFiles /var/hyperledger/crypto-config/Org1MSP/peer0.org1.net/tls-msp/signcerts/cert.pem \
--waitForEvent

${BIN}/peer chaincode invoke --isInit \
-o ${ORDERER_URL} -C ${CHANNEL_NAME} \
--tls --cafile ${ORDERER_CA} \
--name eventstore \
-c "{\"Args\":[\"Init\"]}" \
--peerAddresses p0o1-hlf-peer:7051 \
--tlsRootCertFiles /var/hyperledger/crypto-config/Org1MSP/peer0.org1.net/tls-msp/tlscacerts/tls-tlsca1-hlf-ca-7054.pem \
--waitForEvent

Error: endorsement failure during invoke. response: status:500 message:"error in simulation: failed to execute transaction 1935a23afa2322177aa955bffab42f70c0c0ea689e9edce625b1239afcbe1a42: invalid invocation: could not get 'initialized' key: error unmarshalling json data: unexpected end of JSON input"

marbles:3640833b936bbb810e95c12f24adda9e359e92ef597ab574d95d0ed26f6812a3
