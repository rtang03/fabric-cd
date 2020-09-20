# fabric-cd
continuous deployment


https://stackoverflow.com/questions/54670170/how-to-override-the-istio-proxy-option-in-the-app-deployment

kubectl -n istio-system get configmap istio-sidecar-injector-istio-164 -o=jsonpath='{.data.config}' > inject-config.yaml
kubectl -n istio-system get configmap istio-istio-164 -o=jsonpath='{.data.mesh}' > mesh-config.yaml
kubectl -n istio-system get configmap istio-sidecar-injector-istio-164 -o=jsonpath='{.data.values}' > inject-values.yaml

kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.config}' > inject-config.yaml
kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.values}' > inject-values.yaml
kubectl -n istio-system get configmap istio -o=jsonpath='{.data.mesh}' > mesh-config.yaml

istioctl kube-inject --injectConfigFile inject-config.yaml --meshConfigFile mesh-config.yaml --valuesFile inject-values.yaml \
    --filename deployment.yaml -o deployment-injected.yaml

https://istio.io/latest/docs/setup/platform-setup/gke/

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-b --zone us-central1-c

kubectl create namespace n0
kubectl create namespace n1
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled

curl -d '{"spec":"grpc=debug:debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec
curl -d '{"spec":"debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec

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
