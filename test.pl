#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..29\n"; }
END {print "not ok 1\n" unless $loaded;}
use strict;
use MPEG::MP3Info;
use vars qw/$loaded/;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my($tf1, $tt1, $ti1, $tf2, $tt2, $ti2);
$tf1 = 'test1.mp3';
$tf2 = 'test2.mp3';

test($tt1 = get_mp3tag ($tf1), 2);
test($tt2 = get_mp3tag ($tf2), 3);
test($ti1 = get_mp3info($tf1), 4);
test($ti2 = get_mp3info($tf2), 5);

test($tt1->{ALBUM}      eq '',                                  6);
test($tt1->{ARTIST}     eq 'Pudge',                             7);
test($tt1->{GENRE}      eq 'Sound Clip',                        8);
test($tt1->{COMMENT}    eq 'Copyright, All Rights Reserved',    9);
test($tt1->{YEAR}       eq '1998',                              10);
test($tt1->{TITLE}      eq 'Test 1',                            11);

test($tt2->{ALBUM}      eq '',                                  12);
test($tt2->{ARTIST}     eq 'Pudge',                             13);
test($tt2->{GENRE}      eq 'Sound Clip',                        14);
test($tt2->{COMMENT}    eq 'Copyright, All Rights Reserved',    15);
test($tt2->{YEAR}       eq '1998',                              16);
test($tt2->{TITLE}      eq 'Test 2',                            17);

test($ti1->{FREQUENCY}  eq '44.1',                              18);
test($ti1->{STEREO}     eq '1',                                 19);
test($ti1->{BITRATE}    eq '128',                               20);
test($ti1->{LAYER}      eq '3',                                 21);
test($ti1->{MM}         eq '0',                                 22);
test($ti1->{SS}         eq '0',                                 23);

test($ti2->{FREQUENCY}  eq '22.05',                             24);
test($ti2->{STEREO}     eq '0',                                 25);
test($ti2->{BITRATE}    eq '128',                               26);
test($ti2->{LAYER}      eq '2',                                 27);
test($ti2->{MM}         eq '0',                                 28);
test($ti2->{SS}         eq '1',                                 29);


#use Data::Dumper;
#print Dumper $tt1, $ti1, $tt2, $ti2;

sub test {
    print (($_[0] ? '' : 'not '), "ok $_[1]\n");
}
