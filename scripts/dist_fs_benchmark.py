# author LEI WANG : yiak.wy@gmail.com

import argparse

from enum import Enum

import os
import sys

from pathlib import Path

class Toolkit(Enum):
    fio = 0
    smallfiles = 1
    N = 2
    
    def __str__(self):
        return self.name
    
    @staticmethod
    def parse(s):
        try:
            return Toolkit[s]
        except KeyError:
            return s
    
class BenchOperation(Enum):
    # operations supported by smallfiles and fio
    read = 0 # sequential read
    write = 1 # sequential write
    
    # operations supported by smallfiles
    create = 2
    delete = 3
    append = 4
    N = 5
    
    def __str__(self):
        return self.name
    
    @staticmethod
    def parse(s):
        try:
            return BenchOperation[s]
        except KeyError:
            return s

def parse_args():
    parser = argparse.ArgumentParser()
    group = parser.add_argument_group(title='dist_fs_benchmark')
    
    group.add_argument("--file", type=str, default="", help="device mounted point or a file.")
    group.add_argument("--method", type=Toolkit.parse, choices=list(Toolkit), default="fio", help="benchmark toolkit type.")
    
    group.add_argument("--num-jobs", type=int, default=1, help="num of jobs run concurrently.")
    group.add_argument("--size", type=int, default=2, help="the size of file created for testing, default unit GB.") 
    group.add_argument("--block-size", type=int, default=16, help="io block size, default to 16 kB")
    group.add_argument("--not-use-io-buffer", type=bool, default=True, help="not use io buffer")
    group.add_argument("--io-operation", type=BenchOperation.parse, choices=list(BenchOperation), default="read", help="io operations permit")
    group.add_argument("--use-libaio", action='store_true', help="use libaio")
    group.add_argument("--test-name", type=str, default="IOPS_test", help="name prefix used for generated files")

    group.add_argument("--dry-run", action='store_true', help="echo command to run")
    
    args = parser.parse_args()
    
    return parser, args


def create_test_files(test_dir, test_name, num_jobs, size):
    filename_prefix = os.path.join(test_dir, test_name)
    cmd = f"touch {filename_prefix}.{{0..{num_jobs}}}.0"
    print(f"create test files with prefix {filename_prefix} ...")
    os.system(cmd)
    
    cmd = f"truncate -s {size}G {filename_prefix}.{{0..{num_jobs}}}.0"
    print(f"truncate files to {size}G size ...")
    os.system(cmd)
    
def clear_test_files(test_dir):
    if os.path.exists(test_dir):
        os.system(f"rm -r {test_dir}")

def IOPS_benchmark(parser, FLAGS):
    cwd = os.path.dirname(os.path.realpath(__file__))
    test_dir = os.fspath(Path(f"{cwd}/dist_fs_bench/log").resolve())
    
    os.makedirs(test_dir, exist_ok=True)
    
    if FLAGS.method == Toolkit.fio:
        binary = str(FLAGS.method)
    else:
        smallfile_dir = os.fspath(Path(f"{cwd}/smallfile_dir").resolve())
                
        if not os.path.isdir(smallfile_dir):
            print("prepare smallfile_dir")
            os.system(f"git clone https://github.com/distributed-system-analysis/smallfile.git {smallfile_dir}")
        
        binary = f"python {smallfile_dir}/smallfile_cli.py"
        cmd = f"{binary} --operation {FLAGS.io_operation} --threads {FLAGS.num_jobs} --file-size {FLAGS.size * 1024} --files 2048" \
              f" --top {test_dir}"
        
        if FLAGS.dry_run:
            print(f"{cmd}")
        else:
            
            os.system(cmd)
        
        clear_test_files(test_dir)
        return

    # block size ranging from 4k, 16k to 64 k 
    ioengine = "libaio" if FLAGS.use_libaio else "psync"
    iodepth = 128 if FLAGS.use_libaio else 1
    cmd = f"{binary} --name={FLAGS.test_name} -direct={1 if FLAGS.not_use_io_buffer else 0} -ioengine={ioengine} -thread -rw={FLAGS.io_operation} -size={FLAGS.size}G" \
          f" -numjobs={FLAGS.num_jobs} -bs={FLAGS.block_size}k --iodepth={iodepth} --end_fsync=1 --runtime=300 -time_based -group_reporting --eta-newline=1"
    
    if FLAGS.dry_run:
        print(f"{cmd}")    
    else:
        # pushd
        old_dir = cwd
        os.chdir(test_dir)
                
        # create files
        create_test_files(test_dir, FLAGS.test_name, FLAGS.num_jobs, FLAGS.size)
        
        # execute
        os.system(cmd)
        
        # popd
        os.chdir(old_dir)
        
        clear_test_files(test_dir)

def main():
    parser, FLAGS = parse_args()
    
    IOPS_benchmark(parser, FLAGS)


if __name__ == "__main__":
    main()