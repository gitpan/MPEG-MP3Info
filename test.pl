#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
use MPEG::MP3Info 0.72;
END {print "not ok 1\n" unless $loaded;}
use strict;
use vars qw/$loaded/;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.
