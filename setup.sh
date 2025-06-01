#!/bin/bash -e

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"

kind create cluster --config cluster.yaml
echo "Waiting for cluster to become ready, this may take up to 5m0s ..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

helm -n minio install \
	-f minio/values.yaml \
	minio \
	oci://registry-1.docker.io/bitnamicharts/minio \
	--version 16.0.10 \
	--create-namespace
echo "Waiting for MinIO to become available, this may take up to 5m0s ..."
kubectl -n minio wait --for=condition=Available deploy --all --timeout=300s
kubectl apply -k minio/
echo "Waiting for bucket and data to be available, this may take up to 5m0s ..."
kubectl -n minio wait --for=condition=Complete jobs --all --timeout=300s

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm -n argo install \
	-f argo-workflows/values.yaml \
	argo-workflows \
	argo/argo-workflows \
	--version 0.45.15 \
	--create-namespace
echo "Waiting for Argo Workflows controller and server to be available, this may take up to 5m0s ..."
kubectl -n argo wait --for=condition=Available deploy --all --timeout=300s
kubectl -n argo create -f argo-workflows/workflowtemplates.yaml
echo "Waiting for 5s ..."
sleep 5
kubectl -n argo create -f argo-workflows/workflows.yaml
echo "Waiting for workflow to complete, this may take up to 5m0s ..."
kubectl -n argo wait --for=condition=Completed workflows.argoproj.io --all --timeout=300s
