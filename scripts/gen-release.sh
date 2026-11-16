#!/usr/bin/env bash
set -euo pipefail

FILES=(Packages "Packages.gz" "Packages.bz2")

cat <<EOF
Origin: Duo Tweak Repo
Label: Duo Tweak Repo
Suite: stable
Codename: stable
Version: 1.0
Architectures: iphoneos-arm64
Components: main
Description: Repo voor de Duo Tweak (Sileo)
Date: $(date -R)

MD5Sum:
EOF
for f in "${FILES[@]}"; do
	h=$(md5sum "$f" | cut -d' ' -f1)
	s=$(stat -c%s "$f")
	echo " $h $s $f"
done
echo "SHA1:"
for f in "${FILES[@]}"; do
	h=$(sha1sum "$f" | cut -d' ' -f1)
	s=$(stat -c%s "$f")
	echo " $h $s $f"
done
echo "SHA256:"
for f in "${FILES[@]}"; do
	h=$(sha256sum "$f" | cut -d' ' -f1)
	s=$(stat -c%s "$f")
	echo " $h $s $f"
done
