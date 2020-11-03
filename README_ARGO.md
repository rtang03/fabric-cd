# Continuous Deployment
Continuous deployment for fabric-es

```text
Dear Everyone,

All steps are not future-proof, any change may break. It works, maybe I don't know how it works.

Take your own risk  🎃
```

### Technology
- GKE 1.16.13-gke.401/regular channel
- n1-standard-4: 4 vcpu/15GB x 1 node
- Istio v1.4.10
- installation of gcloud cli, kubectl and istioctl
- helm charts v3
- Fabric v2.2.0
- Argo CD v1.7.7
- Argo Workflow v2.11.3
- sops & Helm Secrets & gpg
- External chaincode launcher

## Key Concepts
- Istio
- Helm Charts
- Cloud DNS
- GKE
- GCS Storage
- GCS KMS
- sops


### Istio
*Install istioctl cli*
Be noted different GKE version comes with different version of istio. After the GKE is created, validate the version of
istio. Also, istio is a pre-GA, I also found that GKE 1.17 comes with dual control plane (v1.4 and 1.6).

```shell script
# client installation of istioctl v1.4.10 CLI on local machine
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 TARGET_ARCH=x86_64 sh -
```

Here uses Istio Service Mesh, and istio CRD is located `networking` directory.

Note that k8s will reply on DNS in host network. I find that "org0.com" is public domain. We need to create private zone
in GCP Cloud DNS, with A record, of "orderer0.org0.com", equal to ip address of istiogateway.

Currently, I have no idea why the peer requires hostAlias for endpoint ip resolution. If no hostAlias, peer fails to send
gossips. It seems running peer rely on /etc/hosts, instead of DNS resolutions. On the other hand, when running installation
job, the "peer" cli will only rely on DNS resolutions.

Before understanding how it works, currently will use both hostAlias and private DNS. And, all peers and orderers shall
work as expected.

*First-time Setup*
For every new cluster, it needs to install istio CRD. For `uninstall', re-install of istio is not required.

```shell script
# One time Install istio
kubectl -n n0 apply -f networking/istio-n0.yaml
kubectl -n n1 apply -f networking/istio-n1.yaml
kubectl -n n2 apply -f networking/istio-n2.yaml
kubectl -n n3 apply -f networking/istio-n3.yaml
```

### DNS
*Update Private DNS*
Currently, one-off setup of private zone DNS in Google Networking is required for:
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

### GKE
**Step 0: after GKE is created, update local machine credentials**

*Configure local machine*

```shell script
# gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-b --zone us-central1-c

# currently, global probe rewrite is not enabled.
# optionally, disable itio probe rewrite globally
# kubectl get cm istio-sidecar-injector -n istio-system -o yaml | sed -e 's/"rewriteAppHTTPProbe": true/"rewriteAppHTTPProbe": false/' | kubectl apply -f -
```

*Configure namespace*

**Step 1: Here assumes auto-injection is used. I attempt manual injection, but did not work.**

```shell script
kubectl create namespace n0
kubectl create namespace n1
kubectl create namespace n2
kubectl create namespace n3
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled
kubectl label namespace n2 istio-injection=enabled
kubectl label namespace n3 istio-injection=enabled
```

*Configure Persistence Volume Claim*

**Step 2: Create persistence volume claim for org0 and org1**
Creation of pvc is intentionally decouple from helm charts; different deployment may require very different storage
requirement. Also, different cloud provider has different offering. In GCP, here assumes to use "standard" storageClass.
Note that if there is running pod in the corresponding namespace, the deletion of PVC will wait.

```shell script
# remove and recreate org0 AND org1 pvc
./recreate-pvc.sh org1

# remove and recreate org2 pvc
./recreate-pvc.sh org2
```

*Configure Host Alias*

**Step 3: Goto GKE, obtain the IP for Istio Ingress Gateway**
Update ip address of below values files
- hlf-peer/values-p0o1.yaml

See below snippets
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


## Argo CD & Workflow
Below are instruction for the deployment with Argo CD and Argo Workflow

*Technology*
- Argo CD & Workflow
- helm Chart v3, with helm-secrets plug-in
- GCP KMS
- sops

### Development and Deployment Workflow
*Naming Convention*
- "Deployment for Development Env": [dev-0.0.1]
- The development branch of "Deployment for Development Environment": [dev-0.0.1]-a
- "Deployment for Production Env": [prod-0.0.1]

*Chart Development*
All CD charts development and ArgoCD development should happen at [dev-0.1]. It should perform pull request
FROM [dev-0.1] ---> master.

*Deployment*
- ArgoCD server will pull changes from [test-0.0] for continuous testing.
- ArgoCD server will pull changes from [prod-0.0] for PROD deployment.

The `master` branch is always is in line with DEV latest.

### Pre-requisite: GCP KMS
You create new GCP keyring, and one key resource `sops-key`. This key will encrypt and decrypt the `secrets.yaml`, when running `sops`
and `helm-secret` commands. For enterprise-graded deployment, a local pgp is not preferred.

```shell script
# CREATE KEY (Local dev machine)
gcloud auth application-default login
gcloud kms keyrings create sops --location us-central1
gcloud kms keys create sops-key --location us-central1 --keyring fdi --purpose encryption

# list keyring: fdi
gcloud kms keys list --location us-central1 --keyring fdi

# CREATE SERVICE ACCOUNT (Encrypt and decrypt access control)
# see https://cloud.google.com/kms/docs/iam
# detailed steps are omitted here.

# IMPORTANT NOTE: after service-account creation, save the credential json file. It will be used in later step.
```


### Pre-requisite: sops or helm-secrets
In GitOps, you use [sops](https://github.com/mozilla/sops) to encrpyt the `secrets.yaml` before commiting. You may use either
`sops` or `helm-secrets` cli to encrypt/decrypt local file. The naming convention is either `secrets.yaml` or `secrets.[RELEASE-NAME].yaml`.

*Installing helm-secrets*
```shell script
# Optional Step: install helm-secrets plug-in locally
# install helm-secret + sops
helm plugin install https://github.com/zendesk/helm-secrets

# Suggest to use helm-secret, instead of sops directly
helm secrets enc hlf-ca/secrets.yaml

# decrypt
helm secrets dec hlf-ca/secrets.yaml
```

`helm-secrets` installation will include `sops` as well. It shall require `.sops.yaml`, defining the keys resources. While
we use GCP, it needs to point your key resources.

```yaml
creation_rules:
  - gcp_kms: projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key
```

*Use sops*
```shell script
# example sops command: if local pgp is used instead
sops -e -i -p 33DBB14071110A8F093B29E7D95D3BE9260E76EA hlf-ca/secrets.yaml

# based on .sops.yaml, encrypt:
sops -e -i hlf-ca/secrets-rca0.yaml
sops -e -i hlf-ca/secrets-rca1.yaml
sops -e -i hlf-ca/secrets-tlsca1.yaml
sops -e -i hlf-ca/secrets-tlsca0.yaml
sops -e -i orgadmin/secrets-admin0.yaml
sops -d -i orgadmin/secrets-admin1.yaml
```


### Pre-requisite: Github
Here assumes the connection to Github is via ssh; and every commit is gpg-signed. `Argo CD` requires ssh-key to pull changes.

- [Add SSH key](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account)
- [Add GPG key](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/adding-a-new-gpg-key-to-your-github-account)

GPG key is optional. The current Argo CD configuration is not enfored with gpg-signed deployment. Will later re-consider.

In your local dev machine for GitOps, you should config project level commit signing.
```shell script
# enable project level commit signing
# git config --global commit.gpgsign false
git config commit.gpgsign true
```


### Argo CD Installation on GKE
*Pre-requisite: Istio*
The multi-org workflow shall rely on REST API, with external access.

```shell script
# see example: https://github.com/speedwing/eks-argocd-bootstrap
kubectl label namespace argocd istio-injection=enabled
kubectl -n argocd apply -f networking/istio-argocd.yaml
```

Currently, `Argo CD` is in-cluster deployment; communicating via port-forwarding. Argo CD does not natively integrate
with `helm-secrets`. It needs a custom image of ArgoCD, in order for ArgoCD to do the on-the-fly decryption; custom image
located at [custom argocd repo](https://github.com/rtang03/argocd); publishing Github Container Registry
[custom argocd image](https://github.com/users/rtang03/packages/container/package/argocd). Therefore, default installation
won't work.

*Making helm value file*
There are two value files:
- `argocd/values-argocd.yaml` contains non-confidential configuration
- `argocd/values-argocd.key.yaml` contains service-acount credential-json, which execute GCP KMS encrytp/decrypt, for
`sops-key` resource. This file is being git-ignored.

`touch argocd/values-argocd.key.yaml` create new value file; and then manually copy the content of credential-json to it;
see example in `argocd/values-argocd.key.example.yaml`.

In above GCP KMS section, you should save the credential json file.

```shell script
# CREATE DEFAULT NS
kubectl create namespace argocd

# ADD COMMUNITY HELM-REPO
helm repo add argo https://argoproj.github.io/argo-helm

# INSTALL COMMUNITY HELM CHART
# see https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd
# see example values file => https://github.com/argoproj/argo-helm/blob/master/charts/argo-cd/values.yaml
helm -n argocd install argocd -f argocd/values-argocd.yaml -f argocd/values-argocd.key.yaml --set installCRDs=false argo/argo-cd

# WAIT
kubectl wait --for=condition=Ready --timeout 180s pod/$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2) -n argocd

# INSTALL CLI ON MAC
brew install argocd

# CONFIGURE, see NOTE1 below
kubectl -n argocd apply -f ./argocd/project.yaml
# NOTE: CAN DELETE
# kubectl -n argocd apply -f ./argocd/argocd-cm.yaml

# Optionally, PORT-FORWARD
# kubectl port-forward svc/argocd-server -n argocd 8080:443

# AUTHENTICATE
# get initial password, i.e. pod id
POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)

# UPDATE PASSWORD: if using port-forward, can update password
argocd login localhost:8080 --insecure --username admin --password $POD
argocd account update-password --current-password $POD --new-password password

# Argocd connect to github with ssh key. Private key of github ssh login is located at `.ssh/id_rsa`
# NOTE1: that this will modify argcd-cm configmap. Hence, after each time 'kubectl -n argocd apply -f ./argocd/argocd-cm.yaml'
# below add-repo needs rerun
argocd repo add git@github.com:rtang03/fabric-cd.git --insecure-ignore-host-key --ssh-private-key-path ~/.ssh/id_rsa

# IF RUNNING GKE, need cluster-admin
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
```

To validate installation, open browswer `http://localhost:8080`

### Argo Workflow Installation on GKE
*Pre-requisite: Istio*
The multi-org workflow shall rely on REST API, with external access.

```shell script
kubectl label namespace argo istio-injection=enabled
kubectl -n argo apply -f networking/istio-argo.yaml
```
As an interim solution, update the `/etc/hosts` to add line `35.202.107.80 argo.server"

*Pre-requisite: service accounts*
It will deploy service account *workflow* into n0 and n1; which can perform all deployment tasks. On the other hand, the
service account *orgadmin* can do a subset of admin task, (subject to futher requirement).

```shell script
# CREATE SERVICE ACCOUNT "workflow" (for each application namespace)
kubectl -n $NS0 apply -f ./argo/service-account-argo.yaml
kubectl -n $NS1 apply -f ./argo/service-account-argo.yaml

# OPTIONALLY, CREATE SERVICE ACCOUNT "orgadmin" (for each application namespace)
# kubectl -n $NS1 apply -f ./argo/service-account-orgadmin.yaml
```

*Install Argo Workflow*
Optionally, modify the `argo/values-argo.yaml` for installation configuration.

```shell script
# CREATE DEFAULT NS
kubectl create ns argo

# INSTALL COMMUNITY HELM CHART
# see https://github.com/argoproj/argo-helm/tree/master/charts/argo
helm -n argo install argo -f argo/values-argo.yaml --set installCRDs=false argo/argo

# see https://argoproj.github.io/argo/rest-api/

# configure artifact repo
# kubectl -n argo apply -f ./argo/argo-cm.yaml

# Optionally using PORT-FORWARD
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

*Argo Server REST API*
In the multi-org deployment workflow, it shall reply Argo Server, for workflow initation. The Argo Server will be configured
with "client mode" (see [auth-mode](https://argoproj.github.io/argo/argo-server-auth-mode/)). Both UI and REST API requires
access token (see [access-token](https://argoproj.github.io/argo/access-token/))

```shell script
# Obtain access token from service account "workflow"
SECRET=$(kubectl -n n1 get sa workflow -o=jsonpath='{.secrets[0].name}')
ARGO_TOKEN="Bearer $(kubectl -n $NS1 get secret $SECRET -o=jsonpath='{.data.token}' | base64 --decode)"

# OR

ARGO_TOKEN=$(argo auth token)

# using UI, open http://35.202.107.80, and logon

# using API
curl -v -H "Authorization: $ARGO_TOKEN" -H "Host: argo.server"  http://35.202.107.80/api/v1/workflows/argo
```


### ArgoCD Application manifest
In `argo-app/templates/application.yaml`, it configures the default for each Argo CD application. Make sure you are working
on the desired `targetRevision`, i.e., github development branch.

```yaml
# argo-app/templates/application.yaml
project: my-project
targetRevision: dev-0.1
repoURL: git@github.com:rtang03/fabric-cd.git
server: https://kubernetes.default.svc
ns: n1
path: orgadmin
rel: admin1
file: values-admin1.yaml
```

You need not edit this templated file directly; you should override its values via cli, shown later.

### Secrets file
Credentials, secrets, and passwords are re-located to `secrets.*.yaml`, in corresponding Helm chart directories. For example,
see `orgadmin/secrets.admin1-example.yaml`, `tlsca_caadmin` must be a base64 encoded value, and created as k8s Secret resource.

```shell script
# encode ==> dGxzY2ExLWFkbWluCg==
echo -n 'tlsca1-admin' | base64

# decode => tlsca1-admin
echo -n 'dGxzY2ExLWFkbWluCg==' | base64 -d
```

`orgadmin/secrets.admin1-example.yaml` is an encoded yaml. You copy its file content into `orgadmin/secrets.admin1.yaml`;
and then run below command to perform sops encryption. `-i` means in-place replacement; the previous unencrypted/encoded
yaml will be replaced. Repeat the same steps for every `secrets.*.yaml`. The yaml property ending with "_unencrypted" will skip encryption.

```shell script
# encrypt
sops -e -i orgadmin/secrets.admin1.yaml

# decrypt
sops -d orgadmin/secrets.admin1.yaml
```


### Bootstrapping
*IMPORTANT NOTE*
1. Make sure the gcs storage `workflow/` and its sub-directory are empty. The workflows in `bootstrap.argo.sh` will output artifacts to `fabric-cd-dev` bucket. The non-empty paths will fail the workflow.
1. ensure no running applications `./uninstall.argo.sh`
1. ensure the empty PVC is ready, run `./recreate-pvc.sh org1`

```shell script
bootstrap.argo.org1.sh
bootstrap.argo.orgx.sh
```


```shell script
# Optional: remove all deployments via ArgoCD. This command is often used for CD development.
./uninstall.argo.sh

# Optional: remove existing pvc, and recreate new ones. This command is often used for CD development.
./recreate-pvc.sh org1
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


### Clean-up
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


### Useful commands
```shell script
# list GPG keys
gpg --list-secret-keys --keyid-format LONG

# Retrive PGP Private key from local machine, assuming gpg suite is used
gpg --export-secret-keys --armor 33DBB14071110A8F093B29E7D95D3BE9260E76EA

# sops encryption command, -i means in-place replacement
sops -e -i --gcp-kms projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key test.yaml

# out argo workflow manifest for debugging
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --server-dry-run --output yaml

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

### Naming convention
*Helm chart value file*
[release name]-[app name].[cloud].yaml => admin0-orgadmin.gcp.yaml


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
