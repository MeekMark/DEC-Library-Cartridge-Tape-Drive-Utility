#!/usr/local/bin/perl -w

# Read in an EBCDIC character set file in variable blocked format, and write it 
# out in ASCII character set, Unix-friendly LF-terminated records.

use Convert::EBCDIC;
use MVS::VBFile qw(:all); 

$USAGE='vb_data_write.pl blksize=##### [filename [filename [...]]] ';

if ($#ARGV == -1)
{
	die "Error: Invalid number of parms. Usage: \n$USAGE\n";
}

$blksize_parm = shift @ARGV;
if ($blksize_parm =~ /^blksize=\d+/)
{
	$blksize = substr($blksize_parm, length("blksize="));
	if ($blksize > 32760)
	{
		die "Error: blksize > 32760 (==>$blksize<==). Usage: \n$USAGE\n";
	}
	print STDERR "Using blocksize of $blksize\n";
}
else
{
	die "Error: Invalid blksize= parm (==>$blksize_parm<==). Usage: \n$USAGE\n";
}


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
	"|vb_data_write Started|" .
	"\n";

$bytes_read=0;
$recs_ttl=0;

if ($#ARGV == -1)
{
	push @ARGV, "-";  # Add STDIN to list of files
	print STDERR "No files specified. Reading from STDIN\n";
}

#
# Read data from any files on command line, or STDIN if none,
# write to STDOUT, dump stats to STDERR
#

$rec_num=0;

# opening '-' opens STDIN and opening '>-' opens STDOUT.
#vbopen (*VB_STDOUT, ">-", 32760);
vbopen (*VB_STDOUT, ">-", $blksize);

#while ($rec = vbget(*FILEHANDLE)) 
foreach $filename (@ARGV)
{
    if (-r $filename || $filename eq '-')
    {
        $open_rc = open (FILEHANDLE, $filename);
        if ($open_rc == 0)
        {
            print STDERR "Error: Unable to open file $filename ->$!<- $? (rc=$open_rc)
skipping\n";
        }
        else
        {
            $files_ttl++;
            $bytes_read=0;
            $recs_file=0;

			while (<>)
			{  # Be sure to use '*'!!
					$rec_num++;
					#!!print STDERR "Rec #$rec_num: $rec\n";
					# process and reality...
					#!!$ascii_string = Convert::EBCDIC::ebcdic2ascii($_);

					# Get rid of new line
					chomp;
					# Convert to EBCDIC
					$ebcdic_string = Convert::EBCDIC::ascii2ebcdic($_);
					$bytes_read += length($ebcdic_string);
					$recs_file++;
					# Write out
					vbput(*VB_STDOUT, $ebcdic_string);
			}
            close FILEHANDLE;
            $bytes_read_ttl+=$bytes_read;
            $recs_ttl+=$recs_file;
            print STDERR "read $bytes_read bytes, $recs_file records ",
                "from $filename\n";
        }
    }
    else
    {
        print STDERR "Error: Unable to read file $filename - skipping\n";
    }
}

vbclose (*VB_STDOUT);
$blocks_wrote = vb_blocks_written(*VB_STDOUT);


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
	"|vb_data_write finished: bytes read: |$bytes_read_ttl|.  files: |$files_ttl|. Records: |$recs_ttl|.  " .
	" blocks written: |$blocks_wrote|" .
	"\n";
