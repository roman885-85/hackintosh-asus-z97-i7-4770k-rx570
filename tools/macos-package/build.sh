#!/bin/bash
# Збирає встановлювальний пакет macOS (dist/Z97-Haswell-Drivers-ВЕРСІЯ.pkg) з вмісту репозиторію:
# EFI/ і PostInstall/VoodooHDA.kext. Запуск: ./tools/macos-package/build.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
V=${VERSION:-$(date +%Y.%m.%d)}
if grep -q "W00000000001" "$REPO/EFI/OC/config.plist"; then
  echo "УВАГА: у EFI/OC/config.plist заглушки серійних номерів (W00000000001)."
  echo "Згенеруйте свої (GenSMBIOS, модель MacPro7,1) і впишіть у PlatformInfo → Generic, інакше iCloud/iMessage не працюватимуть."
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
SUP="$WORK/root/Library/Application Support/Z97-Haswell-Drivers"
mkdir -p "$SUP" "$WORK/scripts" "$REPO/dist"
cp -R "$REPO/EFI" "$SUP/EFI"
cp -R "$REPO/PostInstall/VoodooHDA.kext" "$SUP/"
find "$WORK/root" \( -name "._*" -o -name ".DS_Store" \) -delete
cp "$HERE/postinstall" "$WORK/scripts/postinstall"; chmod 755 "$WORK/scripts/postinstall"
# Явно забороняємо «переїзд» бандлів за ідентифікатором на інший диск (для .kext це й так типово,
# але якщо до пакета додадуть .app — захист уже стоятиме).
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
N=$(/usr/libexec/PlistBuddy -c "Print" "$WORK/component.plist" | grep -c "RootRelativeBundlePath" || true)
for ((i=0; i<N; i++)); do
  /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$WORK/component.plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$i:BundleIsRelocatable bool false" "$WORK/component.plist"
done
pkgbuild --root "$WORK/root" --component-plist "$WORK/component.plist" --scripts "$WORK/scripts" \
  --identifier ua.local.z97-haswell-drivers --version "$V" --install-location / --ownership recommended \
  "$REPO/dist/Z97-Haswell-Drivers-$V.pkg"
echo "Готово: $REPO/dist/Z97-Haswell-Drivers-$V.pkg"
