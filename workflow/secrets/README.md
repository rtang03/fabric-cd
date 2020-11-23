### Helm chart for loading cert and key
- Retrieve the cert and key files from the mounted pvc in batch
- Delete pre-existing Secret resource
- Create Secret resource

For a single organization, this workflow is part of the initial network setup steps. AFTER all CAs are up-and-running,
AND crypto-material are created on the pvc. It will create Secret within the same namespace.
