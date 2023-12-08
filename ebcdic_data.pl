#!/usr/local/bin/perl -w

# Read in an EBCDIC character set file, and write it 
# out in ASCII character set, Unix-friendly LF-terminated records, clearing
# out any binary data in either cc 221-228, or cc 225-228 and 263-266 depending
# on file type.
#
# The data needs to be read from tape in native EBCDIC character set, and 
# processed here to replace binary data with spaces, to eliminate the 
# possibility of the binary data containing a line feed: 0x0a.
#


use Convert::EBCDIC;



#!! OLD: Specify file type: $USAGE="ebcdic_data.pl -lrecl=### inout|card filename \nwhere inout for inbound1 or outbound1 records, card is   for card3 records.";
$USAGE="ebcdic_data.pl -lrecl=### [filename [filename ...]]";

($#ARGV >= 0)
	|| die "Invalid number of parameters: " . ($#ARGV + 1) .
	". Usage: \n$USAGE\n";

# Process logical record length parm
$lrecl = shift @ARGV 
	|| die "Missing logical record length parameter. Usage: $USAGE\n";

$lrecl =~ /^-lrecl=[0-9]+$/
	|| die "Invalid parameter ==>$lrecl<==. Expecting -lrecl=####. Usage: \n$USAGE\n";

# Eat off "-lrecl="
$lrecl = substr($lrecl, index($lrecl,'=')+1);

#
# Initial setup
#

($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime(time);
print STDERR 
    ($year + 1900 ) .
	"/" . (($mon + 1) < 10 ? "0" . ($mon + 1) : ($mon + 1))  .
    "/" . ($mday < 10 ? "0" . $mday : $mday) . 
	" " .
    ($hour < 10 ? "0" . $hour : $hour) .
    ":" . ($min < 10 ? "0" . $min : $min) .
    ":" . ($sec < 10 ? "0" . $sec : $sec) .
	"|ebcdic_data.pl Started|" .
	"\n";

$bytes_read=0;
$bytes_read_file=0;
$bytes_read_ttl=0;
$recs_file=0;
$card_recs=0;
$non_card_recs=0;
$recs_ttl=0;
$files_ttl=0;


if ($#ARGV == -1)
{
	push @ARGV, "-"; # Add STDIN to list of files
	print STDERR "No files specified. Reading from STDIN\n";
}

foreach $filename (@ARGV)
{
	if (-r $filename || $filename eq '-')
	{
		$open_rc = open (CURR_FILE, $filename);
		if ($open_rc == 0)
		{
			print STDERR "Unable to open file $filename ->$!<- (rc=$open_rc) skipping\n";
		}
		else
		{
			$files_ttl++;
			$bytes_read=0;
			$bytes_read_file=0;
			$recs_file=0;
			$bytes_read = read CURR_FILE, $curr_rec, $lrecl;
            while ($bytes_read > 0)
            {
				$bytes_read_file += $bytes_read;
				$recs_file++;
				$ascii_string = Convert::EBCDIC::ebcdic2ascii($curr_rec);
				#
				# Determine record type.  Outbound and TollFree 
				#
				# Inbound1 or Outbound1 file format
				# Outbound1 file format: cc 1-5 is 10155, 10179, 10255, 10279
				# Inbound1  file format: cc 1-5 is (unknown, but probably is
				#           10153, 10159, 10199, 10553, 10559)
				# Clobber binary data at cc 221-228 (offset 220-227) w/spaces
				#
				# Card3 file format: cc 1-5 is 10149
				# Clobber binary data at cc 225-228 (offset 224-227) w/spaces
				# Clobber binary data at cc 263-266 (offset 262-265) w/spaces
				#
				if (substr($ascii_string, 0, 5) eq "10149")
				{
					#Card3 file format
					$card_recs++;

					#Clobber binary data at cc 225-228 (offset 224-227) w/spaces
					substr($ascii_string, 224, 4) = '    ';
					#Clobber binary data at cc 263-266 (offset 262-265) w/spaces
					substr($ascii_string, 262, 4) = '    ';
				}
				else
				{
					#Inbound1 or Outbound1 file format
					$non_card_recs++;

					#Clobber binary data at cc 221-228 (offset 220-227) w/spaces
					substr($ascii_string, 220, 8) = '        ';
				}
				print STDOUT $ascii_string, "\n";
				$bytes_read = read CURR_FILE, $curr_rec, $lrecl;
	   		}

			
			$close_rc = close (CURR_FILE);
			$bytes_read_ttl+=$bytes_read_file;
			$recs_ttl+=$recs_file;
			print STDERR "read $bytes_read_file bytes, $recs_file records ",
				"from $filename\n";
			}
	}
    else
    {
        print STDERR "Unable to read file $filename - skipping\n";
    }
}


($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime(time);
print STDERR 
    ($year + 1900 ) .
	"/" . (($mon + 1) < 10 ? "0" . ($mon + 1) : ($mon + 1))  .
    "/" . ($mday < 10 ? "0" . $mday : $mday) . 
	" " .
    ($hour < 10 ? "0" . $hour : $hour) .
    ":" . ($min < 10 ? "0" . $min : $min) .
    ":" . ($sec < 10 ? "0" . $sec : $sec) .
	"|ebcdic_data.pl Finished.|Files: $files_ttl. Total Records: $recs_ttl " .
	"Total Client Format A: $card_recs " .
	"Total Non-Client Format A: $non_card_recs " .
	"Total Bytes: $bytes_read_ttl" .
	"\n";



