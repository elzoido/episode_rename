# episode_rename.pl

## What is episode_rename?

episode_rename... well... renames episodes. Who would have guessed :)

It's a small Perl-Script that parses filenames like 'Desperate.Housewives.S05E22.PROPER.720p.HDTV.x264-CTU.mkv', tries to guess the name of the show, season and episode, looks up the information on http://thetvdb.com and renames the file to, in this case 'Desperate Housewives - 5x22 - Marry Me a Little.mkv'

Batch renaming multiple files, overriding the name of the show, custom rename-patterns and even renaming to the titles in different languages is supported.

## Where can I get episode_rename?

Download the gzipped Source at http://www.sproesser.org/episode_rename/ or download using git on https://github.com/elzoido/episode_rename

## Installation

You need a running and working Perl-Installation on preferable a Linux-Box (although probably any OS running Perl should do just fine).

Then, make sure, the following Perl-Modules are installed (in braces you'll find the names of the Debian/Ubuntu-Package):

* Getopt::Long (perl-base)
* REST::Client (librest-client-perl)
* JSON (libjson-perl)

If the requirements are met, download and unpack the Source, make the file executable and put it in your path. You should be good to go.

## Syntax

> episode_rename -options <file1> <file2> ...
> 
> -h Display the help screen
> -s <show> Manually supply the name of the show for all the files
> -l <language> Manually supply the language. '-l help' for a list.
> Default: en
> -c Give <=10 Choices for guessing a show.
> -p <pattern> Manually supply rename-pattern. <SHOW>, <SEASON>, <EPISODE> and <TITLE> will be replaced.
> Default: <SHOW> - <SEASON>x<EPISODE> - <TITLE>
> -n Don't strip filenames of characters not allowed in a FAT filesystem.
> -y Don't ask for normal renaming, assume yes
> -d Use DVD order
> -e Omit file extension

## Usage hints

When you batch rename files from multiple shows, don't use the -y-Switch unless you're absolutely sure, the script will recognise all shows correct.

The preferred use-case is a directory with files from one show only. Execute `episode_rename *` (maybe supply the show via the -s-Switch) and if the first suggestion looks correct, abort the script (CTRL-C) and rerun it with an added -y-Switch. Sit back, wait a few moments and enjoy.

## Known Bugs

Due to the loose way, the filenames are parsed, the script may (but shouldn't) fail, when there's a year written in the filename before the season/episode.

Multi-Episodes will only be handled correctly if the filename contains something like S01E02E03.

Due to the likely increased complexity at parsing the filenames, there may be other subtle bugs.

## Release-Informations

The current version is 1.01 (since 2019-11-10). As of this version, it uses the API v2 at https://api.thetvdb.com/.

## Legalese

episode_rename is released under the Perl Artistic License. That basically means, you can do whatever you want with it, as long as you keep the Copyright-Notes in :)

## Finally...

If you like episode_rename, encounter a strange bug or want to send me a thank-you-note, just drop me a few lines at sebastian@sproesser.name :)
