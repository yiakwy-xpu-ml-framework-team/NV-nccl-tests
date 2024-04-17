ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

export NCCL_IB_HCA=mlx5
export NCCL_IB_TC=136
export NCCL_IB_SL=5
export NCCL_IB_GID_INDEX=3
export NCCL_IB_TIMEOUT=22
export NCCL_SOCKET_IFNAME=eth0 #/*NOTE*/
export NCCL_DEBUG=INFO

export NCCL_IB_HCA=ibp
export UCX_NET_DEVICES=ibp0:1,ibp1:1,ibp2:1,ibp3:1,ibp4:1,ibp5:1,ibp6:1,ibp7:1
export SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING=1
export NCCL_COLLNET_ENABLE=0

# make MPI=1 MPI_HOME=/opt/hpcx/ompi
$ROOT/build/all_reduce_perf -b 512M -e 8G -f 2 -g 1
