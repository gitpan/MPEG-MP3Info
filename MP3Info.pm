package MPEG::MP3Info;
use strict;
use Carp;
use vars qw(@ISA @EXPORT $VERSION @mp3_genres %mp3_genres);
@ISA = qw(Exporter);
@EXPORT = qw(set_mp3tag get_mp3tag get_mp3info);
$VERSION = '0.20';

{
  my $c = -1;
  %mp3_genres = map {($_, ++$c, lc($_), $c)} @mp3_genres;
}

=pod

=head1 NAME

MPEG::MP3Info - Manipulate / fetch v1 TAG and header info from a MP3 audio file

=head1 SYNOPSIS

    #!perl -w
    use MPEG::MP3Info;
    my $file = 'Pearls_Before_Swine.mp3';
    set_mp3tag($file, 'Pearls Before Swine', q"77's",
      'Sticks and Stones', '1990', q"(c) 1990 77's LTD.", 'rock & roll');

    my $tag = get_mp3tag($file) or die "No TAG info";
    $tag->{GENRE} = 'rock';
    set_mp3tag($file, $tag);

    my $info = get_mp3info($file);
    printf "$file length is %d:%d", $info->{MM}, $info->{SS};

=head1 DESCRIPTION

=cut

sub set_mp3tag {

=pod

=item set_mp3tag (FILE, TITLE, ARTIST, ALBUM, YEAR, COMMENT, GENRE)

=item set_mp3tag (FILE, $HASHREF)

Adds/changes tag information in an MP3 audio file.  Will clobber
any existing information in file.  All fields have a 30-byte limit,
except for YEAR, which has a four-byte limit.

GENRE is a case-insensitive text string representing a genre found
in C<@mp3_genres>.

Will accept either a list of values, or a hashref of the type
returned by C<get_mp3tag>.

=cut

    my($file, $title, $artist, $album,
        $year, $comment, $genre, $oldfh) = @_;

    if ('HASH' eq ref($title)) {
        ($title, $artist, $album, $year, $comment, $genre) = 
          (@$title{qw(TITLE ARTIST ALBUM YEAR COMMENT GENRE)});
    }

    $file ||= croak('No file specified');
    my $cc = 0;
    foreach ($title, $artist, $album, $comment) {
        $_ ||= '';
        if ($^W && length($_) > 30) {
            carp("Data too long for field [$cc]; truncated");
        }
        $cc++;
    }
    $year ||= '';
    if ($^W && length($year) > 4) {
        carp('Data too long for field; truncated');
    }

    warn "Genre $genre does not exist\n"
        if $^W && $genre && !exists($mp3_genres{$genre});

    local(*FILE);
    open(FILE, "+<$file") or croak($!);
    binmode(FILE);
    $oldfh = select(FILE);
    seek(FILE, -128, 2);
    while (<FILE>) {
        if (/^TAG/) {
            seek(FILE, -128, 2);
        } else {
            seek(FILE, 0, 2);
        }
        last;
    }

    foreach my $x ($title, $artist, $album, $comment) {
        while (length($x) < 30) {
            $x .= "\0";
        }
    }

    while (length($year) < 4) {$year .= "\0"}

    printf("TAG%-30.30s%-30.30s%-30.30s%-4.4s%-30.30s%-1.1s",
        $title, $artist, $album, $year, $comment, 
        ($genre && exists($mp3_genres{$genre})) ?
        chr($mp3_genres{$genre}) : chr(80)
    );

    select($oldfh);
    close(FILE);
    1;
}

sub get_mp3tag {

=pod

=item get_mp3tag (FILE)

Returns hash reference containing tag information in MP3 file.  Same
info as described in C<set_mp3tag>.  You can't change this data.

=cut

    my($file, $tag, %info, @array) = @_;
    $file ||= croak('No file specified');
    local(*FILE);
    open(FILE, "<$file") or croak($!);
    binmode(FILE);
    seek(FILE, -128, 2);
    while(<FILE>) {$tag .= $_}

    return if $tag !~ /^TAG/;
    (undef, @info{qw/TITLE ARTIST ALBUM YEAR COMMENT GENRE/}) = 
        (unpack('a3a30a30a30a4a30', $tag),
        $mp3_genres[ord(substr($tag, -1))]);

    foreach (keys %info) {
        if (defined($info{$_})) {
            $info{$_} =~ s/\s+$//;
        }
    }
    close(FILE);
    return {%info};
}

sub get_mp3info {

=pod

=item get_mp3info (FILE)

Returns hash reference containing file information for MP3 file.

=cut

    my($file, $o, $once, $myseek, $off, $byte, $bytes, $eof, $h, $i,
        @frequency_tbl, @t_bitrate, @t_sampling_freq) = @_[0, 1, 2];

    @t_bitrate = ([
        [0,32,48,56,64,80,96,112,128,144,160,176,192,224,256],
        [0,8,16,24,32,40,48,56,64,80,96,112,128,144,160],
        [0,8,16,24,32,40,48,56,64,80,96,112,128,144,160]
    ],[
        [0,32,64,96,128,160,192,224,256,288,320,352,384,416,448],
        [0,32,48,56,64,80,96,112,128,160,192,224,256,320,384],
        [0,32,40,48,56,64,80,96,112,128,160,192,224,256,320]
    ]);
        
    @t_sampling_freq = (
        [22050, 24000, 16000],
        [44100, 48000, 32000]
    );

    @frequency_tbl = map {eval"${_}e-3"}
        @{$t_sampling_freq[0]}, @{$t_sampling_freq[1]};

    $once ||= 0;
    $o ||= 0;
    $off = $o = ($once == 1 ? 0 : ($o == 164 ? 128 : $o));

    local(*FILE);
    $myseek = sub {
        seek(FILE, $off, 0);
        read(FILE, $byte, 4);
    };

    open(FILE, "<$file") or croak($!);
    binmode(FILE);
    &$myseek;

    if ($off == 0) {
        if ($byte eq 'RIFF') {
            $off += 72;
            &$myseek;
        } else {
            seek(FILE, 36, 0);
            read(FILE, my $b, 5);
            if ($b eq 'MACRZ') {
                $off += 324;
                &$myseek;
            }
        }
    }

    $bytes = unpack('l', pack('L', unpack('N', $byte)));
    seek(FILE, 0, 2);
    $eof = tell(FILE);
    seek(FILE, -128, 2);
    $off += 128 if <FILE> =~ /^TAG/ ? 1 : 0;
    close(FILE);

    @$h{qw(ID layer protection_bit bitrate_index
        sampling_freq padding_bit private_bit mode
        mode_extension copyright original emphasis
        version_index)} = (
        ($bytes>>19)&1, ($bytes>>17)&3, ($bytes>>16)&1, ($bytes>>12)&15, 
        ($bytes>>10)&3, ($bytes>>9)&1, ($bytes>>8)&1, ($bytes>>6)&3, 
        ($bytes>>4)&3, ($bytes>>3)&1, ($bytes>>2)&1, $bytes&3,
        ($bytes>>19)&3, 
    );

    if ($h->{bitrate_index} == 0 || $h->{version_index} == 1 ||
        (($bytes & 0xFFE00000) != 0xFFE00000)) {
        if (!$once) {
            return get_mp3info($file, 36, 0) if !$o;
            return get_mp3info($file, $o+128, (caller(33) ? 1 : 0));
        } else {
            return if caller(1024);
            return get_mp3info($file, $o+1, 2);
        }
    }
#    printf("%10s %10s %s ", $o, $byte, $file) if $DEBUG;

    $h->{mode_extension} = 0 if !$h->{mode};
    if ($h->{ID}) {$h->{size} = $h->{mode} == 3 ? 21 : 36}
    else {$h->{size} = $h->{mode} == 3 ? 13 : 21}
    $h->{size} += 2 if $h->{protection_bit} == 0;
    $h->{bitrate} = $t_bitrate[$h->{ID}][3-$h->{layer}][$h->{bitrate_index}];
    $h->{fs} = $t_sampling_freq[$h->{ID}][$h->{sampling_freq}];
    return if !$h->{fs} || !$h->{bitrate};
    if ($h->{ID}) {$h->{mean_frame_size} = (144000 * $h->{bitrate})/$h->{fs}}
    else {$h->{mean_frame_size} = (72000 * $h->{bitrate})/$h->{fs}}

    $h->{layer} = $h->{mode};
    $h->{freq_idx} = 3 * $h->{ID} + $h->{sampling_freq};
    $h->{'length'} =
        (($eof - $off) / $h->{mean_frame_size}) *
        ((115200/2)*(1+$h->{ID})) / $h->{fs};
    $h->{secs} = $h->{'length'} / 100;

    $i->{MM} = int $h->{secs}/60;
    $i->{SS} = int $h->{secs}%60;  # ? ceil() ?  leftover seconds?
    $i->{STEREO} = $h->{ID};
    $i->{LAYER} = $h->{layer} >= 0 ? ($h->{layer} == 3 ? 2 : 3) : '';
    $i->{BITRATE} = $h->{bitrate} >= 0 ? $h->{bitrate} : '';
    $i->{FREQUENCY} = $h->{freq_idx} >= 0 ?
        $frequency_tbl[$h->{freq_idx}] : '';

    return($i);
}

$SIG{__WARN__} = sub {warn @_ unless $_[0] =~ /recursion/};  # :-)

BEGIN { 
  @mp3_genres = (
    'Blues',
    'Classic Rock',
    'Country',
    'Dance',
    'Disco',
    'Funk',
    'Grunge',
    'Hip-Hop',
    'Jazz',
    'Metal',
    'New Age',
    'Oldies',
    'Other',
    'Pop',
    'R&B',
    'Rap',
    'Reggae',
    'Rock',
    'Techno',
    'Industrial',
    'Alternative',
    'Ska',
    'Death Metal',
    'Pranks',
    'Soundtrack',
    'Euro-Techno',
    'Ambient',
    'Trip-Hop',
    'Vocal',
    'Jazz+Funk',
    'Fusion',
    'Trance',
    'Classical',
    'Instrumental',
    'Acid',
    'House',
    'Game',
    'Sound Clip',
    'Gospel',
    'Noise',
    'AlternRock',
    'Bass',
    'Soul',
    'Punk',
    'Space',
    'Meditative',
    'Instrumental Pop',
    'Instrumental Rock',
    'Ethnic',
    'Gothic',
    'Darkwave',
    'Techno-Industrial',
    'Electronic',
    'Pop-Folk',
    'Eurodance',
    'Dream',
    'Southern Rock',
    'Comedy',
    'Cult',
    'Gangsta',
    'Top 40',
    'Christian Rap',
    'Pop/Funk',
    'Jungle',
    'Native American',
    'Cabaret',
    'New Wave',
    'Psychadelic',
    'Rave',
    'Showtunes',
    'Trailer',
    'Lo-Fi',
    'Tribal',
    'Acid Punk',
    'Acid Jazz',
    'Polka',
    'Retro',
    'Musical',
    'Rock & Roll',
    'Hard Rock',
  );
}


__END__

=pod

=head1 HISTORY

=over 4

=item v0.20, Saturday, October 17, 1998

Changed name from C<MPEG::MP3Tag> to C<MPEG::MP3Info>, because it does
more than just TAG stuff now.

Made header stuff even more reliable.  Lots of help and testing from
Meng Weng Wong again.  :-)

=item v0.13, Thursday, October 8, 1998

Had some problems with header verification, got some code from
Predrag Supurovic:

    E<lt>mpgtools@dv.co.yuE<gt>
    http://www.dv.co.yu/mp3list/mpgtools.htm
    http://www.dv.co.yu/mp3list/mpeghdr.htm

Great stuff.  Also did some looping to find a header if it is not in the 
"right" place.  I did what I think it is a smart way to do it, since
some files have the header as far down as 2 kbytes into the file.  First,
I look at position 0, then at position 36 (a position where I have found
many headers), then I start at 0 again and jump in 128-byte chunks.
Once I do that a bunch of times, I go back at the beginning and try at 0
and go ahead in 1-byte chunks for a bunch more times.

If you have an MP3 that has the header begin at an odd place like byte
761, then I suggest you strip out the junk before the header begins. :-)


=item v0.12, Friday, October 2, 1998

Added C<get_mp3info>.  Thanks again to F<mp3tool> source from
Johann Lindvall, because I basically stole it straight (after
converting it from C to Perl, of course).

I did everything I could to find the header info, but if 
anyone has valid MP3 files that are not recognized, or has suggestions
for improvement of the algorithms, let me know.

=item v0.04, Tuesday, September 29, 1998

Changed a few things, replaced a regex with an C<unpack> 
(Meng Weng Wong E<lt>mengwong@pobox.comE<gt>).

=item v0.03, Tuesday, September 8, 1998

First public release.

=back

=head1 AUTHOR AND COPYRIGHT

Chris Nandor F<E<lt>pudge@pobox.comE<gt>>
http://pudge.net/

Copyright (c) 1998 Chris Nandor.  All rights reserved.  This program is free 
software; you can redistribute it and/or modify it under the same terms as 
Perl itself.  Please see the Perl Artistic License.

Thanks to Johann Lindvall for his mp3tool program:

    http://www.dtek.chalmers.se/~d2linjo/mp3/mp3tool.html

Helped me figure it all out.

=head1 VERSION

v0.20, Saturday, October 17, 1998

=cut
