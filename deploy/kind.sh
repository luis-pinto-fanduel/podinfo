#! /usr/bin/env sh

mkdir -p bin
cat > ./bin/kind.yaml <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
#name: dev
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
EOF

# create the kind cluster
kind create cluster --config=./bin/kind.yaml

# NGINX Ingress installation might differ for your k8s provider
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
# wait for ingress
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=2m
  
#kubectl rollout status --namespace ingress-nginx deployment.apps/ingress-nginx-controller --timeout=2m

# add certificate manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# wait for cert manager
kubectl rollout status --namespace cert-manager deployment/cert-manager --timeout=2m
kubectl rollout status --namespace cert-manager deployment/cert-manager-webhook --timeout=2m
kubectl rollout status --namespace cert-manager deployment/cert-manager-cainjector --timeout=2m

# # apply the secure webapp
kubectl apply -f ./secure/common
kubectl apply -f ./secure/backend
kubectl apply -f ./secure/frontend

# # wait for the podinfo frontend to come up
kubectl rollout status --namespace secure deployment/frontend --timeout=1m

# apply ingress rule for frontend
#kubectl apply -f ./secure/ingress/ingress.yaml

# curl the endpoints (responds with info due to header regexp on route handler)
echo
echo "http enpdoint:"
echo "curl http://localhost"
echo
curl http://localhost

echo
echo "https (secure) enpdoint:"
echo "curl --insecure https://localhost"
echo
curl --insecure https://localhost

# kubectl scale --replicas=2 deployment frontend
# kubectl describe pods ${POD_NAME} 
# kubectl get endpoints ${SERVICE_NAME}