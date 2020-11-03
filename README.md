## Continuous Deployment
Continuous deployment for fabric-es

```text
Dear Everyone,

All steps are not future-proof, any change may break. It works, maybe I don't know how it works.

Take your own risk  🎃
```

### Pre-requisite
- GKE 1.16.13-gke.401/regular channel
- n1-standard-4: 4 vcpu/15GB x 1 node
- Istio v1.4.10
- installation of gcloud cli, kubectl and istioctl
- helm charts v3
- Fabric v2.2.0

*Installation of istioctl*
Be noted different GKE version comes with different version of istio. After the GKE is created, validate the version of
istio. Also, istio is a pre-GA, I also found that GKE 1.17 comes with dual control plane (v1.4 and 1.6).

```shell script
# client installation of istioctl v1.4.10
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 TARGET_ARCH=x86_64 sh -
```

### Update Private DNS
Currently, an one-off setup of private zone DNS in Google Networking is required for:
- orderer0.org0.com
- orderer1.org0.com
- orderer2.org0.com
- orderer3.org0.com
- orderer4.org0.com
- gupload.org1.net
- gupload.org1.net
- gupload.org2.net
- gupload.org3.net
- peer0.org1.net
- peer0.org2.net
- peer0.org3.net

All A-record is set equal to istio gateway ip.

### Preparation Step

**Step 0: after GKE is created, update local machine credentials**

```shell script
# gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-b --zone us-central1-c

# disable itio probe rewrite globally
kubectl get cm istio-sidecar-injector -n istio-system -o yaml | sed -e 's/"rewriteAppHTTPProbe": true/"rewriteAppHTTPProbe": false/' | kubectl apply -f -

# Step 1: Here assumes auto-injection is used. I attempt manual injection, but did not work.
kubectl create namespace n0
kubectl create namespace n1
kubectl create namespace n2
kubectl create namespace n3
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled
kubectl label namespace n2 istio-injection=enabled
kubectl label namespace n3 istio-injection=enabled

# Step 2: Create persistence volume claim for org0 and org1
# Creation of pvc is intentionally decouple from helm charts; different deployment may require very different storage
# requirement. Also, different cloud provider has different offering.
# In GCP, here assumes to use "standard" storageClass.
./recreate-pvc.sh org1
./recreate-pvc.sh org2
./recreate-pvc.sh org3
```

**Goto GKE, obtain the IP for Istio Ingress Gateway**
Update ip address for hlf-peer.gcp.yaml, and all values files of "hlf-operator" jobs.

```yaml
peer:
  hostAlias:
    - hostnames:
        - orderer0.org0.com
        - orderer1.org0.com
        - orderer2.org0.com
        - orderer3.org0.com
        - orderer4.org0.com
        - peer0.org1.net
      ip: 35.xxx.xxx.xxx
```

### Initial Setup
For every new cluster, it needs to install istio CRD. For `uninstall', re-install of istio is not required.

```shell script
# One time Install istio
kubectl -n n0 apply -f networking/istio-n0.yaml
kubectl -n n1 apply -f networking/istio-n1.yaml
kubectl -n n2 apply -f networking/istio-n2.yaml
kubectl -n n3 apply -f networking/istio-n3.yaml
```

### Releases
All releases' custom configuration is at `releases` directory, in form of helm charts value files.
```shell script
# execute one by one
bootstrap.gcp.sh org1
bootstrap.gcp.sh org2
bootstrap.gcp.sh org3
```

### Cleanup
```shell script
# uninstall helm charts for org0 and org1
./uninstall.sh org1
./uninstall.sh org2
./uninstall.sh org3

# and then, delete/recreate ALL pvc
./recreate-pvc.sh org1
./recreate-pvc.sh org2
./recreate-pvc.sh org3

# remove istio objects
# if you want to re-run installation of the same cluster, you are not necessarily removing istio object
kubectl -n n0 delete -f networking/istio-n0.yaml
kubectl -n n1 delete -f networking/istio-n1.yaml
```

*Useful Command*
```shell script
# show streaming logs
kubectl -n n0 logs -f [ORDERER_POD_ID] -c orderer
kubectl -n n1 logs -f [PEER_POD_ID] -c peer

# For orderer debugging when orderering is actively running; you may tty into it, and alter the logging mode
# kubectl -n [Namespace] exec -it [ORDERER_POD_ID] -c orderer

# install curl inside orderer or peer
# apk add curl
# e.g: {"spec":"debug"} {"spec":"grpc=debug:debug"} {"spec":"info"}
curl -d '{"spec":"grpc=debug:debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec

# Similarly, for peer debugging, the port is changed to :9443
# kubectl -n [Namespace] exec -it [PEER_POD_ID] -c peer

# after postgresql is installed, you can valiate it; by decoding the secret
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default psql-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

# you can launch a port-forward, so that the psql client in host system can access it
kubectl port-forward --namespace default svc/psql-postgresql 5433:5432

# login with psql
PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5433

# debug helm chart with --dry-run --debug
helm install rca0 -f ./hlf-ca/values-rca0.yaml -n n0 --dry-run --debug ./hlf-ca

# debug grpc transport
# login the container and turn on grpc debug
# export GODEBUG=http2debug=2

# optionaly, create alias for kubectl and istioctl, and add to your shell's e.g. ./zshrc
# alias k0="kubectl -n n0"
# alias k1="kubectl -n n1"
# alias i0="istioctl -n n0"
# alias i1="istioctl -n n1"
```

### External chaincode container
To remove the shortcoming of DockerInDocker chaincode, here uses the external chaincode, which requires v2.0+.
See [Fabric Documentation](https://hyperledger-fabric.readthedocs.io/en/latest/cc_launcher.html)

The chaincode `dist` is located at `chaincode/fabric-es`. It will be made a docker image via Github Action, by adding a new tag.
```shell script
git tag v0.0.3
git push origin v0.0.3
```

The new image publishes to [my Github container registry](https://github.com/users/rtang03/packages/container/package/eventstore).
Every organization should use this common chaincode.

Similarly, I publish the `gupload` grpc upload server/client to Github container registry.

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

### Networking
Here uses Istio Service Mesh, and istio CRD is located `networking` directory.

Note that k8s will reply on DNS in host network. I find that "org0.com" is public domain. We need to create private zone
in GCP Cloud DNS, with A record, of "orderer0.org0.com", equal to ip address of istiogateway.

Currently, I have no idea why the peer requires hostAlias for endpoint ip resolution. If no hostAlias, peer fails to send
gossips. It seems running peer rely on /etc/hosts, instead of DNS resolutions. On the other hand, when running installation
job, the "peer" cli will only rely on DNS resolutions.

Before understanding how it works, currently will use both hostAlias and private DNS. And, all peers and orderers shall
work as expected.

### Naming convention
*Helm chart value file*
[release name]-[app name].[cloud].yaml => admin0-orgadmin.gcp.yaml

### External Reference
- [External chaincode](https://medium.com/swlh/how-to-implement-hyperledger-fabric-external-chaincodes-within-a-kubernetes-cluster-fd01d7544523)
- [External chaincode sample code](https://github.com/vanitas92/fabric-external-chaincodes)
- [install istio/gke](https://istio.io/latest/docs/setup/platform-setup/gke/)
- [k8s api spec](https://pkg.go.dev/k8s.io/api@v0.16.13)
- [hlf-ca helm chart](https://github.com/helm/charts/tree/master/stable/hlf-ca)
- [postgres helm chart](https://github.com/bitnami/charts/tree/master/bitnami/postgresql)
- [example: nginx ingress](https://matthewpalmer.net/kubernetes-app-developer/articles/kubernetes-ingress-guide-nginx-example.html)
- [fabric helm chart](https://medium.com/google-cloud/helm-chart-for-fabric-for-kubernetes-80408b9a3fb6)
- [kubect documentation](https://kubectl.docs.kubernetes.io/)
- [k8s dashboard](https://github.com/kubernetes/dashboard#kubernetes-dashboard)
- [gke nginx example](https://github.com/GoogleCloudPlatform/community/blob/master/tutorials/nginx-ingress-gke/index.md)
- [Hyperledger on Azure](https://github.com/Azure/Hyperledger-Fabric-on-Azure-Kubernetes-Service/blob/master/fabricTools/deployments/peer/fabric-peer-template-couchDB.yaml)
