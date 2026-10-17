1. Add host user to docker group
sudo usermod -aG docker $USER
2. build the image
docker buildx build --build-arg docker_gid=$(stat -c %g /var/run/docker.sock) -t archlinux-image -f Containerfile .

3. Create the docker container
docker create --name archlinux-container --net=host  --shm-size=4g --memory=0 --memory-swap=0 --cpus=0 --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -it -v /var/run/docker.sock:/var/run/docker.sock archlinux-image zsh
