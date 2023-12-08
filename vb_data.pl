#!/usr/local/bin/perl -w

# Read in an EBCDIC character set file in variable blocked format, and write it 
# out in ASCII character set, Unix-friendly LF-terminated records.

use Convert::EBCDIC;
use MVS::VBFile qw(:all); 

$USAGE='vb_data.pl [filename [filename ...] ] ';


#!!$filename = shift @ARGV;

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
	"|vb_data Started|" .
	"\n";

$bytes_read_file=0;
$bytes_read_ttl=0;
$bytes_read=0;
$recs_file=0;
$recs_ttl=0;

if ($#ARGV == -1)
{
	push @ARGV, "-";  # Add STDIN to list of files
	print STDERR "No files specified. Reading from STDIN\n";
}

#
# Read data
#

# Process Block Descriptor Word
$MVS::VBFile::bdws = 1;

foreach $filename (@ARGV)
{
	if (-r $filename || $filename eq '-')
	{
		$open_rc = open (FILEHANDLE, $filename);
		if ($open_rc == 0)
		{
			print STDERR "Unable to open file $filename ->$!<- $? (rc=$open_rc) skipping\n";
		}
		else
		{
			$files_ttl++;
			$bytes_read=0;
			$bytes_read_file=0;
			$recs_file=0;
			$bytes_read = read CURR_FILE, $curr_rec, $lrecl;

			while ($rec = vbget(*FILEHANDLE)) 
			{  # Be sure to use '*'!!
					# process and reality...
					#!!$ascii_string = Convert::EBCDIC::ebcdic2ascii($_);
					$ascii_string = Convert::EBCDIC::ebcdic2ascii($rec);
					$bytes_read += length($ascii_string);
					$recs_file++;
					print $ascii_string, "\n";	
			}
			close FILEHANDLE;
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
    "|vb_data.pl Finished.|Files: $files_ttl. Total Records: $recs_ttl " .
				"Total Bytes: $bytes_read_ttl" .
	"\n";


