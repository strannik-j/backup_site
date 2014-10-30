#!/bin/bash
SITE_DIR='/home/www-data/www/example.com'
BACK_DIR='/home/www-data/$R_USER/example.com'
DB_NAME='example'
DB_USER='root'
DB_PASS='123456789'
DATE_NOW=`date +%Y-%m-%d.%H_%M_%S`

#Move $R_USER to remote server? (TRUE/FALSE)
MOVE_SCP='FALSE'

#Archivators configs
CORES=`nproc`
A_PBZIP2='pbzip2 -k -p'$CORES' -c '
A_PGZIP='pbzip -k -p'$CORES' -c '
A_BZIP2='bzip2 -c' 
A_GZIP='gzip -c'

#Remote server config
#Connetion over SCP with RSA key or password
R_HOST='192.168.0.1'
R_PORT=22
R_USER='backups'
R_PATH='/home/backups/archives'

###############
# DO NOT EDIT #
###############
if (test -e /usr/bin/pbzip2);then ARCHIVATOR=$A_PBZIP2 EXTRACTOR='bzcat' SUF='bz';\
elif (test -e /usr/bin/pgzip);then ARCHIVATOR=$A_PGZIP EXTRACTOR='gzcat' SUF='gz';\
elif (test -e /bin/bzip2);then ARCHIVATOR=$A_BZIP2 EXTRACTOR='bzcat' SUF='bz';\
elif (test -e /bin/gzip);then ARCHIVATOR=$A_GZIP EXTRACTOR='gzcat' SUF='gz';\
fi
###
echo "*************************"
echo "Start save site to backup"
time tar -P -c $SITE_DIR/* --exclude=.git --exclude=.gitignore --exclude=*.gz --exclude=*.tgz --exclude=*.bz --exclude=*.tbz --exclude=*.xz --exclude=*.txz --exclude=*.tar | $ARCHIVATOR > $BACK_DIR'/site.back.'$DATE_NOW'.t'$SUF
echo "***********************"
echo "Start save DB to backup"
time mysqldump -u $DB_USER -p$DB_PASS $DB_NAME | $ARCHIVATOR > $BACK_DIR'/dump.sql.'$DATE_NOW'.'$SUF
echo "**************"
echo "Archives size:"
echo ""
ls -l -h $BACK_DIR/dump.sql.$DATE_NOW.$SUF | cut --bytes=31- -
ls -l -h $BACK_DIR/site.back.$DATE_NOW.t$SUF | cut --bytes=31- -
sha512sum $BACK_DIR/site.back.$DATE_NOW.t$SUF $BACK_DIR/dump.sql.$DATE_NOW.$SUF > $BACK_DIR/sha512_$DATE_NOW.txt
if [ $MOVE_SCP = 'TRUE' ] ; then scp -P $R_PORT $BACK_DIR/dump.sql.$DATE_NOW.$SUF $BACK_DIR/site.back.$DATE_NOW.t$SUF $R_USER@$R_HOST:$R_PATH/ && rm $BACK_DIR/dump.sql.$DATE_NOW.$SUF $BACK_DIR/site.back.$DATE_NOW.t$SUF && echo "Archives moved" ; fi
################
# RESTORE FILE #
################
echo "#!/bin/bash" > $BACK_DIR/restore.$DATE_NOW.sh
echo "# RESTORE SITE AND DB" >> $BACK_DIR/restore.$DATE_NOW.sh
if [ $MOVE_SCP = "TRUE" ] ; then \
echo "scp -P $R_PORT $R_USER@$R_HOST:$R_PATH/dump.sql.$DATE_NOW.$SUF $BACK_DIR/" >> $BACK_DIR/restore.$DATE_NOW.sh;
echo "scp -P $R_PORT $R_USER@$R_HOST:$R_PATH/site.back.$DATE_NOW.t$SUF $BACK_DIR/" >> $BACK_DIR/restore.$DATE_NOW.sh;
else echo "";
fi
echo "sha512sum -c $BACK_DIR/sha512_$DATE_NOW.txt || echo 'Archives is NOT correct. STOP' exit 0" >> $BACK_DIR/restore.$DATE_NOW.sh;
echo "echo 'Archives is correct. Start restore'" >> $BACK_DIR/restore.$DATE_NOW.sh;
echo "tar -P --"$SUF" -xf "$BACK_DIR"/site.back."$DATE_NOW".t"$SUF" && echo 'SITE archive extracted'" >> $BACK_DIR/restore.$DATE_NOW.sh;
echo $SUF"cat "$BACK_DIR"/dump.sql."$DATE_NOW"."$SUF" | mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME"&& echo 'DB archive extracted' && rm cat "$BACK_DIR"/dump.sql."$DATE_NOW"."$SUF $BACK_DIR"/site.back."$DATE_NOW".t"$SUF >> $BACK_DIR/restore.$DATE_NOW.sh;
chmod +x $BACK_DIR/restore.$DATE_NOW.sh

exit 0
