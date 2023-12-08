#!/usr/local/bin/perl -w

# calc_tapes_comp.pl file_size cart_capacity [##%]
# Calc number of tapes for the given file_size and cart_capacity.
# Prints the number of tapes
# If optional parm ##% (e.g. 95%) scales cart capacity by stated %

$file_size = shift @ARGV || die "Missing file_size\n";
die "file_size not numeric:  ==>" . $file_size . "<==\n"
	if ($file_size !~ /^\d+\.?\d*$/);
die "file_size not an integer:  " . $file_size . "\n"
	if (int($file_size) != $file_size);
die "file_size must be >  0. Was:  " . $file_size . "\n"
	if ($file_size <= 0);

$cart_capacity = shift @ARGV || die "Missing cart_capacity\n";
die "cart_capacity not numeric:  ==>" . $cart_capacity . "<==\n"
	if ($cart_capacity !~ /^\d+\.?\d*$/);
die "cart_capacity not an integer:  " . $cart_capacity . "\n"
	if (int($cart_capacity) != $cart_capacity);
die "cart_capacity must be >  0. Was:  " . $cart_capacity . "\n"
	if ($cart_capacity <= 0);

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


if (defined($percent_scale))
{
	$cart_capacity = $cart_capacity * $percent_scale / 100;
}

$ttl_tapes=$file_size / $cart_capacity;

if (int($ttl_tapes) == $ttl_tapes)
{
	print $ttl_tapes, "\n";
}
else
{
	print int($ttl_tapes) + 1, "\n";
}


