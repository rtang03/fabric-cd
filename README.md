# Continuous Deployment
GitOps Continuous deployment for *fabric-es* and its projects.

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
