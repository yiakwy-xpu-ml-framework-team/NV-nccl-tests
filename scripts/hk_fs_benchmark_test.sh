# author LEI WANG : yiak.wy@gmail.com

#/usr/bin/bash
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e
set -x

TEST_NAME=test_fs

# unit GB
SIZE=2

export RUN_ROOT_PREFIX="/data/shared/public/${USER}/${TEST_NAME}"
TASK_NAME_PREFIX="dist_fs_benchmark"

export NODE_ID=${RANK:-0}
echo "NODE_ID : ${NODE_ID}"

# the number of threads
JOBS_=(8)  # (8 16 32 64)

# unit kB
BLOCK_SIZE_=(16) # (16 32 64 128)

TASK_TYPES_=(
    # sequential read
    "read" 
    # sequential write
    "write"
)

PYTHON_ARGS=
DRY_RUN=false

function run_once() {
    local JOBS=$1
    local BLOCK_SIZE=$2
    local TASK_TYPE=$3

    local TASK_NAME="${TASK_NAME_PREFIX}_size-${SIZE}G_jobs-${JOBS}_BLOCK_SZIE-${BLOCK_SIZE}_${TASK_TYPE}"
    local RUN_ROOT="${RUN_ROOT_PREFIX}/${TASK_NAME}"

    echo "RUN_ROOT : ${RUN_ROOT}"

    mkdir -p ${RUN_ROOT}
    mkdir -p ${RUN_ROOT}/log

    local CMD="python3 $ROOT/dist_fs_benchmark.py"

    if [ $DRY_RUN == true ]; then
        CMD="echo $CMD"
    fi

    $CMD --num-jobs ${JOBS} --block-size ${BLOCK_SIZE} $PYTHON_ARGS \
    &> ${RUN_ROOT}/log/${NODE_ID}.log
}

function benchmark() {
    for JOBS in ${JOBS_[@]}; do
        echo "JOBS : $JOBS"
        for BLOCK_SIZE in ${BLOCK_SIZE_[@]}; do
            for TASK_TYPE in ${TASK_TYPES_[@]}; do
                echo "TASK_TYPE : $TASK_TYPE"
                run_once $JOBS $BLOCK_SIZE $TASK_TYPE
            done
        done
    done
}

function usage() {
    echo "Usage: $0 [Options]"
    echo
    echo "io benchmark for distributed file system."
    echo 
    echo "Options:"
    echo "  -t[=| ]?test_name_val |"
    echo "  --test_name[=| ]?test_name_val      set test name for fio and smallfiles benchmark"
    echo
    echo "  --dry-run                           show commands without execution"
    echo
    echo "  -- python args                      pass args to python command dist_fs_benchmark.py"   
}

function parse_args() {
    local args

    # parse options
    while [[ "$#" -gt 0 ]]; do
        key="$1"
        case $1 in 
            -h|--help)
              usage
              exit 1
              ;;
            --dry-run)
              DRY_RUN=true
              shift
              ;;
            --)
              PYTHON_ARGS="$PYTHON_ARGS ${@:2}"
              break 2;
              ;;
            *)
              args+=("$key")
              shift
              ;;
        esac
    done

    if [ ${#args[@]} -gt 1 ]; then
        echo "$0 : should not have positional arguments!"
        exit 1;
    fi

}

function main() {
    parse_args "$@"
    benchmark
}

main "$@"