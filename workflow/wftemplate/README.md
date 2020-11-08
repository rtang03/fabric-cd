## Helm Chart for generate WorkflowTemplate and ClusterWorkflowTemplate

```shell script
# Deploy WorkflowTemplate
helm template workflow/wftemplate | argo -n n1 template create -
```

### ClusterWorkflowTemplate

**secret-resource**

1. Delete secret
1. Create secret (one key)

**retrieve-from-http**

1. Retrieve file from url
1. Save it to mounted pvc

**create-secret-from-file**

1. Retrieve file content from mounted file system
1. Delete pre-existing secret
1. Create secret

### WorkflowTemplate

**gupload-download-file**

1. Gupload download a file
1. Save it to mounted pvc


