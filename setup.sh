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
