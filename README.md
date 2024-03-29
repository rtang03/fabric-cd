# Continuous Deployment
GitOps Continuous deployment for *fabric-es* and its projects.


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

### 1. Prepare secrets file
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

### 2. Install fabric-network - org0 and org1

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
./bootstrap.org1.sh
```

The successful deployment should show:

```text
Name:                bootstrap-channel-org1
Namespace:           n1
ServiceAccount:      workflow
Status:              Succeeded
Conditions:
 Completed           True
Created:             Tue Dec 22 14:11:15 +0800 (5 minutes ago)
Started:             Tue Dec 22 14:11:15 +0800 (5 minutes ago)
Finished:            Tue Dec 22 14:16:22 +0800 (now)
Duration:            5 minutes 7 seconds
ResourcesDuration:   10m54s*(1 cpu),10m54s*(100Mi memory)

STEP                              TEMPLATE                                DURATION
 ✔ bootstrap-channel-org1         main
 ├-·-✔ sync-g1                    argocd-cli/argocd-app-sync              1m
 | └-✔ sync-p0o1                  argocd-cli/argocd-app-sync              1m
 ├---✔ dl-create-tlscacert        download-and-create-secret/main
 |   ├---✔ retrieve               retrieve-tmpl                           6s
 |   ├---✔ delete-secret-tmpl     secret-resource/delete-secret-tmpl      1s
 |   └---✔ create-secret-tmpl     secret-resource/create-secret-1key-tmpl 2s
 ├---✔ create-channel(0)          create-channel/main                     11s
 ├---✔ join-channel(0)            join-channel/main                       20s
 ├---✔ update-anchor-peer         update-anchor-peer/main                 18s
 ├---✔ package-install-chaincode  package-install-chaincode/main          13s
 ├---✔ chaincode-id-resource      chaincode-id-resource/main
 |   ├---✔ delete-ccid            delete-ccid                             2s
 |   └---✔ create-ccid            create-ccid                             2s
 ├---✔ sync-chaincode             argocd-cli/argocd-app-sync              1m
 ├---✔ approve-chaincode          approve-chaincode/main                  11s
 ├---✔ commit-chaincode           commit-chaincode/main                   13s
 └---✔ smoke-test(0)              smoke-test/main                         21s
```

### 3. Install fabric-network - org2

```shell
# Bootstrap Org2
./bootstrap.orgx.sh org2
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


### 4. Install redis, auth-server, gw-orgX, ui-control - org0 and org1

**Create tls secret to enable secure istio gateway**

For org1, both *ui-control* and *gw-org* are required to expose to public internet. Here utilizes the secure gateway of
istio (see [istio v1.6 doc](https://istio.io/v1.6/docs/tasks/traffic-management/ingress/secure-ingress/)). As below code,
`https://web.org1.net` is exposed, and requiring the secret `peer0.org1.net-tls`.

```yaml
# networking/istio-n1.yaml
- port:
    number: 443
    name: https
    protocol: HTTPS
  tls:
    mode: SIMPLE
    credentialName: "peer0.org1.net-tls"
  hosts:
    - "web.org1.net"
    - "gw.org1.net"
```

```shell
# delete existing tls cert
kubectl -n istio-system delete secret peer0.org1.net-tls

# retrieve tls cert from org1
CERT="$(kubectl -n n1 get secret peer0.org1.net-tls -o=jsonpath='{.data.tls\.crt}' | base64 --decode)"
KEY="$(kubectl -n n1 get secret peer0.org1.net-tls -o=jsonpath='{.data.tls\.key}' | base64 --decode)"

# create tls cert for Istio secure gateway
kubectl -n istio-system create secret generic peer0.org1.net-tls --from-literal=tls.crt="$CERT" --from-literal=tls.key="$KEY"

# Debugging step
kubectl logs -n istio-system "$(kubectl get pod -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].metadata.name}')"
# should return
# 2020-12-22T08:23:04.850277Z	info	Channel Connectivity change to READY
# 2020-12-22T08:45:28.961386Z	info	sds	resource:peer0.org1.net-tls pushed key/cert pair to proxy
# 2020-12-22T08:45:28.961426Z	info	sds	Dynamic push for secret peer0.org1.net-tls
```
**Synchronize apps**

```shell
argo submit -n n1 workflow/aoa-sync-re-au-gw-ui.n1.yaml --watch --request-timeout 900s
```

It should return:

```text
Name:                aoa-sync-gw-org1
Namespace:           n1
ServiceAccount:      workflow
Status:              Succeeded
Conditions:
 Completed           True
Created:             Tue Dec 22 14:39:24 +0800 (8 minutes ago)
Started:             Tue Dec 22 14:39:24 +0800 (8 minutes ago)
Finished:            Tue Dec 22 14:48:03 +0800 (now)
Duration:            8 minutes 39 seconds
ResourcesDuration:   16m57s*(1 cpu),16m57s*(100Mi memory)

STEP                 TEMPLATE                    PODNAME                      DURATION  MESSAGE
 ✔ aoa-sync-gw-org1  main
 ├---✔ sync-redis1   argocd-cli/argocd-app-sync  aoa-sync-gw-org1-3775298967  1m
 ├---✔ sync-auth1    argocd-cli/argocd-app-sync  aoa-sync-gw-org1-3067430853  1m
 ├---✔ sync-gw-org1  argocd-cli/argocd-app-sync  aoa-sync-gw-org1-1951236881  3m
 └---✔ sync-ui-org1  argocd-cli/argocd-app-sync  aoa-sync-gw-org1-2916683662  2m
```


### Tear-down
```shell script
cd scripts

./uninstall.argo.sh

./recreate-pvc.sh org1

./recreate-pvc.sh org2
```

Lastly, remove the 'fabric-cd-dev' storage bucket.




### For gitOps Contributors
Please see [DEVELOPMENT](https://github.com/rtang03/fabric-cd/doc/DEVELOPMENT.md)

