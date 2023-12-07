# DEC-Library-Cartridge-Tape-Drive-Utility
Linux shell and perl scripts to read and write IBM tape cartridges on DEC TKZ61/62 Tape Drive Libraries

Linux Korn Shell and Perl scripts to read and write IBM 3480, 3480, 3490E tapes.  Designed to access tapes on DEC TKZ61/62 Tape Drive Libraries (or clones), for 10 slot libraries.

This was written in 2008 for a Unix server, before I was familiar with Linux and BASH, so much of this could be more elegant.  

The following features are fairly accurate!

# Features

* Can read and write EBDCIC or ASCII data
* Handles VOLSER tape labels
* Allows running tape cleaner cartridge in slot 11
* Keeps history of tapes processed
* For input files being written, for large files that won't fit on a certain tape cartridge, it will automatically create up to 10 tapes with appropriate VOLSER labels.
* Sends an email when tape(s) are finished being written or read.  Email states the VOLSER numbers to label for written data
* Creates/updates a status web page showing
  *  the tape slots and information on the tapes in each slot
  *  Shows how many tapes have been accessed since the last time the cleaner tape was run
* Will compress data on cartridges that support compression
* Scripts handle most common errors automatically by skipping/rewinding
