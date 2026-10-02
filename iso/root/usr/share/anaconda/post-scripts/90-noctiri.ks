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

# The live image uses an ephemeral liveuser autologin. The installed system
# must not retain that config because liveuser is not copied to the target.
install -Dm0644 /usr/share/noctiri/configs/greetd/config.toml /etc/greetd/config.toml

# greetd's Fedora package defines its service account through systemd-sysusers.
# Live-image installation can copy the package payload without materializing
# that account in the target /etc/passwd, so create it explicitly.
systemd-sysusers /usr/lib/sysusers.d/greetd.conf
systemd-tmpfiles --create /usr/lib/tmpfiles.d/greetd.conf

if ! getent passwd greetd >/dev/null; then
    echo "ERROR: greetd system account was not created." >&2
    exit 1
fi

# Prepare Noctalia Greeter's writable state after the greetd account exists.
if command -v noctalia-greeter-apply-appearance >/dev/null 2>&1; then
    noctalia-greeter-apply-appearance --setup-system
fi

systemctl enable greetd.service
systemctl set-default graphical.target
%end
