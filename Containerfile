FROM archlinux:latest

RUN sed -i 's|https://|http://|g' /etc/pacman.d/mirrorlist && \
pacman -Sy --noconfirm aria2 rate-mirrors && \
sed -i '/^\[options\]/a XferCommand = /usr/bin/aria2c --allow-overwrite=true --continue=true --file-allocation=none --log-level=error --max-tries=3 --max-connection-per-server=2 --max-file-not-found=5 --min-split-size=5M --no-conf --remote-time=true --summary-interval=60 --timeout=5 --dir=/ --out %o %u' /etc/pacman.conf && \
pacman -Scc --noconfirm

COPY cert.crt /etc/ca-certificates/trust-source/anchors/
RUN trust extract-compat && \
sed -i 's|http://|https://|g' /etc/pacman.d/mirrorlist

RUN rate-mirrors --allow-root arch --max-delay 21600 | tee /etc/pacman.d/mirrorlist

RUN pacman -Syu --noconfirm \
rustup \
base-devel \
git \
zsh \
sudo \
&& pacman -Scc --noconfirm  

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

USER ${user}
WORKDIR ${homedir}

# Setup git config & git authentication
RUN git config --global init.defaultBranch main && \
git config --global user.name ${name} && \
git config --global user.email ${email} && \
git config --global core.editor "nvim" && \
git config --global pull.rebase true && \
git config --global credential.helper ${homedir}/.secrets/gh-cred-helper.sh && \
mkdir -p ${homedir}/.secrets 
COPY --chown=${user}:${group} gh.gpg ${homedir}/.secrets/gh.gpg
COPY --chown=${user}:${group} --chmod=755 gh-cred-helper.sh ${homedir}/.secrets/gh-cred-helper.sh

# Setup rust
RUN rustup set profile minimal && \ 
rustup default stable && \
rustup component add rust-analyzer clippy rustfmt

# Setup paru
RUN git clone https://aur.archlinux.org/paru.git /tmp/paru && \
cd /tmp/paru && \
makepkg -si --noconfirm && \
rm -rf /tmp/paru

# Setup oh my zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Setup tmux
RUN paru -Syu tmux --noconfirm && paru -Scc --noconfirm && \
git clone https://github.com/tmux-plugins/tpm ${homedir}/.tmux/plugins/tpm
COPY --chown=${user}:${group} tmux.conf ${homedir}/.tmux.conf

# Setup rclone
RUN paru -Syu rclone --noconfirm && paru -Scc --noconfirm && \
mkdir -p ${homedir}/.config/rclone ${homedir}/org && \
echo "alias orgbisync='rclone bisync "${homedir}"/org mega:org --resync --size-only'" >> ${homedir}/.zshrc && \
echo "alias orgsync='rclone sync "${homedir}"/org mega:org'" >> ${homedir}/.zshrc && \
echo "alias gitauth='gpg --decrypt "${homedir}"/.secrets/gh.gpg'" >> ${homedir}/.zshrc
COPY --chown=${user}:${group} rclone.conf ${homedir}/.config/rclone/rclone.conf


# Setup single editor neovim 
ENV EDITOR=nvim
ENV VISUAL=nvim
ENV XDG_CONFIG_HOME=${homedir}/.config
ENV COLORTERM=truecolor
ENV PATH="${homedir}/.local/share/bob/nvim-bin:${PATH}"

RUN paru -Syu --noconfirm github-cli curl wget fd ripgrep unzip texinfo xclip bob && \
paru -Scc --noconfirm && \
git clone https://github.com/vishalgit/kickstart.nvim ${XDG_CONFIG_HOME}/kickstart && \
cd ${XDG_CONFIG_HOME}/kickstart && \
git remote add upstream https://github.com/nvim-lua/kickstart.nvim && \
git remote set-url --push upstream DISABLE && \
echo "alias kvim='NVIM_APPNAME=kickstart nvim'" >> ${homedir}/.zshrc && \
bob use stable 

RUN git clone https://github.com/vishalgit/lazyvim ${XDG_CONFIG_HOME}/lazyvim && \
cd ${XDG_CONFIG_HOME}/lazyvim && \
git remote add upstream https://github.com/LazyVim/starter && \
git remote set-url --push upstream DISABLE && \
echo "alias lvim='NVIM_APPNAME=lazyvim nvim'" >> ${homedir}/.zshrc

# Enable kata
ARG kata_location=${homedir}/.local/bin
ENV PATH="${kata_location}:${PATH}"
RUN mkdir ${kata_location} && \
git clone https://github.com/vishalgit/vim-kata && mv vim-kata ${homedir}/.vim-kata && \
cat > ${kata_location}/kata << 'EOF'
#!/bin/bash
export NVIM_APPNAME=kickstart
cd /home/vishal/.vim-kata
./run.sh
EOF
RUN chmod u+x ${kata_location}/kata

# Setup terminal emacs
RUN git clone https://github.com/vishalgit/doom ${XDG_CONFIG_HOME}/doom && \
paru -Syu ttf-symbola ttf-nerd-fonts-symbols-mono emacs pandoc shellcheck fontconfig --noconfirm && \
paru -Scc --noconfirm && \
git clone --depth 1 https://github.com/doomemacs/doomemacs ${XDG_CONFIG_HOME}/emacs && \
${XDG_CONFIG_HOME}/emacs/bin/doom install --env --force && \
${XDG_CONFIG_HOME}/emacs/bin/doom sync && \
echo "alias cmacs='emacs -nw'" >> ${homedir}/.zshrc
ENV PATH="${XDG_CONFIG_HOME}/emacs/bin:${PATH}"

# Set up nerdfont
RUN mkdir -p ${homedir}/.fonts && \
wget -q --show-progress https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -O ${homedir}/JetBrainsMono.tar.xz && \
tar -xvf ${homedir}/JetBrainsMono.tar.xz -C ${homedir}/.fonts && \
fc-cache -fv ${homedir}/.fonts \
&& rm -rf ${homedir}/JetBrainsMono.tar.xz

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash
# Mise
RUN curl https://mise.run/zsh | sh
ENV PATH="${homedir}/.local/share/mise/shims:${PATH}"
# Ruby on rails
RUN mise settings ruby.compile=false && \ 
mise use -g core:ruby && \
echo "gem: --no-document" >> ${homedir}/.gemrc && \
mkdir -p ${homedir}/.bundle && \
echo "bundle config set --global no-doc true" >> ${homedir}/.bundle/config && \
mise use -g gem:rails gem:neovim

# Nodejs lts
ENV NODE_EXTRA_CA_CERTS=${homedir}/.certs/cert.crt
RUN mkdir -p ${homedir}/.certs && \
cp /etc/ca-certificates/trust-source/anchors/cert.crt ${homedir}/.certs/cert.crt && \ 
mise use -g core:node@lts && \
mise use -g npm:neovim && \
mise use -g npm:npm && \
mise use -g npm:typescript && \
mise use -g npm:tree-sitter-cli 


RUN paru -Syu --noconfirm yazi \
7zip \
jq \
fzf \
zoxide \
btop \
bat \
tldr \
eza \
lsd \
lazygit \
zellij \
&& paru -Scc --noconfirm 

RUN echo 'eval "$(zoxide init zsh)"' >> ${homedir}/.zshrc && \
echo "alias ls='lsd'" >> ${homedir}/.zshrc && \
echo "source /usr/share/fzf/key-bindings.zsh" >> ${homedir}/.zshrc && \
echo "alias gitdc=\"gpg --decrypt ${homedir}/.secrets/gh.gpg\"" >> ${homedir}/.zshrc
