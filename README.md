## Continuous Deployment
Continuous deployment for fabric-es

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

### Preparation Step
```shell script
# gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
# Step 0: after GKE is created, update local machine credentials
gcloud container clusters get-credentials dev-core-b --zone us-central1-c

# Step 1: Here assumes auto-injection is used. I attempt manual injection, but did not work.
kubectl create namespace n0
kubectl create namespace n1
kubectl create namespace n2
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled
kubectl label namespace n2 istio-injection=enabled

# Step 2: Create persistence volume claim for org0 and org1
# Creation of pvc is intentionally decouple from helm charts; different deployment may require very different storage
# requirement. Also, different cloud provider has different offering.
# In GCP, here assumes to use "standard" storageClass.
scripts/recreate-pvc.org01.gcp.sh
```

### Initial Setup
```shell script
# Install istio for org0 and org1
kubectl -n n0 apply -f networking/istio-n0.yaml
kubectl -n n1 apply -f networking/istio-n1.yaml

# Install
bootstrap.gcp.sh
```

### Releases
All releases' custom configuration is at `releases` directory, in form of helm charts value files.

### Cleanup
```shell script
# uninstall helm charts for org0 and org1
scripts/helm-uninstall.org01.sh

# and then, delete/recreate ALL pvc
scripts/recreate-pvc.org01.gcp.sh

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
- gupload
- hlf-ca
- hlf-couchdb
- hlf-ord
- hlf-peer
- hlf-cc
- hlf-operator
- orgadmin

### Helm
```shell script
# search public helm repository
helm search repo stable

# when there is external helm dependency in Chart.yaml
# helm dep update will add postgresql dependency in orgadmin
cd orgadmin
helm dep update

# if you want to install a standsalone postgres to defautl namespace, for standalone testing purpose
# helm install psql --set postgresqlPassword=hello bitnami/postgresql
```

### Networking
Here uses Istio Service Mesh, and istio CRD is located `networking` directory.

### Naming convention
*Helm chart value file*
[release name]-[app name].[cloud].yaml => admin0-orgadmin.gcp.yaml

### Reference Info
[External chaincode](https://medium.com/swlh/how-to-implement-hyperledger-fabric-external-chaincodes-within-a-kubernetes-cluster-fd01d7544523)
[External chaincode sample code](https://github.com/vanitas92/fabric-external-chaincodes)
[install istio/gke](https://istio.io/latest/docs/setup/platform-setup/gke/)
