# fabric-cd
continuous deployment


https://stackoverflow.com/questions/54670170/how-to-override-the-istio-proxy-option-in-the-app-deployment

kubectl -n istio-system get configmap istio-sidecar-injector-istio-164 -o=jsonpath='{.data.config}' > inject-config.yaml
kubectl -n istio-system get configmap istio-istio-164 -o=jsonpath='{.data.mesh}' > mesh-config.yaml
kubectl -n istio-system get configmap istio-sidecar-injector-istio-164 -o=jsonpath='{.data.values}' > inject-values.yaml

kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.config}' > inject-config.yaml
kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.values}' > inject-values.yaml
kubectl -n istio-system get configmap istio -o=jsonpath='{.data.mesh}' > mesh-config.yaml

istioctl kube-inject --injectConfigFile inject-config.yaml --meshConfigFile mesh-config.yaml --valuesFile inject-values.yaml \
    --filename deployment.yaml -o deployment-injected.yaml

https://istio.io/latest/docs/setup/platform-setup/gke/

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
gcloud container clusters get-credentials dev-core-a --zone us-central1-c

kubectl create namespace n0
kubectl create namespace n1
kubectl label namespace n0 istio-injection=enabled
kubectl label namespace n1 istio-injection=enabled

curl -d '{"spec":"grpc=debug:debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec
curl -d '{"spec":"debug"}' -H "Content-Type: application/json" -X PUT http://127.0.0.1:8443/logspec
