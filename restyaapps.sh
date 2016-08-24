set +x
echo "Do you want to install Restyaboard apps (y/n)?"
read -r answer
set -x
case "${answer}" in
	[Yy])
	if ! hash jq 2>&-;
	then
		echo "Installing jq..."
		apt-get install jq
		if [ $? != 0 ]
		then
			echo "jq installation failed with error code 53"
			exit 1
		fi
	fi
	curl -v -L -G -o /tmp/apps.json https://raw.githubusercontent.com/RestyaPlatform/board-apps/master/apps.json
	chmod -R go+w "/tmp/apps.json"
	for fid in `jq -r '.[] | .id + "-v" + .version' /tmp/apps.json`
	do
		mkdir "$dir/client/apps"
		chmod -R go+w "$dir/client/apps"
		curl -v -L -G -o /tmp/$fid.zip https://github.com/RestyaPlatform/board-apps/releases/download/v1/$fid.zip
		unzip /tmp/$fid.zip -d "$dir/client/apps"
	done
esac