#!/usr/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# enable ibverbs RDMA over Infiniband or RoCE
export NCCL_IB_HCA=mlx5_0,mlx5_3,mlx5_4,mlx5_5,mlx5_6,mlx5_9,mlx5_10,mlx5_11
# export NCCL_IB_HCA=mlx5
# export NCCL_TOPO_DUMP_FILE=topo.xml
# traffic class for QoS tunning
export NCCL_IB_TC=136
# service level that maps virtual lane
export NCCL_IB_SL=5
export NCCL_IB_GID_INDEX=3
export NCCL_IB_CUDA_SUPPORT=1
export NCCL_IB_TIMEOUT=22
# for HKUST supper pod, and this sets the TCP/IP-based interface for fallback of socket-based NCCL communication
export NCCL_SOCKET_IFNAME=ibp #/*NOTE*/
export NCCL_DEBUG=INFO

export UCX_NET_DEVICES=ibp
export SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING=1
export NCCL_COLLNET_ENABLE=0

$ROOT/build/all_reduce_perf -b 512M -e 10G -f 2 -g 8
