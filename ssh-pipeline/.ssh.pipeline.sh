#!/bin/bash
echo "Configuring SSH keys...";

BASEDIR=$(dirname "$0");
TARGETDIR='.ssh';

echo "$BASEDIR --> $TARGETDIR";

echo Moving files...
find $BASEDIR -type f -name 'ssh-*' | while read f; do
	fileName=$(basename -- "$f");
	fileNameWoExt="${fileName%.*}";
	echo "$f";

	if [[ "$f" =~ .*[.]config ]]; then
		# Append ssh config.
		echo $fileNameWoExt
		sudo sed "s|\(IdentityFile\)\s*\(.*\)$|\1 $TARGETDIR/$fileNameWoExt|" $f >> $TARGETDIR/config;
		rm "$f";
	else
		# Move ssh files.
		mv "$f" $TARGETDIR;
		if [[ $f =~ ^[^.]*$ ]]; then
			chmod go-rw "$TARGETDIR/$fileName";
		else
			chmod go-rw "$TARGETDIR/$fileName";
		fi
	fi
done

echo Checking key...
ssh -T git@github.com -o StrictHostKeyChecking=no;

echo Cleaning files...;
rm "$0";
echo Done;
