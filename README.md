

### Helm charts
Availble app:
- gupload: grpc file uploader
- hlf-ca: Hyperledger Fabric Certificate Authority
- hlf-couchdb: CouchDB
- hlf-ord: Hyperledger Fabric Orderer
- hlf-peer: Hyperledger Fabric Peer
- hlf-cc: Hyperledger Fabric Chaincode
- hlf-operator: administrative tasks via k8s jobs
- orgadmin: administrative cli

`hlf-operator` involves below list of k8s jobs
- *bootstrap*: (a) multiples step to install `org1`; and (b) `orgX` Note that `orgX` has few steps than `org1`
- *fetch*: fetch block by `org1`, and then `gupload` to `orgX`
- *joinchannel*: join channel by `orgX`
- *neworg*: create new configtx.yaml of `orgX`, and then `gupload` to `org1`
- *updatechannel*: `org1` update channel with `orgX`'s channel-update-envelope

### Helm
```shell script
# search public helm repository
helm search repo stable

# add argo helm chart repo
helm repo add argo https://argoproj.github.io/argo-helm

# when there is external helm dependency in Chart.yaml
# helm dep update will add postgresql dependency in orgadmin
cd orgadmin
helm dep update

# if you want to install a standsalone postgres to defautl namespace, for standalone testing purpose
# helm install psql --set postgresqlPassword=hello bitnami/postgresql
```

