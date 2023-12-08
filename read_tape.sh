#!/usr/bin/ksh


if [ -f ${CLIENT_BASE}/common/bin/email.sh ]
then
	. ${CLIENT_BASE}/common/bin/email.sh
else
	if [ -f /export/home/cots/common/bin/email.sh	]
	then
		export CLIENT_BASE=/export/home/cots
		. /export/home/cots/common/bin/email.sh	
	else
		. /export/home/cots2/common/bin/email.sh	
	fi
fi

# Set dev/prod info based on host value
# $host is set in email.sh

if [ "$host" = "dev.example" ]
then
	HOST_TYPE="dev DEC"
	HOST_LOAD_URL=http://dev.example.com/env_support/tapes_faq.html#load
	HOST_TAPE_CURR_URL=http://example.com/env_support/tapes.html
else
	HOST_TYPE="prod IBM"
	HOST_LOAD_URL=http://example.com/env_support/tapes_faq.html#load
	HOST_TAPE_CURR_URL=http://example.com/env_support/tapes.html
fi


#
# set DEBUG=echo to run in DEBUG mode, which will not access the tape drive
#
# !! To Do:  *  Speed up vol_ser_catalog_both.pl, 
#            *  Use info from vol ser for -lrecl= parm on data_filter parms 
#                  (ie ebcdic_data.pl -lrecl=?)
#            *  Validate tapes are in order (just warn?)
#
#

#DEBUG=echo
DEBUG=


# !! To do: Possibly call vol_ser_sniff.pl to obtain vol_ser_alpha, 
# !!        first_vol_ser_num, filename_base, lrecl, blksize parms, if $# is 3.
# !! Note:  Can already do ? for lrecl and/or blksize

####
#
#  Subroutines
#
####

pager()
{

SUBJECT=$1
PAGER_TEXT=$2

/usr/bin/mailx -t <<-EOF
To: $PAGE_TO_TAPE
From: "Tape Loader" <$LOGNAME>
Reply-to: $REPLY_TO
Subject: PAGE- $HOST_TYPE - $SUBJECT

$PAGER_TEXT

EOF

}

mailer()
{

SUBJECT=$1
MAILER_TEXT=$2

/usr/bin/mailx -t <<-EOF
To: $MAIL_TO_TAPE
From: "Tape Loader " <$LOGNAME>
Reply-to: $REPLY_TO
Subject: CLIENT $HOST_TYPE - $SUBJECT

$MAILER_TEXT

EOF

}


VALID_NUM_PARMS=8
VALID_NUM_PARMS_OPT=9
USAGE="read_tape.sh dest_dir num_of_tapes vol_ser_alpha first_vol_ser_num filename_base lrecl blksize rewind|norewind|eject [3490E|3480|3490]  [noconvert|data_filter]"

if [ $# -lt $VALID_NUM_PARMS ]
then
	if [ $# -lt $VALID_NUM_PARMS_OPT ]
	then
		echo "Invalid number of parameters ($#) - Expecting $VALID_NUM_PARMS"
		echo "or $VALID_NUM_PARMS_OPT or more parameters."
		echo $USAGE
		echo "use ? for lrecl and/or blksize parameter to use info from tape"
		echo "or for variable blocked records"
		echo "3490E is default for type of tape cartridges.  Used only to "
		echo "calculate estimated disk space."
		exit -1
	fi
fi

# Accept parameters
DEST_DIR=$1;shift
NUM_TAPES=$1;shift
VOL_SER_ALPHA=$1;shift
VOL_SER_NUM_FIRST=$1;shift
FILE_NAME_BASE=$1;shift
LRECL=$1;shift
BLKSIZE=$1;shift
EOF_OPTION=$1;shift

# Optional parm: 3490E or 3480 or 3490. Default: 3490E
if [ $# -ge 1 ]
then
	if [ "3490E" = "$1" -o "3480" = "$1" -o "3490" = "$1" ]
	then
		TAPE_CART=$1
		shift
	else
		TAPE_CART=3490E
	fi
fi

# Optional parm: noconvert
if [ $# -ge 1 ]
then
	DATA_FILTER_PARM=$1
	if [ "noconvert" = "$DATA_FILTER_PARM" ]
	then
		: # OK
		shift
		NO_CONVERT_CHAR_SET=1
		CONVERT_DATA=0
		TAPE_OPTIONS_CONVERT=" "
	else
		# See if DATA_FILTER_PARM is ebcdic_data.pl or vb_data.pl + parms...
		if [ "ebcdic_data.pl" = "$DATA_FILTER_PARM" -o  "vb_data.pl" = "$DATA_FILTER_PARM" ]
		then
			shift
			NO_CONVERT_CHAR_SET=1
			CONVERT_DATA=1
			TAPE_OPTIONS_CONVERT=" "
			DATA_OPTIONS_CONVERT=$*
		else
			echo "Invalid noconvert option ==>$NO_CONVERT_CHAR_SET<==.  Valid: noconvert or ebcdic_data.pl or vb_data.pl"
			echo $USAGE
			exit -1
		fi
	fi
else
	NO_CONVERT_CHAR_SET=0
	CONVERT_DATA=0
	#!!!!TAPE_OPTIONS_CONVERT="conv=ascii,unblock "
	TAPE_OPTIONS_CONVERT="conv=unblock,ascii "
fi

# Validate Destinatin Directory
if [ -d $DEST_DIR ]
then
	if [ -w $DEST_DIR ]
	then
		: # Cool.  Can write to directory.
	else
		echo $LOGNAME does not have write authority to directory $DEST_DIR
		echo exiting
		exit -1
	fi
else
	echo Destination Directory $DEST_DIR is not a directory 
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

# Validate numeric parms
let TEST_NUM=$VOL_SER_NUM_FIRST+1
if [ $? -ne 0 ]
then
	echo "Non-numeric Vol Ser Numeric portion ==>$VOL_SER_NUM_FIRST<==."
	echo $USAGE
	exit -1
fi

let TEST_NUM=$NUM_TAPES+1
if [ $? -ne 0 ]
then
	echo "Number of tapes is non-numeric ==>$NUM_TAPES<==."
	echo $USAGE
	exit -1
fi

FILE_NAME_AUTO=N
if [ "?" = "$FILE_NAME_BASE" ]
then
	: # Use info from header "vol ser" file
	FILE_NAME_AUTO=Y
	# Add call here to trimmed-down version of vol_ser_sniff.pl that just
	# gets the file name from the header label, and does a rewind.
	echo Auto file name extract not yet supported.  Get busy and write it.
	exit -1
fi

LRECL_AUTO=N
if [ "?" = "$LRECL" ]
then
	: # Use info from header "vol ser" file
	LRECL_AUTO=Y
else
	let TEST_NUM=$LRECL+1
	if [ $? -ne 0 ]
	then
		echo "Logical Record Length is non-numeric ==>$LRECL<==."
		echo $USAGE
		exit -1
	fi
fi

BLKSIZE_AUTO=N
if [ "?" = "$BLKSIZE" ]
then
	: # Use info from header "vol ser" file
	BLKSIZE_AUTO=Y
else
	let TEST_NUM=$BLKSIZE+1
	if [ $? -ne 0 ]
	then
		echo "Block size is non-numeric ==>$BLKSIZE<==."
		echo $USAGE
		exit -1
	fi
fi


# Calc various info
let VOL_SER_NUM_LAST=$VOL_SER_NUM_FIRST+$NUM_TAPES-1

# pad with zeros if needed
LEN_NUM_FIRST=`echo $VOL_SER_NUM_FIRST | wc -c | tr -d ' '`
LEN_NUM_LAST=`echo $VOL_SER_NUM_LAST | wc -c | tr -d ' '`
echo HEY LEN_NUM_FIRST=$LEN_NUM_FIRST, LEN_NUM_LAST=$LEN_NUM_LAST
let LEN_DIFF=$LEN_NUM_FIRST-$LEN_NUM_LAST
if [ $LEN_DIFF -gt 0 ]
then
	VOL_SER_NUM_LAST=`echo "0000000" | cut -c1-$LEN_DIFF`$VOL_SER_NUM_LAST
fi

if [ $NUM_TAPES -eq 1 ]
then
	TAPE_INFO=tape
else
	TAPE_INFO=tapes
fi

# The values below are on the high side a bit
if [ "3490E" = "$TAPE_CART" ]
then
	#3490E cartridges
	let TOTAL_KBYTES_NEEDED=$NUM_TAPES*2697945
else
	if [ "3490" = "$TAPE_CART" ]
	then
		#3490 cartridges
		let TOTAL_KBYTES_NEEDED=$NUM_TAPES*822000
	else
		if [ "3480" = "$TAPE_CART" ]
		then
			#3480 cartridges
			let TOTAL_KBYTES_NEEDED=$NUM_TAPES*411000
		else
			echo Invalid TAPE_CART: $TAPE_CART
			exit 1
		fi
	fi
fi

KBYTES_AVAIL=`df -k $DEST_DIR | tail -1 | tr -s ' ' | cut -d' ' -f4`
echo "KBYTES_AVAIL ==>$KBYTES_AVAIL<=="
# Add 10 meg for fun
let TOTAL_KBYTES_NEEDED=$TOTAL_KBYTES_NEEDED+10240
echo "KBYTES Needed==>$TOTAL_KBYTES_NEEDED<=="
if [ $TOTAL_KBYTES_NEEDED -gt $KBYTES_AVAIL ]
then
	echo "Error: Not enough disk space on $DEST_DIR.  Need: $TOTAL_KBYTES_NEEDED Kb, available: $KBYTES_AVAIL Kb"
	echo "Assuming source $TAPE_INFO is $TAPE_CART.  If 3480, need to modify $0 to"
	echo "add an optional parm of cartridge type, and set Assuming source $TAPE_INFO is $TAPE_CART.  If 3480, need to modify $0 to let TOTAL_KBYTES_NEEDED=$NUM_TAPES* (appropriate value for cart).  See write_tape_generic.sh for some code to leverage."
	exit -1
fi

#!!echo Hit Enter to read $NUM_TAPES $TAPE_INFO to directory $DEST_DIR
echo Going to read $NUM_TAPES $TAPE_INFO to directory $DEST_DIR
echo Vol Ser ${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST} to \
	${VOL_SER_ALPHA}${VOL_SER_NUM_LAST} blksize=$BLKSIZE \
	and $EOF_OPTION last tape
#!!read stuff



# Don't Clobber log files

if [ -f $DEST_DIR/${FILE_NAME_BASE}.out -a -w $DEST_DIR/${FILE_NAME_BASE}.err ]
then
	: # log files exist - leave 'em be
else
	# Create log files
	> $DEST_DIR/${FILE_NAME_BASE}.out 2> $DEST_DIR/${FILE_NAME_BASE}.err
fi

if [ -w $DEST_DIR/${FILE_NAME_BASE}.out -a -w $DEST_DIR/${FILE_NAME_BASE}.err ]
then
	: # OK to write in this dir
else
	echo Unable to write files in `pwd`
	exit -1
fi

echo `date '+%D %T'` read_tape.sh going to read $NUM_TAPES $TAPE_INFO \
	starting with VOL_SER=${VOL_SER_ALPHA}${VOL_SER_NUM_FIRST}, \
	last=${VOL_SER_ALPHA}${VOL_SER_NUM_LAST} \
	| tee -a $DEST_DIR/${FILE_NAME_BASE}.out 

echo 	`date '+%D %T'` Base File Name=$FILE_NAME_BASE, Lrecl=$LRECL, \
	Blocksize=$BLKSIZE \
	| tee -a $DEST_DIR/${FILE_NAME_BASE}.out 


CURR_TAPE=$VOL_SER_NUM_FIRST

# 2: TAPE_OPTIONS="conv=ascii,unblock ibs=$BLKSIZE cbs=$LRECL "
# 3: TAPE_OPTIONS="conv=ascii,unblock ibs=$BLKSIZE "
# 4: TAPE_OPTIONS="conv=ascii ibs=$BLKSIZE cbs=$LRECL "
#TAPE_OPTIONS_LABEL="conv=ascii,unblock ibs=$BLKSIZE_HDR cbs=80 "
#TAPE_OPTIONS_LABEL="conv=ascii,unblock cbs=80 "
TAPE_OPTIONS_LABEL="conv=unblock,ascii cbs=80 "
#TAPE_OPTIONS_DATA="conv=unblock,ascii ibs=$BLKSIZE cbs=$LRECL "
TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT ibs=$BLKSIZE cbs=$LRECL "
#!!	TAPE_OPTIONS_CONVERT="conv=ascii,unblock "

$DEBUG mt status >> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
RC_MT_STATUS=$?
if [ $RC_MT_STATUS -ne 0 ]
then
	echo `date '+%D %T'` "Error $RC_MT_STATUS doing preliminary mt status " 
	more $DEST_DIR/${FILE_NAME_BASE}.[oe][ur][tr]
	exit -1
else
	# If just one tape, check if not first file on tape.  
	read_tape_file_number.sh
	# CURR_TAPE_FILE_NUMBER = File number as reported by mt status
	CURR_TAPE_FILE_NUMBER=$?
	if [ $CURR_TAPE_FILE_NUMBER -gt 0 ]
	then
		# Not at beginning of tape.  See if file number multiple of 3
		# (3 = header file, data file, trailer file)
		let LAST_FILE_ON_TAPE_FLAG=$CURR_TAPE_FILE_NUMBER%3
		if [ $LAST_FILE_ON_TAPE_FLAG -eq 0 ]
		then
			: # All OK - divisable by 3
			echo "!! CURR_TAPE_FILE_NUMBER=$CURR_TAPE_FILE_NUMBER"
			echo "!!Tape in right position LAST_FILE_ON_TAPE_FLAG=$LAST_FILE_ON_TAPE_FLAG"
			echo `date '+%D %T'` \
				"Warning: Current file number ($CURR_TAPE_FILE_NUMBER) is not zero.  OK if multiple files are on 1 tape" \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
				$DEST_DIR/${FILE_NAME_BASE}.err
			# Get terminal ID, such as pts/3, to write to user (in case
			# STDOUT is being redirected)
			MY_TERM=`ps -f | grep '[0-9] -ksh' | awk '{ print $6 }' `
			echo Hit ctrl-C NOW to abort. You have 20 seconds to abort
			echo "Warning: Current file number is not zero.  OK if multiple files are on 1 tape.  Do a \"kill -9 $$\" within 20 seconds to abort if process is in background" \
				| write $LOGNAME $MY_TERM 2> /dev/null
			# Give them 30 
			sleep 30
		else
			echo `date '+%D %T'` \
				"Error: Current file number ($CURR_TAPE_FILE_NUMBER) is not zero, nor a multiple of 3.  " \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
					$DEST_DIR/${FILE_NAME_BASE}.err
			exit -1
		fi
	fi
fi

TTL_FILE_SIZE=0
TEMP_FILE_NAME=/tmp/read_tape_$$.txt

while [ $CURR_TAPE -le $VOL_SER_NUM_LAST ]
do
	echo `date '+%D %T'` \
		"working on Tape Vol Ser: ${VOL_SER_ALPHA}${CURR_TAPE} (derived) " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err

	# Keep track of tape info
	#vol_ser_catalog_both.pl 
	vol_ser_catalog.pl \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out 

	echo `date '+%D %T'` \
		"Reading vol ser header for ${VOL_SER_ALPHA}${CURR_TAPE} (derived)" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err

	# Don't use tee here - it will clobber the return code from dd
	set -x  # !! TEMP DEBUG
	time $DEBUG /usr/bin/dd if=/dev/rmt/0n \
		of=$TEMP_FILE_NAME \
		$TAPE_OPTIONS_LABEL \
			>> $DEST_DIR/${FILE_NAME_BASE}.out \
			2>> $DEST_DIR/${FILE_NAME_BASE}.err 
	RC_READ_HEADER=$?
	if [ $RC_READ_HEADER -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_READ_HEADER Reading vol ser header " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape.  mt status follows: \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		mt status \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		exit -1
	fi
	# Get actual vol ser from tape label
	# Set base file name using actual vol ser from tape label
	VOL_SER_FROM_LABEL=`grep '^VOL1' $TEMP_FILE_NAME | cut -c5-10`
	BASE_FILE_NAME_W_VOLSER=${FILE_NAME_BASE}_${VOL_SER_FROM_LABEL}
	echo `date '+%D %T'` \
		"BASE_FILE_NAME_W_VOLSER=>$BASE_FILE_NAME_W_VOLSER<=" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
	cp $TEMP_FILE_NAME $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0
	set +x  # !! TEMP DEBUG
	# Reset status to reading from just loaded
	tape_web_page_refresh.sh reading

	# Don't use tee here - it will clobber the return code from mt status
	$DEBUG mt status \
		>> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
	RC_MT_STATUS=$?
	if [ $RC_MT_STATUS -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_MT_STATUS doing 1st mt status " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape
		exit -1
	fi

	#!!set -x  # !! TEMP DEBUG
	if [ "Y" = "$LRECL_AUTO" ]
	then
		# Recalculate for each tape to be on the safe side

		# See if FIXED_BLOCK - from header "vol ser" file: 
		# Note that the value for Fixed is F, the value for Variable is V or D
		# FIXED_BLOCK flag is in CC 5 of the record that starts with HDR2
		FIXED_BLOCK=`grep '^HDR2' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 | cut -c5`
		if [ "F" = "$FIXED_BLOCK" ]
		then
			: # OK
			# Use info from header "vol ser" file: LRECL is in CC 11-15 of the
			# record that starts with HDR2
			LRECL=`grep '^HDR2' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 | cut -c11-15`
			# strip off leading zeros
			let LRECL=$LRECL
			#!!!TAPE_OPTIONS_DATA="conv=ascii,unblock ibs=$BLKSIZE cbs=$LRECL "
			TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT ibs=$BLKSIZE cbs=$LRECL "
			#!!TAPE_OPTIONS_DATA="conv=ascii ibs=$BLKSIZE cbs=$LRECL "
			#!! echo HEY hit enter to continue
			#!! read ans
		else
			#!!TAPE_OPTIONS_DATA="conv=ascii "
			#!! To Do: Use MVS::VBFile
			#!! man MVS::VBFile.3 
			#!!!TAPE_OPTIONS_DATA=" "
			TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT "
			echo "Input tape data is in variable lrecl format. Leaving in EBCDIC char set. " \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
				$DEST_DIR/${FILE_NAME_BASE}.err
		fi
	else
		echo "Using cmd line lrecl = $LRECL"
	fi

	if [ "Y" = "$BLKSIZE_AUTO" ]
	then
		# Recalculate for each tape to be on the safe side

		# See if FIXED_BLOCK - from header "vol ser" file: 
		# Note that the value for Fixed is F, the value for Variable is V or D
		# FIXED_BLOCK flag is in CC 5 of the record that starts with HDR2
		FIXED_BLOCK=`grep '^HDR2' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 | cut -c5`
		if [ "F" = "$FIXED_BLOCK" ]
		then
			: # OK
			# Use info from header "vol ser" file: BLKSIZE is in CC 6-10 of the
			# record that starts with HDR2
			BLKSIZE=`grep '^HDR2' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 | cut -c6-10`
			# strip off leading zeros
			let BLKSIZE=$BLKSIZE
			#!!!TAPE_OPTIONS_DATA="conv=ascii,unblock ibs=$BLKSIZE cbs=$LRECL "
			TAPE_OPTIONS_DATA="$TAPE_OPTIONS_CONVERT ibs=$BLKSIZE cbs=$LRECL "
			#!!TAPE_OPTIONS_DATA="conv=ascii ibs=$BLKSIZE cbs=$LRECL "
			#!! echo HEY hit enter to continue
			#!! read ans
		else
			# Variable blocked.  Use ibs= but not cbs=
			# Use info from header "vol ser" file: BLKSIZE is in CC 6-10 of the
			# record that starts with HDR2
			BLKSIZE=`grep '^HDR2' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 | cut -c6-10`
			if [ -z "$BLKSIZE" ]
			then
				echo `date '+%D %T'` \
					"Error getting BLKSIZE from $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_0 - check for HDR2 rec " \
					| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
						$DEST_DIR/${FILE_NAME_BASE}.err
				echo You may need to mt rewind this tape
				exit -1
			fi
			#!!TAPE_OPTIONS_DATA="conv=ascii,unblock ibs=$BLKSIZE cbs=$LRECL "
			#!!TAPE_OPTIONS_DATA="conv=ascii ibs=$BLKSIZE "
			#!! To Do: Use MVS::VBFile
			#!! man MVS::VBFile.3 
			TAPE_OPTIONS_DATA="ibs=$BLKSIZE  "
			echo "Input tape data is in variable lrecl format. Leaving in EBCDIC char set. Using only " \
				"ibs=$BLKSIZE parameter" \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
				$DEST_DIR/${FILE_NAME_BASE}.err
		fi
	else
		echo "Using cmd line blksize = $BLKSIZE"
	fi

	
	echo `date '+%D %T'` "Reading data for $VOL_SER_FROM_LABEL" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
	# Don't use tee here - it will clobber the return code from dd
	set -x  # !! TEMP DEBUG
	if [ $CONVERT_DATA -eq 1 ]
	then
		# Use dd with no "of" parm, pipe to DATA_FILTER_PARM 
		time $DEBUG /usr/bin/dd if=/dev/rmt/0n \
			$TAPE_OPTIONS_DATA \
			2>> $DEST_DIR/${FILE_NAME_BASE}.err |
				$DATA_FILTER_PARM $DATA_OPTIONS_CONVERT \
				> $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_1 \
				2>> $DEST_DIR/${FILE_NAME_BASE}.err
		RC_READ_DATA=$?
		# Need to grep $DEST_DIR/${FILE_NAME_BASE}.err to see if dd had a
		# error, since the $DATA_FILTER_PARM program might have masked a 
		# bad RC
		grep '^read:' $DEST_DIR/${FILE_NAME_BASE}.err
		if [ $? -eq 0 ]
		then
			# Found string - there was an error
			RC_READ_DATA=123
		fi
	else
		# Write directly to file
		time $DEBUG /usr/bin/dd if=/dev/rmt/0n \
			of=$DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_1 \
			$TAPE_OPTIONS_DATA \
			>> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
		RC_READ_DATA=$?
	fi
	if [ $RC_READ_DATA -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_READ_DATA reading data" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape.  mt status follows: \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		mt status \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		exit -1
	fi
	#!!set +x  # !! TEMP DEBUG
	#!!set +y  # !! TEMP DEBUG
	$DEBUG mt status \
		>> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
	RC_MT_STATUS=$?
	if [ $RC_MT_STATUS -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_MT_STATUS doing 2nd mt status " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		exit -1
	fi

	# Collect statistics for file size
	LAST_FILE_SIZE=`stat --format='%s' $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_1`
	let TTL_FILE_SIZE=$TTL_FILE_SIZE+$LAST_FILE_SIZE
	ALL_DATA_FILE_NAMES="$ALL_DATA_FILE_NAMES $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_1"
	# !! Replace the 34xx below with the correct cartridge info when available
	# !! Try the Record Density field? (See Rec Dens in vol_ser_catalog_both.pl)
	echo "$DEST_DIR\t$LAST_FILE_SIZE\t34xx\t${VOL_SER_FROM_LABEL}" >> ${CLIENT_BASE}/common/log/tape_size_hist.txt

	#!!set +x  # !! TEMP DEBUG
	set +x  # !! TEMP DEBUG

	echo `date '+%D %T'` "Reading vol ser trailer for ${VOL_SER_FROM_LABEL}" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
	echo `date '+%D %T'` "dd of parm: $DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_2" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
	time $DEBUG /usr/bin/dd if=/dev/rmt/0n \
		of=$DEST_DIR/${BASE_FILE_NAME_W_VOLSER}_2 \
		$TAPE_OPTIONS_LABEL \
		>> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
	RC_READ_TRAILER=$?
	if [ $RC_READ_TRAILER -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_READ_TRAILER Reading vol ser trailer" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape
		exit -1
	fi

	# Reset status from reading to just loaded
	tape_web_page_refresh.sh 

	$DEBUG mt status \
		>> $DEST_DIR/${FILE_NAME_BASE}.out 2>> $DEST_DIR/${FILE_NAME_BASE}.err
	RC_MT_STATUS=$?
	if [ $RC_MT_STATUS -ne 0 ]
	then
		echo `date '+%D %T'` "Error $RC_MT_STATUS doing 3rd mt status " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		echo You may need to mt rewind this tape
		exit -1
	fi

	if [ $CURR_TAPE -eq $VOL_SER_NUM_LAST ]
	then
		# Last tape.  Rewind or Eject to next tape
		if [ "eject" = "$EOF_OPTION" ]
		then
			echo `date '+%D %T'` "Switching to next tape " \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
				$DEST_DIR/${FILE_NAME_BASE}.err
			# Don't do a tee here - it will clobber the return code
			time $DEBUG mt_swap_tape.sh swap \
				>> $DEST_DIR/${FILE_NAME_BASE}.out \
				2>> $DEST_DIR/${FILE_NAME_BASE}.err
			RC_MT_SWAP=$?
			if [ $RC_MT_SWAP -ne 0 ]
			then
				echo `date '+%D %T'` "Error $RC_MT_SWAP doing mt_swap_tape.sh" \
					| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
					$DEST_DIR/${FILE_NAME_BASE}.err
				exit -1
			fi
		else
            if [ "rewind" = "$EOF_OPTION" ]
            then
				echo `date '+%D %T'` "Rewinding last tape " \
					| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
					$DEST_DIR/${FILE_NAME_BASE}.err
				time $DEBUG mt rewind \
					>> $DEST_DIR/${FILE_NAME_BASE}.out \
					2>> $DEST_DIR/${FILE_NAME_BASE}.err
				RC_MT_REW=$?
				if [ $RC_MT_REW -ne 0 ]
				then
					echo `date '+%D %T'` "Error $RC_MT_REW doing mt rewind " \
						| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
						$DEST_DIR/${FILE_NAME_BASE}.err
					exit -1
				fi
			else
                echo `date '+%D %T'` "Leaving last tape positioned at EOF" \
						| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
						$DEST_DIR/${FILE_NAME_BASE}.err
			fi
		fi
	else
		echo `date '+%D %T'` "Switching to next tape " \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
		# Don't do a tee here - it will clobber the return code
		time $DEBUG mt_swap_tape.sh swap \
			>> $DEST_DIR/${FILE_NAME_BASE}.out \
			2>> $DEST_DIR/${FILE_NAME_BASE}.err
		RC_MT_SWAP=$?
		if [ $RC_MT_SWAP -ne 0 ]
		then
			echo `date '+%D %T'` "Error $RC_MT_SWAP doing a mt_swap_tape.sh" \
				| tee -a $DEST_DIR/${FILE_NAME_BASE}.out \
				$DEST_DIR/${FILE_NAME_BASE}.err
			exit -1
		fi
	fi

	echo `date '+%D %T'` " - End of Loop" \
		| tee -a $DEST_DIR/${FILE_NAME_BASE}.out $DEST_DIR/${FILE_NAME_BASE}.err
	ps -f -p $$ \
		>> $DEST_DIR/${FILE_NAME_BASE}.out 

	# Bump counter
	let CURR_TAPE=$CURR_TAPE+1
	# pad with zeros if needed
	LEN_NUM_LAST=`echo $CURR_TAPE | wc -c | tr -d ' '`
	echo HEY LEN_NUM_FIRST=$LEN_NUM_FIRST, LEN_NUM_LAST=$LEN_NUM_LAST
	let LEN_DIFF=$LEN_NUM_FIRST-$LEN_NUM_LAST
	if [ $LEN_DIFF -gt 0 ]
	then
		CURR_TAPE=`echo "0000000" | cut -c1-$LEN_DIFF`$CURR_TAPE
	fi
	echo HEY CURR_TAPE=$CURR_TAPE

done

# Page Mark so he can know it is OK to swap tapes
if [ $NUM_TAPES -gt 1 ]
then
	pager "Done w/ last tape" "$NUM_TAPES tapes read." 
	mailer "Done w/ last tape" "$NUM_TAPES tapes read." 
else
	: # Don't bother me
	#pager "Done reading tape" "$NUM_TAPES tape read." 
fi


# !! Need to move the following into "if [ $NUM_TAPES -gt 1 ]" block
KBYTES_AVAIL=`df -k $DEST_DIR | tail -1 | tr -s ' ' | cut -d' ' -f4`
echo "KBYTES_AVAIL ==>$KBYTES_AVAIL<=="
echo "TTL_FILE_SIZE==>$TTL_FILE_SIZE<=="
# Add 10 meg for fun, and divide to get KBYTES
let CAT_TOTAL_KBYTES_NEEDED=\($TTL_FILE_SIZE+10240000\)/1024
echo "Cat KBYTES Needed==>$CAT_TOTAL_KBYTES_NEEDED<=="
if [ $CAT_TOTAL_KBYTES_NEEDED -gt $KBYTES_AVAIL ]
then
	echo "Error: Not enough disk space on $DEST_DIR to cat files.  Need: $CAT_TOTAL_KBYTES_NEEDED Kb, available: $KBYTES_AVAIL Kb"
	echo "Assuming source $TAPE_INFO is $TAPE_CART.  If 3480, need to modify $0 to"
	echo "add an optional parm of cartridge type, and set Assuming source $TAPE_INFO is $TAPE_CART.  If 3480, need to modify $0 to let TOTAL_KBYTES_NEEDED=$NUM_TAPES* (appropriate value for cart).  See write_tape_generic.sh for some code to leverage."
	exit -1
fi

# $ALL_DATA_FILE_NAMES 
if [ $NUM_TAPES -gt 1 ]
then
	# Ensure number of files for wildcard matches number of files expected,
	# which is $NUM_TAPES
	FILE_COUNT=`ls $ALL_DATA_FILE_NAMES | wc -l`
	if [ $FILE_COUNT -ne $NUM_TAPES ]
	then
		echo Cannot concatenate files: # of Files matching ALL_DATA_FILE_NAMES \($FILE_COUNT\)
		echo is not equal to # of tapes specified on command line \($NUM_TAPES\):
		echo ALL_DATA_FILE_NAMES: $ALL_DATA_FILE_NAMES
		ls -o $ALL_DATA_FILE_NAMES
		exit -1
	fi

	# Ensure target file does not exist
	#if [ -f $DEST_DIR/${FILE_NAME_BASE}_ALL ]
	if [ -f $DEST_DIR/${FILE_NAME_BASE}.inv ]
	then
		echo Cannot concatenate files: 
		ls -o $ALL_DATA_FILE_NAMES
		echo Destination file already exists
		ls -o $DEST_DIR/${FILE_NAME_BASE}.inv 
		exit -1
	fi

	# Offer to conCATenate files
	# Get OK (well, Y/N) to proceed with cat
	#!!echo "OK to concatenate $ALL_DATA_FILE_NAMES ? (Y/N) \c"
	echo "Going to concatenate $ALL_DATA_FILE_NAMES"
	#!!read ans
	#!!echo $ans | grep -i '^Y' > /dev/null 2>&1
	echo 'Y'  | grep -i '^Y' > /dev/null 2>&1
	OK_RC=$?
	if [ $OK_RC -eq 0 ]
	then
		/usr/local/bin/cat $ALL_DATA_FILE_NAMES > $DEST_DIR/${FILE_NAME_BASE}.inv
		CAT_RC=$?
		if [ $CAT_RC -ne 0 ]
		then
			echo Error in concatenating files 
		else
			echo 
			echo About to rm $ALL_DATA_FILE_NAMES
			rm $ALL_DATA_FILE_NAMES
			echo 
		fi
	else
		echo Did not concatenate files: 
		ls -o $ALL_DATA_FILE_NAMES
	fi
fi


#!! temp
echo FYI $TEMP_FILE_NAME contents:
cat $TEMP_FILE_NAME
#!! end temp
rm $TEMP_FILE_NAME

exit 0



