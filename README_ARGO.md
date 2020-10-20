## Argo CD & Workflow
Below are instruction for the deployment with Argo CD and Argo Workflow

### KMS Preparation
```shell script
gcloud auth application-default login
gcloud kms keyrings create sops --location us-central1
gcloud kms keys create sops-key --location us-central1 --keyring fdi --purpose encryption
gcloud kms keys list --location us-central1 --keyring fdi

# install helm-secret + sops
helm plugin install https://github.com/zendesk/helm-secrets

# update .sops.yaml with gcp kms resource id
# example sops command
# sops -e -i -p 33DBB14071110A8F093B29E7D95D3BE9260E76EA hlf-ca/secrets.yaml
# sops -e -i hlf-ca/secrets.yaml
# sops -d -i hlf-ca/secrets.yaml

# Suggest to use helm-secret, instead of sops directly
helm secrets enc hlf-ca/secrets.yaml

# decrypt
helm secrets dec hlf-ca/secrets.yaml

gpg --export-secret-keys --armor 33DBB14071110A8F093B29E7D95D3BE9260E76EA
```

### Github Preparation
Here assumes the connection to Github is via ssh; and every commit is gpg signed.

- Add ssh key in Github.com
- Add gpg key in Github.com

```shell script
# enable project level commit signing
# git config --global commit.gpgsign false
git config commit.gpgsign true
```


### Argo CD Installation on GKE
```shell script
# https://argoproj.github.io/argo-cd/getting_started/
kubectl create namespace argocd

# Option 1: Quick install
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Option 2: ArgoCD install with helm (Preferred)
helm repo add argo https://argoproj.github.io/argo-helm
helm -n argocd install argocd-sops -f argocd/values-argocd.yaml argo/argo-cd

# install argocd cli locally on macos
brew install argocd

# configure argocd
kubectl -n argocd apply -f ./argocd/project.yaml
kubectl -n argocd apply -f ./argocd/argocd-cm.yaml

# adopt port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# initial password
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2

# change initial password
# see https://argoproj.github.io/argo-cd/getting_started/

```

If running on GKE,
```shell script
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
```

```shell script
# open browswer http://localhost:8080/settings/repos

argocd repo add git@github.com:rtang03/fabric-cd.git --insecure-ignore-host-key --ssh-private-key-path ~/.ssh/id_rsa
```

### Argo Workflow Installation on GKE
```shell script
# see https://argoproj.github.io/argo/installation/
kubectl create ns argo

# Note: We choose to use "cluster-install"
# TODO: need to revisit how to customize the Argo workflow installation.
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo/stable/manifests/quick-start-postgres.yaml

or

kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo/stable/manifests/install.yaml

# create service account for each application namespace
kubectl -n n0 apply -f ./argocd/service-account.yaml
kubectl -n n1 apply -f ./argocd/service-account.yaml

# adopt port-forward
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

### Installation
```shell script
./recreate-pvc.sh org1

```

###

### Reference Information
- [argocd api spec](https://github.com/argoproj/argo/blob/master/api/openapi-spec/swagger.json)
- [helm chart for installing argo](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd)
- [docker image with helm and gke](https://hub.docker.com/r/devth/helm)
- [sops](https://github.com/mozilla/sops#test-with-the-dev-pgp-key)
- [helm-secrets plugin](https://github.com/zendesk/helm-secrets)
- [custom argocd image](https://medium.com/faun/handling-kubernetes-secrets-with-argocd-and-sops-650df91de173)
https://cloud.google.com/kms/docs/iam

https://github.com/camptocamp/docker-argocd
