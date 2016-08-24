RESTYABOARD_VERSION = 0.3
echo "Downloading Restyaboard script..."
			mkdir /opt/restyaboard
			curl -v -L -G -d "app=board&ver=${RESTYABOARD_VERSION}" -o /tmp/restyaboard.zip http://restya.com/download.php
			unzip /tmp/restyaboard.zip -d /opt/restyaboard
			cp /opt/restyaboard/restyaboard.conf /etc/nginx/conf.d
			rm /tmp/restyaboard.zip
			
			set +x
			echo "To configure nginx, enter your domain name (e.g., www.example.com, 192.xxx.xxx.xxx, etc.,):"
			read -r webdir
			while [[ -z "$webdir" ]]
			do
				read -r -p "To configure nginx, enter your domain name (e.g., www.example.com, 192.xxx.xxx.xxx, etc.,):" webdir
			done
			set -x
			echo "$webdir"
			echo "Changing server_name in nginx configuration..."
			sed -i "s/server_name.*$/server_name \"$webdir\";/" /etc/nginx/conf.d/restyaboard.conf
			sed -i "s|listen 80.*$|listen 80;|" /etc/nginx/conf.d/restyaboard.conf
			
			set +x
			echo "Enter your document root (where your Restyaboard to be installed. e.g., /usr/share/nginx/html/restyaboard):"
			read -r dir
			while [[ -z "$dir" ]]
			do
				read -r -p "Enter your document root (where your Restyaboard to be installed. e.g., /usr/share/nginx/html/restyaboard):" dir
			done
			set -x
			echo "$dir"
			mkdir -p "$dir"
			echo "Changing root directory in nginx configuration..."
			sed -i "s|root.*html|root $dir|" /etc/nginx/conf.d/restyaboard.conf
			echo "Copying Restyaboard script to root directory..."
			cp -r /opt/restyaboard/* "$dir"
			
			echo "Installing postfix..."
			echo "postfix postfix/mailname string $webdir"\
			| debconf-set-selections &&\
			echo "postfix postfix/main_mailer_type string 'Internet Site'"\
			| debconf-set-selections &&\
			apt-get install -y postfix
			        if [ $? != 0 ]
				then
					echo "-y postfix installation failed with error code 16"
					exit 1
				fi
			echo "Changing permission..."
			chmod -R go+w "$dir/media"
			chmod -R go+w "$dir/client/img"
			chmod -R go+w "$dir/tmp/cache"
			chmod -R 0755 $dir/server/php/shell/*.sh

			psql -U postgres -c "\q"
			if [ $? != 0 ]
			then
				echo "PostgreSQL Changing the permission failed with error code 34"
				exit 1
			fi
			sleep 1

			echo "Creating PostgreSQL user and database..."
			psql -U postgres -c "CREATE USER ${POSTGRES_DBUSER} WITH ENCRYPTED PASSWORD '${POSTGRES_DBPASS}'"
			if [ $? != 0 ]
			then
				echo "PostgreSQL user creation failed with error code 35 "
				exit 1
			fi
			psql -U postgres -c "CREATE DATABASE ${POSTGRES_DBNAME} OWNER ${POSTGRES_DBUSER} ENCODING 'UTF8' TEMPLATE template0"
			if [ $? != 0 ]
			then
				echo "PostgreSQL database creation failed with error code 36"
				exit 1
			fi
			psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;"
			if [ $? != 0 ]
			then
				echo "PostgreSQL extension creation failed with error code 37"
				exit 1
			fi
			psql -U postgres -c "COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';"
			if [ "$?" = 0 ];
			then
				echo "Importing empty SQL..."
				psql -d ${POSTGRES_DBNAME} -f "$dir/sql/restyaboard_with_empty_data.sql" -U ${POSTGRES_DBUSER}
				if [ $? != 0 ]
				then
					echo "PostgreSQL Empty SQL importing failed with error code 39"
					exit 1
				fi
			fi
			
			echo "Changing PostgreSQL database name, user and password..."
			sed -i "s/^.*'R_DB_NAME'.*$/define('R_DB_NAME', '${POSTGRES_DBNAME}');/g" "$dir/server/php/config.inc.php"
			sed -i "s/^.*'R_DB_USER'.*$/define('R_DB_USER', '${POSTGRES_DBUSER}');/g" "$dir/server/php/config.inc.php"
			sed -i "s/^.*'R_DB_PASSWORD'.*$/define('R_DB_PASSWORD', '${POSTGRES_DBPASS}');/g" "$dir/server/php/config.inc.php"
			sed -i "s/^.*'R_DB_HOST'.*$/define('R_DB_HOST', '${POSTGRES_DBHOST}');/g" "$dir/server/php/config.inc.php"
			sed -i "s/^.*'R_DB_PORT'.*$/define('R_DB_PORT', '${POSTGRES_DBPORT}');/g" "$dir/server/php/config.inc.php"
			
			echo "Setting up cron for every 5 minutes to update ElasticSearch indexing..."
			echo "*/5 * * * * $dir/server/php/shell/indexing_to_elasticsearch.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 5 minutes to send email notification to user, if the user chosen notification type as instant..."
			echo "*/5 * * * * $dir/server/php/shell/instant_email_notification.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 1 hour to send email notification to user, if the user chosen notification type as periodic..."
			echo "0 * * * * $dir/server/php/shell/periodic_email_notification.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 30 minutes to fetch IMAP email..."
			echo "*/30 * * * * $dir/server/php/shell/imap.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 5 minutes to send activities to webhook..."
			echo "*/5 * * * * $dir/server/php/shell/webhook.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 5 minutes to send email notification to past due..."
			echo "*/5 * * * * $dir/server/php/shell/card_due_notification.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 5 minutes to send chat conversation as email notification to user..."
			echo "*/5 * * * * $dir/server/php/shell/chat_activities.sh" >> /var/spool/cron/crontabs/root
			
			echo "Setting up cron for every 1 hour to send chat conversation as email notification to user, if the user chosen notification type as periodic..."
			echo "0 * * * * $dir/server/php/shell/periodic_chat_email_notification.sh" >> /var/spool/cron/crontabs/root