#!/bin/bash
set -e

APP_NAME="SwitchRPC"
VERSION="1.0.0"
SOURCE_APP="$HOME/Applications/$APP_NAME.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
TMP_DIR="/tmp/switchrpc-dmg-pack"

echo "🚀 Préparation du DMG pour $APP_NAME v$VERSION..."

# Vérification du bundle
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ Erreur : $SOURCE_APP introuvable."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Copie de l'application
cp -R "$SOURCE_APP" "$TMP_DIR/"

# Création du lien symbolique vers le dossier /Applications
ln -s /Applications "$TMP_DIR/Applications"

# Suppression de l'ancien DMG s'il existe
rm -f "$DMG_PATH"

# Création du DMG avec l'outil natif macOS hdiutil
echo "📦 Compression et création du DMG..."
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$TMP_DIR" \
               -ov \
               -format UDZO \
               "$DMG_PATH"

# Nettoyage temporaire
rm -rf "$TMP_DIR"

echo "✅ DMG créé avec succès !"
echo "📍 Emplacement : $DMG_PATH"
ls -lh "$DMG_PATH"
