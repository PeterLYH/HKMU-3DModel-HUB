#!/bin/bash
echo "🚀 Cleaning and building Flutter Web..."

flutter clean
flutter pub get
flutter build web --pwa-strategy=none --no-wasm-dry-run --no-tree-shake-icons --profile

echo "🔧 Adding cache-busting timestamp..."

cd build/web || exit

# 生成版本戳
VERSION=$(date +%Y%m%d%H%M%S)

# 修改 index.html（讓它載入帶版本的 flutter_bootstrap.js）
sed -i "s|flutter_bootstrap.js|flutter_bootstrap.js?v=$VERSION|g" index.html

# 修改 flutter_bootstrap.js（讓它載入帶版本的 main.dart.js）
sed -i "s|main.dart.js|main.dart.js?v=$VERSION|g" flutter_bootstrap.js
sed -i "s|main.dart.mjs|main.dart.mjs?v=$VERSION|g" flutter_bootstrap.js 2>/dev/null || true

echo "✅ Cache busting applied with version: $VERSION"
echo "📦 Build completed! Ready to deploy build/web/"

echo "🚀 Deploying Flutter Web in Firebase..."

firebase deploy