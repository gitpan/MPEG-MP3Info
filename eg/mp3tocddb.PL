#!perl
use Config;
use File::Basename qw(&basename &dirname);
use Cwd;

$origdir = cwd;
chdir dirname($0);
$file = basename($0, '.PL');
$file .= '.com' if $^O eq 'VMS';

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{startperl} -sw-
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';
# ----------------------------------------------------------
# 			    mp3tocddb
# 		Tue Oct  6 11:25:52 SGT 1998
# 
# 		       Meng Weng Wong
# $Id: mp3tocddb,v 1.1 1998/10/15 11:44:18 mengwong Exp mengwong $
# simple program to guess at frame offsets and produce a cddb query string
# 
# usage: mp3tocddb u2-achtung_baby*.mp3
# 
# 19981015-19:34:57 mengwong@homey:~/mp3% mp3tocddb ella_fitzgerald-30_by_ella-0*.mp3
# track 1 lasts 12:25.
# track 2 lasts 6:21.
# track 3 lasts 7:01.
# track 4 lasts 11:13.
# track 5 lasts 6:44.
# track 6 lasts 9:49.
# (63 % 255) << 24 | 3213 << 8 | 6
# the projected discid is 3f0c8d06.  that's probably almost, but not quite, right.
# here are some plausible frame numbers.  try a fuzzy match with them and see what comes out!
# after telnetting to a cddb server such as www.cddb.com 8880, you will need to say:
# cddb hello mengwong homey.starnet.gov.sg mp3tocddb v0.1-freeside
# cddb query 3f0c8d06 6 0 55875 84450 116025 166500 196800 3213
#
# later mangled by Pudge 1998/10/17
# ----------------------------------------------------------

# ----------------------------------------------------------
# 		       initialization
# ----------------------------------------------------------

# ----------------------------------------------------------
# 	 no user-serviceable parts below this line
# ----------------------------------------------------------

use strict;
use vars qw($debug);
use MPEG::MP3Info;

# ----------------------------------------------------------
#			    main
# ----------------------------------------------------------

if (! @ARGV) { die "usage: mp3tocddb albumname-*.mp3\n" }

# 
# build the table of contents for each album.
# 
my %cdtoc = ();
if (@ARGV) {
    foreach my $file (@ARGV) {
        next if $file !~ /mp3/i;
#        my $album =  $file;           # heh, but my convention does not ...
#        $album =~ s/\-?\d+\.mp3$//i; # my naming convention is artist-albumtitle-NN.mp3
        my $info  = get_mp3info($file);
        push (@{$cdtoc{1}}, $info );
    }
}

# 
# build the cddb query data for each album.
# 
my %cddb_query = ();
foreach my $album (sort keys %cdtoc) {
    $cddb_query{$album} = [&build_cddb_query($cdtoc{$album})];
}

if (do 'CDDB.pm') {
    print "OK, trying to connect to CDDB ourselves ...\n";
    my $cddb = new CDDB(debug=>($debug ? 1 : 0));
    $cddb->connect('www.cddb.com', 8880) or die "unable to connect to www.cddb.com:8880: $!";

    foreach my $album (sort keys %cddb_query) {
        my ($disc_id,
	    $total_tracks,
	    $total_time,
	    @frames) = @{$cddb_query{$album}};

        my @discs = $cddb->get_discs($disc_id, [@frames], $total_time);

        foreach my $disc (@discs) {
            my ($genre, $cddb_id, $title) = @$disc;
            print "Found: $genre \t $cddb_id \t $title\n";
            my $info = $cddb->get_disc_details($genre, $cddb_id);
            foreach my $track (@{$info->{ttitle}}) {
	            print "\t$track\n";
            }
        }
    }
}

# ----------------------------------------------------------
# 			 functions
# ----------------------------------------------------------

sub build_cddb_query {
    my @cdtoc = @{+shift};
    my $count = 1;

    foreach (@cdtoc) {
	my ($mm, $ss) = ($_->{MM}, $_->{SS});
#	printf "track %d lasts %d:%02d.\n", $count++, $mm, $ss;
    }

    my $discid = cddb_discid(@cdtoc);

    my @frames         = &invent_frame_numbers(@cdtoc);
    my $total_time     = &total_time(@cdtoc);
    my $total_tracks   = @cdtoc;

    my $login          = $ENV{USER};
    my $hostname       = &hostname; use Sys::Hostname; $hostname = `hostname` if $hostname !~ /\./; # macperl bug?
    my $client_name    = "mp3tocddb";
    my $client_version = "v0.1-freeside"; # for credit, grow yourself into this.

#    print "the projected discid is $discid.  that's probably almost, but not quite, right.\n";
#    print "here are some plausible frame numbers.  try a fuzzy match with them and see what comes out!\n";
    print "after telnetting to a cddb server such as www.cddb.com 8880, you will need to say:\n";
    print "cddb hello $login $hostname $client_name $client_version\n";
    print "cddb query $discid $total_tracks @frames $total_time\n";

    return ( $discid,
	     $total_tracks,
	     $total_time,
	     @frames );
}

sub cddb_sum {
    my ($n, $ret) = (shift, 0);
    for (split //, $n) { $ret += $_ }
    return $ret;
}

sub total_time {
    my @cdtoc      = @_;
    my $total_time = 0;

    foreach my $track (@cdtoc) {
	my $track_time = $track->{MM} * 60 + $track->{SS};
	$total_time +=           $track_time;
    }

    return $total_time;
}


sub cddb_discid {
    my @cdtoc      = @_;
    my $n          = 0;
    my $total_time = 0;

    foreach my $track (@cdtoc) {
	my $track_time = $track->{MM} * 60 + $track->{SS};

	# the starting offset of each track is usually, but not always, the total time up until now.
	$n          += &cddb_sum($total_time);
	# suppose:
	# track 4 begins at 14:49.55. it lasts 03:51.25.
	# track 5 begins at 18:41.05.  hm.
	# this isn't good enough.  we're going to have to fake it. -- freeside 19981006

	$total_time +=           $track_time;
    }

#                    print "($n % 255) << 24 | $total_time << 8 | @{[scalar @cdtoc]}\n";
    return sprintf("%08x", ($n % 0xFF) << 24 | $total_time << 8 | @cdtoc);
}

sub invent_frame_numbers {

    # >>> cddb query 450b5018 24 150 13425 30325 38475 43650 53400 64600 74575 77400 85525 95650 102400 113550 123050 133800 136125 147850 153050 162525 164400 181423 183375 200750 216325 2896

    # hokay, let's make up some frame numbers.
    
    my @cdtoc      = @_;
    my $n          = 0;
    my $total_time = 0;

    foreach my $track (@cdtoc) {

	# there are 75 frames in a second.
	$track->{FRAME_OFFSET} = $total_time * 75;

	my $track_time  = $track->{MM} * 60 + $track->{SS};
	$total_time    += $track_time;

    }

    return map { $_->{FRAME_OFFSET} } @cdtoc;
}

# ----------------------------------------------------------
# 		     format statements
# ----------------------------------------------------------
!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
chdir $origdir;

