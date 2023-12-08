#!/usr/bin/ksh

# wrapper for mt offline to update status information
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

USAGE="mt_swap_tape.sh swap|reset|info  # where swap=unload current tape, load next.      reset=reset status after manually loading tape 1. info=dump current slot."

if [ -w $STATUS_FILE ]
then
	: # Cool.
else
	: # NOT Cool.
	echo User ID $LOGNAME cannot write status file $STATUS_FILE.
	echo Exitting.
	exit -1
fi

if [ $# -ne 1 ]
then
	echo Invalid number of parameters: $#
	echo $USAGE
	exit -1
fi

if [ "swap" = "$1" -o "reset" = "$1" -o "info" = "$1" ]
then
	: # Cool
else
	echo "Invalid option parameter: $1. Valid: swap|reset|info"
	echo $USAGE
	exit -1
fi

CURR_SLOT=`cat $STATUS_FILE`
echo Current Slot: $CURR_SLOT Action: $1


if [ "swap" = "$1" ]
then
	if [ $CURR_SLOT -lt 10 ]
	then
		let NEXT_SLOT=$CURR_SLOT+1
		# OK to swap tapes
		mt offline
		RC_OFFLINE=$?
		if [ $RC_OFFLINE -ne 0 ]
		then
			echo "Error $RC_OFFLINE doing mt offline command"
			exit $RC_OFFLINE
		fi
		echo $NEXT_SLOT > $STATUS_FILE
		echo Current Slot is now : `cat $STATUS_FILE`
		date "+updated by $LOGNAME as of %A %B %d, %Y %T </p>" \
			> $STATUS_DATE_FILE
		# The file $WEB_DOCS/tapes${NEXT_SLOT}.tpl has the appropriate 
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
			$WEB_DOCS/tapes${NEXT_SLOT}.tpl \
			$WEB_DOCS/tapes_tail.tpl > $WEB_DOCS/tapes.html

		echo Web pg http://148.94.136.84/env_support/tapes.html updated

		exit 0
	else
		echo "Cannot swap tapes: Current Slot is $CURR_SLOT"
		exit -1
	fi
else
	if [ "reset" = "$1" ]
	then
		if [ $CURR_SLOT -eq 1 ]
		then
			echo Current Slot is already 1: `cat $STATUS_FILE`
			exit -1
		else
			echo 'Is the first tape loaded in slot1? (Y/N) \c'
			read ans
			echo $ans | grep -i '^Y' > /dev/null 2>&1
			OK_RC=$?
			if [ $OK_RC -eq 0 ]
			then
				let NEXT_SLOT=1
				echo $NEXT_SLOT > $STATUS_FILE
				echo Current Slot is now : `cat $STATUS_FILE`
				date "+reset by $LOGNAME as of %A %B %d, %Y %T </p>" \
					> $STATUS_DATE_FILE
				# The file $WEB_DOCS/tapes${NEXT_SLOT}.tpl has the appropriate 
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
					$WEB_DOCS/tapes${NEXT_SLOT}.tpl \
					$WEB_DOCS/tapes_tail.tpl > $WEB_DOCS/tapes.html

				HOST_NAME_ALL=`grep txpln /etc/hosts`
				HOST_NAME_FULL=`echo $HOST_NAME_ALL | cut -f2 -d' ' | grep txpln`
				if [ -z "$HOST_NAME_FULL" ]
				then
					HOST_NAME_FULL=`echo $HOST_NAME_ALL | cut -f3 -d' ' | grep txpln`
				fi

				echo Web pg http://$HOST_NAME_FULL/env_support/tapes.html updated


				exit 0
			else
				echo Current Slot left at: `cat $STATUS_FILE`
				exit -1
			fi
		fi
	else
		# Must be info request
		echo Current Tape Slot: `cat $STATUS_FILE`
		exit 0
	fi
fi


