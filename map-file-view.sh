#!/bin/bash

REVERSE_TABLE_NAME_PREFIX=${DEFAULT_REVERSE_TABLE_NAME_PREFIX:-R}
TABLE_NAME_PREFIX=${DEFAULT_TABLE_NAME_PREFIX:-O}
VIEW_NAME_PREFIX=${DEFAULT_VIEW_NAME_PREFIX:-V}
COLUMN_NAME_INDEX=${DEFAULT_COLUMN_NAME_INDEX:-1}
DATA_TYPE_INDEX=${DEFAULT_DATA_TYPE_INDEX:-2}
MAX_LENGTH_INDEX=${DEFAULT_MAX_LENGTH_INDEX:-4}
MAPPING_TYPE_INDEX=${DEFAULT_MAPPING_TYPE_INDEX:-7}
MAPPING_VALUE_INDEX=${DEFAULT_MAPPING_VALUE_INDEX:-8}
MAP_FILE_DELIMITER=${DEFAULT_MAP_FILE_DELIMITER:-~}

TABLE_NAME=$1
SOURCE_FILE=$2

function get_column_definition() {
  v_column_name=$(echo ${1:0:30} | tr '[:lower:]' '[:upper:]')
  v_justification=$(echo ${2} | tr '[:lower:]' '[:upper:]')
  v_max_length=${3}

  case "$v_justification" in
   'RIGHT')
     echo " LPAD(NVL($v_column_name,' '),$v_max_length) $v_column_name "
    ;;
   *)
     echo " RPAD(NVL($v_column_name,' '),$v_max_length)  $v_column_name"
    ;;
  esac
}

function define_view() {
  echo "CREATE OR REPLACE VIEW ${1}_${2}_${3} AS "
  echo "SELECT "

  counter=0
  while IFS='~' read -r column_name old_column_name data_type max_length mapping_code mapping_value justification mandatory info1 info2 info3;
  do
    if [[ -z "$column_name" ]]; then
      continue;
    fi
    if [[ counter -eq 0 ]]; then
      counter=$counter+1;
      continue;
    fi
  
    if [[ counter -eq 1 ]]; then
      get_column_definition "$column_name" "$justification" $max_length
    else
      echo ", $(get_column_definition "$column_name" "$justification" $max_length) "
    fi
    counter=$counter+1;
  done < <(cat ${SOURCE_FILE} | tr '\t' '~' | tr -d '\r' | grep .)
  echo "FROM ${2}_${3} ;"
}

define_view ${VIEW_NAME_PREFIX} ${TABLE_NAME_PREFIX} ${TABLE_NAME}
define_view ${VIEW_NAME_PREFIX} ${REVERSE_TABLE_NAME_PREFIX} ${TABLE_NAME}
