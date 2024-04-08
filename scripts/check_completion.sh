ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

SSHD_PORT=$WORKER_SSH_PORT

mpi_setup() {

# start ssh service
nohup /usr/sbin/sshd -p $WOKER_SSH_PORT -D &


# check
echo | ssh-keygen -P ''

echo "sleep 3 seconds to wait for sshd completion ..."
sleep 3

job_id=nccl_tests
mkdir -p "${ROOT}/log/mpi/${job_id}"

this_ip=$(echo `hostname -i`)
echo "$this_ip" > "${ROOT}/log/mpi/${job_id}/ip.${RANK}.txt"

# generate ssh key
# TODO(yiakwy)  : add timestamp checking
echo | ssh-keygen -P ''
cat "/root/.ssh/id_rsa.pub" > "${ROOT}/log/mpi/${job_id}/rsa.${RANK}.txt"

while true; do
  sleep 1
  all_worker_uploaded=true
  for i in $(seq 0 $((WORLD_SIZE - 1))); do
    echo "visiting node#{i} ..."
    if [ ! -f "${ROOT}/log/mpi/${job_id}/rsa.${i}.txt" ] || [ ! -f "${ROOT}/log/mpi/${job_id}/ip.${i}.txt" ]; then
      all_worker_uploaded=false
      break
    fi
  done
  # stop checking
  if [ "$all_worker_uploaded" = true ]; then
    break
  fi
done

# writing all workers RSA keys to local authorized_keys
for i in $(seq 0 $((WORLD_SIZE - 1))); do
  read -r key < "${ROOT}/log/mpi/${job_id}/rsa.${RANK}.txt"
  echo "${key}" >> "/root/.ssh/authorized_keys"
done
}

nccl_tests() {

mpirun --allow-run-as-root \
--oversubscribe \
-np 64 \
-hostfile "${ROOT}/log/mpi/${job_id}/mpi_hostfile" \
-mca plm_rsh_args "-p 22 -q -o StrictHostKeyChecking=no" \
-mca coll_hcoll_enable 0 \
-mca pml ob1 \
-mca btl ^openib \
-mca btl_openib_if_include mlx5_0:1,mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_7:1,mlx5_8:1,mlx5_9:1,mlx5_10:1,mlx5_11:1 \
-mca btl_openib_cpc_include rdmacm \
-mca btl_openib_rroce_enable 1 \
-mca btl_tcp_if_include eth0 \
-x NCCL_IB_DISABLE=0 \
-x NCCL_SOCKET_IFNAME=eth0 \
-x NCCL_IB_GID_INDEX=0 \
-x NCCL_IB_TC=136 \
-x NCCL_IB_TIMEOUT=23 \
-x NCCL_IB_RETRY_CNT=7 \
-x NCCL_IB_PCI_RELAXED_ORDERING=1 \
-x NCCL_IB_HCA=mlx5 \
-x CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 \
-x CUDA_DEVICE_ORDER=PCI_BUS_ID \
-x NCCL_DEBUG=DEBUG \
-x NCCL_ALGO=Ring \
-x LD_LIBRARY_PATH \
-x PATH \
-x NCCL_NET_GDR_READ=1 \
-x UCX_IB_PCI_RELAXED_ORDERING=on \
$ROOT/build/all_reduce_perf -b 128M -e 8G -f 2 -g 1

}


main() {

  mpi_setup "$@"

if [ "$RANK" -eq 0 ]; then

  # generate mpi hostfile
  > "$ROOT/log/mpi/${job_id}/mpi_hostfile"
  for i in $(seq 0 $((WORLD_SIZE - 1))); do
    read -r ip < "$ROOT/log/mpi/${job_id}/ip.${i}.txt"
    echo "${ip} slots=${MLP_WORKER_GPU}" >> "${ROOT}/log/mpi/${job_id}/mpi_hostfile"
    ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -p ${SSHD_PORT} ${ip} hostname
  done


  # execute mpi cmd
  nccl_tests

  # notfiy the worker machines that the task done
  echo "Work Done" >> "${ROOT}/log/mpi/${job_id}/work_done.txt"

else
  while true; do
    sleep 100
    if [ -f "$ROOT/log/mpi/${job_id}/work_done.txt" ]; then
      break
    fi
  done

fi
}

main "$@"
