%post --erroronfail --log=/root/noctiri-post-install.log
# The Noctiri live image is intentionally smaller than the installed system.
# These packages are downloaded into the target system, so installation needs
# an active network connection.
echo "==> Checking network access for deferred Noctiri packages"
if ! dnf5 -q makecache --refresh; then
    echo "ERROR: Noctiri needs an active internet connection during installation." >&2
    echo "Connect to Wi-Fi or Ethernet in Anaconda's Network step and retry." >&2
    exit 1
fi

echo "==> Installing deferred Noctiri desktop packages"
dnf5 -y group install fonts multimedia
dnf5 -y install btop cava fastfetch

# The live image uses SDDM because Fedora's livesys tooling already knows how
# to autologin a live user there. Installed Noctiri switches to greetd.
systemctl disable sddm.service 2>/dev/null || true
systemctl enable greetd.service 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

if command -v noctalia-greeter-apply-appearance >/dev/null 2>&1; then
    noctalia-greeter-apply-appearance --setup-system || true
fi
%end
