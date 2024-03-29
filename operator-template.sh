#!/bin/bash

CONTAINER=$1
INDEX=$(echo $2 | cut -d ',' -f 1)
FILE_NAME=$(echo $2 | cut -d ',' -f 2)
FILE_TYPE=$(echo $2 | cut -d ',' -f 3)
CONNECTION_NAME=$(echo $2 | cut -d ',' -f 4)
TABLE_NAME=$FILE_NAME

if test "$PRECISION100_RUNTIME_SIMULATION_MODE" = "TRUE"; then
   echo "        START SMART-MAP-FILE ADAPTOR $FILE_NAME"
   sleep $PRECISION100_RUNTIME_SIMULATION_SLEEP;
   echo "        END SMART-MAP-FILE ADAPTOR $FILE_NAME"
   exit;
fi

echo "        START SMART-MAP-FILE ADAPTOR $FILE_NAME"
source $PRECISION100_OPERATORS_FOLDER/smart-map-file/conf/.operator.env.sh

$PRECISION100_BIN_FOLDER/audit.sh  $0 "PRE-SMART-MAP-FILE" "$CONTAINER / $FILE_NAME" "SMART-MAP-FILE" $0 "START"

SOURCE_FILE="$PRECISION100_EXECUTION_CONTAINER_FOLDER/$CONTAINER/$TABLE_NAME.$MAP_FILE_FILE_SUFFIX"
PREFIX="$PRECISION100_OPERATOR_SMART_MAP_FILE_WORK_FOLDER/$TABLE_NAME-XX"
SUFFIX="%d.$MAP_FILE_FILE_SUFFIX"
UNION_DELIMITER="/__UNION__\|__UNIONALL__/"

CONNECTION_STRING=$($PRECISION100_BIN_FOLDER/get-connection-string.sh "$CONNECTION_NAME")

function execute_sql() {
sqlplus -s /nolog << EOL
CONNECT $CONNECTION_STRING
SET FEEDBACK OFF
@$1
exit
EOL
}

csplit -s -b "$SUFFIX" -f "$PREFIX" --suppress-matched "$SOURCE_FILE" "$UNION_DELIMITER" {*}

counter=1
for SPLIT_FILE in $(ls $PREFIX*.$MAP_FILE_FILE_SUFFIX)
do
  JUST_FILE_NAME=$(basename $SPLIT_FILE)
  O_TABLE_SQL=$PRECISION100_OPERATOR_SMART_MAP_FILE_WORK_FOLDER/"${DEFAULT_TABLE_NAME_PREFIX}-${JUST_FILE_NAME}.sql"
  V_O_VIEW_SQL=$PRECISION100_OPERATOR_SMART_MAP_FILE_WORK_FOLDER/"${DEFAULT_VIEW_NAME_PREFIX}-${DEFAULT_TABLE_NAME_PREFIX}-${JUST_FILE_NAME}.sql"
  O_TAB_COLUMN_SQL=$PRECISION100_OPERATOR_SMART_MAP_FILE_WORK_FOLDER/"${DEFAULT_TABLE_NAME_PREFIX}-${DEFAULT_TAB_COLUMN_SUFFIX}-${JUST_FILE_NAME}.sql"
  TRANSFORM_SQL=$PRECISION100_OPERATOR_SMART_MAP_FILE_WORK_FOLDER/"${DEFAULT_TABLE_NAME_PREFIX}-${DEFAULT_TRANSFORM_SUFFIX}-${JUST_FILE_NAME}.sql"
  echo "        SMART-MAP-FILE ADAPTOR CREATING SPLIT SCRIPT $JUST_FILE_NAME"

  $PRECISION100_OPERATORS_FOLDER/smart-map-file/bin/map-file-split-template.sh $TABLE_NAME $SPLIT_FILE $O_TABLE_SQL $V_O_VIEW_SQL $O_TAB_COLUMN_SQL $TRANSFORM_SQL

  if [[ $counter = 1 ]]; then
     echo "        SMART-MAP-FILE ADAPTOR EXECUTING CATALOG SCRIPTS"
     execute_sql $O_TABLE_SQL
     execute_sql $V_O_VIEW_SQL
     execute_sql $O_TAB_COLUMN_SQL
  fi
  echo "        SMART-MAP-FILE ADAPTOR EXECUTING DATA SCRIPTS"
  execute_sql $TRANSFORM_SQL
  counter=$counter+1
done


$PRECISION100_BIN_FOLDER/audit.sh  $0 "POST-SMART-MAP-FILE" "$CONTAINER / $FILE_NAME" "SMART-MAP-FILE" $0 "END"

echo "        END SMART-MAP-FILE ADAPTOR $FILE_NAME"
