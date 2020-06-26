#!/usr/bin/perl

use warnings;
use strict;

use Getopt::Std;
use REST::Client;
use JSON qw/encode_json decode_json/;

my %opt;
getopts( 'vydnechi:s:l:p:', \%opt );

if ( defined $opt{'h'} ) {
    print << 'EOF';
episode_rename.pl - Rename episodes based on information from thetvdb.com

Syntax:
=======

episode_rename.pl -options [<file1> <file2>]

-h            This help.
-s <series>   Supply show and don\'t try to guess it from filename
-i <seriesid> Force seriesid from http://www.thetvdb.com/
-l <language> Supply language (\'-l help\' for list of available languages
              Default: en (english)
-c            Give me <=10 choices for each show
-p <pattern>  Rename to <pattern>. <SHOW>, <SEASON>, <EPISODE>, <TITLE> will
              be replaced.
              Default: <SHOW> - <SEASON>x<EPISODE> - <TITLE>
-n            Don't strip filenames of characters hazardous to FAT. Not recommended.
-y            Don't ask for normal renaming, assume yes
-d            Use DVD ordering
-v            Script is verbose and will tell what it's renaming.
-e            Omit file extension
EOF

}

my $verbose = defined( $opt{v} ? 1 : 0 );

my $apikey        = '8F6EF4AE2A36435E';
my $mirror        = 'https://api.thetvdb.com';
my $language      = 'en';
my $renamepattern = '<SHOW> - <SEASON>x<EPISODE> - <TITLE>';
my $seriesid      = '';

$renamepattern = $opt{p} if ( defined $opt{p} );
$language      = $opt{l} if ( defined $opt{l} );
$seriesid      = $opt{i} if ( defined $opt{i} );

my $header;
$header->{'Content-Type'} = 'application/json';
$header->{'Accept'} = 'application/json';

# login
my $client = REST::Client->new();
$client->POST("$mirror/login", encode_json({"apikey" => $apikey}),$header);
if ($client->responseCode() != 200) {
    die 'Failed login (response code ' . $client->responseCode() . ')';
}
my $token = decode_json($client->responseContent())->{token};
$header->{'Authorization'} = 'Bearer ' . $token;
if ( exists $opt{l} and $opt{l} eq 'help' ) {
    $client->GET("$mirror/languages", $header);
    if ($client->responseCode() != 200) {
        die 'Failed getting languages (response code ' . $client->responseCode() . ')';
    }
    my $languages = decode_json($client->responseContent());
    print "Possible languages:\n";
    for ( @{$languages->{data}} ) {
        print $_->{abbreviation} . ' - ' . $_->{englishName} . "\n";
    }
    exit;
}

$header->{'Accept-Language'} = $language;

my $seriescache;

SERIES: for my $file (@ARGV) {
    my ( $base, $filename ) = ( $file =~ m!^(.*?)([^/]*)$! );

    my ( $series, $season, $episode, $multiepisode, $suffix ) =
      ( $filename =~ /^(.*?)s?(\d?\d)[-xe](\d\d)(?:[-xe]?(\d\d)?).*\.(.{2,4}?)$/i );

    unless ($suffix) {
        ( $series, $season, $episode, $multiepisode, $suffix ) =
          ( $filename =~ /^(.*?)s?(\d?\d)[-xe]?(\d\d)(?:[-xe]?(\d\d)?).*\.(.{2,4}?)$/i );
    }

    if ( defined $opt{'s'} ) {
        ( $season, $episode, $multiepisode, $suffix ) =
          ( $filename =~ /s?(\d?\d)[-xe](\d\d)(?:[-xe]?(\d\d)?).*\.(.{2,4}?)$/i );

        unless ($suffix) {
            ( $season, $episode, $multiepisode, $suffix ) =
              ( $filename =~ /s?(\d?\d)[-xe]?(\d\d)(?:[-xe]?(\d\d)?).*\.(.{2,4}?)$/i );
        }
        $series = $opt{'s'};
    }

    next unless $suffix;
    next if ( $episode == 0 );

    # Normalize name of series
    $series =~ s/\.|_/ /g;
    $series =~ s/\s*-\s*/ /g;
    $series =~ s/\s+/ /g;
    $series =~ s/^\s*//g;
    $series =~ s/\s*$//g;
    $series = lc($series);
    $series =~ s/ /\%20/g;

    $season =~ s/^0*//;
    $season = '0' unless ($season);

    $episode = '0' . $episode if ( length($episode) == 1 );
    $multiepisode = '0' . $multiepisode if ( $multiepisode and length($multiepisode) == 1 );

    next unless ( $suffix =~ /avi|mpe?g|rm|ogm|mkv|mp[34]|wav/i );

    my %newtitles;
    my %seriesids;
    my $newseries;
    my %seriescnt;
	if ($seriesid) {
		$seriescache->{$series} = $seriesid;
	}
    unless ( exists $seriescache->{$series} ) {
        $client->GET("$mirror/search/series?name=$series", $header);
        if ($client->responseCode() != 200) {
            die 'Failed getting series (response code ' . $client->responseCode() . ')';
        }
        my $getseries = decode_json($client->responseContent());
        if ( defined $opt{'c'} and scalar(@{$getseries->{data}}) > 1) {

            print "Here are the choices for show '$series' (File: $filename):\n";
          SHOW:
            for ( @{$getseries->{data}} )
            {
                print "\t"
                  . $_->{seriesName}
                  . " (press y to confirm, i for more info, anything else to skip)\n";
                my $input;
                chomp( $input = <STDIN> );
                if ( $input =~ /^y$/i ) {
                    $seriescache->{$series} = $_->{id};
                }
                elsif ( $input =~ /^i$/i ) {
                    print "\t Overview for "
                      . $_->{seriesName} . ":\n";
                    print "\t"
                      . $_->{overview} . "\n";
                    redo SHOW;
                }
            }
        }
        else {
            if ( scalar(@{$getseries->{data}}) == 0 ) {
                die "$mirror returned no results for show '$series' (File: $filename)\n";
            }
            # Take first result
            $seriescache->{$series} = ( $getseries->{data}->[0]->{id} );
        }
    }

    # Actually rename file
    my $search_by = 'aired';
    $search_by = 'dvd' if (exists $opt{d});
    $client->GET("$mirror/series/" . $seriescache->{$series} . '/episodes/query?'.$search_by.'Season=' . $season . '&'.$search_by.'Episode=' . ($episode + 0), $header);
    if ($client->responseCode() != 200) {
        die 'Failed getting episode info (response code ' . $client->responseCode() . ')';
    }

    my $fileinfo = decode_json($client->responseContent());
    $client->GET("$mirror/series/".$seriescache->{$series}, $header);
    if ($client->responseCode() != 200) {
        die 'Failed getting series info (response code ' . $client->responseCode() . ')';
    }
    my $showinfo = decode_json($client->responseContent());
    
    my $newfilename = $renamepattern;
    $newfilename =~ s/<SHOW>/$showinfo->{data}->{seriesName}/g;
    $newfilename =~ s/<SEASON>/$season/g;

    if ($multiepisode) {
	    my $episodes = $episode . '-' . $multiepisode;
	    $newfilename =~ s/<EPISODE>/$episodes/g;

        $client->GET("$mirror/series/" . $seriescache->{$series} . '/episodes/query?'.$search_by.'Season=' . $season . '&'.$search_by.'Episode=' . ($multiepisode + 0), $header);
        if ($client->responseCode() != 200) {
            die 'Failed getting episode info (response code ' . $client->responseCode() . ')';
        }

     	my $multiinfo = decode_json($client->responseContent());

	    $newfilename =~ s/<TITLE>/$fileinfo->{data}->[0]->{episodeName} - $multiinfo->{data}->[0]->{episodeName}/g;
	
    } else {
	    $newfilename =~ s/<EPISODE>/$episode/g;
	    $newfilename =~ s/<TITLE>/$fileinfo->{data}->[0]->{episodeName}/g;
    }

    $newfilename =~ s!["*/:<>?\\|]!!g;

    $newfilename =~ s/\s\s+/ /g;
    $newfilename =~ s/^\s+|\s+$//g;

    # omit file extension
    unless ($opt{'e'}) {
	    $newfilename .= '.' . lc($suffix);
    }

    my $normal = 0;

    if ( $newfilename eq $filename ) {
        print "File '$filename' is already named correct.\n";
        next SERIES;
    }
    elsif ( -e $base . $newfilename ) {
        print "CAUTION: Destination file '$newfilename' already exists! Overwrite? [yN]\n";
    }
    else {
	print "Rename '$filename' to '$newfilename'? [yN]\n" unless ( $opt{y} );
        $normal = 1;
    }

    my $input = 'y';
    chomp( $input = <STDIN> ) if ( not( $opt{y} and $normal ) );

    if ( $input =~ /^y/i ) {
        if ($verbose) {
            print "Renaming '$filename' to '$newfilename'\n";
        }
        rename( $file, $base . $newfilename );
    }
}
