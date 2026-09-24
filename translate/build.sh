#!/bin/sh
# Compile .po files into .mo (adapted for metadata.json)

DIR=$(cd "$(dirname "$0")" && pwd)
cd "${DIR}"

plasmoidName=$(python3 -c "import json; print(json.load(open('${DIR}/../metadata.json'))['KPlugin']['Id'])" 2>/dev/null)

if [ -z "$plasmoidName" ]; then
	plasmoidName=$(grep -o '"Id"[[:space:]]*:[[:space:]]*"[^"]*"' "${DIR}/../metadata.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi

projectName="plasma_applet_${plasmoidName}"

if [ -z "$plasmoidName" ]; then
	echo "[build] Error: Couldn't read plasmoidName from metadata.json."
	exit 1
fi

echo "[build] Compiling messages"

catalogs=$(find . -name '*.po' | sort)
for cat in $catalogs; do
	echo "$cat"
	catLocale=$(basename "${cat%.*}")
	msgfmt -o "${catLocale}.mo" "$cat"

	installPath="$DIR/../contents/locale/${catLocale}/LC_MESSAGES/${projectName}.mo"

	echo "[build] Install to ${installPath}"
	mkdir -p "$(dirname "$installPath")"
	mv "${catLocale}.mo" "${installPath}"
done

echo "[build] Done building messages"
