#!/usr/bin/env bash
set -euox pipefail
FONTSIZE=${1:-18}
BACKUP_DIR="/tmp/font-change-$$"
mkdir -p "$BACKUP_DIR"

# Backup everything first
FIlES=(
	~/.config/kickstart/lua/custom/plugins/overrides.lua
	~/.config/lazyvim/lua/plugins/neovide.lua
	~/.config/i3/config
	~/.config/neovide/config.toml
	~/.config/kitty/kitty.conf
	~/.config/gtk-3.0/settings.ini
	~/.config/rofi/config.rasi
	~/.config/doom/config.el
	~/.Xresources
	~/.xsettingsd
)

for f in "${FILES[@]}"; do
	[ -f "$f" ] && cp "$f" "$BACKUP_DIR/"
done

restore() {
	echo "Error - restoring backups..."
	for f in "$BACKUP_DIR"/*; do
		filename=$(basename "$f")
		for orig in "${FILES[@]}"; do
			if [ "$(basename "$orig")" = "$filename" ]; then
				cp "$f" "$orig"
			fi
		done
	done
	rm -rf "$BACKUP_DIR"
}

trap restore ERR

sed -i "s/vim.o.guifont.*/vim.o.guifont = \'JetBrainsMono Nerd Font:h${FONTSIZE}\'/" ~/.config/kickstart/lua/custom/plugins/overrides.lua

sed -i "s/vim.o.guifont.*/vim.o.guifont = \"JetBrainsMono Nerd Font:h${FONTSIZE}\"/" ~/.config/lazyvim/lua/plugins/neovide.lua

LINES=($(grep -n "pango:JetBrainsMono Nerd Font" ~/.config/i3/config | cut -d: -f1))
sed -i "${LINES[0]} s/\(pango:JetBrainsMono Nerd Font[^0-9]*\)[0-9]*/\1${FONTSIZE}/" ~/.config/i3/config
sed -i "${LINES[1]} s/\(pango:JetBrainsMono Nerd Font Mono \)[0-9]*/\1$((FONTSIZE-4))/" ~/.config/i3/config
sed -i "${LINES[2]} s/\(pango:JetBrainsMono Nerd Font \)[0-9]*/\1$((FONTSIZE-2))/" ~/.config/i3/config

sed -i "/\[font\]/{n; s/size = [0-9]*/size = $FONTSIZE/}" ~/.config/neovide/config.toml

sed -i "s/\(font_size\s*\)[0-9]*\.[0-9]*/\1${FONTSIZE}.0/" ~/.config/kitty/kitty.conf

sed -i "s/\(gtk-font-name=JetBrainsMono Nerd Font \)[0-9]*/\1$((FONTSIZE-4))/" ~/.config/gtk-3.0/settings.ini

sed -i "s/\(JetBrainsMono Nerd Font \)[0-9]*/\1$((FONTSIZE-2))/" ~/.config/rofi/config.rasi

sed -i "s/\(XTerm\*faceSize:\s*\)[0-9]*/\1${FONTSIZE}/" ~/.Xresources

sed -i "s/\(JetBrainsMono Nerd Font \)[0-9]*/\1$((FONTSIZE-4))/" ~/.xsettingsd

sed -i "/^[^;]*doom-font .*(font-spec/s/:size [0-9]*/:size $((FONTSIZE+4))/" ~/.config/doom/config.el
sed -i "/^[^;]*doom-variable-pitch-font/s/:size [0-9]*/:size $((FONTSIZE+6))/" ~/.config/doom/config.el

rm -rf "$BACKUP_DIR"
echo "DONE"
