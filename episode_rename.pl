#!/usr/bin/perl

use warnings;
use strict;

use Getopt::Std;
use XML::Simple;
use LWP::Simple;

my %opt;
getopts( 'vynechi:s:l:p:', \%opt );

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
-v            Script is verbose and will tell what it's renaming.
-e            Omit file extension
EOF

}

my $verbose = defined( $opt{v} ? 1 : 0 );

my $apikey        = '8F6EF4AE2A36435E';
my $mirror        = 'http://thetvdb.com/';
my $parser        = new XML::Simple;
my $language      = 'en';
my $renamepattern = '<SHOW> - <SEASON>x<EPISODE> - <TITLE>';
my $seriesid      = '';

$renamepattern = $opt{p} if ( defined $opt{p} );
$language      = $opt{l} if ( defined $opt{l} );
$seriesid      = $opt{i} if ( defined $opt{i} );

# Select random mirror
# Disable for now (no mirrors exist!)
#{
#	my $mirrorfile = get("$mirror/api/$apikey/mirrors.xml");
#	die "Couldn't retrieve mirror-file. Bailing out.\n" unless defined $mirrorfile;
#	my $mirrorsparsed = $parser->XMLin($mirrorfile);
#	my @suitablemirrors;
#	for ($mirrorsparsed) {
#
#	}
#}

if ( exists $opt{l} and $opt{l} eq 'help' ) {
    my $langfile = get("$mirror/api/$apikey/languages.xml");
    die "Couldn't retrieve language-file. Bailing out.\n"
      unless defined $langfile;
    my $langparsed = $parser->XMLin($langfile);
    print "Possible languages:\n";
    for ( keys %{ $langparsed->{Language} } ) {
        print $langparsed->{Language}->{$_}->{abbreviation} . ' - ' . $_ . "\n";
    }
    exit;
}

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
    next if ( ( $season == 0 ) or ( $episode == 0 ) );

    # Normalize name of series
    $series =~ s/\.|_/ /g;
    $series =~ s/\s*-\s*/ /g;
    $series =~ s/\s+/ /g;
    $series =~ s/^\s*//g;
    $series =~ s/\s*$//g;
    $series = lc($series);

    $season =~ s/^0*//;

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
        my $getseries =
          get("$mirror/api/GetSeries.php?seriesname=$series&lang=$language");
        my $seriesparsed = $parser->XMLin($getseries);
        if ( defined $opt{'c'} ) {

            # Let the user select
            my ($firstid) = ( $getseries =~ /<seriesid>(\d+)<\/seriesid>/ );    # Sorting purposes
            if ( !$firstid ) {
                die "$mirror returned no results for show '$series' (File: $filename)\n";
            }
            print "Here are the choices for show '$series' (File: $filename):\n";
          SHOW:
            for (
                sort {
                    return -1 if ( $a == $firstid );
                    return 1  if ( $b == $firstid );
                    return 0;
                } keys %{ $seriesparsed->{Series} }
              )
            {
                print "\t"
                  . $seriesparsed->{Series}->{$_}->{SeriesName}
                  . " (press y to confirm, i for more info, anything else to skip)\n";
                my $input;
                chomp( $input = <STDIN> );
                if ( $input =~ /^y$/i ) {
                    $seriescache->{$series} = $_;
                }
                elsif ( $input =~ /^i$/i ) {
                    print "\t Overview for "
                      . $seriesparsed->{Series}->{$_}->{SeriesName} . ":\n";
                    print "\t"
                      . $seriesparsed->{Series}->{$_}->{Overview} . "\n";
                    redo SHOW;
                }
            }
        }
        else {

            # Take first result
            my ($firstid) = ( $getseries =~ /<seriesid>(\d+)<\/seriesid>/ );
            if ($firstid) {
				$seriescache->{$series} = $firstid;
            }
            else {
                die "$mirror returned no results for show '$series' (File: $filename)\n";
            }
        }
    }

    # Actually rename file
    my $fileinfo =
      get(  "$mirror/api/$apikey/series/"
          . $seriescache->{$series}
          . "/default/$season/"
          . ( $episode + 0 )
          . "/$language.xml" );
    my $fileinfoparsed = $parser->XMLin($fileinfo);
    my $showinfo =
      get(  "$mirror/api/$apikey/series/"
          . $seriescache->{$series}
          . "/$language.xml" );
    my $showparsed  = $parser->XMLin($showinfo);
    my $newfilename = $renamepattern;
    $newfilename =~ s/<SHOW>/$showparsed->{Series}->{SeriesName}/g;
    $newfilename =~ s/<SEASON>/$season/g;

     if ($multiepisode) {
	my $episodes = $episode . '-' . $multiepisode;
	$newfilename =~ s/<EPISODE>/$episodes/g;

     	my $multiinfo = get("$mirror/api/$apikey/series/".$seriescache->{$series}."/default/$season/".($multiepisode+0)."/$language.xml");
        my $multiinfoparsed = $parser->XMLin($multiinfo);

	$newfilename =~ s/<TITLE>/$fileinfoparsed->{Episode}->{EpisodeName} - $multiinfoparsed->{Episode}->{EpisodeName}/g;
	
     } else {
	$newfilename =~ s/<EPISODE>/$episode/g;
	$newfilename =~ s/<TITLE>/$fileinfoparsed->{Episode}->{EpisodeName}/g;
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
