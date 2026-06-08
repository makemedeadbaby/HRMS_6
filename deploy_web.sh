#!/usr/bin/env bash
# Build Flutter web admin panel and deploy to Firebase Hosting.
set -euo pipefail
cd "$(dirname "$0")"

echo "→ Building Flutter web (release)..."
flutter build web --release

echo "→ Deploying to Firebase Hosting..."
if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only hosting
else
  npx --yes firebase-tools deploy --only hosting
fi

echo ""
echo "✅ Admin panel live at:"
echo "   https://abhishek-international-hrms.web.app"
echo "   https://abhishek-international-hrms.firebaseapp.com"
