%post
# The live image uses SDDM because Fedora's livesys tooling already knows how
# to autologin a live user there. Installed Noctiri switches to greetd.
systemctl disable sddm.service 2>/dev/null || true
systemctl enable greetd.service 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

if command -v noctalia-greeter-apply-appearance >/dev/null 2>&1; then
    noctalia-greeter-apply-appearance --setup-system || true
fi
%end
