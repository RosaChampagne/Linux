script_path="$(cd "$(dirname "$0")" && pwd)"
declare -a DATETIME=$(date +'%Y%m%d')
declare -a OUTPUT_FILE=etl_applicant_gates_cohort2_TGSSI_PostConferece_Survey.$DATETIME.log

touch ${script_path}/$OUTPUT_FILE

startdate=`date +"%Y-%m-%d %H:%M"`
echo 'Star time : '$startdate >> ${script_path}/$OUTPUT_FILE 2>&1

##gates shell for 2018-2019

###Daily
sh ${script_path}/etl_applicant_bash/conference_finance_app_2019_test.sh prod hsf >> ${script_path}/$OUTPUT_FILE 2>&1
sh ${script_path}/etl_applicant_bash/doSingleHSFReaderEva2019Test.sh prod hsf >> ${script_path}/$OUTPUT_FILE 2>&1

#script_path="$(cd "$(dirname "$0")" && pwd)"
#current_date="$(date +%Y)"
#last_date="$(date -d last-year +%Y)"
#current_day="$(date +%Y%m%d)"
#before_one_day="$(date -d "-1 day" +%Y%m%d)"
#before_two_day="$(date -d "-2 day" +%Y%m%d)"

#for file in `cd "$(dirname "$0")" && ls ${!script_path}`
#do
#    if [[ (${file} == *"${current_date}"* || ${file} == *"${last_date}"*) && ${file} != *"${current_day}"* && ${file} != *"${before_one_day}"* && ${file} != *"${before_two_day}"* && ${file} != *"2018_2019"* && ${file} != *"2017_2018"* ]]; then
#         echo "remove folder ${file}"
#         `cd "$(dirname "$0")" && rm -rf ${file}`
#    fi
#done

### Remove log file
sh ${script_path}/remove_temp_file.sh >> ${script_path}/$OUTPUT_FILE 2>&1