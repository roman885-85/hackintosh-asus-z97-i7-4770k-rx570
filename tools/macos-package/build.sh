#!/bin/bash
# Збирає встановлювальний пакет macOS dist/Z97-Haswell-Drivers-ВЕРСІЯ.pkg з вмісту репозиторію.
#   ./tools/macos-package/build.sh             — лише драйвери (вбудований звук VoodooHDA для macOS 26+);
#   ./tools/macos-package/build.sh --with-efi  — ще й завантажувач OpenCore з EFI/ (спершу впишіть свої серійні номери).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
V=${VERSION:-$(date +%Y.%m.%d)}
WITH_EFI=0; [ "${1:-}" = "--with-efi" ] && WITH_EFI=1
if [ $WITH_EFI = 1 ] && grep -q "W00000000001" "$REPO/EFI/OC/config.plist"; then
  echo "У EFI/OC/config.plist заглушки серійних номерів (W00000000001). Згенеруйте свої (GenSMBIOS, MacPro7,1),"
  echo "впишіть у PlatformInfo → Generic і запустіть збирання ще раз."; exit 1
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/comp" "$WORK/res" "$REPO/dist"
SUPDIR="Library/Application Support/Z97-Haswell-Drivers"

component() { # id root script out
  local id=$1 root=$2 script=$3 out=$4 n i
  mkdir -p "$WORK/s-$id"; cp "$HERE/scripts/$script" "$WORK/s-$id/postinstall"; chmod 755 "$WORK/s-$id/postinstall"
  find "$root" \( -name "._*" -o -name ".DS_Store" \) -delete
  pkgbuild --analyze --root "$root" "$WORK/$id.plist" >/dev/null
  n=$(/usr/libexec/PlistBuddy -c "Print" "$WORK/$id.plist" | grep -c "RootRelativeBundlePath" || true)
  for ((i=0; i<n; i++)); do
    /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$WORK/$id.plist" 2>/dev/null ||
      /usr/libexec/PlistBuddy -c "Add :$i:BundleIsRelocatable bool false" "$WORK/$id.plist"
  done
  pkgbuild --root "$root" --component-plist "$WORK/$id.plist" --scripts "$WORK/s-$id" --identifier "$id" \
    --version "$V" --install-location / --ownership recommended "$WORK/comp/$out" >/dev/null
  echo "компонент $out готовий"
}

mkdir -p "$WORK/r-vhda/$SUPDIR"; cp -R "$REPO/PostInstall/VoodooHDA.kext" "$WORK/r-vhda/$SUPDIR/"
component ua.local.z97.voodoohda "$WORK/r-vhda" voodoohda-postinstall z97-voodoohda.pkg
LINES='<line choice="vhda"/>'; CHOICES='<choice id="vhda" title="Вбудований звук (VoodooHDA)" description="Realtek ALC887 на macOS 26 і новіших. Потрібен дозвіл у «Конфіденційність і безпека» і перезапуск."><pkg-ref id="ua.local.z97.voodoohda"/></choice>'
REFS="<pkg-ref id=\"ua.local.z97.voodoohda\" version=\"$V\" onConclusion=\"RequireRestart\">z97-voodoohda.pkg</pkg-ref>"
if [ $WITH_EFI = 1 ]; then
  mkdir -p "$WORK/r-oc/$SUPDIR"; cp -R "$REPO/EFI" "$WORK/r-oc/$SUPDIR/EFI"
  component ua.local.z97.opencore "$WORK/r-oc" opencore-postinstall z97-opencore.pkg
  LINES="<line choice=\"oc\"/>$LINES"
  CHOICES="<choice id=\"oc\" title=\"Завантажувач OpenCore\" description=\"OpenCore на розділ EFI системного диска, якщо його там немає.\"><pkg-ref id=\"ua.local.z97.opencore\"/></choice>$CHOICES"
  REFS="<pkg-ref id=\"ua.local.z97.opencore\" version=\"$V\" onConclusion=\"none\">z97-opencore.pkg</pkg-ref>$REFS"
fi
cp "$HERE/resources/"*.html "$WORK/res/"
cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Драйвери ASUS Z97 · i7-4770K · RX 570</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <options customize="allow" require-scripts="false" hostArchitectures="x86_64" rootVolumeOnly="true"/>
  <domains enable_localSystem="true"/>
  <choices-outline>$LINES</choices-outline>
  $CHOICES
  $REFS
</installer-gui-script>
XML
OUT="$REPO/dist/Z97-Haswell-Drivers-$V.pkg"; [ $WITH_EFI = 1 ] && OUT="$REPO/dist/Z97-Haswell-Drivers-with-EFI-$V.pkg"
productbuild --distribution "$WORK/distribution.xml" --resources "$WORK/res" --package-path "$WORK/comp" "$OUT" >/dev/null
echo "Готово: $OUT"
