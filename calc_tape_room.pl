#!/usr/local/bin/perl -w

#
# calc_tape_room.pl file_size current_file_sizes cart_type [bytes_written]
#
# Calc whether there is room on a tape for the given file_size,
# the files already on the tape, and cartridge type.
# returns a 1 if file_size > (cart_capacity - current_file_sizes)
# or a 0 if the file will fit.
# If optional parm bytes_written is provided, use that value as the 
# cartridge capacity instead of the capacity of the cart_type
#
# $Id: calc_tape_room.pl,v 1.1 2004/01/23 19:37:55 meekmark Exp $
# Log
# $Log: calc_tape_room.pl,v $
# Revision 1.1  2004/01/23 19:37:55  meekmark
# Calc whether there is room on a tape for the given sizes
#
#

$file_size = shift @ARGV || die "Missing file_size\n";
die "file_size not numeric:  ==>" . $file_size . "<==\n"
	if ($file_size !~ /^\d+\.?\d*$/);
die "file_size not an integer:  " . $file_size . "\n"
	if (int($file_size) != $file_size);
die "file_size must be >  0. Was:  " . $file_size . "\n"
	if ($file_size <= 0);

$curr_file_sizes = shift @ARGV || die "Missing curr_file_sizes\n";
die "curr_file_sizes not numeric:  ==>" . $curr_file_sizes . "<==\n"
	if ($curr_file_sizes !~ /^\d+\.?\d*$/);
die "curr_file_sizes not an integer:  " . $curr_file_sizes . "\n"
	if (int($curr_file_sizes) != $curr_file_sizes);
die "curr_file_sizes must be >  0. Was:  " . $curr_file_sizes . "\n"
	if ($curr_file_sizes <= 0);

$cart_type = shift @ARGV || die "Missing cart_type\n";
die "Invalid cartridge type:  " . $cart_type . ". Valid: 3480|3490|3490E\n"
	if ($cart_type !~ /^(34[89]0|3490E)$/);

if (($#ARGV + 1) == 1)
{
	$bytes_written = shift @ARGV;
	die "Invalid bytes_written.  Should be positive integer. Found:  " . 
		$bytes_written . ".\n"
		if ($bytes_written !~ /^\d+$/);
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
	$cart_capacity = defined($bytes_written) ?  
		$bytes_written : 2722230600;
}

#$file_size = shift @ARGV || die "Missing file_size\n";
#$curr_file_sizes = shift @ARGV || die "Missing curr_file_sizes\n";
# returns a 1 if file_size > (cart_capacity - current_file_sizes)
if ($file_size > ($cart_capacity - $curr_file_sizes))
{
	print STDERR "File of size $file_size will not fit on a $cart_type ",
		"cartridge, which holds $cart_capacity bytes, and already has ",
		"$curr_file_sizes bytes in files\n";
	exit 1;
}
else
{
	exit 0;
}

