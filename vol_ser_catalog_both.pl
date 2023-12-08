#!/usr/local/bin/perl -w

# Read in a file containing Vol Ser records and format them nicely (for data dumped previously from tape), or
# if no parameter given, sniff the currently mounted tape files
# Current VOLSER documentation:  # https://www.ibm.com/docs/en/zos/2.1.0?topic=format-standard-data-set-label-1-hdr1eov1eof1



$USAGE='vol_ser_catalog_both.pl  [file [file ...]]';

$CLIENT_BASE=$ENV{'CLIENT_BASE'};
if ( ! -f "${CLIENT_BASE}/common/log/mt_swap_tape_info.txt" )
{
    if ( -f "/export/home/cots/common/log/mt_swap_tape_info.txt" )
    {
        $CLIENT_BASE="/export/home/cots";
    }
}

$STATUS_FILE="${CLIENT_BASE}/common/log/mt_swap_tape_info.txt"; 
$VOL_SER_DB_FILE="${CLIENT_BASE}/common/log/vol_ser_db.dat";


$TAPE_OPTIONS_LABEL="conv=unblock,ascii cbs=80 ";

$info_from_tape = 0;
if ($#ARGV == -1)
{
	$info_from_tape = 1;
	$tape_slot_num=`cat $STATUS_FILE`;
	chomp $tape_slot_num;
	print STDERR "Going to sniff info from currently loaded tape # ",
		"==>$tape_slot_num<==\n";
	# Ensure "file no= 0" from mt status, to ensure tape has been rewound.
	# prompt> mt status
	#Vendor 'DEC     ' Product 'TKZ62CL        ' tape drive:
	#   sense key(0x0)= No Additional Sense   residual= 0   retries= 0
	#   file no= 0   block no= 0
	`mt status | grep "file no= 0" > /dev/null`;
	$RC_GREP=$?;
	if ( $RC_GREP != 0 )
	{
		die "Tape not rewound:  Do a mt status for details\n";
	}


	# Read header file
	$file_hdr="/tmp/vol_ser_sniff_${$}_hdr";
	$hdr_output=`/usr/bin/dd if=/dev/rmt/0n of=$file_hdr $TAPE_OPTIONS_LABEL `;
	
	# Skip data file
	$fsf_output=`mt fsf`;

	# Read trailer file
	$file_tlr="/tmp/vol_ser_sniff_${$}_tlr";
	$tlr_output=`/usr/bin/dd if=/dev/rmt/0n of=$file_tlr $TAPE_OPTIONS_LABEL `;


	# Now shove the header and trailer files onto ARGV, and rewind the tape.
	push @ARGV, $file_hdr;
	push @ARGV, $file_tlr;

	$rew_output=`mt rewind`;
	print STDERR "dd hdr output: $hdr_output\n";
	print STDERR "mt fsf output: $fsf_output\n";
	print STDERR "dd tlr output: $tlr_output\n";
	print STDERR "mt rewind output: $rew_output\n";

	# Now grep for "VOL1" to ensure label was converted from EBCDIC.
	# If not found, tape is in ASCII format, and we need to read it again.
	`grep '^VOL1' $file_hdr > /dev/null`;
	$RC_GREP=$?;
	if ( $RC_GREP == 0 )
	{
		$TAPE_CHAR_SET='EBCDIC';
	}
	else
	{
		$TAPE_OPTIONS_LABEL="conv=unblock cbs=80 ";
		$hdr_output=`/usr/bin/dd if=/dev/rmt/0n of=$file_hdr $TAPE_OPTIONS_LABEL `;
		`grep '^VOL1' $file_hdr > /dev/null`;
		$RC_GREP=$?;
		if ( $RC_GREP != 0 )
		{
			$rew_output=`mt rewind`;
			die "Unable to determine tape character set.  See $file_hdr";
		}
		$TAPE_CHAR_SET='ASCII';

		# Skip data file
		$fsf_output=`mt fsf`;

		# Read trailer file
		$file_tlr="/tmp/vol_ser_sniff_${$}_tlr";
		$tlr_output=`/usr/bin/dd if=/dev/rmt/0n of=$file_tlr $TAPE_OPTIONS_LABEL `;
		# Now rewind the tape.
		$rew_output=`mt rewind`;
		print STDERR "dd hdr output: $hdr_output\n";
		print STDERR "mt fsf output: $fsf_output\n";
		print STDERR "dd tlr output: $tlr_output\n";
		print STDERR "mt rewind output: $rew_output\n";
	}
	print STDERR "tape character set is $TAPE_CHAR_SET.\n";
	

}
else
{
	# die "Invalid number of parameters.  Should have none";
}

# 0 = one parm
$dump_filename = ($#ARGV > 0);


foreach $file (@ARGV)
{

	if (-r $file)
	{
			$open_rc = open (CURR_FILE, $file);
			if ($open_rc == 0)
			{
				print STDERR "Unable to open file $file ->$!<- (rc=$open_rc) skipping\n";
			}
			else
			{
				# Process 
				if ($dump_filename)
				{
					print STDOUT "#############\n", $file, "\n#############\n";
				}

				#	$VOL_SER=substr($rest_rec, 0, 6);
				open (VOL_SER_DB, 
					">>$VOL_SER_DB_FILE")
					|| die "Unable to append $VOL_SER_DB_FILE: $?";

				if ($info_from_tape && $file eq $file_hdr)
				{
					# Create a template HTML file for this tape, that will look
					# like this:
#       <td>
#		<pre>
#	<a href="/env_support/tapes/t_XA7088_info.html">X</a>
#	A
#	7
#	0
#	8
#	8
#		</pre>
#		</td>
#
					open (HTML_FILE, 
						">/usr/local/apache2/htdocs/env_support/tapes/t_${tape_slot_num}.tpl")
						|| die "Unable to open /usr/local/apache2/htdocs/env_support/tapes/t_${tape_slot_num}.tpl: $?";
					print HTML_FILE "	<td>\n";
					print HTML_FILE "	<pre>\n";
				}

				while ( (eof CURR_FILE) != 1)
				{
					$curr_rec = <CURR_FILE>;
					$rec_type = substr($curr_rec, 0, 4);
					$rest_rec = substr($curr_rec, 4);

					SWITCH:
					{
						if ( $rec_type =~ /^VOL1/ )
						{
							$VOL_SER=substr($rest_rec, 0, 6);
							print "Vol Ser:  $VOL_SER\n";
							last SWITCH;
						}

						if ( $rec_type =~ /^HDR1|EO[VF]1/ )
						{
							$FILENAME=substr($rest_rec, 0, 17);
							#print "Filename: " . substr($rest_rec, 0, 17) . "\n";
							print "Filename:  $FILENAME\n";
							print "1st Vol :  " . substr($rest_rec, 17, 6) . "\n";
							print "Tape# (section#): " . substr($rest_rec, 23, 4) . "\n";
							print "(sequenc#):" . substr($rest_rec, 27, 4) . "\n";
							print "(gen   #): " . substr($rest_rec, 31, 4) . "\n";
							$CREATE_DATE_RAW = substr($rest_rec, 37, 6);
							print "Create dt: $CREATE_DATE_RAW";
							# create dt: cyyddd c=century, yy= last two digits
							# of year, ddd=day of year
							$cr_date = timegm(0, 0, 0, # Time
								1, 0, # 0th day of month 0 (Jan 1)
								(substr($CREATE_DATE_RAW, 0, 3)), # Year - 1900
								0, # Weekday
								0 # Day of year
								);
							# Take day of year and multiply by number of 
							# seconds in a day to increment $cr_date.
							$cr_date += ((substr($CREATE_DATE_RAW, 3, 3)) *
								86400); # 86400 seconds in a day
							($sec, $min, $hour, $mday, $mon, $year, 
								$wday, $yday, $isdst) = gmtime($cr_date);
							$cr_date_fmt = gmtime($cr_date) . "\n";
							printf " mm/dd/yyyy: %02d/%02d/%04d\n", 
								$mon+1, $mday, $year + 1900;

							$EXPIRE_DATE_RAW = substr($rest_rec, 43, 6);
							print "Expire dt: $EXPIRE_DATE_RAW";
							$ex_date = timegm(0, 0, 0, # Time
								1, 0, # 0th day of month 0 (Jan 1)
								(substr($EXPIRE_DATE_RAW, 0, 3)), # Year - 1900
								0, # Weekday
								0 # Day of year
								);
							$ex_date += ((substr($EXPIRE_DATE_RAW, 3, 3)) *
								86400); # 86400 seconds in a day
							($sec, $min, $hour, $mday, $mon, $year, 
								$wday, $yday, $isdst) = gmtime($ex_date);
							$ex_date_fmt = gmtime($ex_date) . "\n";
							printf " mm/dd/yyyy: %02d/%02d/%04d\n", 
								$mon+1, $mday, $year + 1900;
							if ( $rec_type =~ /^EO/ )
							{
								# Dump block count
								print "BlkCount: " . substr($rest_rec, 49, 7) . "\n";
								if ( $rec_type =~ /^EOF/ )
								{
									print "(Last volume of file)\n";
								}
								else
								{
									print "(file continues on another volume)\n";
								}
							}
							print "Creator : " . substr($rest_rec, 56, 13) . "\n";
							last SWITCH;
						}

						if ( $rec_type =~ /^HDR2|EO[VF]2/ )
						{
							$FMT=substr($rest_rec, 0, 1);
							print "Fixed/V: $FMT\n";
							#print "Fixed/V: " . substr($rest_rec, 0, 1) . "\n";
							$BLKSIZE=substr($rest_rec, 1, 5);
							print "Blksize: $BLKSIZE\n";
							#print "Blksize: " . substr($rest_rec, 1, 5) . "\n";
							$LRECL=substr($rest_rec, 6, 5);
							print "LRECL  : $LRECL\n";
							#print "LRECL  : " . substr($rest_rec, 6, 5) . "\n";
							#
							# Note: If substr($rest_rec, 30, 2) = 'P ' then
							#       data is compressed.  If not, then if
							#       substr($rest_rec,  11, 1) = '1', then
							#       MAYBE data is compressed.
							print "Rec Dens: " . substr($rest_rec, 11, 1) . "\n";
							print "P- Compressed data follows:>" . substr($rest_rec, 30, 2) . "<\n";
							print "Blocking Attr: " . substr($rest_rec, 34, 1) . "\n";
							if ( substr($rest_rec, 12, 1) eq '0' )
							{
								if ( $rec_type =~ /^EOF2/ )
								{
									print "(First and Last volume of file)\n";
								}
								else
								{
									$VOL_FILE_INFO="(First volume of file)";
									print "$VOL_FILE_INFO\n";
									#print "(First volume of file)\n";
								}
							}
							else
							{
								if ( $rec_type =~ /^EOF2/ )
								{
									print "(subsequent and Last volume of file)\n";
								}
								else
								{
									$VOL_FILE_INFO="(subsequent volume of file)";
									print "$VOL_FILE_INFO\n";
									#print "(subsequent volume of file)\n";
								}
							}
							last SWITCH;
						}

						# Default
						{
							print "Unexpected record type: $rec_type\n";
						}
					}
					print VOL_SER_DB "$VOL_SER\t$curr_rec";
					
				} # end  while ( (eof CURR_FILE) != 1)
				$close_rc = close (CURR_FILE);
				close (VOL_SER_DB);

				if ($info_from_tape && $file eq $file_hdr)
				{
					@VOL_SER_ARRAY = split(/ */, $VOL_SER);
					# Yank first character for fancy stuff
					#	<a href="tapes/t_XA7088_info.html">X</a>
					$first_char = shift @VOL_SER_ARRAY;
					print HTML_FILE "<a href=\"/env_support/tapes/t_${VOL_SER}_info.html\">",
						"$first_char</a>\n";

					# For rest of vol ser, one char per line
					foreach $vol_ser_char (@VOL_SER_ARRAY)
					{
						print HTML_FILE "$vol_ser_char\n";
					}
					print HTML_FILE "	</pre>\n";
					print HTML_FILE "	</td>\n";
					close (HTML_FILE);
					# Copy the info for archive purposes
					`cp /usr/local/apache2/htdocs/env_support/tapes/t_${tape_slot_num}.tpl /usr/local/apache2/htdocs/env_support/tapes/t_${VOL_SER}.tpl`;
					#!! To Do: Also create a t_${VOL_SER}_info.html file
					#			that would contain details on the tape.
					open (HTML_FILE_INFO, 
						">/usr/local/apache2/htdocs/env_support/tapes/t_${VOL_SER}_info.html")
						|| die "Unable to open /usr/local/apache2/htdocs/env_support/tapes/t_${VOL_SER}.html: $?";
					print HTML_FILE_INFO "<html>\n<head>\n";
					print HTML_FILE_INFO "<title>Tape Volume $VOL_SER Info</title>\n";
					print HTML_FILE_INFO "</head>\n<body>\n";
					print HTML_FILE_INFO "<h1>Tape Volume $VOL_SER Info</h1>\n";
					print HTML_FILE_INFO "<p>$VOL_FILE_INFO Char Set $TAPE_CHAR_SET\n";
					print HTML_FILE_INFO "<p>\n<table border=1>\n";
					print HTML_FILE_INFO "<tr><td>Filename</td>";
					print HTML_FILE_INFO "<td>$FILENAME</td></tr>\n";
					print HTML_FILE_INFO "<tr><td>Fixed Variable</td>";
					print HTML_FILE_INFO "<td>$FMT</td></tr>\n";
					print HTML_FILE_INFO "<tr><td>Blksize</td>";
					print HTML_FILE_INFO "<td>$BLKSIZE</td></tr>\n";
					print HTML_FILE_INFO "<tr><td>LRECL</td>";
					print HTML_FILE_INFO "<td>$LRECL</td></tr>\n";
					print HTML_FILE_INFO "<tr><td>Tape Slot #</td>";
					print HTML_FILE_INFO "<td>$tape_slot_num</td></tr>\n";
					print HTML_FILE_INFO "<p>\n</table>\n";
					print HTML_FILE_INFO "</body>\n</html>\n";
					close (HTML_FILE_INFO);
				}
			}
	}
	else
	{
			print STDERR "Unable to read file $file - skipping\n";
	}
}


if (defined $file_hdr)
{
	$file_info=`more $file_hdr $file_tlr`;
	print STDERR "Info from tape header and trailer:\n$file_info";
	unlink $file_hdr;
	unlink $file_tlr;
}

