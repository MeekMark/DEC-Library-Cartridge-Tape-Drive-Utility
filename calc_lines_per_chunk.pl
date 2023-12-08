#!/usr/local/bin/perl -w

# calc_lines_per_chunk.pl line_count num_tapes [breathing_room%]
# prints the number of lines a file needs to be split into
# given the file size, with the optional amount of 
# breathing room

$line_count = shift @ARGV || die "Missing line_count\n";
die "line_count not numeric:  ==>" . $line_count . "<==\n"
	if ($line_count !~ /^\d+\.?\d*$/);
die "line_count not an integer:  " . $line_count . "\n"
	if (int($line_count) != $line_count);
die "line_count must be >  0. Was:  " . $line_count . "\n"
	if ($line_count <= 0);

$num_tapes = shift @ARGV || die "Missing num_tapes\n";
die "num_tapes not numeric:  ==>" . $num_tapes . "<==\n"
	if ($num_tapes !~ /^\d+\.?\d*$/);
die "num_tapes not an integer:  " . $num_tapes . "\n"
	if (int($num_tapes) != $num_tapes);
die "num_tapes must be >  0. Was:  " . $num_tapes . "\n"
	if ($num_tapes <= 0);

if (($#ARGV + 1) == 1)
{
	$percent_scale = shift @ARGV;
	die "Invalid percent to scale.  Should be like 95%. Found:  " . 
		$percent_scale . ".\n"
		if ($percent_scale !~ /^\d+%$/);
	# chop off % char
	chop $percent_scale;
	die "percent to scale must be > 0 & < 100. Was:  " . $percent_scale. "\n"
		if ($percent_scale <= 0 || $percent_scale >= 100);
}


$lines_per_chunk = int($line_count/ $num_tapes);
if (defined($percent_scale))
{
	$lines_per_chunk = int($lines_per_chunk * $percent_scale / 100);
}


print "$lines_per_chunk\n";
