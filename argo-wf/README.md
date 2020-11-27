###  Helm Chart for generate WorkflowTemplate

This is first step of bootstraping script. It needs to deploy *Argo* workflowTemplates, prior to any other deployment.
The bootstraping script will execute below. The **TARGET** is the targeted branch.

```shell script
# Deploy WorkflowTemplate
helm template ../argo-app --set ns=$NS0,path=argo-wf,target=$TARGET,rel=argo-template-$ORG0,file=values-$ORG0.yaml | argocd app create -f -

# OR

helm template ../argo-app --set ns=n1,path=argo-wf,target=dev-0.2,rel=argo-template-org0,file=values-org0.yaml | argocd app create -f -
```

**List of Templates**

- *secret-resource*: operations for k8s secret resource
- *approve-chaincode*
- *argocd-app-sync*: download ArgoCD cli, and then run "argocd app sync"
- *chaincode-id-resource*: delete/create chaincodeid (a.k.a package-id) after chaincode instalation
- *commit-chaincode*
- *create-channel*
- *curl-event*: run curl to submit *Argo* Event
- *download-and-create-secret*: (http) download TLS root cert and create secret, with key "tlscacert.pem"
- *fetch-upload*: (1) fetch channel config from orderer; (2) (grpc) upload to remote gupload server
- *gupload-up-file*: use "gupload cli" to (grpc) upload a single file to remote gupload server
- *join-channel*: join channel at org1
- *join-channel-orgx*:
- *neworg-config-update*: (1) create channel update block; (2) (grpc) upload to org1's gupload server
- *package-install-chaincode*: after chaincode installation, will output "package-id"
- *smoke-test*
- *update-anchor-peer*
- *update-channle*
