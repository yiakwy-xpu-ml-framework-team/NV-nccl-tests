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
# 'ibp154s0'(tcp), 'ibp170s0f0'(tcp), 'ibp192s0'(tcp), 'ibp206s0'(tcp), 'ibp220s0'(tcp), 'ibp24s0'(tcp), 'ibp41s0f0'(tcp), 'ibp64s0'(tcp), 'ibp79s0'(tcp), 'ibp94s0'(tcp)
# NOTE(yiakwy) : see ib device and roce device mapping via ibdev2netdev
export NCCL_SOCKET_IFNAME=ibp24s0,ibp41s0f0,ibp64s0,ibp79s0,ibp94s0,ibp154s0,ibp170s0f0,ibp192s0
# export UCX_NET_DEVICES=$NCCL_SOCKET_IFNAME
export NCCL_SOCKET_IFNAME=ibp #/*NOTE*/
export NCCL_DEBUG=INFO

export SHARP_COLL_ENABLE_PCI_RELAXED_ORDERING=1
export NCCL_COLLNET_ENABLE=1

$ROOT/build/all_reduce_perf -b 512M -e 10G -f 2 -g 8
