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
	dir = /usr/share/nginx/html/quilky
echo "Creating PostgreSQL user and database..."
			psql -U postgres -c "CREATE USER ${POSTGRES_DBUSER} WITH ENCRYPTED PASSWORD '${POSTGRES_DBPASS}'"
			if [ $? != 0 ]
			then
				echo "PostgreSQL user creation failed with error code 35 "
				#exit 1
			fi
			psql -U postgres -c "CREATE DATABASE ${POSTGRES_DBNAME} OWNER ${POSTGRES_DBUSER} ENCODING 'UTF8' TEMPLATE template0"
			if [ $? != 0 ]
			then
				echo "PostgreSQL database creation failed with error code 36"
				#exit 1
			fi
			psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;"
			if [ $? != 0 ]
			then
				echo "PostgreSQL extension creation failed with error code 37"
				#exit 1
			fi
			psql -U postgres -c "COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';"
			if [ "$?" = 0 ];
			then
				echo "Importing empty SQL..."
				psql -d ${POSTGRES_DBNAME} -f "$dir/sql/restyaboard_with_empty_data.sql" -U ${POSTGRES_DBUSER}
				if [ $? != 0 ]
				then
					echo "PostgreSQL Empty SQL importing failed with error code 39"
				#	exit 1
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