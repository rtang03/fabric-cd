# Continuous Deployment
GitOps Continuous deployment for *fabric-es* and its projects.

- **o0** http://argocd.server/api/badge?name=o0&revision=true

(This page is under construction).
```text
Dear Everyone,

All steps are not future-proof, any change may break. It works, maybe I don't know how it works.

Take your own risk  🎃
```

### Availble Application
- gupload: grpc file uploader
- hlf-ca: Hyperledger Fabric Certificate Authority
- hlf-couchdb: CouchDB
- hlf-ord: Hyperledger Fabric Orderer
- hlf-peer: Hyperledger Fabric Peer
- hlf-cc: Hyperledger Fabric Chaincode
- hlf-operator: administrative tasks via k8s jobs
- orgadmin: administrative cli
- argo-app: ArgoCD application manifest

`hlf-operator` involves below list of k8s jobs
- *bootstrap*: (a) multiples step to install `org1`; and (b) `orgX` Note that `orgX` has few steps than `org1`
- *fetch*: fetch block by `org1`, and then `gupload` to `orgX`
- *joinchannel*: join channel by `orgX`
- *neworg*: create new configtx.yaml of `orgX`, and then `gupload` to `org1`
- *updatechannel*: `org1` update channel with `orgX`'s channel-update-envelope

### INSTRUCTIONS

**Update Host Alias in values files**
In GCP, istio is in-cluster deployment, newly created GKE cluster will have different istio gateway ip address.
Every newly created cluster, you need to update host alias in values files.

```shell script
# obtain ingressgateway ip address
kubectl -n istio-system get svc | grep ingressgateway
```

Update ip address of below values files:
- hlf-peer/values-p0o1.yaml
- hlf-peer/values-p0o2.yaml
- hlf-ord/values-o0.yaml
- hlf-ord/values-o1.yaml
- hlf-ord/values-o2.yaml
- hlf-ord/values-o3.yaml
- hlf-ord/values-o4.yaml
- workflow/bootstrap/values.yaml

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

### Naming Convention
See `./scripts/env.org2.sh`

```shell script
## Org0
DOMAIN0=org0.com
MSPID0=Org0MSP
NS0=n0
ORG0=org0
REL_O0=o0
REL_O1=o1
REL_O2=o2
REL_O3=o3
REL_O4=o4
REL_ORGADMIN0=admin0
REL_RCA0=rca0
REL_TLSCA0=tlsca0
TLSCACERT0=org0.com-tlscacert

## Org1
DOMAIN1=org1.net
MSPID1=Org1MSP
NS1=n1
ORG1=org1
JOB_BOOTSTRAP_A=b1
JOB_BOOTSTRAP_B=b2
JOB_FETCH_BLOCK=fetch1
JOB_UPDATE_CHANNEL=upch1
REL_GUPLOAD=g1
REL_ORGADMIN1=admin1
REL_PEER=p0o1
REL_RCA1=rca1
REL_TLSCA1=tlsca1
PEER=peer0.org1.net
TLSCACERT1=org1.net-tlscacert
```

**Argo CD application manifest**
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


### Initial Network Bootstrapping for DEV
For the setup of org0 and org1, use `bootstrap.argo.org1.sh` script.

**Checklist**
Below running bootstrapping the initial network from scratch:
1. Go to GCP web UI; make sure the *gcs storage* `workflow/secrets` and `workflow/genesis` are both empty.
The workflows in `bootstrap.argo.sh` will output artifacts to `fabric-cd-dev` storage bucket. The non-empty
paths will give the workflow error when outputing artifacts.
1. Go to argocd web UI, make sure no running applications. If neccessary, run `uninstall.argo.sh` under `scripts` directory.
1. If `uninstall.argo.sh` is run, also run `./recreate-pvc.sh org1` to recreate the pvc. Repeat the same for `org2`.
1. Make the *argo* and *argocd*'s port forwarding is live.

**REMARK**: while the tls of *argo* and *argocd* web server is not ready, the installation script will require port-forwarding.
Future enhancment will replace port-forwaring with API servers.

**Install org0 and org1**
The run may take 20 ~ 30 minutes. In addition to CLI, you may also use GKE dashboard, *argocd* and *argo* web UI to monitor the live
status.

```shell script
cd scripts
bootstrap.argo.org1.sh
```

**Post installation step**
1. Go to [GCS Storage UI](https://console.cloud.google.com/storage/browser/fabric-cd-dev/workflow/secrets/n1/org1.net-tlscacert), to make org1.net *tlscacert.pem* PUBLIC.
The public link should be https://storage.googleapis.com/fabric-cd-dev/workflow/secrets/n1/org1.net-tlscacert/tlscacert.pem
1. Repeat the same step for orderer0.org0.com *tlscacert.pem*
