## Argo CD & Workflow
Below are instruction for the deployment with Argo CD and Argo Workflow

### Argo CD Installation on GKE
```shell script
# https://argoproj.github.io/argo-cd/getting_started/
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

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
[argocd api spec](https://github.com/argoproj/argo/blob/master/api/openapi-spec/swagger.json)
[helm chart for installing argo](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd)
[docker image with helm and gke](https://hub.docker.com/r/devth/helm)


git config --global commit.gpgsign true
