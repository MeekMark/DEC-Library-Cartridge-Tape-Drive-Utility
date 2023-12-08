#!/usr/bin/ksh

# update tape drive web page status information
# 
echo APP_BASE=$APP_BASE
if [ ! -f ${APP_BASE}/common/log/mt_swap_tape_info.txt ]
then
    if [ -f /export/home/cots/common/log/mt_swap_tape_info.txt ]
    then
        export APP_BASE=/export/home/cots
    fi
fi
echo APP_BASE=$APP_BASE

STATUS_FILE=${APP_BASE}/common/log/mt_swap_tape_info.txt 
STATUS_DATE_FILE=${APP_BASE}/common/log/mt_swap_tape_info_date.txt 
WEB_DOCS=/usr/local/apache2/htdocs/env_support
WEB_TAPE_DOCS=/usr/local/apache2/htdocs/env_support/tapes

#CAT_CMD='cat ${WEB_DOCS}/tapes_head.tpl 


if [ -w $STATUS_FILE ]
then
	: # Cool.
else
	: # NOT Cool.
	echo User ID $LOGNAME cannot write status file $STATUS_FILE.
	echo Exitting.
	exit -1
fi

if [ $# -gt 1 ]
then
	echo Invalid number of parameters: $#. 
	echo Usage: `basename $0` "[reading|writing]"
	exit -1
else
	if [ $# -gt 0 ]
	then
		if [ "reading" = "$1" -o "writing" = "$1" ]
		then
			echo parameter: $1. 
			UPDATE_TYPE=_`echo $1 | cut -c1`
		else
			echo Invalid parameter: $1. 
			echo Usage: `basename $0` "[reading|writing]"
			exit -1
		fi
	else
		UPDATE_TYPE=
	fi
fi

CURR_SLOT=`cat $STATUS_FILE`
echo Current Slot: $CURR_SLOT 
CURR_SLOT_TEMPLATE=${CURR_SLOT}${UPDATE_TYPE}
echo Current Slot Template: $CURR_SLOT_TEMPLATE


echo Current Slot is still : `cat $STATUS_FILE`
date "+updated by $LOGNAME as of %A %B %d, %Y %T </p>" \
	> $STATUS_DATE_FILE
# The file $WEB_DOCS/tapes${CURR_SLOT_TEMPLATE}.tpl has the appropriate 
# tape slot number highlighted.  
cat $WEB_DOCS/tapes_head1.tpl $STATUS_DATE_FILE \
	$WEB_DOCS/tapes_head2a.tpl \
	$WEB_TAPE_DOCS/t_1.tpl \
	$WEB_TAPE_DOCS/t_2.tpl \
	$WEB_TAPE_DOCS/t_3.tpl \
	$WEB_TAPE_DOCS/t_4.tpl \
	$WEB_TAPE_DOCS/t_5.tpl \
	$WEB_TAPE_DOCS/t_6.tpl \
	$WEB_TAPE_DOCS/t_7.tpl \
	$WEB_TAPE_DOCS/t_8.tpl \
	$WEB_TAPE_DOCS/t_9.tpl \
	$WEB_DOCS/tapes_head10a.tpl \
	$WEB_TAPE_DOCS/t_10.tpl \
	$WEB_DOCS/tapes_head10b.tpl \
	$WEB_DOCS/tapes${CURR_SLOT_TEMPLATE}.tpl \
	$WEB_DOCS/tapes_tail.tpl > $WEB_DOCS/tapes.html

HOST_NAME_ALL=`grep example /etc/hosts`
HOST_NAME_FULL=`echo $HOST_NAME_ALL | cut -f2 -d' ' | grep example`
if [ -z "$HOST_NAME_FULL" ]
then
	HOST_NAME_FULL=`echo $HOST_NAME_ALL | cut -f3 -d' ' | grep example`
fi

echo Web pg http://$HOST_NAME_FULL/env_support/tapes.html updated


