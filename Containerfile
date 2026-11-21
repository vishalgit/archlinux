# syntax=docker/dockerfile:1
FROM archlinux:latest

RUN sed -i 's|https://|http://|g' /etc/pacman.d/mirrorlist
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
pacman -Sy --noconfirm aria2 rate-mirrors && \
sed -i '/^\[options\]/a XferCommand = /usr/bin/aria2c --allow-overwrite=true --continue=true --file-allocation=none --log-level=error --max-tries=3 --max-connection-per-server=2 --max-file-not-found=5 --min-split-size=5M --no-conf --remote-time=true --summary-interval=60 --timeout=5 --dir=/ --out %o %u' /etc/pacman.conf

COPY cert.crt /etc/ca-certificates/trust-source/anchors/
RUN trust extract-compat && \
sed -i 's|http://|https://|g' /etc/pacman.d/mirrorlist

RUN rate-mirrors --allow-root arch --max-delay 21600 | tee /etc/pacman.d/mirrorlist

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
pacman -Syu --noconfirm && \
pacman -S --noconfirm rustup \
base-devel \
git \
zsh \
sudo

ARG user=vishal
ARG group=vishal
ARG name="Vishal Saxena"
ARG email="vishal.reply@gmail.com"
ARG homedir="/home/vishal"

RUN groupadd -g 1000 ${group} && \
useradd -m -u 1000 -g 1000 -s /bin/zsh ${user} && \
echo "${user}:${user}" | chpasswd && \
echo "${user} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
mkdir -p /run/user/1000 && \
chown ${user}:${group} /run/user/1000 && \
chmod 700 /run/user/1000

ENV XDG_RUNTIME_DIR=/run/user/1000
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup timezone and locale
RUN ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
locale-gen && \
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Docker CLI
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
pacman -S --noconfirm docker docker-buildx docker-compose github-cli sops age

USER ${user}
WORKDIR ${homedir}

# Setup secrets
COPY --chown=${user}:${group} key.age secrets.enc.yaml ${homedir}/.secrets/

# Setup git config & git authentication
COPY --chown=${user}:${group} .gitattributes ${homedir}/.secrets/.gitattributes
RUN git config --global init.defaultBranch main && \
git config --global core.editor nvim && \
git config --global user.name ${name} && \
git config --global user.email ${email} && \
git config --global pull.rebase true && \
mkdir -p ${homedir}/.secrets && \
git config --global core.attributesfile ${homedir}/.secrets/.gitattributes

# Setup rust
RUN rustup set profile minimal && \ 
rustup default stable && \
rustup component add rust-analyzer clippy rustfmt rust-src

# Setup paru
RUN git clone https://aur.archlinux.org/paru.git /tmp/paru && \
cd /tmp/paru && \
makepkg -si --noconfirm && \
rm -rf /tmp/paru

# Setup oh my zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${homedir}/.oh-my-zsh/custom/themes/powerlevel10k && \
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ${homedir}/.zshrc


# Setup tmux
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu tmux --noconfirm && \
git clone https://github.com/tmux-plugins/tpm ${homedir}/.tmux/plugins/tpm
COPY --chown=${user}:${group} tmux.conf ${homedir}/.config/tmux/tmux.conf
RUN ${homedir}/.tmux/plugins/tpm/bin/install_plugins

# Setup rclone
RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu rclone --noconfirm && \
mkdir -p ${homedir}/org ${homedir}/.config/rclone 
COPY --chown=${user}:${group} rclone.conf ${homedir}/.config/rclone/rclone.conf
RUN mkdir -p ${homedir}/.config/shell && \
cat >> ${homedir}/.config/shell/unlock.sh <<'EOF'
unlock() {
  local key
  key=$(rage -d $HOME/.secrets/key.age) || return 1
  set -a
  source <(SOPS_AGE_KEY="$key" sops decrypt --output-type dotenv $HOME/.secrets/secrets.enc.yaml)
  set +a
}
EOF

# Setup single editor neovim 
ENV EDITOR=nvim
ENV VISUAL=nvim
ENV XDG_CONFIG_HOME=${homedir}/.config
ENV COLORTERM=truecolor
ENV PATH="${homedir}/.local/share/bob/nvim-bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu --noconfirm github-cli curl wget \
fd ripgrep unzip texinfo xclip bob tree-sitter-cli \
tidy fontconfig && \
git clone https://github.com/vishalgit/kickstart.nvim ${XDG_CONFIG_HOME}/kickstart && \
cd ${XDG_CONFIG_HOME}/kickstart && \
git remote add upstream https://github.com/nvim-lua/kickstart.nvim && \
git remote set-url --push upstream DISABLE && \
bob use stable 

# Enable kata
ARG kata_location=${homedir}/.local/bin
ENV PATH="${kata_location}:${PATH}"
RUN mkdir ${kata_location} && \
git clone https://github.com/vishalgit/vim-kata && mv vim-kata ${homedir}/.vim-kata && \
cat > ${kata_location}/kata <<'EOF'
#!/bin/bash
export NVIM_APPNAME=kickstart
cd $HOME/.vim-kata
./run.sh
EOF
RUN chmod u+x ${kata_location}/kata

# Set up nerdfont
RUN mkdir -p ${homedir}/.fonts && \
wget -q --show-progress https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -O ${homedir}/JetBrainsMono.tar.xz && \
wget -q --show-progress https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz -O ${homedir}/NerdFontsSymbolsOnly.tar.xz && \
tar -xvf ${homedir}/JetBrainsMono.tar.xz -C ${homedir}/.fonts && \
tar -xvf ${homedir}/NerdFontsSymbolsOnly.tar.xz -C ${homedir}/.fonts && \
fc-cache -fv ${homedir}/.fonts \
&& rm -rf ${homedir}/JetBrainsMono.tar.xz NerdFontsSymbolsOnly.tar.xz

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash
# Mise
RUN curl https://mise.run/zsh | sh
ENV PATH="${homedir}/.local/share/mise/shims:${PATH}"

# Nodejs lts
ENV NODE_EXTRA_CA_CERTS=${homedir}/.certs/cert.crt
RUN mkdir -p ${homedir}/.certs && \
cp /etc/ca-certificates/trust-source/anchors/cert.crt ${homedir}/.certs/cert.crt && \ 
mise use -g core:node@lts && \
mise use -g npm:neovim && \
mise use -g npm:npm && \
mise use -g npm:typescript && \
mise use -g npm:stylelint && \
mise use -g npm:js-beautify && \
mise use -g npm:vscode-langservers-extracted && \
mise use -g npm:prettier

RUN mise use -g dotnet && \
mise use -g dotnet:csharpier && \
mise use -g 'dotnet:roslyn-language-server[prerelease=true]'

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu --noconfirm yazi \
jq \
fzf \
zoxide \
bat \
tldr \
eza 
ENV SHELL=/usr/bin/zsh

# Setup emacs
RUN wget -q --show-progress https://github.com/Samsung/netcoredbg/releases/latest/download/netcoredbg-linux-amd64.tar.gz -O ${homedir}/netcoredbg-linux-amd64.tar.gz && \
tar -xvf ${homedir}/netcoredbg-linux-amd64.tar.gz -C ${homedir}/.local/bin && \
rm -rf ${homedir}/netcoredbg-linux-amd64.tar.gz
ENV PATH="${homedir}/.config/emacs/bin:${homedir}/.cargo/bin:${homedir}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu --noconfirm \
emacs \
cmake \
lldb \
libvterm \
ttf-symbola \
maim \
pandoc-bin \
graphviz \
shellcheck-bin && \
rm -rf ${homedir}/.config/emacs && \
git clone --depth 1 https://github.com/doomemacs/core ${homedir}/.config/emacs && \
${homedir}/.config/emacs/bin/doom install --force
COPY --chown=${user}:${group} configuration.org ${homedir}/org/configuration.org
RUN emacs --batch --eval "(require 'ob-tangle)" --eval '(org-babel-tangle-file "~/org/configuration.org")' && \
${homedir}/.config/emacs/bin/doom sync 


RUN rustup target add wasm32-unknown-unknown && \
cargo install cargo-binstall && \
cargo binstall trunk cargo-leptos leptosfmt

RUN cat >> ${homedir}/.zshrc <<'EOF'
eval "$(zoxide init zsh)"
source $HOME/.config/shell/unlock.sh
alias orgbisync='rclone bisync $HOME/org mega:org --resync --size-only'
alias orgsync='rclone bisync $HOME/org mega:org --size-only'
alias kvim='[[ -z "${GH_TOKEN:-}" ]] && unlock;NVIM_APPNAME=kickstart nvim'
alias ls='eza'
alias ll='eza -l --git --icons'
alias la='eza -la --git --icons'
alias lt='eza -A --tree --level=3 --icons'
alias cmacs='emacs -nw'
source /usr/share/fzf/key-bindings.zsh
export PROMPT_EOL_MARK=""
EOF

COPY --chown=${user}:${group} p10k.zsh ${homedir}/.p10k.zsh
RUN echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> ${homedir}/.zshrc
RUN printf '%s\n' \
  'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then' \
  '  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"' \
  'fi' | cat - ${homedir}/.zshrc > /tmp/zshrc && mv /tmp/zshrc ${homedir}/.zshrc

# ── GUI: xrdp + i3 / i3status / dunst / feh ──────────────────────────────────
# rdp_bind=127.0.0.1 → only reachable from this host (you use --net=host).
# Set to 0.0.0.0 only if you connect from another machine AND changed the password.
ARG rdp_bind=127.0.0.1
ARG rdp_port=3389

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
paru -Syu --noconfirm \
tini \
xorg-server xorg-xauth xorg-xrandr xorg-xsetroot xorg-xrdb \
xrdp xorgxrdp \
i3-wm i3status rofi dunst libnotify feh \
dbus ttf-dejavu i3lock xss-lock picom xterm kitty neovide firefox-esr-bin xdg-utils \
rage-encryption pinentry \
thunar gvfs tumbler ffmpegthumbnailer \
xsettingsd arc-gtk-theme papirus-icon-theme \
zathura zathura-pdf-mupdf inlyne glow code \
noto-fonts noto-fonts-emoji ttf-liberation

USER root
# machine-id for D-Bus; bind xrdp listener (only the first port= line, the
# [Xorg] session section also has a port= line that must stay -1)
RUN dbus-uuidgen --ensure=/etc/machine-id && \
sed -i "0,/^port=/s|^port=.*|port=tcp://${rdp_bind}:${rdp_port}|" /etc/xrdp/xrdp.ini && \
sed -i 's/^autorun=.*/autorun=Xorg/' /etc/xrdp/xrdp.ini && \
sed -i 's/^EnableUserWindowManager=.*/EnableUserWindowManager=false/' /etc/xrdp/sesman.ini && \
printf 'allowed_users=anybody\nneeds_root_rights=no\n' > /etc/X11/Xwrapper.config
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

RUN sudo mkdir -p /etc/firefox/policies
COPY firefox-policy.json /etc/firefox/policies/policies.json

USER ${user}

# i3 config: start from the stock one (skips the first-run wizard), then add ours
RUN mkdir -p ${homedir}/.config/i3 \
${homedir}/.config/i3status \
${homedir}/Pictures \
${homedir}/.config/neovide \
${homedir}/.config/kitty \
${homedir}/.config/rofi \
${homedir}/.config/gtk-3.0 \
${homedir}/.config/zathura \
${homedir}/.config/inlyne \
${homedir}/.vscode-oss
COPY --chown=${user}:${group} i3status.config ${homedir}/.config/i3status/config
COPY --chown=${user}:${group} i3.config ${homedir}/.config/i3/config 
COPY --chown=${user}:${group} wall1.jpg ${homedir}/Pictures 
COPY --chown=${user}:${group} wall2.jpg ${homedir}/Pictures 
COPY --chown=${user}:${group} neovide.png ${homedir}/Pictures 
COPY --chown=${user}:${group} neovide.toml ${homedir}/.config/neovide/config.toml 
COPY --chown=${user}:${group} kitty.conf ${homedir}/.config/kitty/kitty.conf 
COPY --chown=${user}:${group} config.rasi ${homedir}/.config/rofi/config.rasi
COPY --chown=${user}:${group} neovide.desktop ${homedir}/.local/share/applications/neovide.desktop
COPY --chown=${user}:${group} mimeapps.list ${homedir}/.config/mimeapps.list
COPY --chown=${user}:${group} xsettings.ini ${homedir}/.config/gtk-3.0/settings.ini
COPY --chown=${user}:${group} xsettingsd    ${homedir}/.xsettingsd
COPY --chown=${user}:${group} Xresources    ${homedir}/.Xresources
COPY --chown=${user}:${group} zathurarc     ${homedir}/.config/zathura/zathurarc
COPY --chown=${user}:${group} inlyne.toml   ${homedir}/.config/inlyne/inlyne.toml
COPY --chown=${user}:${group} argv.json     ${homedir}/.vscode-oss/argv.json

# Every xrdp login runs /etc/xrdp/startwm.sh → straight into i3.
# Sessions start through PAM, so they do NOT inherit the container ENV;
# entrypoint.sh writes it to /etc/environment, which pam_env loads at login.
ENV TERMINAL=kitty
USER root
RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
source /home/vishal/.config/shell/unlock.sh
unlock || true
exec dbus-run-session -- i3
EOF
RUN chmod 755 /etc/xrdp/startwm.sh
USER ${user}

# tini as PID 1: reaps zombies from xrdp/X sessions and forwards signals.
# Default command keeps the container alive in the background as a GUI box;
# get a shell with: docker exec -it archlinux-container zsh
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
