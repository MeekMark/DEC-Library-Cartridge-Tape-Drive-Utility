#!/usr/local/bin/perl -w

# calc_bytes_in_block.pl blocks_written
# Calc number of bytes for the given number of 512 char blocks written to a tape


$blocks_written = shift @ARGV || die "Missing blocks_written\n";
die "blocks_written not numeric:  ==>" . $blocks_written . "<==\n"
	if ($blocks_written !~ /^\d+\.?\d*$/);
die "blocks_written not an integer:  " . $blocks_written . "\n"
	if (int($blocks_written) != $blocks_written);
die "blocks_written must be >  0. Was:  " . $blocks_written . "\n"
	if ($blocks_written <= 0);

$bytes_written=$blocks_written * 512;

print $bytes_written, "\n";



