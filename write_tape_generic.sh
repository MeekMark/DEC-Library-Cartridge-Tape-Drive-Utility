#!/usr/bin/ksh

#
# set DEBUG=echo to run in DEBUG mode, which will not access the tape drive
#

export PATH=.:$PATH


DEBUG=
#DEBUG=echo

####
#
#  Subroutines
#
####

padValueLeft()
{

VALUE_TO_PAD=$1
TOTAL_LEN=$2
PAD_WITH=$3

LEN_VALUE=`echo $VALUE_TO_PAD | wc -c | tr -d ' '`
if [ $LEN_VALUE -ge $TOTAL_LEN ]
then
	echo "$VALUE_TO_PAD"
	return
fi

let LEN_DIFF=$TOTAL_LEN-$LEN_VALUE+1
PADDED_VALUE=`echo "$PAD_WITH" | cut -c1-$LEN_DIFF`$VALUE_TO_PAD
echo "$PADDED_VALUE"


}

padValueRight()
{

VALUE_TO_PAD=$1
TOTAL_LEN=$2
PAD_WITH=$3

LEN_VALUE=`echo $VALUE_TO_PAD | wc -c | tr -d ' '`
if [ $LEN_VALUE -ge $TOTAL_LEN ]
then
	echo "$VALUE_TO_PAD"
	return
fi

let LEN_DIFF=$TOTAL_LEN-$LEN_VALUE+1
PADDED_VALUE=$VALUE_TO_PAD`echo "$PAD_WITH" | cut -c1-$LEN_DIFF`
echo "$PADDED_VALUE"


}
####
#
#  Mainline
#
####

echo APP_BASE=$APP_BASE
if [ -f ${APP_BASE}/common/bin/email.sh ]
then
	. ${APP_BASE}/common/bin/email.sh
else
	if [ -f /export/home/cots/common/bin/email.sh	]
	then
		export APP_BASE=/export/home/cots
		. /export/home/cots/common/bin/email.sh	
	else
		. /export/home/cots2/common/bin/email.sh	
	fi
fi
echo APP_BASE=$APP_BASE

# Set dev/prod info based on host value
# $host is set in email.sh

if [ "$host" = "Clientd002" ]
then
	HOST_TYPE="dev DEC"
	HOST_LOAD_URL=http://Clientd002.example.com/env_support/tapes_faq.html#load
	HOST_TAPE_CURR_URL=http://Clientd002.example.com/env_support/tapes.html
else
	HOST_TYPE="prod IBM"
	HOST_LOAD_URL=http://Clientp001.example.com/env_support/tapes_faq.html#load
	HOST_TAPE_CURR_URL=http://Clientp001.example.com/env_support/tapes.html
fi


VALID_NUM_PARMS=8
VALID_NUM_PARMS_OPT=9
USAGE="write_tape_generic.sh source_dir vol_ser_alpha first_vol_ser_num file_name_base lrecl blksize rewind|norewind|eject 3480|3490|3490E [vb_data_write.pl ]"

if [ $# -ne $VALID_NUM_PARMS ]
then
	if [ $# -ne $VALID_NUM_PARMS_OPT ]
	then
		echo "Invalid number of parameters ($#) - Expecting $VALID_NUM_PARMS or $VALID_NUM_PARMS_OPT"
		echo $USAGE
		exit -1
	fi
fi

# Accept parameters
SRC_DIR=$1;shift
VOL_SER_ALPHA=$1;shift
VOL_SER_NUM_FIRST=$1;shift
FILE_NAME_BASE=$1;shift
LRECL=$1;shift
BLKSIZE=$1;shift
EOF_OPTION=$1;shift
CART_TYPE=$1;shift


#!!TAPE_OPTIONS_DATA="conv=block,ebcdic obs=$BLKSIZE cbs=$LRECL "
#!!TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT obs=$BLKSIZE cbs=$LRECL "

#Default record format: F (Fixed Block)
RECFM=F
# Optional Data Conversion parameter
if [ $# -ge 1 ]
then
	DATA_FILTER_PARM=$1
	if [ "noconvert" = "$DATA_FILTER_PARM" ]
	then
		: # OK
		shift
		NO_CONVERT_CHAR_SET=1
		FILTER_DATA=0
		TAPE_OPTIONS_CONVERT=" "
	else
		# See if DATA_FILTER_PARM is vb_data_write.pl 
		if [ "vb_data_write.pl" = "$DATA_FILTER_PARM" ]
		then
			shift
			NO_CONVERT_CHAR_SET=1
			#record format: V (Variable Block)
			RECFM=V
			FILTER_DATA=1
			TAPE_OPTIONS_CONVERT=" "
			DATA_OPTIONS_CONVERT=$*
			if [ -n "$DATA_OPTIONS_CONVERT" ]
			then
				echo "Data filter options found ==>$DATA_OPTIONS_CONVERT<==. Ignring."
			fi
		else
			echo "Invalid noconvert option ==>$NO_CONVERT_CHAR_SET<==.  Valid: noconvert or vb_data_write.pl"
			echo $USAGE
			exit -1
		fi
	fi
else
	NO_CONVERT_CHAR_SET=0
	FILTER_DATA=0
	TAPE_OPTIONS_CONVERT="conv=block,ebcdic "
fi

TAPE_OPTIONS_LABEL="conv=block,ebcdic cbs=80 "
TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT obs=$BLKSIZE cbs=$LRECL "

# Validate Destination Directory
if [ -d $SRC_DIR ]
then
	if [ -w $SRC_DIR ]
	then
		: # Cool.  Can write to directory.
	else
		echo $LOGNAME does not have write authority to directory $SRC_DIR
		echo exiting
		exit -1
	fi
else
	echo Input Directory $SRC_DIR is not a directory 
	echo exiting
	exit -1
fi

# Validate Destination Directory
if [ -f ${SRC_DIR}/${FILE_NAME_BASE} ]
then
	: # Cool. File exisits
else
	echo Input  File ${SRC_DIR}/${FILE_NAME_BASE} not found
	echo exiting
	exit -1
fi

if [ "rewind" = "$EOF_OPTION" -o "eject" = "$EOF_OPTION" -o "norewind" = "$EOF_OPTION" ]
then
	: # OK
else
	echo "Invalid end of tape option ==>$EOF_OPTION<==.  Valid: rewind|norewind|eject"
	echo $USAGE
	exit -1
fi

if [ "3480" = "$CART_TYPE" -o "3490" = "$CART_TYPE" -o "3490E" = "$CART_TYPE" ]
then
	: # OK
	if [ "3480" = "$CART_TYPE" ]
	then
		CART_CAPACITY=419429996
	else
		if [ "3490" = "$CART_TYPE" ]
		then
			CART_CAPACITY=838860396
		else
			# !! CART_CAPACITY=2576979974
			# !! Future: Use info from ../log/tape_size_hist.txt
			CART_CAPACITY=2722230600
		fi
	fi
else
	echo "Invalid tape cartridge option ==>$CART_TYPE<==.  \
		Valid: 3480|3490|3490E"
	echo $USAGE
	exit -1
fi

# Validate numeric parms
let TEST_NUM=$VOL_SER_NUM_FIRST+1
if [ $? -ne 0 ]
then
	echo "Non-numeric Vol Ser Numeric portion ==>$VOL_SER_NUM_FIRST<==."
	echo $USAGE
	exit -1
fi

let TEST_NUM=$LRECL+1
if [ $? -ne 0 ]
then
	echo "Logical Record Length is non-numeric ==>$LRECL<==."
	echo $USAGE
	exit -1
fi

let TEST_NUM=$BLKSIZE+1
if [ $? -ne 0 ]
then
	echo "Block size is non-numeric ==>$BLKSIZE<==."
	echo $USAGE
	exit -1
fi


set -x # !! DEBUG - comment out this line when all is cool.

# Calc various info

# Determine # of tapes
FILE_SIZE=`/usr/local/bin/stat --dereference --format='%s' ${SRC_DIR}/${FILE_NAME_BASE}`

echo `date` About to count number of lines in ${SRC_DIR}/${FILE_NAME_BASE}
LF_COUNT_ALL=`/usr/local/bin/wc -l ${SRC_DIR}/${FILE_NAME_BASE}`
LF_COUNT=`echo $LF_COUNT_ALL | tr -s ' ' | cut -d' ' -f1 | tr -d ' '`
echo `date` Done     count number of lines in ${SRC_DIR}/${FILE_NAME_BASE}

if [ -z "$LF_COUNT" ]
then
	LF_COUNT=`echo $LF_COUNT_ALL | tr -s ' ' | cut -d' ' -f2 | tr -d ' '`
fi

# The following code rounds up the TTL_BLOCKS to the next 
# integer, since the korn shell uses integer arithmetic.
TTL_BLOCKS=`calc_block.pl $FILE_SIZE $LF_COUNT $BLKSIZE`
echo "!!FYI: New TTL_BLOCKS=>$TTL_BLOCKS<="

# This does take into account header/trailer files on each tape
# Calc number of tapes.  If CART_TYPE is 3490E, and FILE_SIZE is over 50%,
# the return code will be 1, indicating need to test compression
NUM_TAPES=`calc_tapes.pl $FILE_SIZE $CART_TYPE`
BIG_FILE_COMPRESS=$?
echo "!!FYI: First Original number of tapes estimate now $NUM_TAPES"

if [ $BIG_FILE_COMPRESS -eq 1 ]
then
	echo `date` About to write test tape to check compressability of data
	# Need to ensure compressability of data.
	# Write the file to the tape, and capture the output, 
	# then see how many blocks were written.
	time $DEBUG /usr/bin/dd of=/dev/rmt/0n \
		if=$SRC_DIR/${FILE_NAME_BASE} \
		$TAPE_OPTIONS_DATA \
		> $SRC_DIR/${FILE_NAME_BASE}_test.out \
		2> $SRC_DIR/${FILE_NAME_BASE}_test.err
	RC_WRITE_DATA=$?
	echo `date` Done     write test tape to check compressability of data
	# Need to grep $SRC_DIR/${FILE_NAME_BASE}_test.err to see if 
	# $DATA_FILTER_PARM script had a
	# error, since the dd program might have masked a 
	# bad RC
	ERROR_FOUND=0
	grep '^dd: unexpected short write' $SRC_DIR/${FILE_NAME_BASE}_test.err
	if [ $? -eq 0 ]
	then
		# Found string - there was an expected error - too much data for
		# the tape
		ERROR_FOUND=1
		#echo HEY found too much data for tape error 

		# There will be a line like the following:
		#8035991+0 records in
		# which we extract the 8035991 from, and multiply by 512 - dd's 
		# block size.  That gives us how much data fit on one tape.
		BLOCKS_WRITTEN=`grep 'records in' \
			$SRC_DIR/${FILE_NAME_BASE}_test.err | cut -d'+' -f1`
		#echo HEY wrote $BLOCKS_WRITTEN 512 blocks
		# Now get bytes written
		let BYTES_WRITTEN=$BLOCKS_WRITTEN*512
		echo "!!FYI was wrote $BYTES_WRITTEN bytes"
		BYTES_WRITTEN=`calc_bytes_in_block.pl $BLOCKS_WRITTEN`
		echo "!!FYI now wrote $BYTES_WRITTEN bytes"
	fi

	if [ $ERROR_FOUND -eq 1 ]
	then
		# Write history of bytes written
		echo "$FILE_NAME_BASE	$CART_TYPE	$BYTES_WRITTEN" \
			>> ${APP_BASE}/common/log/write_tape_info.txt

		# Recalculate capacity, and number of tapes needed
		echo FYI: Original CART_CAPACITY: $CART_CAPACITY
		echo FYI: Original number of tapes estimate $NUM_TAPES
		# Now scale BYTES_WRITTEN by 95% to give some leeway in case some data
		# doesn't compress as well as the first x bytes
		let CART_CAPACITY=$BYTES_WRITTEN*95/100
		let NUM_TAPES=$FILE_SIZE/$CART_CAPACITY+1
		echo FYI: New      CART_CAPACITY: $CART_CAPACITY
		echo FYI: Actual   number of tapes needed   $NUM_TAPES
		NUM_TAPES=`calc_tapes_comp.pl $FILE_SIZE $BYTES_WRITTEN 95%`
		echo FYI: Actual2  number of tapes needed   $NUM_TAPES
	fi

	echo "Done writing sample tape - about to rewind"
	$DEBUG mt rewind \
				>> $SRC_DIR/${FILE_NAME_BASE}_test.out \
				2>> $SRC_DIR/${FILE_NAME_BASE}_test.err

fi

echo FILE_SIZE=$FILE_SIZE, TTL_BLOCKS=$TTL_BLOCKS, NUM_TAPES=$NUM_TAPES
echo LF_COUNT=$LF_COUNT

if [ $NUM_TAPES -gt 1 ]
then
	# Not stacking multiple files on tape(s)
	STACKING_FILES=0
	# CURR_TAPE_FILE_NUMBER = File number as reported by mt status
	CURR_TAPE_FILE_NUMBER=0
	# Data Set Sequence Number - If only one data file on tape, then = 1
	DATA_SET_NUMBER=1
	#echo HEY more than one tape - need to split 
	#
	#		let CART_CAPACITY=$BYTES_WRITTEN*95/100
	#
	#		RECFM=V
	# If number of tapes > 1, see if room for work file on $SRC_DIR
	# Calc du
	DF_K_AVAIL=`/usr/bin/df -k $SRC_DIR |  tail -1 | cut -d' ' -f4`
	#echo "HEY DF_K_AVAIL==>$DF_K_AVAIL<=="
	#echo "HEY DF_K_AVAIL was set to output of ==>df -k $SRC_DIR |  tail -1 | cut -d' ' -f<=="
	let DF_AVAIL=$DF_K_AVAIL*1024
	let DF_USABLE=$DF_AVAIL*90/100
	echo HEY DF_K_AVAIL=$DF_K_AVAIL DF_AVAIL=$DF_AVAIL DF_USABLE=$DF_USABLE
	calc_disk_work_space.pl $FILE_SIZE $DF_K_AVAIL 90%
	CALC_DWS_RC=$?
	# if [ $FILE_SIZE -gt $DF_USABLE ]
	if [ $CALC_DWS_RC -gt 0 ]
	then
		echo "Not enough space ($FILE_SIZE) for work files in $SRC_DIR. "
		echo "Total space $DF_K_AVAIL Kbytes"
		exit -1
	fi

	if [ "$RECFM" = "V" ]
	then
		# Need to shrink the number of lines by around 93% to allow for 
		# extra overhead from RDW
		LINES_PER_CHUNK=`calc_lines_per_chunk.pl $LF_COUNT $NUM_TAPES 93%`
		echo "FYI: Variable Blocked! LINES_PER_CHUNK is now $LINES_PER_CHUNK"
	else
		LINES_PER_CHUNK=`calc_lines_per_chunk.pl $LF_COUNT $NUM_TAPES`
		echo "FYI: Not Variable Blocked! LINES_PER_CHUNK is now $LINES_PER_CHUNK"
	fi
	echo `date` about to  split $SRC_DIR/${FILE_NAME_BASE}
	# File chunk name base is wt_ followed by current pid
	FILE_CHUNK_NAME_BASE=wt_$$.
	FILE_CHUNK_DIR_NAME_BASE=$SRC_DIR/${FILE_CHUNK_NAME_BASE}
	#echo FYI: FILE_CHUNK_NAME_BASE=$FILE_CHUNK_NAME_BASE
	#echo FYI: FILE_CHUNK_DIR_NAME_BASE=$FILE_CHUNK_DIR_NAME_BASE
	df -k $SRC_DIR
	/usr/local/bin/split -l $LINES_PER_CHUNK \
		$SRC_DIR/${FILE_NAME_BASE} \
		$SRC_DIR/$FILE_CHUNK_NAME_BASE
	echo `date` done with split $SRC_DIR/${FILE_NAME_BASE}
	df -k $SRC_DIR
	#FILE_CHUNK_NAME=$SRC_DIR/${FILE_NAME_BASE}
	#    wt_$PID.aa, wt_$PID.ab, ... wt_$PID.zz
	#echo Ensure $NUM_TAPES blank $TAPE_INFO2 in the tape library 
	#echo and $TAPE_INFO3 is loaded
	echo FYI: "Actual   number of tapes needed was ==>$NUM_TAPES<=="
	echo FYI: "Going to ls ${FILE_CHUNK_DIR_NAME_BASE}* | wc -l | tr -d ' '"
	NEW_NUM_TAPES=`ls ${FILE_CHUNK_DIR_NAME_BASE}* | wc -l | tr -d ' '`
	if [ $NEW_NUM_TAPES -gt $NUM_TAPES ]
	then
		NUM_TAPES=$NEW_NUM_TAPES
		echo FYI: "Actual   number of tapes needed now ==>$NUM_TAPES<=="
	fi
else
	# If just one tape, check if not first file on tape.  
	read_tape_file_number.sh
	# CURR_TAPE_FILE_NUMBER = File number as reported by mt status
	CURR_TAPE_FILE_NUMBER=$?
	if [ $CURR_TAPE_FILE_NUMBER -eq 0 ]
	then
		# Not stacking multiple files on tape(s)
		STACKING_FILES=0
		if [ "rewind" = "$EOF_OPTION" ]
		then
			: # Might be stacking files onto a single tape.
			STACKING_FILES=1
		fi
		# Data Set Sequence Number - If > 1 data file on tape, then 
		# position of this file on the tape.
		DATA_SET_NUMBER=1
		# Set current file size info, in case other files are added later
		echo "$FILE_SIZE" \
				> ${APP_BASE}/common/log/write_tape_curr_size.txt
		if [ ! -w ${APP_BASE}/common/log/write_tape_curr_size.txt ]
		then
			echo "Unable to create or  over-write ${APP_BASE}/common/log/write_tape_curr_size.txt "
			exit -1
		fi
		echo "!!Tape in beginning of tape position"
	else
		# Stacking multiple files on tape(s)
		STACKING_FILES=1
		# See if room on tape for file 
		CURR_FILE_SIZES=`awk ' { s += $1 }; END { print s } ' \
			${APP_BASE}/common/log/write_tape_curr_size.txt `
		calc_tape_room.pl $FILE_SIZE $CURR_FILE_SIZES $CART_TYPE $BYTES_WRITTEN
		ROOM_LEFT=$?
		if [ $ROOM_LEFT -ne 0 ]
		then
			echo "Not enough room left on tape for input file"
			exit -1
		fi
		echo "$FILE_SIZE" \
				>> ${APP_BASE}/common/log/write_tape_curr_size.txt
		# If not first file, check if we need to back up one EOF mark.
		#  (There is an extra EOF mark written when the last tape of a file is
		#   written.  Rewind one EOF to over-write second EOF)
		#  (If the file number is evenly divisable by 3, then tape is in 
		#   correct position)
		#  (If the file number is divisable by 3 with a remainder of 1, 
		#   then tape needs to be backed up.)
		let LAST_FILE_ON_TAPE=$CURR_TAPE_FILE_NUMBER%3
		if [ $LAST_FILE_ON_TAPE -eq 0 ]
		then
			: # All OK - divisable by 3
			echo "!! CURR_TAPE_FILE_NUMBER=$CURR_TAPE_FILE_NUMBER"
			echo "!!Tape in right position LAST_FILE_ON_TAPE=$LAST_FILE_ON_TAPE"
			# Data Set Sequence Number - If > 1 data file 
			# on tape, then position of this file on tape.
			let DATA_SET_NUMBER=\($CURR_TAPE_FILE_NUMBER/3\)+1
		else
			if [ $LAST_FILE_ON_TAPE -eq 1 ]
			then
				: # All OK
				echo "!! CURR_TAPE_FILE_NUMBER=$CURR_TAPE_FILE_NUMBER"
				echo "!!Tape in past EOF position LAST_FILE_ON_TAPE=$LAST_FILE_ON_TAPE"
				echo "Tape in past EOF position - going to mt nbsf " \
					>> $SRC_DIR/${FILE_NAME_BASE}.out \
					2>> $SRC_DIR/${FILE_NAME_BASE}.err
				# Backspace over last eof - so we can write 
				# the next file on this tape.
				mt nbsf \
					>> $SRC_DIR/${FILE_NAME_BASE}.out \
					2>> $SRC_DIR/${FILE_NAME_BASE}.err
				# Data Set Sequence Number - If > 1 data file 
				# on tape, then position of this file on tape.
				# Allow for extra 1 in CURR_TAPE_FILE_NUMBER
				let DATA_SET_NUMBER=\(\($CURR_TAPE_FILE_NUMBER-1\)/3\)+1
			else
				echo "!! CURR_TAPE_FILE_NUMBER=$CURR_TAPE_FILE_NUMBER"
				echo "!!Tape in past EOF position LAST_FILE_ON_TAPE=$LAST_FILE_ON_TAPE"
				echo "Unexpected File Number $CURR_TAPE_FILE_NUMBER - should be multiple of 3, or (multiple of 3)+1"
				exit -1
			fi
		fi

	fi

fi

let VOL_SER_NUM_LAST=$VOL_SER_NUM_FIRST+$NUM_TAPES-1

# pad with zeros if needed
LEN_NUM_FIRST=`echo $VOL_SER_NUM_FIRST | wc -c | tr -d ' '`
LEN_NUM_LAST=`echo $VOL_SER_NUM_LAST | wc -c | tr -d ' '`
#echo HEY LEN_NUM_FIRST=$LEN_NUM_FIRST, LEN_NUM_LAST=$LEN_NUM_LAST
let LEN_DIFF=$LEN_NUM_FIRST-$LEN_NUM_LAST
if [ $LEN_DIFF -gt 0 ]
then
	VOL_SER_NUM_LAST=`echo "0000000" | cut -c1-$LEN_DIFF`$VOL_SER_NUM_LAST
fi


if [ $NUM_TAPES -eq 1 ]
then
	TAPE_INFO=tape
	TAPE_INFO2="tape is"
	TAPE_INFO3="it"
else
	TAPE_INFO=tapes
	TAPE_INFO2="tapes are"
	TAPE_INFO3="the first tape"
fi

FIRST_SLOT=`cat ${APP_BASE}/common/log/mt_swap_tape_info.txt`
FIRST_VOL_SER=${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST} 
CURR_SLOT=$FIRST_SLOT
MAX_SLOT=10

let MAX_FIRST_BATCH=$MAX_SLOT-$CURR_SLOT+1

if [ $NUM_TAPES -gt $MAX_FIRST_BATCH ]
then
	echo Will be using more than $MAX_FIRST_BATCH tapes.  Will send email
	echo when it is time to swap tapes out.
fi

let MAX_FIRST_BATCH=$MAX_SLOT-$CURR_SLOT+1
if [ $MAX_FIRST_BATCH -lt $NUM_TAPES ]
then
	let FIRST_BATCH=$MAX_FIRST_BATCH
	echo "HEY MAX_FIRST_BATCH $MAX_FIRST_BATCH -lt NUM_TAPES $NUM_TAPES " 
	echo "HEY FIRST_BATCH is $FIRST_BATCH " 
	echo Ensure $MAX_FIRST_BATCH blank $TAPE_INFO2 in the tape library 
	echo and $TAPE_INFO3 is loaded in slot $CURR_SLOT
else
	let FIRST_BATCH=$NUM_TAPES
	echo "HEY MAX_FIRST_BATCH $MAX_FIRST_BATCH -lt NUM_TAPES $NUM_TAPES " 
	echo "HEY FIRST_BATCH is $FIRST_BATCH " 
	echo Ensure $NUM_TAPES blank $TAPE_INFO2 in the tape library 
	echo and $TAPE_INFO3 is loaded in slot $CURR_SLOT
fi


echo About to write $NUM_TAPES $TAPE_INFO from ${SRC_DIR}/${FILE_NAME_BASE} 
echo Vol Ser ${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST} to \
	${VOL_SER_ALPHA}${VOL_SER_NUM_LAST} blksize=$BLKSIZE \
	and $EOF_OPTION last tape
echo Hit Ctrl-C within 30 seconds to abort
sleep 30


# Clobber log files

echo about to "> $SRC_DIR/${FILE_NAME_BASE}.out 2> $SRC_DIR/${FILE_NAME_BASE}.err"
> $SRC_DIR/${FILE_NAME_BASE}.out 2> $SRC_DIR/${FILE_NAME_BASE}.err

# Don't clobber inventory if still there - in case we are stacking files
# on a tape
MAIL_TEXT=$SRC_DIR/${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST}.inv 
if [ -f $MAIL_TEXT ]
then
	echo Using existing File Inventory to mail: $MAIL_TEXT
	APPENDING_INVENTORY=1
else
	APPENDING_INVENTORY=0
	cat > $MAIL_TEXT <<-EOF
To: $MAIL_TO_TAPE
From: Tape Writer <$host>
Reply-to: $REPLY_TO
Subject: Client  $HOST_TYPE Tape Inventory for $SRC_DIR/${FILE_NAME_BASE}

Client Name  ($HOST_TYPE tape drive) Tape Inventory

EOF

fi


if [ -w $SRC_DIR/${FILE_NAME_BASE}.out -a -w $SRC_DIR/${FILE_NAME_BASE}.err ]
then
	: # OK to write in this dir
else
	echo Unable to write files in $SRC_DIR
	exit -1
fi

echo `date '+%D %T'` write_tape_generic.sh going to write $NUM_TAPES $TAPE_INFO \
	starting with VOL_SER=${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST}, \
	last=${VOL_SER_ALPHA}${VOL_SER_NUM_LAST} \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out 

echo 	`date '+%D %T'` Base File Name=$FILE_NAME_BASE, LRECL=$LRECL, \
	Blocksize=$BLKSIZE \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out 

CURR_TAPE=$VOL_SER_NUM_FIRST

# 2: TAPE_OPTIONS="conv=ascii,unblock ibs=$BLKSIZE cbs=$LRECL "
# 3: TAPE_OPTIONS="conv=ascii,unblock ibs=$BLKSIZE "
# 4: TAPE_OPTIONS="conv=ascii ibs=$BLKSIZE cbs=$LRECL "
#!TAPE_OPTIONS_LABEL="conv=ebcdic,block obs=$BLKSIZE cbs=80 "
#!!! set earlier TAPE_OPTIONS_LABEL="conv=block,ebcdic cbs=80 "
#!TAPE_OPTIONS_DATA="conv=ebcdic,block obs=$BLKSIZE cbs=$LRECL "
#!!TAPE_OPTIONS_DATA="conv=block,ebcdic obs=$BLKSIZE cbs=$LRECL "
#!!! set earlier TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT obs=$BLKSIZE cbs=$LRECL "

# inventory list overview
if [ $APPENDING_INVENTORY -eq 1 ]
then
	echo  "Tape Inventory List updated " `date` \
		>> $MAIL_TEXT 
else
	echo  "Tape Inventory List created " `date` \
		>> $MAIL_TEXT 
fi
cat >> $MAIL_TEXT <<-EOF2

Summary: 

Input File Name:   $FILE_NAME_BASE
EOF2


#echo >> $MAIL_TEXT 
#echo "Summary: "  >> $MAIL_TEXT 
#echo "Input File Name:   $FILE_NAME_BASE"  >> $MAIL_TEXT 

FNB_LEN=`echo $FILE_NAME_BASE | wc -c | tr -d ' '`
if [ $FNB_LEN -gt 17 ]
then
	let NUM_CHARS_TO_DROP=$FNB_LEN-17
	FILE_NAME_ON_TAPE=`echo $FILE_NAME_BASE | cut -c$NUM_CHARS_TO_DROP-`
	echo \
		"Tape  File Name:   $FILE_NAME_ON_TAPE (Name on tape is last 17 chars)"  \
			>> $MAIL_TEXT 
fi

# RECFM on JCL is FB or VB; on vol ser electronic label the F/V goes one
# place, and the "B"locked indicator goes elsewhere.  Append the "B" to this
# report so we don't confuse anyone
cat >> $MAIL_TEXT <<-EOF3
LRECL:       $LRECL (Logical Record Length)
BLKSIZE:     $BLKSIZE (Block Size)
RECFM:       ${RECFM}B (Record Format)
Total Tapes: $NUM_TAPES


Tapes: 
EOF3

if [ $STACKING_FILES -eq 1 ]
then
	cat >> $MAIL_TEXT <<-EOF4
VolSer Tape# Blocks Slot# FileName          Data Set Seq#
------ ----- ------ ----- ----------------- -------------
EOF4
else
	cat >> $MAIL_TEXT <<-EOF5
VolSer Tape# Blocks Slot# FileName
------ ----- ------ ----- -----------------
EOF5
fi

time $DEBUG mt status >> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err

TAPES_WRITTEN=1
echo "HEY!! YOU!! CURR_TAPE = $CURR_TAPE and VOL_SER_NUM_LAST = $VOL_SER_NUM_LAST"
while [ $CURR_TAPE -le $VOL_SER_NUM_LAST ]
do
	echo `date '+%D %T'` \
		"working on Tape Vol Ser: ${VOL_SER_ALPHA}${CURR_TAPE}" \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err


	##
	# perl script to generate header file
	# !! To do:  Handle files spanning tapes
	##
	echo `date '+%D %T'` "Creating vol ser header for ${VOL_SER_ALPHA}${CURR_TAPE}" \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 
	$DEBUG write_vol_ser.pl ${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST} \
		${VOL_SER_ALPHA}${CURR_TAPE} $FILE_NAME_BASE \
		$LRECL $BLKSIZE $TAPES_WRITTEN $NUM_TAPES $DATA_SET_NUMBER \
		$CART_TYPE $RECFM > \
		$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_0 
	RC_WRITE_HDR=$?
	if [ $RC_WRITE_HDR -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_WRITE_HDR Writing header label " \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err
		exit -1
	fi

	echo `date '+%D %T'` "Writing vol ser header for ${VOL_SER_ALPHA}${CURR_TAPE}" \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err

	time $DEBUG /usr/bin/dd of=/dev/rmt/0n \
		if=$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_0 \
		$TAPE_OPTIONS_LABEL \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err 
	time $DEBUG mt status \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err
	# Update info for web page
	$DEBUG vol_ser_catalog.pl \
		$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_0
	tape_web_page_refresh.sh writing

	##
	# Write data file
	##
	echo `date '+%D %T'` "Writing data for ${VOL_SER_ALPHA}${CURR_TAPE}" \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err
	echo `date '+%D %T'` "Options: $TAPE_OPTIONS_DATA " \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err

	set -x  # !! TEMP DEBUG
	# Figure out input file name.  If NUM_TAPES > 1, then we did a split
	# earlier, which generated file names like 
	#    wt_$PID.aa, wt_$PID.ab, ... wt_$PID.zz
	if [ $NUM_TAPES -gt 1 ]
	then
		FILE_CHUNK_NAME=`ls ${FILE_CHUNK_DIR_NAME_BASE}* | head -$TAPES_WRITTEN | tail -1 `
		echo HEY Tape number $TAPES_WRITTEN FILE_CHUNK_NAME=$FILE_CHUNK_NAME
	else
		FILE_CHUNK_NAME=$SRC_DIR/${FILE_NAME_BASE}
		echo HEY FILE_CHUNK_NAME=$FILE_CHUNK_NAME
	fi

	echo FYI Current input #$TAPES_WRITTEN filename: $FILE_CHUNK_NAME
	if [ $FILTER_DATA -eq 1 ]
	then
		# Use dd with no "if" parm, pipe from DATA_FILTER_PARM 
		time $DEBUG $DATA_FILTER_PARM blksize=$BLKSIZE  \
			$FILE_CHUNK_NAME \
			2>> $SRC_DIR/${FILE_NAME_BASE}.err | \
			/usr/bin/dd of=/dev/rmt/0n \
			$TAPE_OPTIONS_DATA \
			>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err
		RC_WRITE_DATA=$?
		# Need to grep $SRC_DIR/${FILE_NAME_BASE}.err to see if 
		# $DATA_FILTER_PARM script had a
		# error, since the dd program might have masked a 
		# bad RC
		grep '^Error:' $SRC_DIR/${FILE_NAME_BASE}.err
		if [ $? -eq 0 ]
		then
			# Found string - there was an error
			RC_WRITE_DATA=123
		fi

		# Need to obtain blocks written if $DATA_FILTER_PARM is vb_data_write.pl
		# since writing VB data means that we can't determine the number of 
		# blocks written by simply dividing file size by block size,
		# since each record can be varying in length.
		if [ "vb_data_write.pl" = "$DATA_FILTER_PARM" ]
		then
			TTL_BLOCKS=`grep 'vb_data_write finished.* blocks written' $SRC_DIR/${FILE_NAME_BASE}.err | cut -f 9 -d'|'`
			echo "HEY: Just set TTL_BLOCKS to $TTL_BLOCKS based on vb_data_write.pl info"
			#echo "HEY: TTL_BLOCKS=grep 'vb_data_write finished.* blocks written' $SRC_DIR/${FILE_NAME_BASE}.err | cut -f 9 -d'|'"
			# The grep below of $SRC_DIR/${FILE_NAME_BASE}.err would produce
			# a line similar to:
			# =====================
			# 506+1 records out
			# =====================
			# We take the last record as there are two lines that match - from
			# writing the header label, and writing the data.
			let TTL_BLOCKS=`grep 'records out' $SRC_DIR/${FILE_NAME_BASE}.err \
				| tail -1 | cut -d' ' -f1`
			echo "HEY: Just reset TTL_BLOCKS to $TTL_BLOCKS based on grep of $SRC_DIR/${FILE_NAME_BASE}.err"
		fi
	else
		# Write directly to file
		time $DEBUG /usr/bin/dd of=/dev/rmt/0n \
			if=$FILE_CHUNK_NAME \
			$TAPE_OPTIONS_DATA \
			>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err
		RC_WRITE_DATA=$?
		if [ $NUM_TAPES -gt 1 ]
		then
			# Calc TTL_BLOCKS for this chunk
			# The following ugly code attempts to round up the TTL_BLOCKS to the next 
			# integer, since the korn shell uses integer arithmetic.
			FILE_CHUNK_SIZE=`/usr/local/bin/stat --dereference --format='%s' $FILE_CHUNK_NAME`
			if [ $CURR_TAPE -eq $VOL_SER_NUM_LAST ]
			then
				CURR_LINES_PER_CHUNK_ALL=`/usr/local/bin/wc -l $FILE_CHUNK_NAME`
				CURR_LINES_PER_CHUNK=`echo $CURR_LINES_PER_CHUNK_ALL | tr -s ' ' | cut -d' ' -f1 | tr -d ' '`
			else
				CURR_LINES_PER_CHUNK=$LINES_PER_CHUNK
			fi
			TTL_BLOCKS=`calc_block.pl $FILE_CHUNK_SIZE $LF_COUNT $BLKSIZE`
			echo "!!FYI: New-2 TTL_BLOCKS=>$TTL_BLOCKS<="
			TTL_BLOCKS=`calc_block.pl $FILE_CHUNK_SIZE $CURR_LINES_PER_CHUNK $BLKSIZE`
			echo "!!FYI: New-3 TTL_BLOCKS=>$TTL_BLOCKS<="
			let TEST_TTL_BLOCKS=`grep 'records out' $SRC_DIR/${FILE_NAME_BASE}.err \
				| tail -1 | cut -d' ' -f1`
			echo "!!FYI: TEST_TTL_BLOCKS was set to $TEST_TTL_BLOCKS based on grep of $SRC_DIR/${FILE_NAME_BASE}.err TTL_BLOCKS left at $TTL_BLOCKS"
		fi
	fi

	if [ $RC_WRITE_DATA -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_WRITE_DATA Writing data " \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape
		exit -1
	fi
	set +x  # !! TEMP DEBUG

	time $DEBUG mt status \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err

	##
	#
	# perl script to generate trailer file
	#
	##
	# Need to fix this unfortunate variable name.
	let CURR_BLOCKS=$TTL_BLOCKS
	if [ $NUM_TAPES -gt 1 ]
	then
		# HEY !! May need to fix this check for if we have more than 10 tapes...
		: # OK
	else
		: # OK
	fi
	echo `date '+%D %T'` "Creating vol ser trailer for ${VOL_SER_ALPHA}${CURR_TAPE}" \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 
	echo `date '+%D %T'` "HEY! CURR_TAPE==>$CURR_TAPE<==, NUM_TAPES==>$NUM_TAPES<==, TAPES_WRITTEN==>$TAPES_WRITTEN<==" \
	echo `date '+%D %T'` "HEY! CURR_BLOCKS==>$CURR_BLOCKS<==, TTL_BLOCKS==>$TTL_BLOCKS<==, TAPES_WRITTEN==>$TAPES_WRITTEN<==" \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 
	$DEBUG write_vol_ser.pl ${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST} \
		${VOL_SER_ALPHA}${CURR_TAPE} $FILE_NAME_BASE \
		$LRECL $BLKSIZE $TAPES_WRITTEN $NUM_TAPES $DATA_SET_NUMBER \
		$CART_TYPE $RECFM $CURR_BLOCKS > \
		$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_2 
	# Update info for web page
	$DEBUG vol_ser_catalog.pl \
		$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_2 
	tape_web_page_refresh.sh

	# Append to inventory list
	#Tapes: 
	#VolSer Tape# Blocks Slot# File Name
	#------ ----- ------ ----- -----------------
	#VolSer Tape# Blocks Slot# FileName          Data Set Seq#
	#------ ----- ------ ----- ----------------- -------------
	#
	#
	TAPES_WRITTEN_RPT=`padValueLeft $TAPES_WRITTEN 5 "00000"`
	CURR_BLOCKS_RPT=`padValueLeft $CURR_BLOCKS 6 "000000"`
	CURR_SLOT_RPT=`padValueLeft $CURR_SLOT 5 "000000"`
	DATA_SET_NUMBER_RPT=`padValueLeft $DATA_SET_NUMBER 4 "0000"`
	if [ $STACKING_FILES -eq 1 ]
	then
		FILE_NAME_BASE_TEMP=`padValueRight $FILE_NAME_BASE 17 "+++++++++++++++++"`
		FILE_NAME_BASE_TEMP2="${FILE_NAME_BASE_TEMP} $DATA_SET_NUMBER_RPT"
		FILE_NAME_BASE_RPT=`echo $FILE_NAME_BASE_TEMP2 | tr '+' ' ' `
		#echo "!! HEY !! FILE_NAME_BASE_TEMP==>$FILE_NAME_BASE_TEMP<== FILE_NAME_BASE_TEMP2==>$FILE_NAME_BASE_TEMP2<== FILE_NAME_BASE_RPT==>$FILE_NAME_BASE_RPT<=="
	else
		FILE_NAME_BASE_RPT=${FILE_NAME_BASE}
	fi
	#echo "HEY!! YOU!! About to append tape info to email file $MAIL_TEXT"
	echo "${VOL_SER_ALPHA}${CURR_TAPE} $TAPES_WRITTEN_RPT $CURR_BLOCKS_RPT $CURR_SLOT_RPT ${FILE_NAME_BASE_RPT}" >> $MAIL_TEXT 
	echo `date '+%D %T'` \
		"Writing vol ser trailer for ${VOL_SER_ALPHA}${CURR_TAPE}" \
		| tee -a $SRC_DIR/${FILE_NAME_BASE}.out $SRC_DIR/${FILE_NAME_BASE}.err

	time $DEBUG /usr/bin/dd of=/dev/rmt/0n \
		if=$SRC_DIR/${FILE_NAME_BASE}_${VOL_SER_ALPHA}${CURR_TAPE}_2 \
		$TAPE_OPTIONS_LABEL \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err
	time $DEBUG mt status \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 2>> $SRC_DIR/${FILE_NAME_BASE}.err

	if [ $CURR_TAPE -eq $VOL_SER_NUM_LAST ]
	then
		# Last tape.  Write an extra EOF, and Rewind or Eject to next tape
		echo `date '+%D %T'` "Writing extra EOF mark " \
				| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
					$SRC_DIR/${FILE_NAME_BASE}.err
		mt eof \
				>> $SRC_DIR/${FILE_NAME_BASE}.out \
				2>> $SRC_DIR/${FILE_NAME_BASE}.err
		if [ "eject" = "$EOF_OPTION" -a  $CURR_SLOT -lt $MAX_SLOT ]
		then
			echo `date '+%D %T'` "Switching to next tape " \
				| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
					$SRC_DIR/${FILE_NAME_BASE}.err
			time $DEBUG mt_swap_tape.sh swap \
				>> $SRC_DIR/${FILE_NAME_BASE}.out \
				2>> $SRC_DIR/${FILE_NAME_BASE}.err
			let CURR_SLOT=$CURR_SLOT+1
		else
			if [ "rewind" = "$EOF_OPTION" ]
			then
				echo `date '+%D %T'` "Rewinding last tape " \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
				time $DEBUG mt rewind \
					>> $SRC_DIR/${FILE_NAME_BASE}.out \
					2>> $SRC_DIR/${FILE_NAME_BASE}.err
			else
				# norewind 
				echo `date '+%D %T'` "Leaving last tape positioned at EOF" \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
				# Backspace over last eof - in case we write another file on 
				# this tape.
				mt nbsf \
					>> $SRC_DIR/${FILE_NAME_BASE}.out \
					2>> $SRC_DIR/${FILE_NAME_BASE}.err
			fi
		fi
	else
		# !! HEY
		# !! To Do:  Need to ensure not on last tape slot (10).  If so,
		# !!         pause until tape magazine is reloaded with 10 
		# !!         blank tapes.
		# !! Look at /export/home/cots2/common/log/mt_swap_tape_info.txt
		# !! to determine current tape slot in use.
		if [ $CURR_SLOT -eq $MAX_SLOT ]
		then
			# Need to email/page someone to swap tapes, then 
			# wait until a file  is created, then invoke mt_swap_tape.sh reset, then
			# continue

			# Page/email tape librarian
			FILE_TO_WAIT_FOR=/tmp/wt_$$_done.txt
			echo HEY NUM_TAPES=$NUM_TAPES CURR_TAPE=$CURR_TAPE MAX_SLOT=$MAX_SLOT
			let TAPES_LEFT=$NUM_TAPES-$TAPES_WRITTEN
			if [ $TAPES_LEFT -gt $MAX_SLOT ]
			then
				TAPES_IN_NEXT_BATCH=$MAX_SLOT
			else
				TAPES_IN_NEXT_BATCH=$TAPES_LEFT
			fi
			echo HEY TAPES_IN_NEXT_BATCH=$TAPES_IN_NEXT_BATCH TAPES_LEFT=$TAPES_LEFT 
			if [ $TAPES_IN_NEXT_BATCH -eq 1 ]
			then
				TAPE_DESC=tape
			else
				TAPE_DESC=tapes
			fi
			FIRST_SLOT_FMT=`padValueLeft $FIRST_SLOT 2 "0"`
			CURR_SLOT_FMT=`padValueLeft $CURR_SLOT 2 "0"`
			/usr/bin/mailx -t <<-EOF_TS
To: $MAIL_TO_TAPE
From: Tape Writer <$host>
Reply-to: $REPLY_TO
Subject: PAGE- Client  Swap tapes on $HOST_TYPE 

Finished writing tapes in slots $FIRST_SLOT through $CURR_SLOT.  Please label
these tapes, as follows:

	slot $FIRST_SLOT_FMT volser $FIRST_VOL_SER
	slot $CURR_SLOT_FMT volser ${VOL_SER_ALPHA}${CURR_TAPE}

Unload all tapes, and load $TAPES_IN_NEXT_BATCH $CART_TYPE $TAPE_DESC in the 
tape drive, starting in slot 1.

When done, and tape 1 is loaded, invoke the script

	tapes_loaded.sh $FILE_TO_WAIT_FOR

on $host

See $HOST_LOAD_URL
and $HOST_TAPE_CURR_URL

EOF_TS

			# Wait for $FILE_TO_WAIT_FOR to show up.  Check every minute.
			echo `date '+%D %T'` \
				"Waiting for Tapes to be swapped.  Awaiting file $FILE_TO_WAIT_FOR" \
				| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
					$SRC_DIR/${FILE_NAME_BASE}.err
			while [ ! -f $FILE_TO_WAIT_FOR ]
			do
				sleep 60
			done
			if [ ! -w $FILE_TO_WAIT_FOR ]
			then
				# Hmmm. Can't clobber file.  Someone created file with non-world
				# permissions.
				echo `date '+%D %T'` \
					"Found file $FILE_TO_WAIT_FOR but has wrong permissions." \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
				echo `date '+%D %T'` \
					"You need to rm $FILE_TO_WAIT_FOR manually for this job to work." \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
				/usr/bin/mailx -t <<-EOF_TSBAD
To: $MAIL_TO_TAPE
From: Tape Writer $host
Reply-to: $REPLY_TO
Subject: PAGE- Client  $HOST_TYPE Error - invalid $FILE_TO_WAIT_FOR file created 

Found file $FILE_TO_WAIT_FOR on $host but has wrong permissions. File must be
able to be deleted by $LOGNAME - change the permissions to continue.

I will wait until you do.


EOF_TSBAD
				while [ ! -w $FILE_TO_WAIT_FOR ]
				do
					sleep 60
				done
			fi
			rm -f $FILE_TO_WAIT_FOR
			# Reset web page
			echo `date '+%D %T'` "Tapes swapped.  Resetting web page to tape 1" \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
			echo 'y' | mt_swap_tape.sh reset \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
			let CURR_SLOT=1
			FIRST_SLOT=1
			# Save off vol ser for next batch of tapes
			let NEXT_TAPE=$CURR_TAPE+1
			# pad with zeros if needed
			LEN_NUM_LAST=`echo $NEXT_TAPE | wc -c | tr -d ' '`
			#echo HEY LEN_NUM_FIRST=$LEN_NUM_FIRST, LEN_NUM_LAST=$LEN_NUM_LAST
			let LEN_DIFF=$LEN_NUM_FIRST-$LEN_NUM_LAST
			if [ $LEN_DIFF -gt 0 ]
			then
				NEXT_TAPE=`echo "0000000" | cut -c1-$LEN_DIFF`$NEXT_TAPE
			fi
			FIRST_VOL_SER=${VOL_SER_ALPHA}${NEXT_TAPE} 
		else
			echo `date '+%D %T'` "Switching to next tape " \
					| tee -a $SRC_DIR/${FILE_NAME_BASE}.out \
						$SRC_DIR/${FILE_NAME_BASE}.err
			time $DEBUG mt_swap_tape.sh swap \
				>> $SRC_DIR/${FILE_NAME_BASE}.out \
				2>> $SRC_DIR/${FILE_NAME_BASE}.err
			let CURR_SLOT=$CURR_SLOT+1
		fi
	fi

	echo `date '+%D %T'` " - End of Loop" \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 
	ps -f -p $$ \
		>> $SRC_DIR/${FILE_NAME_BASE}.out 

	# Bump counters
	let CURR_TAPE=$CURR_TAPE+1
	let TAPES_WRITTEN=$TAPES_WRITTEN+1
	# pad with zeros if needed
	LEN_NUM_LAST=`echo $CURR_TAPE | wc -c | tr -d ' '`
	#echo HEY LEN_NUM_FIRST=$LEN_NUM_FIRST, LEN_NUM_LAST=$LEN_NUM_LAST
	let LEN_DIFF=$LEN_NUM_FIRST-$LEN_NUM_LAST
	if [ $LEN_DIFF -gt 0 ]
	then
		CURR_TAPE=`echo "0000000" | cut -c1-$LEN_DIFF`$CURR_TAPE
	fi
	#echo HEY CURR_TAPE=$CURR_TAPE

done

# Email inventory
echo  >> $MAIL_TEXT 
echo  "Tape Inventory List finished at " `date` >> $MAIL_TEXT 

/usr/bin/mailx -t < $MAIL_TEXT 

# Clean up temporary files
if [ -f ${FILE_CHUNK_DIR_NAME_BASE}.aa ]
then
	# Clean up work files - up to 52 of them
	rm ${FILE_CHUNK_DIR_NAME_BASE}.[ab][a-z]
fi


exit 0



