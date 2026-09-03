#!/bin/sh
# 发布网页版到 Cloudflare Pages
set -e
cd "$(dirname "$0")"
flutter build web --release
npx --yes wrangler@latest pages deploy build/web --project-name sendit --branch main --commit-dirty=true
