#!/bin/sh
# Extract messages and merge into .po files (adapted for metadata.json)

DIR=$(cd "$(dirname "$0")" && pwd)
cd "${DIR}"

plasmoidName=$(python3 -c "import json; print(json.load(open('${DIR}/../metadata.json'))['KPlugin']['Id'])" 2>/dev/null)
website=$(python3 -c "import json; print(json.load(open('${DIR}/../metadata.json'))['KPlugin']['Website'])" 2>/dev/null)

if [ -z "$plasmoidName" ]; then
	# Fallback without python
	plasmoidName=$(grep -o '"Id"[[:space:]]*:[[:space:]]*"[^"]*"' "${DIR}/../metadata.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
	website=$(grep -o '"Website"[[:space:]]*:[[:space:]]*"[^"]*"' "${DIR}/../metadata.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi

widgetName="${plasmoidName##*.}"
bugAddress="${website}"
packageRoot=".."
projectName="plasma_applet_${plasmoidName}"

if [ -z "$plasmoidName" ]; then
	echo "[merge] Error: Couldn't read plasmoidName from metadata.json."
	exit 1
fi

echo "[merge] Extracting messages"
find "${packageRoot}" \( -name '*.cpp' -o -name '*.h' -o -name '*.c' -o -name '*.qml' -o -name '*.js' \) | sort > "${DIR}/infiles.list"

xgettext \
	--files-from=infiles.list \
	--from-code=UTF-8 \
	--width=400 \
	--add-location=file \
	-C -kde -ci18n -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 -ktr2i18n:1 -kI18N_NOOP:1 \
	-kI18N_NOOP2:1c,2 -kN_:1 -kaliasLocale -kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
	--package-name="${widgetName}" \
	--msgid-bugs-address="${bugAddress}" \
	-D "${packageRoot}" \
	-D "${DIR}" \
	-o "template.pot.new" \
	|| { echo "[merge] error while calling xgettext. aborting."; exit 1; }

sed -i 's/"Content-Type: text\/plain; charset=CHARSET\\n"/"Content-Type: text\/plain; charset=UTF-8\\n"/' "template.pot.new"
sed -i 's/# SOME DESCRIPTIVE TITLE./'"# Translation of ${widgetName} in LANGUAGE"'/' "template.pot.new"
sed -i 's/# Copyright (C) YEAR THE PACKAGE'"'"'S COPYRIGHT HOLDER/'"# Copyright (C) $(date +%Y)"'/' "template.pot.new"

if [ -f "template.pot" ]; then
	newPotDate=$(grep "POT-Creation-Date:" template.pot.new | sed 's/.\{3\}$//')
	oldPotDate=$(grep "POT-Creation-Date:" template.pot | sed 's/.\{3\}$//')
	sed -i 's/'"${newPotDate}"'/'"${oldPotDate}"'/' "template.pot.new"
	changes=$(diff "template.pot" "template.pot.new" || true)
	if [ ! -z "$changes" ]; then
		sed -i 's/'"${oldPotDate}"'/'"${newPotDate}"'/' "template.pot.new"
		mv "template.pot.new" "template.pot"
		addedKeys=$(echo "$changes" | grep "> msgid" | cut -c 9- | sort)
		removedKeys=$(echo "$changes" | grep "< msgid" | cut -c 9- | sort)
		echo ""
		echo "Added Keys:"
		echo "$addedKeys"
		echo ""
		echo "Removed Keys:"
		echo "$removedKeys"
		echo ""
	else
		rm "template.pot.new"
	fi
else
	mv "template.pot.new" "template.pot"
fi

rm -f "${DIR}/infiles.list"
echo "[merge] Done extracting messages"

echo "[merge] Merging messages"
catalogs=$(find . -name '*.po' | sort)
for cat in $catalogs; do
	echo "[merge] $cat"
	catLocale=$(basename "${cat%.*}")
	msgmerge \
		--width=400 \
		--add-location=file \
		--no-fuzzy-matching \
		-o "$cat.new" \
		"$cat" "${DIR}/template.pot"
	sed -i 's/# SOME DESCRIPTIVE TITLE./'"# Translation of ${widgetName} in ${catLocale}"'/' "$cat.new"
	sed -i 's/# Translation of '"${widgetName}"' in LANGUAGE/'"# Translation of ${widgetName} in ${catLocale}"'/' "$cat.new"
	sed -i 's/# Copyright (C) YEAR THE PACKAGE'"'"'S COPYRIGHT HOLDER/'"# Copyright (C) $(date +%Y)"'/' "$cat.new"
	mv "$cat.new" "$cat"
done

echo "[merge] Done merging messages"
