ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

set -x

K8S_ROOT=$ROOT/k8s

WORLD_SIZE=7

kubectl delete --force -f $K8S_ROOT/nccl-tests/nccl-test-distributed-h100-8x8-master.yaml
kubectl delete --force -f $K8S_ROOT/nccl-tests/nccl-test-distributed-h100-8x8-workers.yaml

kubectl delete --force pod nccl-test-distributed-h100-8x8-master-0
for i in $(seq $((WORLD_SIZE - 1))); do
  kubectl delete --force pod nccl-test-distributed-h100-8x8-worker-${i}
done

kubectl get pods

sleep 10

# start jobs
# kubectl apply --force -f $K8S_ROOT/nccl-tests/nccl-test-distributed-h100-8x8-master.yaml
# kubectl apply --force -f $K8S_ROOT/nccl-tests/nccl-test-distributed-h100-8x8-workers.yaml
