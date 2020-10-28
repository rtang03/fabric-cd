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
All CD charts development and ArgoCD development should happen at [dev-0.0.1]-a. It should perform pull request
FROM [dev-0.0.1]-a ---> [dev-0.0.1]

*Deployment*
- ArgoCD server will pull changes from [dev-0.0.1] for DEV deployment.
- ArgoCD server will pull changes from [prod-0.0.1] for PROD deployment.

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
helm -n argocd install argocd -f argocd/values-argocd.yaml -f argocd/values-argocd.key.yaml argo/argo-cd

# WAIT
kubectl wait --for=condition=Ready --timeout 180s pod/$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2) -n argocd

# INSTALL CLI ON MAC
brew install argocd

# CONFIGURE
kubectl -n argocd apply -f ./argocd/project.yaml
kubectl -n argocd apply -f ./argocd/argocd-cm.yaml

# PORT-FORWARD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# AUTHENTICATE
POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
argocd login localhost:8080 --insecure --username admin --password $POD
argocd account update-password --current-password $POD --new-password password

# Argocd connect to github with ssh key. Private key of github ssh login is located at `.ssh/id_rsa`
# Note that this will modify argcd-cm configmap. Hence, after each time 'kubectl -n argocd apply -f ./argocd/argocd-cm.yaml'
# below add-repo needs rerun
argocd repo add git@github.com:rtang03/fabric-cd.git --insecure-ignore-host-key --ssh-private-key-path ~/.ssh/id_rsa

# IF RUNNING GKE, need cluster-admin
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
```

To validate installation, open browswer `http://localhost:8080`

### Argo Workflow Installation on GKE
```shell script
# CREATE DEFAULT NS
kubectl create ns argo

# Note: We choose to use "cluster-install"
# TODO: need to revisit how to customize the Argo workflow installation.
# Seems to namespace scope
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo/stable/manifests/quick-start-postgres.yaml


# ClusterScope
# kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo/stable/manifests/install.yaml

# CREATE SERVICE ACCOUNT (for each application namespace)
kubectl -n n0 apply -f ./argocd/service-account.yaml
kubectl -n n1 apply -f ./argocd/service-account.yaml

# configure artifact repo
kubectl -n argo apply -f ./argocd/argo-cm.yaml

# PORT-FORWARD
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

### ArgoCD Application manifest
In `argo-app/templates/application.yaml`, it configures the default for each Argo CD application. Make sure you are working
on the desired `targetRevision`, i.e., github development branch.

```yaml
# argo-app/templates/application.yaml
project: my-project
targetRevision: dev-0.0.1-a
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
See `bootstrap.argo.sh`


```shell script
# Optional: remove all deployments via ArgoCD. This command is often used for CD development.
./uninstall.argo.sh org1

# Optional: remove existing pvc, and recreate new ones. This command is often used for CD development.
./recreate-pvc.sh org1
```


### Useful commands
```shell script
# list GPG keys
gpg --list-secret-keys --keyid-format LONG

# Retrive PGP Private key from local machine, assuming gpg suite is used
gpg --export-secret-keys --armor 33DBB14071110A8F093B29E7D95D3BE9260E76EA

# sops encryption command, -i means in-place replacement
sops -e -i --gcp-kms projects/fdi-cd/locations/us-central1/keyRings/fdi/cryptoKeys/sops-key test.yaml
```

### Reference Information
- [Argo CD getting started](https://argoproj.github.io/argo-cd/getting_started/)
- [Argo CD default install manifest](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)
- [Argo CD api spec](https://github.com/argoproj/argo/blob/master/api/openapi-spec/swagger.json)
- [Argo Workflow installation](https://argoproj.github.io/argo/installation/)
- [helm chart for installing argo](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd)
- [Docker image with helm and gcloud](https://hub.docker.com/r/devth/helm)
- [sops](https://github.com/mozilla/sops#test-with-the-dev-pgp-key)
- [helm-secrets plugin](https://github.com/zendesk/helm-secrets)
- [How to prepare custom argocd image](https://medium.com/faun/handling-kubernetes-secrets-with-argocd-and-sops-650df91de173)
- [Setup IAM for kms](https://cloud.google.com/kms/docs/iam)
- [GKE permission and role](https://cloud.google.com/kms/docs/reference/permissions-and-roles)

echo -n 'admin' | base64
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 lint
helm template workflow/cryptogen -f workflow/cryptogen/values-$REL_RCA1.yaml | argo -n $NS1 submit - --server-dry-run --output yaml
