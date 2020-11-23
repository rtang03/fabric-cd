# Continuous Deployment
GitOps Continuous deployment for *fabric-es* and its projects.

(This page is under construction).
```text
Dear Everyone,

All steps are not future-proof, any change may break. It works, maybe I don't know how it works.

Take your own risk  🎃
```

### Directory Structure
**CD Application**
- app-of-app: ArgoCD application-of-application helm chart
- argo-app: ArgoCD application helm chart
- argo-wf: Argo WorkflowTemplate helm chart
- argocd: Deployment manifests for *ArgoCD* server

**Hyperledger Application**
- chaincode: for building chaincode docker image
- gupload: grpc file uploader helm chart
- hlf-ca: Hyperledger Fabric CA server helm chart
- hlf-cc: Hyperledger Fabric Chaincode helm chart
- hlf-ord: Hyperledger Fabric Orderer helm chart
- hlf-peer: Hyperledger Fabric Peer helm chart
- networking: Istio manifests
- orgadmin: cli for organization administrator
- workflow: Argo Workflow manifest for first-time bootraping

### Usable Release: dev-0.1
Quickstart deployment

- Target branch: `dev-0.1`
- Topology: 2-org;1-peer Fabric-only (org0/org1/org2)
- namespace: n0/n1/n2
- Configtx: Standard
- GCP project: fdi-cd
- GKE: dev-core-b
- GCS bucket: fabric-cd-dev
- GCP KMS: projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key

**Requirements**

- All applications are deployed to project *fdi-cd* of GKE account *hktfp.5.gmail.com*.
- All `secrets.*.yaml` are encrypted with GCP KMS key *sops-key* of keyring *fdi*. Encrypt/decrypt are made via service accounts.
- *rtang03* is only deployer. All ArgoCD application deployment and synchronization requires github SSH key of *rtang03*.

**List of deployment manifest**

- argo/*
- argocd/*
- networking/*
- workflow/*
- scripts/env.*.sh

**List of application value files**

- .sops.yaml and */.sops.yaml
- app-of-app/values-*.yaml
- argo-wf/values-*.yaml
- gupload/values-*.yaml
- hlf-ca/values-*.yaml
- hlf-ca/secrets.*.yaml
- hlf-cc/values-*.yaml
- hlf-ord/values-*.yaml
- hlf-peer/values-*.yaml
- orgadmin/secrets.*.yaml
- orgadmin/values-*.yaml

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


### Getting Started: first-time network setup

**Checklist**:

1. MUST READ [DEVELOPMENT](https://github.com/rtang03/fabric-cd/doc/DEVELOPMENT.md)
1. *GKE* cluster creation
1. *Argo* and *ArgoCD* installation on GKE in-cluster
1. GCP Cloud DNS, KMS, Storage setup
1. Remove pre-existing GCS storage bucket `fabric-cd-dev`. The workflows output artifacts to bucket. The non-empty paths will give error when outputing.

In local machine:
- login with *gcloud*, installed with *kubectl*, *gsutil* cli
- install SOPS, *Argo* and *ArgoCD* CLI
- activate *Argo* and *ArgoCD* port-forwarding
- update `/etc/hosts` to point to *Argo* and *ArgoCD*, the IP comes from Istio gateway

```text
# /etc/hosts
35.202.107.80 argocd.server
35.202.107.80 argo.server
```

**Install org0 and org1**

The run may take 30+ minutes. In addition to CLI, you may also use GKE dashboard, *argocd* and *argo* web UI to monitor the live
status.

```shell script
cd scripts

# Optionally, if there is running application from previous installation
# this will uninstall all ArgoCD applications and workflows in all namespace.
./uninstall.argo.sh

# First time setup, will remove pre-existing PVC for org0 and org1; and create new ones
# ALL DATA WILL BE REMOVED
./recreate-pvc.sh org1

# Similarly for org2
./recreate-pvc.sh org2

# Bootstrap Org0 and Org1
./bs.argo.org1.sh

# Bootstrap Org2
./bs.argo.orgx.sh org2
```

Successful deployment should show something below.
```shell script
Name:                bootstrap-ch-org2-mrzz8
Namespace:           n2
ServiceAccount:      workflow
Status:              Succeeded
Conditions:
 Completed           True
ResourcesDuration:   8m18s*(1 cpu),8m18s*(100Mi memory)

STEP                                  TEMPLATE                                  DURATION
 ✔ bootstrap-ch-org2-mrzz8            main
 ├-·-✔ load-org0tlscacert             download-and-create-secret/main
 | | ├---✔ retrieve                   retrieve-tmpl                             28s
 | | ├---✔ delete-secret-tmpl         secret-resource/delete-secret-tmpl        3s
 | | └---✔ create-secret-tmpl         secret-resource/create-secret-1key-tmpl   2s
 | ├-✔ load-org1tlscacert             download-and-create-secret/main
 | | ├---✔ retrieve                   retrieve-tmpl                             24s
 | | ├---✔ delete-secret-tmpl         secret-resource/delete-secret-tmpl        2s
 | | └---✔ create-secret-tmpl         secret-resource/create-secret-1key-tmpl   3s
 | └-✔ load-org2tlscacert             download-and-create-secret/main
 |   ├---✔ retrieve                   retrieve-tmpl                             26s
 |   ├---✔ delete-secret-tmpl         secret-resource/delete-secret-tmpl        4s
 |   └---✔ create-secret-tmpl         secret-resource/create-secret-1key-tmpl   2s
 ├---✔ delete-files                   gupload-up-file/delete-files-tmpl         5s
 ├---✔ curl-pull-tlscacert            curl-event/curl-tmpl                      4s
 ├-·-✔ sync-g2                        argocd-cli/argocd-app-sync                28s
 | └-✔ sync-p0o2                      argocd-cli/argocd-app-sync                1m
 ├---✔ curl-fetch-block               curl-event/curl-tmpl                      3s
 ├---✔ wait-1                         utility/sleep                             33s
 ├---✔ check-fetchconfig-log-exist    gupload-up-file/file-exist-and-no-error   5s
 ├---✔ neworg-config-update           neworg-config-update/main
 |   ├---✔ neworg                     neworg-tmpl                               23s
 |   └---✔ gupload                    gupload-up-file/upload-tmpl               7s
 ├---✔ curl-update-channel            curl-event/curl-tmpl                      3s
 ├---✔ wait-2                         utility/sleep                             33s
 ├---✔ check-updatechannel-log-exist  gupload-up-file/file-exist-and-no-error   4s
 ├---✔ join-channel-orgx              join-channel-orgx/main
 |   ├---✔ fetch-block                fetch-tmpl                                8s
 |   └---✔ join-channel               join-channel/main                         11s
 ├---✔ update-anchor-peer             update-anchor-peer/main                   19s
 ├---✔ package-install-chaincode      package-install-chaincode/main            15s
 ├---✔ chaincode-id-resource          chaincode-id-resource/main
 |   ├---✔ delete-ccid                delete-ccid                               2s
 |   └---✔ create-ccid                create-ccid                               2s
 ├---✔ sync-chaincode                 argocd-cli/argocd-app-sync                15s
 ├---✔ approve-chaincode              approve-chaincode/main                    13s
 └---✔ smoke-test                     smoke-test/main                           13s
```

### Tear-down
```shell script
cd scripts

./uninstall.argo.sh

./recreate-pvc.sh org1

./recreate-pvc.sh org2
```

Lastly, remove the 'fabric-cd-dev' storage bucket.


### Prepare secrets file
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


### For gitOps Contributors
Please see [DEVELOPMENT](https://github.com/rtang03/fabric-cd/doc/DEVELOPMENT.md)

