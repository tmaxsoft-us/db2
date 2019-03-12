#!/bin/bash

################################################################################
#                                 db2_access.sh                                #
#DESCRIPTION: This script is used to create a text file that is formattable in #
#             Excel. It reads in COBOL programs in the cobol_source directory  #
#             and searches for EXEC SQL statements                             #
#             Then, the script checks what kind of DB2 access is being invoked #
#             i.e. SELECT, INSERT, UPDATE, DELETE                              #
#             The output is a text file that includes 1 row per access         #
#             It includes, the COBOL file name, the table name, and type of    #
#             access                                                           #
#REQUIREMENTS: Change work_dir variable in the VARIABLES section               #
#AUTHOR: Matthew Koziel                                                        #
#DATE: 2019/03/11                                                              #
#USAGE: sh db2_access.sh                                                       #
################################################################################ 

################################################################################
#                                VARIABLES                                     #
#DESCRIPTION: Setting variables for this script                                #
################################################################################
work_dir="/home/oframe/YSW/db2_access_script"
cobol_source="${work_dir}/source"
cobol_source_cut="${work_dir}/inserts"
audit_log="${work_dir}/audit.log"
audit_log_sorted="${audit_log}.sorted"
regexp="INSERT[\s\d\t\n\v]*INTO[\s]*\w*"
has_ins=""
has_upd=""
has_sel=""
has_del=""

################################################################################
#                                FUNCTIONS                                     #
################################################################################

################################################################################
#                                find_select                                   #
#DESCRIPTION: This script finds the select statements in the COBOL source      #
################################################################################
find_select(){
  echo "...Finding all Select Statements"
  if [ -d $cobol_source_cut ];
    cd $cobol_source_cut
  else
    echo "The cobol_source_cut directory was not found"
    exit 10
  fi
  #For all the files in the cobol_source_cut directory
  for item in `ls`
  do
    #And if the File is not empty...
    if [ -s $item ]
      then
      table_list=`cat $item | grep -A60 "SELECT" | grep -A20 "FROM " | sed -n -e 's/^.*FROM //p' | awk '{print $1}'`
  
        for table in $table_list
        do
          if [ "$table" != "(" ] && ! [[ "$table" =~ ^[0-9]*$ ]]
          then
            has_sel="X"
            print_audit $item $table
            has_sel=""
          fi
        done
        #Great for Debugging, Uncomment below 4 lines
        #echo $item
        #echo $table_list
        #echo ""
        #echo ""
      fi
  done
  echo "Found all Select statements..."
}

################################################################################
#                               find_insert                                    #
#DESCRIPTION: This function finds the insert statements in the COBOL source    #
################################################################################
find_insert(){
  echo "Finding Insert Statements..."
  cd $cobol_source_cut
  for item in `ls $cobol_source_cut`
  do
    table_list=`cat $item | grep -A40 "INSERT" | grep "INTO " | sed -n -e 's/^.*INTO //p' | awk '{print $1}' | head -1`
    #echo $table_list

      if [ ! -z $table_list ]
      then
        has_ins="X"
        print_audit $item $table_list
        has_ins=""
      fi
  done
  echo "Found all Insert Statements..."
}

################################################################################
#                               find_update                                    #
#DESCRIPTION: this function finds the update statements in the COBOL source    #
################################################################################
find_update(){
echo "...Finding all Update Statements"
cd $cobol_source_cut
#For all the files in the cobol_source_cut directory
for item in `ls`
do
        #And if the File is not empty...
        if [ -s $item ]
        then
                table_list=`cat $item | grep -A2 "UPDATE " | sed -n -e 's/^.*UPDATE //p' | awk '{print $1}'`
                for table in $table_list
                do
                        if [ "$table" != "(" ] && ! [[ "$table" =~ ^[0-9]*$ ]]
                        then

                        has_upd="X"
                        print_audit $item $table
                        has_upd=""

                        fi
                done
                #Great for Debugging, Uncomment below 4 lines
                #echo $item
                #echo $table_list
                #echo ""
                #echo ""
        fi
done
echo "Found all Update Statements..."
}

################################################################################
#                               find_delete                                    #
#DESCRIPTION: this function finds the delete statements in the COBOL source    #
################################################################################
find_delete(){
  echo "...Finding all Delete Statements"
  cd $cobol_source_cut
  #For all the files in the cobol_source_cut directory
  for item in `ls`
  do
    #And if the File is not empty...
    if [ -s $item ]
    then
      table_list=`cat $item | grep -A60 "DELETE" | grep -A20 "FROM " | sed -n -e 's/^.*FROM //p' | awk '{print $1}'`

      for table in $table_list
      do
        if [ "$table" != "(" ] && ! [[ "$table" =~ ^[0-9]*$ ]]
        then

          has_del="X"
          print_audit $item $table
          has_del=""

        fi
      done
      #Great for Debugging, Uncomment below 4 lines
      #echo $item
      #echo $table_list
      #echo ""
      #echo ""
    fi
  done
  echo "Found all Delete Statements..."
}

get_db2_statements(){
echo "...Copying Source"
cd $cobol_source
cp * ${cobol_source_cut}
echo "Source Copied..."
get_between_exec
remove_beg_line_nums


}
get_between_exec(){
echo "...Removing all Except Exec Statements"
cd $cobol_source_cut
        for item in `ls`; do sed -n '/EXEC SQL/,/END-EXEC./p' $item > tmp && mv tmp ${item}; done
echo "Removed all Except Exec Statements..."
remove_beg_line_nums
}

remove_beg_line_nums(){
echo "...Removing all leading line numbers"
cd $cobol_source_cut
        for item in `ls`; do sed -i 's/^......//p' $item ; done
echo "Removed all leading line numbers..."
}


init_audit_file(){
echo "...Removing audit Log"
rm ${audit_log}.sorted
echo "audit Log Removed..."
echo "Creating new audit Log..."
touch ${audit_log}
echo "Program:Table/View:SELECT:INSERT:UPDATE:DELETE" > ${audit_log}
echo "... New audit Log Created"
}

print_audit(){

#$1 is the Program Name
#$2 is the Table/View Name
echo "${1}:${2}:${has_sel}:${has_ins}:${has_upd}:${has_del}" >> ${audit_log}
}

remove_duplicates(){
(head -n 2 ${audit_log} && tail -n +3 ${audit_log} | sort -u) > $audit_log_Sorted
rm ${audit_log}
}

#MAIN#
main(){
get_db2_statements
init_audit_file
find_insert
find_select
find_delete
find_update
remove_duplicates
}

main
