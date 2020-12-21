## INSTRUCTION FOR USING NEW GKE

### Install GKE v1.18
```shell
gcloud beta container --project "fdi-cd" clusters create "dev-core-b" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.18.12-gke.1200" --release-channel "rapid" --machine-type "n1-standard-4" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/cloud-platform" --preemptible --num-nodes "1" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/fdi-cd/global/networks/fdi-core" --subnetwork "projects/fdi-cd/regions/us-central1/subnetworks/org0msp" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,Istio --istio-config auth=MTLS_PERMISSIVE --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --no-shielded-integrity-monitoring
```

### Upgrade from v1.14 to v1.16
See https://cloud.google.com/istio/docs/istio-on-gke/upgrade-with-operator
