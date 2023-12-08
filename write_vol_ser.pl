#!/usr/local/bin/perl -w

use Time::Local;

# write_vol_ser.pl - writes an electronic tape label
# Historical URLS
# See http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/DGT1M300/2.3
# and http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/DGT1M300/CONTENTS#2.2
# and http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/IGG3M300/CONTENTS#3.16
# and http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/IGG3M300/CONTENTS#2.13
# Current:  # https://www.ibm.com/docs/en/zos/2.1.0?topic=format-standard-data-set-label-1-hdr1eov1eof1

$USAGE='write_vol_ser.pl vol_ser_first vol_ser_curr file_name_base lrecl blksize curr_tape_# ttl_tapes dataset_num cart_type F|V [block_count]';

die "Invalid number of parameters (" .
    ($#ARGV + 1) .
    ") Usage:\n$USAGE\n"
    if (($#ARGV + 1) < 10 || 
		($#ARGV + 1) > 11 );



$VOL_SER_FIRST = $ARGV[0];
$VOL_SER_CURR = $ARGV[1];
$FILE_NAME = $ARGV[2];
$LRECL = $ARGV[3];
$BLKSIZE = $ARGV[4];
$CURR_TAPE_NUM = $ARGV[5];
$TOTAL_NUM_TAPES = $ARGV[6];
# File sequence number (file sequence on tape, for many files on a tape)
$FILE_SEQ_NUM = $ARGV[7]; # dataset_num - If > 1 file on tape.
$cart_type = $ARGV[8];
die "Invalid cartridge type:  " . $cart_type . ". Valid: 3480|3490|3490E\n"
	if ($cart_type !~ /^(34[89]0|3490E)$/);

$RECFM = $ARGV[9];
$BLOCK_COUNT = $ARGV[10]
	if ($#ARGV == 10);

# Tape Recording Technique: "  " or "P " for compressed (3490E)
$COMPRESSED = ($cart_type eq '3490E' ? 'P ' : '  ');

#warn "BLOCK_COUNT is $BLOCK_COUNT and \$#ARGV is $#ARGV";

$SPACES = '                                                                                ';

if (length($FILE_NAME) > 17)
{
	$NEW_FILE_NAME = substr $FILE_NAME, length($FILE_NAME)-17, 17;
	warn "FILE_NAME $FILE_NAME longer than 17 characters. Using " .
		"right-most 17: $NEW_FILE_NAME";
	$FILE_NAME = $NEW_FILE_NAME;
}


die "Invalid RECFM ==>$RECFM<==:  Should be F or V"
	if (($RECFM !~ /^F|V$/));

die "VOL_SER_FIRST $VOL_SER_FIRST longer than 6 characters. "
	if (length($VOL_SER_FIRST) > 6);
# Spec allows for trailing blanks, but why ask for trouble
die "VOL_SER_FIRST $VOL_SER_FIRST invalid: Must be 3 Uppercase A-Z or 0-9, " .
	"followed by 3 numeric characters."
	if ($VOL_SER_FIRST !~ /^[A-Z0-9]{3}[0-9]{3}$/);

die "VOL_SER_CURR $VOL_SER_CURR longer than 6 characters. "
	if (length($VOL_SER_CURR) > 6);
die "VOL_SER_CURR $VOL_SER_CURR invalid: Must be 3 Uppercase A-Z or 0-9, " .
	"followed by 3 numeric characters."
	if ($VOL_SER_CURR !~ /^[A-Z0-9]{3}[0-9]{3}$/);


#print STDERR "SPACES len=" . length($SPACES) . "\n";

if (defined $BLOCK_COUNT)
{
	# EOF: End Of File, EOV: End Of (tape) Volume
	$REC_TYPE = ($CURR_TAPE_NUM == $TOTAL_NUM_TAPES) ? 'EOF' : 'EOV';
}
else
{
	$REC_TYPE = 'HDR';
}

$BLOCK_COUNT_FMT = (defined $BLOCK_COUNT) 
	? sprintf ("%07d", $BLOCK_COUNT)
	: '0000000';

#
# Print VOL1 record if header file
#
# !! To Do:  Handle file sequence numbers for several files on one tape.
# Don't print VOL1 header if file sequence number > 1
if ($FILE_SEQ_NUM gt "0001")
{
	# See http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/IGG3M300/3.16?DT=19911220181358
	print "VOL1$VOL_SER_CURR" . substr($SPACES,0,70) . "\n"
		if (! defined $BLOCK_COUNT);
}

$FILE_NAME = $FILE_NAME . substr($SPACES,0,17-length($FILE_NAME))
	if (length($FILE_NAME) < 17);

# Calculate Creation Date and Expiration Date
# Get current time
#
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = gmtime;

# Creation Date: cyyddd in theory; probably yyyddd 
# if yyyy = 2003 and ddd = 159, then us 003159 (drop the 2)
$year += 1900;
$three_digit_year = sprintf("%03d", $year % 1000);
$three_digit_yday = sprintf("%03d", $yday+1);
$create_date_formatted = "$three_digit_year$three_digit_yday";
#print STDERR "three_digit_year==>$three_digit_year<== three_digit_yday==>$three_digit_yday<==\n";
#print STDERR "yday==>$yday<==\n";
#print STDERR "create_date_formatted==>$create_date_formatted<==\n";

# Calc expiration date - 10 years from today
$expire_date = timegm($sec, $min, $hour, $mday, $mon, ($year + 10));
($sec, $min, $hour, $mday, $mon, $e_year, $wday, $e_yday) = 
	gmtime($expire_date);
$e_year += 1900;
$e_three_digit_year = sprintf("%03d", $e_year % 1000);
$three_digit_e_yday = sprintf("%03d", $e_yday+1);
$expire_date_formatted = "$e_three_digit_year$three_digit_e_yday";


#
# Print xxx1 record
#

# !! To Do:  Handle file sequence numbers for several files on one tape.
# Need to accept file sequence number as a parm, replacing hard-coded value:
#	"0001", # File sequence number (file sequence on tape, for many files on
# below.

print "${REC_TYPE}1$FILE_NAME", 
	$VOL_SER_FIRST,
	sprintf ("%04d", $CURR_TAPE_NUM), # Volume Sequence #
	sprintf ("%04d", $FILE_SEQ_NUM), # File sequence number 
			#(file sequence on tape, for many files on one tape)
	"    ", # Generation Number (G1234V12 - Generation Data Set)
	"  ", # Version Number  (G1234V12 - Generation Data Set)
	$create_date_formatted,
	$expire_date_formatted,
	"$BLOCK_COUNT_FMT",	
	"IBM OS/VS 370       \n";
	# Note: Some MVS tape systems use the value in System Code (set to
	# "IBM OS/VS 370" here) to determine how the following labels are 
	# processed.  See http://publibz.boulder.ibm.com/cgi-bin/bookmgr_OS390/BOOKS/IGG3M300/3.17 for details.
	# To be safest, could set to "OS370        " but most tapes we get in are
	# set to these values:
	#
	# 214 IBM OS/VS 370
	#   4 IBMOS400
	#   1 IBMVM370CMS

#
# Print xxx2 record
#
print "${REC_TYPE}2${RECFM}" . 
	sprintf ("%05d", $BLKSIZE) .
	sprintf ("%05d", $LRECL) .
	" ", # Recording density (blank (cart), 0-5)
	($CURR_TAPE_NUM == 1 ? "0" : "1"),
	"         ",
	"        ",	# JCL Job Step?
	$COMPRESSED, #  Compressed
	" ", #  Control Character
	" ", #  Reserved
	"B   ",
	"     ", substr($SPACES,0,33), "\n";
	
