#!/usr/bin/env bash
# Runs once after the devcontainer is created. Fills in the pieces the base
# mcr.microsoft.com/devcontainers/universal image doesn't provide out of the
# box: a working rbenv (its RBENV_ROOT ships root-owned and empty), the Ruby
# version this repo pins to, and an actual Chrome binary for system tests
# (bin/setup only installs Chrome's *library* dependencies, not the browser).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Fixing up rbenv =="
sudo chown -R "$(id -u):$(id -g)" "$(~/.rbenv/bin/rbenv root)"
if [ ! -d "$(~/.rbenv/bin/rbenv root)/plugins/ruby-build" ]; then
  git clone https://github.com/rbenv/ruby-build.git "$(~/.rbenv/bin/rbenv root)/plugins/ruby-build"
fi

RUBY_VERSION="$(cat .ruby-version)"
if ! ~/.rbenv/bin/rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
  ~/.rbenv/bin/rbenv install "$RUBY_VERSION"
fi
~/.rbenv/bin/rbenv rehash

echo "== Installing Google Chrome (for system tests) =="
if ! command -v google-chrome >/dev/null 2>&1; then
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
  sudo apt-get update
  sudo apt-get install -y google-chrome-stable
fi

echo "== Installing editor-support gems globally (ruby-lsp, ruby-lsp-rails, debug) =="
~/.rbenv/bin/rbenv exec gem install ruby-lsp ruby-lsp-rails debug
~/.rbenv/bin/rbenv rehash

echo "== bin/setup (bundle install, Chrome deps, db:prepare) =="
PATH="$HOME/.rbenv/shims:$PATH" bin/setup --skip-server
