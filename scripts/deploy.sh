#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_TAG:?set IMAGE_TAG to the app image tag in ECR}"
cd "$(dirname "$0")/.."

CLUSTER=eks-platform
REGION=us-east-1

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" > /dev/null

helm repo add eks https://aws.github.io/eks-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ > /dev/null
helm repo update > /dev/null

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query cluster.resourcesVpcConfig.vpcId --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 3.6.3 -n kube-system \
  --set clusterName="$CLUSTER" --set region="$REGION" --set vpcId="$VPC_ID" \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait --timeout 3m

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version 93.6.0 -n monitoring --create-namespace \
  -f k8s/monitoring/kube-prometheus-stack-values.yaml --wait --timeout 10m

helm upgrade --install metrics-server metrics-server/metrics-server \
  --version 3.14.0 -n kube-system --wait --timeout 3m

REG=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com
MYCIDR="$(curl -s https://checkip.amazonaws.com)/32"
[[ "$MYCIDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/32$ ]] || { echo "could not detect my IP" >&2; exit 1; }

sed -e "s|IMAGE|$REG/eks-platform-app:$IMAGE_TAG|" -e "s|MYCIDR|$MYCIDR|" k8s/app.yaml | kubectl apply -f -
kubectl apply -f k8s/app-servicemonitor.yaml -f k8s/hpa.yaml

kubectl -n monitoring create configmap app-dashboard --from-file=k8s/monitoring/app-dashboard.json --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -

until [ -n "$(kubectl get ingress app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')" ]; do sleep 10; done
echo "ALB address is ready"
