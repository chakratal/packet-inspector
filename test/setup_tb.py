#!/usr/bin/env python3.14
#autograder from lab 3 - not relevant to project
#import os
#import shutil
#import subprocess
#
#REPO_URL = "https://github.com/transcendental-software/csc-397-595-auto-grader.git"
#
#def main():
#    # Clone the auto-grader repository into the test folder
#    clone_dir = os.path.join('test', 'auto-grader')
#    if os.path.exists(clone_dir):
#        print(f"Updating existing repository at {clone_dir}...")
#        subprocess.run(["git", "pull"], cwd=clone_dir, check=True)
#    else:
#        print(f"Cloning {REPO_URL} into {clone_dir}...")
#        subprocess.run(["git", "clone", REPO_URL, clone_dir], check=True)
#
#    # Copy tb/Makefile from the cloned repo to the root of the current repo
#    src_makefile = os.path.join(clone_dir, 'tb/miner', 'Makefile')
#    dst_makefile = os.path.join('tb', 'Makefile')
#    os.makedirs('tb', exist_ok=True)
#    if os.path.exists(src_makefile):
#        if os.path.exists(dst_makefile):
#            os.remove(dst_makefile)
#            print(f"Overwriting existing {dst_makefile}")
#        shutil.copy2(src_makefile, dst_makefile)
#        print(f"Copied {src_makefile} to {dst_makefile}")
#    else:
#        print(f"Error: {src_makefile} not found.")
#
#    # Copy tb/neorv32_verilog_wrapper.vhd from the cloned repo to the root of the current repo
#    src_wrapper_file = os.path.join(clone_dir, 'tb/miner', 'neorv32_verilog_wrapper.vhd')
#    dst_wrapper_file = os.path.join('tb', 'neorv32_verilog_wrapper.vhd')
#    os.makedirs('tb', exist_ok=True)
#    if os.path.exists(src_wrapper_file):
#        if os.path.exists(dst_wrapper_file):
#            os.remove(dst_wrapper_file)
#            print(f"Overwriting existing {dst_wrapper_file}")
#        shutil.copy2(src_wrapper_file, dst_wrapper_file)
#        print(f"Copied {src_wrapper_file} to {dst_wrapper_file}")
#    else:
#        print(f"Error: {src_wrapper_file} not found.")
#
#    # Copy tb/miner_tb.v from the cloned repo to the root of the current repo
#    src_tb_file = os.path.join(clone_dir, 'tb/miner', 'miner_tb.v')
#    dst_tb_file = os.path.join('tb', 'miner_tb.v')
#    os.makedirs('tb', exist_ok=True)
#    if os.path.exists(src_tb_file):
#        if os.path.exists(dst_tb_file):
#            os.remove(dst_tb_file)
#            print(f"Overwriting existing {dst_tb_file}")
#        shutil.copy2(src_tb_file, dst_tb_file)
#        print(f"Copied {src_tb_file} to {dst_tb_file}")
#    else:
#        print(f"Error: {src_tb_file} not found.")
#    
#    # Copy tb/miner_tb.cpp from the cloned repo to the root of the current repo
#    src_tb_file = os.path.join(clone_dir, 'tb/miner', 'miner_tb.cpp')
#    dst_tb_file = os.path.join('tb', 'miner_tb.cpp')
#    os.makedirs('tb', exist_ok=True)
#    if os.path.exists(src_tb_file):
#        if os.path.exists(dst_tb_file):
#            os.remove(dst_tb_file)
#            print(f"Overwriting existing {dst_tb_file}")
#        shutil.copy2(src_tb_file, dst_tb_file)
#        print(f"Copied {src_tb_file} to {dst_tb_file}")
#    else:
#        print(f"Error: {src_tb_file} not found.")
#
#    # Copy test/miner_test.py from the cloned repo to the root of the current repo
#    src_test_file = os.path.join(clone_dir, 'test', 'miner_test.py')
#    dst_test_file = os.path.join('test', 'miner_test.py')
#    if os.path.exists(src_test_file):
#        if os.path.exists(dst_test_file):
#            os.remove(dst_test_file)
#            print(f"Overwriting existing {dst_test_file}")
#        shutil.copy2(src_test_file, dst_test_file)
#        print(f"Copied {src_test_file} to {dst_test_file}")
#    else:
#        print(f"Error: {src_test_file} not found.")
#
#if __name__ == "__main__":
#    main()
