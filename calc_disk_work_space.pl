#!/usr/local/bin/perl -w

# calc_disk_work_space.pl file_size df_k_ttl_avail [breathing_room%]
# Calc whethter there is enough space for a file of the given size,
# given the number of 1024-byte blocks, with the optional amount of 
# breathing room
# returns a 1 if not enought room or 0 if room

$file_size = shift @ARGV || die "Missing file_size\n";
die "file_size not numeric:  ==>" . $file_size . "<==\n"
	if ($file_size !~ /^\d+\.?\d*$/);
die "file_size not an integer:  " . $file_size . "\n"
	if (int($file_size) != $file_size);
die "file_size must be >  0. Was:  " . $file_size . "\n"
	if ($file_size <= 0);

$df_k_ttl_avail = shift @ARGV || die "Missing df_k_ttl_avail\n";
die "df_k_ttl_avail not numeric:  ==>" . $df_k_ttl_avail . "<==\n"
	if ($df_k_ttl_avail !~ /^\d+\.?\d*$/);
die "df_k_ttl_avail not an integer:  " . $df_k_ttl_avail . "\n"
	if (int($df_k_ttl_avail) != $df_k_ttl_avail);
die "df_k_ttl_avail must be >  0. Was:  " . $df_k_ttl_avail . "\n"
	if ($df_k_ttl_avail <= 0);

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

$rc=0;

if (defined($percent_scale))
{
	$df_k_ttl_avail = int($df_k_ttl_avail * $percent_scale / 100);
}

$df_bytes_avail=$df_k_ttl_avail * 1024;

if ($file_size > $df_bytes_avail)
{
	print "Not enough disk space ($df_bytes_avail) for file of ",
		"size $file_size\n";
	$rc=1;
}

exit ({$rc});
