# DEVELOPER SECTION
This document is for use by repo contributor.

**IMPORTANT NOTE**

- All development should happen on `dev-x.x` branch. The `master` branch shall maintain
the latest runnable deployment; and is protected. It should perform pull request from `dev-x.x` ---> master.
- Collaborator should work on forked repo, and deploying his own development GKE cluster and google project.
- All contribution requires approval.

**Naming Convention**

- Deployment for Development Env: *dev-x.x*
- Deployment for Production Env: *prod-x.x*

**Technology**

- GKE 1.16.13-gke.401/regular channel (n1-standard-4: 4 vcpu/15GB x 1 node)
- Istio v1.4.10
- installation of gcloud cli, kubectl and istioctl
- helm charts v3
- Fabric v2.2.0
- Argo CD v1.7.7
- Argo Workflow v2.11.3
- sops
- Helm Secrets
- gpg
- GoLang


## First-time setup
### GKE
We need to deploy GKE using UI. After GKE is created, update local machine credentials. The current project name
is `fabric-cd-dev`.

**Configure local machine**

```shell script
# gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-b --zone us-central1-c
```

**Configure namespace**

Here assumes to deploy 2 organizations, and a commonly shared argo and argocd.

```shell script
kubectl create namespace argo
kubectl create namespace argocd
kubectl create namespace n0
kubectl create namespace n1
kubectl create namespace n2
```


### Istio
**Install istioctl cli**

Be noted different GKE version comes with different version of istio. After the GKE is created, validate the version of
istio. Also, istio is a pre-GA, I also found that GKE 1.17 comes with dual control plane (v1.4 and 1.6). Make sure
to install the correct version level of istio cli; compatibile with GKE bundled istio version.

*WARNING*: the latest / recent version may not work.

```shell script
# client installation of istioctl v1.4.10 CLI on local machine
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 TARGET_ARCH=x86_64 sh -
```

Here uses Istio Service Mesh, and istio CRD is located `networking` directory.

Note that k8s will reply on DNS in host network. I find that "org0.com" is public domain. We need to create private zone
in GCP Cloud DNS, with A record, of "orderer0.org0.com", equal to ip address of *istiogateway*. Currently, I have no idea
why the peer requires hostAlias for endpoint ip resolution. If no hostAlias, peer fails to send
gossips. It seems running peer rely on /etc/hosts, instead of DNS resolutions. On the other hand, when running installation
job, the "peer" cli will only rely on DNS resolutions. Before understanding how it works, currently will use both hostAlias
and private DNS. All peers and orderers shall work as expected. For every new cluster, it needs to install istio CRD.
Unless istio manifest changes, repetitive of istio deployment not required.

```shell script
kubectl -n n0 apply -f networking/istio-n0.yaml
kubectl -n n1 apply -f networking/istio-n1.yaml
kubectl -n n2 apply -f networking/istio-n2.yaml
kubectl -n argo apply -f networking/istio-argo.yaml
kubectl -n argocd apply -f networking/istio-argocd.yaml
```

**Auto injection**

```shell script
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled
kubectl label namespace n2 istio-injection=enabled
kubectl label namespace argo istio-injection=enabled
kubectl label namespace argocd istio-injection=enabled
```

**Optionally, istio probe rewrite**

```shell script
# currently, global probe rewrite is not enabled. We may consider disable itio probe rewrite globally
# kubectl get cm istio-sidecar-injector -n istio-system -o yaml | sed -e 's/"rewriteAppHTTPProbe": true/"rewriteAppHTTPProbe": false/' | kubectl apply -f -
```

**Compatibility issues**

Notice that the current version of istio (v1.4.x) provided by GKE is too low version. The addon of istio v1.7, like kiali and prometheus
do not work well. No traffic metric is able to capture in control plane. Still, istio traffic is fine.


### Cloud DNS
**Update Cloud Private Zone DNS**

You need create GCP private zone DNS, using UI. Currently, setup of private zone DNS in Google Networking required for:

- orderer0.org0.com
- orderer1.org0.com
- orderer2.org0.com
- orderer3.org0.com
- orderer4.org0.com
- gupload.org1.net
- gupload.org2.net
- peer0.org1.net
- peer0.org2.net
- argo.org1.net
- argo.org2.net
- argocd.org1.net
- argocd.org2.net

Remember to configure the private zone DNS to be upstream of `fabric-cd-dev` project.
All A-record is set equal to istio gateway ip address, which can be obtained below. This is one-time setup.

```shell script
kubectl -n istio-system get svc | grep ingressgateway
```

### Persistence Volume Claim
**Configure Persistence Volume Claim**

Creation of pvc is intentionally decouple from helm charts; different deployment may require very different storage
requirement. Also, different cloud provider has different offering. In GCP, here assumes to use "standard" storageClass.
Note that if there is running pod in the corresponding namespace, the deletion of PVC will wait. Consider that we
may have other persistence requirement. We do not choose dynamic provisoning.

For development scenarioes, we shall require to clean the PVC, in order to tear down the setup.
```shell script
# tear down
./scripts/uninstall.argo.sh

# remove and recreate org0 AND org1 pvc
./scripts/recreate-pvc.sh org1

# remove and recreate org2 pvc
./scripts/recreate-pvc.sh org2
```


### Github.com
Here assumes the connection to Github is via ssh; and every commit is gpg-signed. `Argo CD` requires ssh-key to pull changes.

- [Add SSH key](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account)
- [Add GPG key](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/adding-a-new-gpg-key-to-your-github-account)

GPG key is optional. The current Argo CD configuration is not enfored with gpg-signed deployment. Will later re-consider.

In your local dev machine for GitOps, you should configure project level commit signing. Notice that the pull request is
signed by *github.com*, instead of your *gpg*.

```shell script
# enable project level commit signing
# git config --global commit.gpgsign false
git config commit.gpgsign true
```


### KMS
We create new GCP keyring, and one key resource `sops-key`. This key will encrypt and decrypt the `secrets.yaml` or
`secrets.*.yaml`, when running `sops` or `helm-secret` commands. We do not use local pgp.

```shell script
# CREATE KEY (Local dev machine)
gcloud auth application-default login

# gcloud kms keyrings create [RESOURCE] --location [LOCATION]
gcloud kms keyrings create sops --location us-central1

# here uses Google managed key for encryption/decryption
gcloud kms keys create sops-key --location us-central1 --keyring fdi --purpose encryption

# list keyring: fdi
gcloud kms keys list --location us-central1 --keyring fdi

# CREATE SERVICE ACCOUNT (Encrypt and decrypt access control)
# see https://cloud.google.com/kms/docs/iam
# detailed steps are omitted here.
```

**IMPORTANT NOTE**: after service-account creation, download and save the credential json file. It will be used
in later steps. We recommend putting it inside `download` directory, which is already gitignored.


### Helm
```shell script
# search public helm repository
helm search repo stable

# add argo helm chart repo
helm repo add argo https://argoproj.github.io/argo-helm

# if you want to install a standsalone postgres to defautl namespace, for standalone testing purpose
# helm install psql --set postgresqlPassword=hello bitnami/postgresql
```


### sops / helm-secrets
In GitOps, you use [sops](https://github.com/mozilla/sops) to encrpyt the `secrets.yaml` before commiting. You may use either
install `sops` or `helm-secrets` cli to encrypt/decrypt local file. The naming convention is either `secrets.yaml` or `secrets.*.yaml`.

**Installing helm-secrets**

```shell script
# Optional Step: install helm-secrets plug-in locally
# install helm-secret + sops
helm plugin install https://github.com/zendesk/helm-secrets

# encrypt
helm secrets enc hlf-ca/secrets.yaml

# decrypt
helm secrets dec hlf-ca/secrets.yaml
```

`helm-secrets` installation will include `sops` as well. It shall require `.sops.yaml`, defining the keys resources. While
we use GCP, it needs to point your key resources. If you use different naming convention in above KMS setup; `.sops.yaml`
need modify as well.

```yaml
creation_rules:
  - gcp_kms: projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key
```

*basic sops command*

```shell script
# example sops command: if local pgp is used instead
# sops -e -i -p 33DBB14071110A8F093B29E7D95D3BE9260E76EA hlf-ca/secrets.yaml

# based on .sops.yaml, encrypt:
sops -e -i hlf-ca/secrets-rca0.yaml

# decrypt
sops -d -i orgadmin/secrets-admin1.yaml
```

**IMPORTANT NOTE**: sops is field-level encryption. In our case, *argocd-server* will decrypt the `secrets.yaml`,
after `argocd submit` is run. The decrypted values append as normal helm chart values files. There are two common uses:
1. the decrypted value is an input to creating the k8s Secret resource. In such cases, you need to do base64 encoding,
*BEFORE* encryption.
1. the decrypted value is used as environment variables of the pod. The base64 encoding is not required.


### Argo CD Installation on GKE
*Argo CD* (a.k.a. argocd) is in-cluster deployment; exposing either via port-forwarding or istiogateway. Argo CD does not natively integrate
with `helm-secrets`. It needs a custom image of ArgoCD, in order for ArgoCD to do the on-the-fly decryption; custom image
located at [custom argocd repo](https://github.com/rtang03/argocd); publishing Github Container Registry
[custom argocd image](https://github.com/users/rtang03/packages/container/package/argocd). Therefore, default installation
won't work.

**Optional: Istio**

Here assumes that each organization will deploy his own cluster-scope *argocd*. This is loose requirement to expose
*argocd* to public internet. Istio-enabled *argocd* is an optional feature.

**Making helm value file**  There are two value files:
- `argocd/values-argocd.yaml` contains non-confidential configuration
- `argocd/values-argocd.key.yaml` contains service-acount credential-json, which execute GCP KMS encrytp/decrypt, for
`sops-key` resource. This file is being git-ignored.

`touch argocd/values-argocd.key.yaml` create new value file; and then manually copy the content of credential-json to it;
see example in `argocd/values-argocd.key.example.yaml`. In above GCP KMS section, you should save the credential json file..

**Install argocd with community supported helm chart**

Modify the `argocd/values-argocd.yaml` for installation configuration.

```shell script
# see https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd
# see example values file => https://github.com/argoproj/argo-helm/blob/master/charts/argo-cd/values.yaml
helm -n argocd install argocd -f argocd/values-argocd.yaml -f argocd/values-argocd.key.yaml --set installCRDs=false argo/argo-cd

# wait to complete
kubectl wait --for=condition=Ready --timeout 180s pod/$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2) -n argocd
```

**Install local argocd cli**

```shell script
# on mac
brew install argocd
```

**Deploy project specific configuration**

```shell script
kubectl -n argocd apply -f ./argocd/project.yaml

# if accidentally modify argocd-cm in later step, you may need to re-load it.
# this step should use with care
# kubectl -n argocd apply -f ./argocd/argocd-cm.yaml
```

**Port Forwarding**

```shell script
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Authenticate**

```shell script
# the initial password is pod-id
POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)

# UPDATE PASSWORD: when port-forwarding is live, can update password
# Do update password after initial setup
argocd login localhost:8080 --insecure --username admin --password $POD
argocd account update-password --current-password $POD --new-password [some-strong-password]
```

**Add your git repo**

As a pre-requisite, you need to create ssh key in your github.com account; and having ssh key in below path.
In your fork repo, the below git url and ssh will be different. Notice that we intentionally not configuring
the ssh as part of *argocd-cm* configMap, preventing the ssh private key from commiting to github.

```shell script
# Argocd connect to github with ssh key. Private key of github ssh login is located at `.ssh/id_rsa`
# NOTE1: that this will modify argcd-cm configmap. Hence, after each time 'kubectl -n argocd apply -f ./argocd/argocd-cm.yaml'
# below add-repo needs rerun
argocd repo add git@github.com:rtang03/fabric-cd.git --insecure-ignore-host-key --ssh-private-key-path ~/.ssh/id_rsa
```

*IMPORTANT NOTE*: currently, *rtang03* is the sole owner/maintainer of private repository `fabric-cd`. It may require
a better developer workflow for new collaborator.

As an interim approach, need to update `/etc/hosts` for *argocd.server* entry. To validate installation, open browser.
- if using port-forward, `http://localhost:8080`
- if using publicly exposed, `http://argocd.server`

**GKE cluster admin**

```shell script
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
```

### Argo Workflow Installation on GKE
*Argo Workflow* (a.k.a. argo) is also in-cluster deployemt; exposing either via port-forwarding or istiogateway.
*argo*, not like *argocd*, does not handle secrets, and it does not require custom image.

**Pre-requisite: Istio**

The multi organization workflow orchestration requires interactions over REST API. Istio-enabled *argo* is a
required feature.

As a development, *argo* is not hard-coded host file. Update the `/etc/hosts` to add line "35.xxx.xxx.xxx argo.server".

*Pre-requisite: service accounts*

All workflow are performed by rbac backed service accounts. There are two service accounts:
- *workflow*: is created for each namespace, e.g. n0 and n1. It can perform any verbs.
- *orgadmin*: can do a subset of admin task, (subject to futher requirement).

```shell script
# CREATE SERVICE ACCOUNT "workflow" (for each application namespace)
kubectl -n n0 apply -f ./argo/service-account-argo.yaml
kubectl -n n1 apply -f ./argo/service-account-argo.yaml
kubectl -n n2 apply -f ./argo/service-account-argo.yaml

# TODO: TO BE REVIEWED
# kubectl -n istio-system apply -f ./argo/service-account-argo.yaml

# OPTIONALLY, CREATE SERVICE ACCOUNT "orgadmin" (for each application namespace)
# kubectl -n $NS1 apply -f ./argo/service-account-orgadmin.yaml
```

**Install argo with community supported helm chart**

Modify the `argo/values-argo.yaml` for installation configuration.
```shell script
# see https://github.com/argoproj/argo-helm/tree/master/charts/argo
helm -n argo install argo -f argo/values-argo.yaml --set installCRDs=false argo/argo
```

**Artifactory**

```shell script
# configure artifactory to using GCS Storage
kubectl -n argo apply -f ./argo/argo-cm.yaml
```

**Install local argo cli**

Download cli from the [release page](https://github.com/argoproj/argo/releases)

**Port Forwarding**

```shell script
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

**Argo Server REST API**

In the multi-org deployment workflow, it shall reply Argo Server, for workflow execution. The Argo Server will be configured
with "client mode" (see [auth-mode](https://argoproj.github.io/argo/argo-server-auth-mode/)). Both UI and REST API requires
access token (see [access-token](https://argoproj.github.io/argo/access-token/))

**Authenicate**

```shell script
ARGO_TOKEN=$(argo auth token)
echo $ARGO_TOKEN

# using UI, open http://35.202.107.80   <== expose via istio gateway
# login by copy-and-past the above access token in the login page
```

**cUrl**

```shell script
curl -v -H "Authorization: $ARGO_TOKEN" -H "Host: argo.server"  http://35.202.107.80/api/v1/workflows/argo
```

**Obtain access token for different service account**

```shell script
# Obtain access token from service account "workflow"
SECRET=$(kubectl -n n1 get sa workflow -o=jsonpath='{.secrets[0].name}')
ARGO_TOKEN="Bearer $(kubectl -n $NS1 get secret $SECRET -o=jsonpath='{.data.token}' | base64 --decode)"
```

**WorkflowTemplates**

Here installs both *WorkflowTemplate* and *ClusterWorkflowTemplate*, via helm chart, under `workflow/wftemplate` directory. The
workflow templates includes:
- secret-resource (cluster scoped): create, delete
- (namespace scoped)

See concept of [WorkflowTemplate](https://argoproj.github.io/argo/workflow-templates/), and [Cluster Workflow Templates](https://argoproj.github.io/argo/cluster-workflow-templates/).

```shell script
# ClusterWorkflowTemplate
# Optionally, clean-up
argo cluster-template delete secret-resource

# Create ClusterWorkflowTemplate
helm template workflow/wftemplate --set clusterscope=true | argo cluster-template create -

# Create WorkflowTemplate
argo -n n1 template delete retrieve-from-http

helm template workflow/wftemplate | argo -n n1 template create -

helm template workflow/wftemplate | argo -n n2 template create -

# workflow of workflow - ORG1
# STEP 1: send org1.net-tlscacert.pem to to n1 /var/gupload/fileserver/public
# 1. retrieve-from-http

# STEP 2: send org0.com-tlscacert.pem to to n1 /var/gupload/fileserver/public
# 1. retrieve-from-http
argo -n n1 submit workflow/wow-bootstrap.n1.yaml

# workflow of workflow - ORG2
# STEP 1: send org1.net-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
# 1. retrieve-from-http
# 2. create-secret-from-file

# STEP 2: send org0.com-tlscacert.pem to to n2 /var/gupload/fileserver; and create secret
# 1. retrieve-from-http
# 2. create-secret-from-file

# STEP 3: get org2.net-tlscacert.pem and create org2.net-tlscacert.pem in n2
# 1. retrieve-from-http
# 2. create-secret-from-file

# STEP 4: curl n1, to repeat STEP 3 for n1

argo -n n2 submit workflow/wow-bootstrap.n2.yaml

# testing code. Not used now
helm template workflow/secrets -f workflow/secrets/values-istio-org1.yaml | argo -n $NS1 submit - --wait
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
Every organization should use this common chaincode. Similarly, I publish the `gupload` grpc upload server/client to Github container registry.


### Tear down
In most cases, you are not required to re-create GKE cluster / DNS / istio in most development scenarios. You should
uninstall application by `argocd` commands, this will delete corresponding pods in the cluster. Then, recreate persistence
volume claims.

```shell script
# Step 1: uninstall applications  via argocd, in ALL NAMESPACES
# if you need to uninstall application in one namespace, need to do it UI, or manually in cli.
./uninstall.argo.sh

# Step 2: delete/recreate All pvc in corresponding namespace
./recreate-pvc.sh org1
./recreate-pvc.sh org2

# just in case, remove istio objects. If you want to re-run installation of the same cluster, unnecessarily removing istio object
# kubectl -n n0 delete -f networking/istio-n0.yaml
# kubectl -n n1 delete -f networking/istio-n1.yaml
```

### Useful commands
**gpg**

```shell script
# list GPG keys
gpg --list-secret-keys --keyid-format LONG

# Retrive PGP Private key from local machine, assuming gpg suite is used
gpg --export-secret-keys --armor 33DBB14071110A8F093B29E7D95D3BE9260E76EA
```

**sops**

```shell script
# sops encryption command, -i means in-place replacement
sops -e -i --gcp-kms projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key test.yaml
```

**kubectl**

```shell script
# streaming logs
kubectl -n n0 logs -f [ORDERER_POD_ID] -c orderer
kubectl -n n1 logs -f [PEER_POD_ID] -c peer

# For orderer debugging when orderering is actively running; you may tty into it, and alter the logging mode
# kubectl -n [Namespace] exec -it [ORDERER_POD_ID] -c orderer
# kubectl -n [Namespace] exec -it [PEER_POD_ID] -c peer
```

**istioctl**

```shell script
# output status
istioctl ps
```

**helm**

```shell script
# example to output argo workflow manifest for debugging
helm template workflow/cryptogen -f workflow/cryptogen/values-rca1.yaml | argo -n n1 submit - --server-dry-run --output yaml

# debug helm chart with --dry-run --debug
helm install rca0 -f ./hlf-ca/values-rca0.yaml -n n0 --dry-run --debug ./hlf-ca
```

**Postgres**

```shell script
# after postgresql is installed, you can valiate it; by decoding the secret
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default psql-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

# you can launch a port-forward, so that the psql client in host system can access it
kubectl port-forward --namespace default svc/psql-postgresql 5433:5432

# login with psql
PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5433
```

**ksniff**

```shell script
kubectl sniff <POD_NAME> [-n <NAMESPACE_NAME>] [-c <CONTAINER_NAME>] [-i <INTERFACE_NAME>] [-f <CAPTURE_FILTER>] [-o OUTPUT_FILE] [-l LOCAL_TCPDUMP_FILE] [-r REMOTE_TCPDUMP_FILE]

# POD_NAME: Required. the name of the kubernetes pod to start capture its traffic.
# NAMESPACE_NAME: Optional. Namespace name. used to specify the target namespace to operate on.
# CONTAINER_NAME: Optional. If omitted, the first container in the pod will be chosen.
# INTERFACE_NAME: Optional. Pod Interface to capture from. If omited, all Pod interfaces will be captured.
# CAPTURE_FILTER: Optional. specify a specific tcpdump capture filter. If omitted no filter will be used.
# OUTPUT_FILE: Optional. if specified, ksniff will redirect tcpdump output to local file instead of wireshark. Use '-' for stdout.
# LOCAL_TCPDUMP_FILE: Optional. if specified, ksniff will use this path as the local path of the static tcpdump binary.
# REMOTE_TCPDUMP_FILE: Optional. if specified, ksniff will use the specified path as the remote path to upload static tcpdump to.

kubectl sniff <POD_NAME> -f "port 80" -o - | tshark -r -

# e.g.
kubectl sniff tlsca1-hlf-ca-69647d6cfb-gs7wn -n n1 -c ca
kubectl sniff tlsca1-hlf-ca-69647d6cfb-gs7wn -n n1 -c ca -f "port 80" -o - | tshark -r -
```

**miscellaneous**

```shell script
# install curl inside orderer or peer
# apk add curl
# e.g: {"spec":"debug"} {"spec":"grpc=debug:debug"} {"spec":"info"}
curl -d '{"spec":"grpc=debug:debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec

# debug grpc transport
# login the container and turn on grpc debug
# export GODEBUG=http2debug=2

# optionaly, create alias for kubectl and istioctl, and add to your shell's e.g. ./zshrc
# alias k0="kubectl -n n0"
# alias k1="kubectl -n n1"
# alias i0="istioctl -n n0"
# alias i1="istioctl -n n1"
```


### Reference Information
- [Argo CD getting started](https://argoproj.github.io/argo-cd/getting_started/)
- [Argo CD install manifest](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)
- [Argo CD api spec](https://github.com/argoproj/argo/blob/master/api/openapi-spec/swagger.json)
- [Argo Workflow installation](https://argoproj.github.io/argo/installation/)
- [helm chart for installing argo](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd)
- [Docker image with helm and gcloud](https://hub.docker.com/r/devth/helm)
- [sops](https://github.com/mozilla/sops#test-with-the-dev-pgp-key)
- [helm-secrets plugin](https://github.com/zendesk/helm-secrets)
- [How to prepare custom argocd image](https://medium.com/faun/handling-kubernetes-secrets-with-argocd-and-sops-650df91de173)
- [Setup IAM for kms](https://cloud.google.com/kms/docs/iam)
- [GKE permission and role](https://cloud.google.com/kms/docs/reference/permissions-and-roles)
- [Argo CD/istio compatibility issue](https://github.com/argoproj/argo-cd/issues/2784)
- [Argo WF - install manifest](https://raw.githubusercontent.com/argoproj/argo/stable/manifests/install.yaml)
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
- [auto-changelog generator](https://github.com/marketplace/actions/automatic-changelog-generator)
- [ArgoCD + Istio: sample](https://github.com/speedwing/eks-argocd-bootstrap)
- [install krew](https://krew.sigs.k8s.io/docs/user-guide/setup/install)
- [ksniff](https://github.com/eldadru/ksniff)
https://itnext.io/verifying-service-mesh-tls-in-kubernetes-using-ksniff-and-wireshark-2e993b26bf95

### TODO
**Sops commit hook**

See `scripts/.sopscommithook`. This is an example of commit hook to prevent commiting un-encrypted secret files accidentally.
Create commit hook in your local repository.

**Change initial secret**

The *orgadmin* helm chart will create *crypto-material* Secret resource. It contains a number of username / password.
Currently, there is no way to modify after *orgadmin* is running.

**Enable HTTPS proxy**

For argo, and argocd; enable https proxy, via istio secure gateway pattern. I attempted it, but failed. Try later.
