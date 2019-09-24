script_path="$(cd "$(dirname "$0")" && pwd)"
source ${script_path}/config.sh

#params
if [ ! -n "${1}" ]
then
  echo 'environment name cannot be empty'
fi
if [ ! -n "${2}" ]
then
  echo 'tenant name cannot be empty'
fi

date_time=$(date +'%Y%m%d')
oneDayBefore=$(date -d"-1 day" +'%Y%m%d')
twoDayBefore=$(date -d"-2 day" +'%Y%m%d')
threeDayBefore=$(date -d"-3 day" +'%Y%m%d')

sourceserver="${1,,}server"
targetserver="${1,,}rpt"
sourcedbname="lportal_$2"
targetdbname="rpt_hsf"
originalschemaname="hsf_app_2019_reder_eva_test"
schemaname=${originalschemaname:0:37}
username="liferay"
password="AugDev4Hsf1!"
threadsNum="3"

#true/false
isDumpNormalstage="false"
programid="101935856"
stageid="6"

#If no dependentstageid, dependentstageid set 0
dependentstageid="0"
#running/done
status="''"
childstagename="Evaluations"
childstatus="''"

formsList="Reader_Evaluation_Quiz_Form_1_DDL Reader_Evaluation_Cumulative_Questions_DDL Reader_Evaluation_Flag_DDL Reader_Evaluation_Highlight_DDL"
tableNameList="users_roles role_"

logSchemaName="log_etl"
scriptname="doSingleHSFReaderEva2019Test.sh"

#rpt folder name
rptFolderName="${targetdbname}"
schmaFolderName="${schemaname}"

oneDayBeforeFolderName="${schmaFolderName}_${oneDayBefore}"

currentfolderPath="${script_path}/${rptFolderName}/${schemaname}"
oneDayBeforeFolderPath="${script_path}/${rptFolderName}/${oneDayBeforeFolderName}"
executeSQLPath="${currentfolderPath}/table"

#check dump view success
dumpView=(`psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "select status from ${logSchemaName}.etl_job where script_name = 'dumpView.sh' order by start_time desc limit 1"`)
dumpViewResult=${dumpView[2]}
echo "dump view result:"${dumpViewResult}
if [ ! "success" = "${dumpViewResult}" ]
then
  echo 'dump view not success'
  exit
fi

#process get current schema folder modified time
if [ -d "${currentfolderPath}" ]
then
    #get folder modified time
    echo "${schemaname} folder already exists"
    lastModifiedTime=$(stat ${currentfolderPath}|grep -i Modify | awk '{print $2}'| awk -F- '{print $1$2$3}')
else
    echo "${schemaname} folder is not exists"
    lastModifiedTime=0
fi
echo "${schemaname} folder lastModified time:${lastModifiedTime}"

#rename current schema folder to one Day Before Folder name
if [[ ${datetime} != ${lastModifiedTime} ]]
then
  #rename currentfolderName to oneDayBeforeTargetdbname
  if [ -d "${currentfolderPath}" ]
  then
    echo "rename foldername to one Day Before Folder name"
    mv ${currentfolderPath} ${oneDayBeforeFolderPath}
  fi
fi

#create database reporter
echo "create report database ${targetdbname}"
result=`psql -h ${!targetserver} "user=${username} password=${password}" -c "create database ${targetdbname}"`

#create etl history schema and etl_job table
psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "create schema ${logSchemaName}"

echo "create sequence etl_log_sequence"
psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "CREATE SEQUENCE if not exists ${logSchemaName}.etl_log_sequence;"

echo "create table etl_job"
psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "CREATE TABLE if not exists ${logSchemaName}.etl_job
(
  pkid bigint NOT NULL DEFAULT nextval('${logSchemaName}.etl_log_sequence'::regclass),
  start_time timestamp without time zone,
  end_time timestamp without time zone,
  status text,
  rpt_db_name text,
  schema_name text,
  script_name text,
  CONSTRAINT etl_main_pkey PRIMARY KEY (pkid)
);"
nowdate=`date`
psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "insert into ${logSchemaName}.etl_job (start_time, status, rpt_db_name, schema_name, script_name) values ('${nowdate}', 'running', '${targetdbname}', '${schemaname}', '${scriptname}');"

etlIdResult=(`psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "select pkid from ${logSchemaName}.etl_job where script_name = '${scriptname}' and rpt_db_name = '${targetdbname}' and schema_name = '${schemaname}' order by start_time desc limit 1"`)
etlId=${etlIdResult[2]}
echo "etlid=${etlIdResult[2]}"

#convert to csv files
echo "application data"
java -jar "${script_path}/MainDumpTest.jar" ${script_path} ${!sourceserver} ${sourcedbname} ${schemaname} ${!targetserver} ${targetdbname} ${logSchemaName} ${username} ${password} ${threadsNum} ${etlId} ${programid} ${isDumpNormalstage} ${stageid} ${status} ${dependentstageid} ${childstagename} ${childstatus} ${targetdbname} ${formsList}

#log
echo "dump param: "${script_path} ${!sourceserver} ${sourcedbname} ${schemaname} ${!targetserver} ${targetdbname} ${logSchemaName} ${username} ${password} ${threadsNum} ${etlId} ${programid} ${isDumpNormalstage} ${stageid} ${status} ${dependentstageid} ${childstagename} ${childstatus} ${targetdbname} ${formsList}

#delete yesterday schema folder
if [ -d "${currentfolderPath}" ]
  then
    echo "delete folder"
    rm -rf ${oneDayBeforeFolderPath}
    echo "delete folder"
fi

#create schema
result=`psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "create schema ${schemaname}"`
flag=$?
if [[ ${flag} != 0 ]]
then
    echo "drop schema and create schema"
    #psql -h ${!targetserver} "user=${username} password=${password}" -c "select pg_terminate_backend(pg_stat_activity.pid) from pg_stat_activity where datname='${targetdbname}' AND pid<>pg_backend_pid()";
    psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "drop schema ${schemaname} cascade"
    psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "create schema ${schemaname}"
fi

#import to database
java -jar "${script_path}/MainProcess.jar" ${script_path} ${!targetserver} ${targetdbname} ${schemaname} ${username} ${password} ${etlId} ${logSchemaName}

#log
echo "process param: " ${script_path} ${!targetserver} ${targetdbname} ${schemaname} ${username} ${password} ${etlId} ${logSchemaName}

#create folder for export form script
if [ -d "${executeSQLPath}" ]
then
  rm -rf ${executeSQLPath}
else
  mkdir ${executeSQLPath}
fi

#get ETL log jobDetailId
jobDetailIdResult=(`psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "select pkid from ${logSchemaName}.job_detail where etlid=${etlId}"`)
jobDetailId=${jobDetailIdResult[2]}

#log
echo jobDetailId=${jobDetailId}

#import table to database
for tableName in ${tableNameList}
do
    #dump
    echo "Begin dump ${tableName} table"
    dumpResult=`PGPASSWORD="${password}" pg_dump -h ${!sourceserver} --encoding=utf8 --no-owner -U ${username} ${sourcedbname} -t ${tableName} > ${executeSQLPath}/${tableName}.sql`
    dumpFlag=$?
    echo ${dumpFlag}
    if [[ ${dumpFlag} == 0 ]]
    then

        #update sql file remove schemaname
        #For psql 9.5.2
        #sed -i "s/SET search_path = public, pg_catalog/SET search_path = ${schemaname}, public, pg_catalog/" ${executeSQLPath}/${tableName}.sql

        #For psql 9.5.13
        sed -i "s/public.//" ${executeSQLPath}/${tableName}.sql
        sed -i "s/SELECT pg_catalog.set_config('search_path', '', false)/SELECT pg_catalog.set_config('search_path', '${schemaname}', false)/" ${executeSQLPath}/${tableName}.sql

        #restore
        echo "Begin execute ${tableName}.sql"
        psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "\i ${executeSQLPath}/${tableName}.sql"
        echo "restore end"

        dumpCountResult=(`psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "select count(*) from ${schemaname}.${tableName}"`)
        psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "insert into ${logSchemaName}.insert_detail (job_detail_id, schema_name, table_name, table_record_count) values (${jobDetailId}, '${schemaname}', '${tableName}', ${dumpCountResult[2]}) "
    fi
done

nowdate=`date`

psql "host=${!targetserver} dbname=${targetdbname} user=${username} password=${password}" -c "update ${logSchemaName}.etl_job e set end_time = '${nowdate}', status = case when dump_status = 'success' and insert_status = 'success' then 'success' else 'failed' end from ${logSchemaName}.etl_job ej left join ${logSchemaName}.job_detail jd on jd.etlid = ej.pkid where ej.pkid = e.pkid and ej.pkid = ${etlId}"

#notification
#source ${script_path}/etlNotification.sh

PGPASSWORD="${password}" psql -h ${!targetserver} -U ${username} ${targetdbname} -c "GRANT USAGE ON SCHEMA ${schemaname} TO rpt_user"

PGPASSWORD="${password}" psql -h ${!targetserver} -U ${username} ${targetdbname} -c "GRANT SELECT ON ALL TABLES IN SCHEMA ${schemaname} TO rpt_user"

