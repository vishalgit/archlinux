docker create --name archlinux-container --net=host  --shm-size=4g --memory=0 --memory-swap=0 --cpus=0 --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -it archlinux-image zsh
