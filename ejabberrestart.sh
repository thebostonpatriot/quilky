	RESTYABOARD_VERSION=$(curl --silent https://api.github.com/repos/RestyaPlatform/board/releases | grep tag_name -m 1 | awk '{print $2}' | sed -e 's/[^v0-9.]//g')
	POSTGRES_DBHOST=localhost
	POSTGRES_DBNAME=restyaboard
	POSTGRES_DBUSER=restya
	POSTGRES_DBPASS=hjVl2!rGd
	POSTGRES_DBPORT=5432
	EJABBERD_DBHOST=localhost
	EJABBERD_DBNAME=ejabberd
	EJABBERD_DBUSER=ejabb
	EJABBERD_DBPASS=ftfnVgYl2
	EJABBERD_DBPORT=5432
	DOWNLOAD_DIR=/opt/restyaboard
	
	set +x
	echo "Enter your document root (where your Restyaboard to be installed. e.g., /usr/share/nginx/html/restyaboard):"
	read -r dir
	while [[ -z "$dir" ]]
	do
		read -r -p "Enter your document root (where your Restyaboard to be installed. e.g., /usr/share/nginx/html/restyaboard):" dir
	done
	set -x
	echo "$dir"

	cd /opt
	wget http://liquidtelecom.dl.sourceforge.net/project/expat/expat/2.1.1/expat-2.1.1.tar.bz2
	tar -jvxf expat-2.1.1.tar.bz2
	cd expat-2.1.1/
	./configure
	make
	make install

	cd /opt
	wget https://www.process-one.net/downloads/ejabberd/15.07/ejabberd-15.07.tgz
	tar -zvxf ejabberd-15.07.tgz
	cd ejabberd-15.07
	./autogen.sh
	./configure --enable-pgsql
	make
	make install

	cd /etc/ejabberd
	echo "Creating ejabberd user and database..."
	psql -U postgres -c "CREATE USER ${EJABBERD_DBUSER} WITH ENCRYPTED PASSWORD '${EJABBERD_DBPASS}'"

	cd /etc/ejabberd
	psql -U postgres -c "CREATE DATABASE ${EJABBERD_DBNAME}"

	psql -d ${EJABBERD_DBNAME} -f "/opt/ejabberd-15.07/sql/pg.sql" -U postgres
	mv $dir/ejabberd.yml /etc/ejabberd/ejabberd.yml
	chmod -R go+w "/etc/ejabberd/ejabberd.yml"
	sed -i 's/restya.com/'$webdir'/g' /etc/ejabberd/ejabberd.yml
	sed -i 's/ejabberd15/'${EJABBERD_DBNAME}'/g' /etc/ejabberd/ejabberd.yml
	
	ejabberdctl start
	sleep 15
	ejabberdctl change_password admin $webdir restya
	ejabberdctl stop
	sleep 15
	ejabberdctl start
	
	echo "Starting services..."
	service cron restart
	service php5-fpm restart
	service nginx restart
	service postfix restart
	service elasticsearch restart