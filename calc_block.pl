#!/usr/local/bin/perl -w

# calc_block.pl file_size line_count blksize
# Calc number of blocks 


$file_size = shift @ARGV || die "Missing file_size\n";
die "file_size not numeric:  ==>" . $file_size . "<==\n"
	if ($file_size !~ /^\d+\.?\d*$/);
die "file_size not an integer:  " . $file_size . "\n"
	if (int($file_size) != $file_size);
die "file_size must be >  0. Was:  " . $file_size . "\n"
	if ($file_size <= 0);

$line_count = shift @ARGV || die "Missing line_count\n";
die "line_count not numeric:  " . $line_count . "\n"
	if ($line_count !~ /^\d+\.?\d*$/);
die "line_count not an integer:  " . $line_count . "\n"
	if (int($line_count) != $line_count);
die "line_count must be >  0. Was:  " . $line_count . "\n"
	if ($line_count <= 0);

$blksize = shift @ARGV || die "Missing blksize\n";
die "blksize not numeric:  " . $blksize . "\n"
	if ($blksize !~ /^\d+\.?\d*$/);
die "blksize not an integer:  " . $blksize . "\n"
	if (int($blksize) != $blksize);
die "blksize must be >  0. Was:  " . $blksize . "\n"
	if ($blksize <= 0);

$ttl_blocks=($file_size - $line_count) / $blksize;
if (int($ttl_blocks) == $ttl_blocks)
{
	print $ttl_blocks, "\n";
}
else
{
	print int($ttl_blocks) + 1, "\n";
}



