#!/bin/bash
# Minimal web server so the public instance has something to serve.
set -euo pipefail

dnf install -y nginx
cat > /usr/share/nginx/html/index.html <<'EOF'
<!doctype html>
<title>acme dev</title>
<p>Public instance is up.</p>
EOF
systemctl enable --now nginx
