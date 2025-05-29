#!/bin/bash

CONFIG=$1
if [ -z "$CONFIG" ]; then
  echo "Usage: $0 <config>"
  exit 1
fi

NS="triton-ns"

# Get the pod name
POD=$(kubectl get pods -n $NS -l app=triton-perf-analyzer -o jsonpath='{.items[0].metadata.name}')

# Define endpoints
ENDPOINTS=("cpu-x86-intel" "cpu-x86-amd" "cpu-arm-graviton" "gpu-g-nvidia")

# Run perf_analyzer for each endpoint in parallel
for endpoint in "${ENDPOINTS[@]}"; do
  kubectl exec $POD -n $NS -- perf_analyzer -m bert-large-uncased -u "triton-${endpoint}-service:8000" \
    --input-data zero \
    --shape input_ids:512 \
    --shape attention_mask:512 \
    --shape token_type_ids:512 \
    --concurrency-range 1:25:3 \
    --measurement-mode "time_windows" \
    --measurement-interval 20000 \
    --request-distribution "poisson" >> "perf_analyzer_${CONFIG}_triton-${endpoint}.log" 2>&1 &
done

# Wait for all background processes to complete
wait

echo "All performance tests completed"

# kubectl exec -n triton-ns $(kubectl get pods -n triton-ns -l app=triton-perf-analyzer -o jsonpath='{.items[0].metadata.name}') -- perf_analyzer -m bert-large-uncased -u "triton-gpu-g-nvidia-service:8000" --input-data zero --shape input_ids:512 --shape attention_mask:512 --shape token_type_ids:512 --measurement-mode "time_windows" --request-distribution "poisson" --measurement-interval 10000 --concurrency-range 1:100:5
