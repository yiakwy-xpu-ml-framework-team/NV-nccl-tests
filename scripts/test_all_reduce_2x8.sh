#!/usr/bin/bash

set -e
set -x

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

job_id=nccl_tests

mkdir -p "${ROOT}/log/mpi/${job_id}"

WORKER_SSH_PORT=${WORKER_SSH_PORT:-2222}
WORLD_SIZE=${WORLD_SIZE:-2}
MLP_WORKER_GPU=${MLP_WORKER_GPU:-8}

SSHD_PORT=$WORKER_SSH_PORT

set -x
# set -e

job_id=nccl_tests

mpi_setup() {

if [ "$RANK" -eq 0 ] ; then
  rm -r $ROOT/log/mpi/${job_id}
fi

# start ssh service
nohup /usr/sbin/sshd -p $WORKER_SSH_PORT -D &


# check
# echo | ssh-keygen -P ''
prefix=id_ed25519

echo "sleep 3 seconds to wait for sshd completion ..."
sleep 3

mkdir -p "${ROOT}/log/mpi/${job_id}"

this_ip=$(echo `hostname -i`)
# this_ip=$(echo `hostname`)
echo "$this_ip" > "${ROOT}/log/mpi/${job_id}/ip.${RANK}.txt"

# generate ssh key
# TODO(yiakwy)  : add timestamp checking
cat "/root/.ssh/$prefix.pub" > "${ROOT}/log/mpi/${job_id}/$prefix.${RANK}.txt"

while true; do
  sleep 1
  all_worker_uploaded=true
  for i in $(seq 0 $((WORLD_SIZE - 1))); do
    if [ ! -f "${ROOT}/log/mpi/${job_id}/$prefix.${i}.txt" ]; then
      all_worker_uploaded=false
      echo "ip.$i.txt IS  NOT uploaded."
      break
    else
      echo "ip.$i.txt is  uploaded."
    fi
  done

  for i in $(seq 0 $((WORLD_SIZE - 1))); do
    if [ ! -f "${ROOT}/log/mpi/${job_id}/ip.${i}.txt" ]; then
      all_worker_uploaded=false
      echo "$prefix.${i}.txt IS NOT uploaded."
    else
      echo "$prefix.${i}.txt is uploaded."
    fi
  done

  # stop checking
  if [ "$all_worker_uploaded" = true ]; then
    break
  fi
done

# writing all workers RSA keys to local authorized_keys
for i in $(seq 0 $((WORLD_SIZE - 1))); do
  read -r key < "${ROOT}/log/mpi/${job_id}/$prefix.${i}.txt"
  echo "${key}" >> "/root/.ssh/authorized_keys"
done

}

nccl_tests() {

NCCL_IB_HCA=${NCCL_IB_HCA:-mlx5_0,mlx5_3,mlx5_4,mlx5_5,mlx5_6,mlx5_9,mlx5_10,mlx5_11}
# 'ibp154s0'(tcp), 'ibp170s0f0'(tcp), 'ibp192s0'(tcp), 'ibp206s0'(tcp), 'ibp220s0'(tcp), 'ibp24s0'(tcp), 'ibp41s0f0'(tcp), 'ibp64s0'(tcp), 'ibp79s0'(tcp), 'ibp94s0'(tcp)
# NOTE(yiakwy) : see ib device and roce device mapping via ibdev2netdev
NCCL_SOCKET_IFNAME=ibp24s0,ibp41s0f0,ibp64s0,ibp79s0,ibp94s0,ibp154s0,ibp170s0f0,ibp192s0
UCX_NET_DEVICES=$NCCL_SOCKET_IFNAME
SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING=1
NCCL_COLLNET_ENABLE=1

# -x UCX_IB_PCI_RELAXED_ORDERING=on \
# -x UCX_NET_DEVICES=$UCX_NET_DEVICES \

# NOTE(yiakwy) : HKUST H800 SuperPod upto 16GB memory can used for mpi testing
mpirun --allow-run-as-root \
--oversubscribe \
-np 16 \
-hostfile "${ROOT}/log/mpi/${job_id}/mpi_hostfile" \
-mca plm_rsh_args "-p ${SSHD_PORT} -q -o StrictHostKeyChecking=no" \
-mca coll_hcoll_enable 0 \
-mca coll ^hcoll \
-x NCCL_IB_DISABLE=0 \
-x NCCL_IB_TC=136 \
-x NCCL_IB_SL=5 \
-x NCCL_IB_GID_INDEX=3 \
-x NCCL_IB_CUDA_SUPPORT=1 \
-x NCCL_IB_TIMEOUT=22 \
-x NCCL_IB_RETRY_CNT=3 \
-x NCCL_IB_PCI_RELAXED_ORDERING=1 \
-x NCCL_IB_HCA=$NCCL_IB_HCA \
-x NCCL_IB_QPS_PER_CONNECTION=2 \
-x NCCL_IB_SPLIT_DATA_ON_QPS=0 \
-x NCCL_SOCKET_IFNAME=$NCCL_SOCKET_IFNAME \
-x NCCL_COLLNET_ENABLE=$NCCL_COLLNET_ENABLE \
-x NCCL_ALGO=Ring \
-x NCCL_NET_GDR_READ=1 \
-x NCCL_DEBUG=DEBUG \
-x SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING=$SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING \
-x CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 \
-x CUDA_DEVICE_ORDER=PCI_BUS_ID \
-x LD_LIBRARY_PATH=/opt/hpcx/sharp/lib:$LD_LIBRARY_PATH \
-x PATH=$PATH \
$ROOT/build/all_reduce_perf -b 128M -e 16G -f 2 -g 1 -w 5 -n 20 &> "$ROOT/log/mpi/${job_id}/output_$RANK.log"

}


main() {

  mpi_setup "$@"

  echo "mpi setup completes."

if [ "$RANK" -eq 0 ]; then

  # generate mpi hostfile
  > "$ROOT/log/mpi/${job_id}/mpi_hostfile"
  for i in $(seq 0 $((WORLD_SIZE - 1))); do
    read -r ip < "$ROOT/log/mpi/${job_id}/ip.${i}.txt"
    echo "${ip} slots=${MLP_WORKER_GPU}" >> "${ROOT}/log/mpi/${job_id}/mpi_hostfile"
    echo "ssh ${ip}:${SSHD_PORT}..."
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p ${SSHD_PORT} ${ip} hostname
    echo "ssh ${ip}:${SSHD_PORT} successfully."
  done

  sleep 10

  # execute mpi cmd
  nccl_tests

  # notfiy the worker machines that the task done
  echo "Work Done" >> "${ROOT}/log/mpi/${job_id}/work_done.txt"
  # echo "Work Done"

fi
# else
  while true; do
    sleep 5
    if [ -f "$ROOT/log/mpi/${job_id}/work_done.txt" ]; then
      break
    fi
  done
# fi
}

main "$@"
