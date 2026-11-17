1. Add host user to docker group
sudo usermod -aG docker $USER
2. build the image
docker buildx build -t archlinux-image -f Containerfile .

3. Create the docker container in case of docker (GUI mode: no "zsh" at the end)
docker create --name archlinux-container --net=host  --shm-size=4g --memory=0 --memory-swap=0 --cpus=0 --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v /var/run/docker.sock:/var/run/docker.sock --group-add $(stat -c %g /var/run/docker.sock) archlinux-image

4. Create the docker container in case of podman (GUI mode: no "zsh" at the end)
podman create --name archlinux-container --net=host  --shm-size=4g --memory=0 --memory-swap=0 --cpus=0 --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v /run/user/1000/podman/podman.sock:/var/run/docker.sock --userns=keep-id archlinux-image

5. Start in GUI mode (runs in the background, xrdp listening)
docker start archlinux-container        # or: podman start archlinux-container

6. Log in over RDP → you land directly in i3 (user vishal)
xfreerdp3 /v:127.0.0.1:3389 /u:vishal /dynamic-resolution +clipboard
(or Remmina → RDP → 127.0.0.1:3389)

Terminal without RDP:  docker exec -it archlinux-container zsh
Stop:                  docker stop archlinux-container
Old terminal-only mode: create with "-it archlinux-image zsh" (and -e ENABLE_RDP=0 to skip xrdp)

Build args:
--build-arg rdp_port=3390     # if the host already uses 3389
--build-arg rdp_bind=0.0.0.0  # to connect from another machine (change the password first!)
--build-arg i3_mod=Mod1       # use Alt instead of the Windows key as the i3 mod key

Keys: Win+Enter alacritty, Win+d rofi apps, Win+Tab rofi windows, Win+Shift+Return emacs
Log out of i3 (Win+Shift+e) ends the RDP session; the container keeps running.
Wallpaper: put an image at ~/Pictures/wallpaper.jpg, then Win+Shift+r
Logs if the screen is blank: /var/log/xrdp-sesman.log, ~/.xorgxrdp.10.log, ~/.xsession-errors
