#!/usr/local/bin/perl -w

# calc_tapes.pl file_size cart_type [##%]
# Calc number of tapes for the given file_size and cartridge type
# Prints the number of tapes, and if the cartridge type is 3490E and
# file_size > 50% of capacity, also returns a 1 instead of 0 return code
# If optional parm ##% (e.g. 95%) scales cart capacity by stated %

$file_size = shift @ARGV || die "Missing file_size\n";
die "file_size not numeric:  ==>" . $file_size . "<==\n"
	if ($file_size !~ /^\d+\.?\d*$/);
die "file_size not an integer:  " . $file_size . "\n"
	if (int($file_size) != $file_size);
die "file_size must be >  0. Was:  " . $file_size . "\n"
	if ($file_size <= 0);

$cart_type = shift @ARGV || die "Missing cart_type\n";
die "Invalid cartridge type:  " . $cart_type . ". Valid: 3480|3490|3490E\n"
	if ($cart_type !~ /^(34[89]0|3490E)$/);

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
if ($cart_type eq "3480")
{
	$cart_capacity=419429996;
}
elsif ($cart_type eq "3490")
{
	$cart_capacity=838860396;
}
elsif ($cart_type eq "3490E")
{
	$cart_capacity=2722230600;
	if ($file_size > ($cart_capacity/2))
	{
		# if the cartridge type is 3490E and
		# file_size > 50% of capacity, returns a 1 return code
		$rc=1;
	}
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

exit ({$rc});
