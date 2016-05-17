#!/usr/bin/perl -w
use strict;
use warnings;

use Term::ANSIColor;
use Getopt::Long;
use Pod::Usage;

my $app_version = 0.1;

# my $opt_config = "$ENV{'HOME'}/.checkstylerc";
# my $opt_config = "checkvalastylerc";
my ($opt_quiet, $opt_silent, $opt_summary, $opt_lang, $opt_help, $opt_man, $opt_version);

Getopt::Long::Configure ("bundling");
GetOptions (
    # 'config=s'  => \$opt_config,
    'quiet!'    => \$opt_quiet,
    'silent|s!' => \$opt_silent,
    'summary|i!'=> \$opt_summary,
    'lang|language|l=s' => \$opt_lang,
    'help!'     => \$opt_help,
    'man!'      => \$opt_man,
    'version!'  => \$opt_version,
) or  pod2usage(-verbose => 1) && exit;
pod2usage(-verbose => 1) && exit if defined $opt_help;
pod2usage(-verbose => 2) && exit if defined $opt_man;
my @files  = @ARGV;
pod2usage(-verbose => 1) && exit unless @files;

if (defined $opt_version) {
    print "checkstyle $app_version\n",
          "Copyright (C) 2013 Dominique Lasserre <lasserre.d\@gmail.com>\n",
          "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n",
          "  This is free software: you are free to change and redistribute it.\n",
          "  There is NO WARRANTY, to the extent permitted by law.\n";
    exit;
}

$opt_quiet = 1 if defined $opt_silent;

#unless (-f $opt_config) {
#    print STDERR "No such file: $opt_config\n";
#    exit 1;
#}

# our $lang = {};
# require($opt_config);

our $lang = {
   'vala' => [  # file type
        ["//"],  # line comment
        [["/*","*/"]],  # block comment
        [  # regexes what to check
            ['[^ \t!_("$]\(', "missing space before method parameter bracket", 0],
            ['\){', "no space between method bracket and next block bracket", 0],
            ['[\t]+', "usage of tab", 0],
            ['[ \t]+;', "space before semikolon", 0],
            ['[ \t]+$', "space character at end of line", 0],
            ['\)=>[{]?|=>{', "no space arround lambda method operator", 0],
            ['[^ "]([ ]{2,})', "multiple spaces", 1],
            ['[^ \t<>!=+-][<>!=]=[ \t]', "no space arround comparison operator", 0],    # aX b
            ['([ \t][<>!=+-]=[^ \t>=]).', "no space arround comparison operator", 1],   # a Xb
            ['[^ \t<>!=+-][<>!=]=[^ \t>=]', "no space arround comparison operator", 0], # aXB
            ['[^ \t<>!=+-]=[ \t]', "no space arround assignment operator", 0],    # aX b
            ['([ \t]=[^ \t>=]).', "no space arround assignment operator", 1],     # a Xb
            ['[^ \t<>!=+-]=[^ \t>=]', "no space arround assignment operator", 0], # aXB
            ['[^ \t"]{', "no space before beginning block", 0],
            ['({[^ \t}]).', "no space after beginning block", 1],
            ['[ \t]((?:g|s)et{)', "no space arround getter/setter method", 1],
            ['{(?:g|s)et[ \t;]', "no space arround getter/setter method", 0],
            ['[^ \t]([ \t]+)\[', "space before array index", 1],
            ['^[ \t]*\{', "new line before opening brace", 0],
            ['namespace [a-z]+[a-zA-Z0-9]*', "bad namespace name", 0, 1],
            ['class [a-z]+[a-zA-Z0-9]*', "bad class name", 0, 1],
            ['struct [a-z]+[a-zA-Z0-9]*', "bad class name", 0, 1],
            ['enum [a-z]+[a-zA-Z0-9]*', "bad class name", 0, 1],
        ]
             ],
    'vapi' => 'vala',
};


my $file_cnt = 0;
my $file_checked_cnt = 0;
my $line_cnt_glob = 0;
my $comment_cnt_glob = 0;
my $valid_cnt_glob = 0;
my $err_cnt_glob = 0;


foreach my $filename (@files) {
    next unless (-f $filename);
    ++$file_cnt;

    my $filetype;
    unless (defined $opt_lang) {
        $filetype = $1 if $filename =~ /\.([^.]+)$/;
        unless (defined $filetype) {
            print STDERR "No filetype: $filename\n" unless defined $opt_quiet;
            next;
        }
    } else {
        $filetype = $opt_lang;
    }

    my (@comment_line_match, @comment_block_match, @matchexpressions);
    unless ($lang->{$filetype}) {
        print STDERR "No rule for filetype: $filetype\n" unless defined $opt_quiet;
        next;
    } else {
        if (ref($lang->{$filetype}) ne 'ARRAY') {
            my $oldfiletype = $filetype;
            $filetype = $lang->{$filetype};
            unless ($lang->{$filetype}) {
                print STDERR "No rule for referenced filetype: $filetype ($oldfiletype)\n" unless defined $opt_quiet;
                next;
            }
        }
        @comment_line_match = @{$lang->{$filetype}[0]};
        @comment_block_match = @{$lang->{$filetype}[1]};
        @matchexpressions = @{$lang->{$filetype}[2]};
    }
    ++$file_checked_cnt;

    my $line_cnt = 0;
    my $comment_cnt = 0;
    my $valid_cnt = 0;
    my $err_cnt = 0;
    my $init = 0;
    my $check_disabled = 0;

    my $blockcomment = 0;

    open(FILE, "<", $filename) or die $!;
    while (<FILE>) {
        my $line = my $oldline = $_;
        my $errline = undef;
        my $offset = 0;
        ++$line_cnt;
        ++$line_cnt_glob;

        # Check for comment.
        if ($blockcomment) {
            foreach my $i (0..$#comment_block_match) {  # end of block
                if ($line =~ /\Q$comment_block_match[$i][1]\E/) {
                    $line =~ s/.*\Q$comment_block_match[$i][1]\E//;
                    $offset = $+[0];
                    $blockcomment = 0;
                }
            }
        } else {
            foreach my $i (0..$#comment_block_match) {  # start of block
                if ($line =~ /(?:\\\")?[^"]*\Q$comment_block_match[$i][0]\E/) {
                    $line =~ s/[ \t]*\Q$comment_block_match[$i][0]\E.*//;
                    $blockcomment = -1;
                }
            }
        }

        if ($blockcomment > 0) {
            ++$comment_cnt;
            ++$comment_cnt_glob;
            next;
        } elsif ($blockcomment < 0) {
            $blockcomment = 1;
        }

        if ($line =~ /NOLINT_START/) {
            $check_disabled = 1;
        } elsif ($line =~ /NOLINT_STOP/) {
            $check_disabled = 0;
        }

        if (($check_disabled == 1) || ($line =~ /NOLINT/)) {
            next;
        }

        foreach (@comment_line_match) {
            $line =~ s/((?:\\\")?[^" \t]*)[ \t]*\Q$_\E.*/$1/;
        }

        # check line length
        if (length($line) > 120) {
            print "$filename : ($line_cnt): line length > 120\n";
        }

        # remove string
        $line =~ s/\".*\"/""/;

        # Check syntax.
        my ($begin, $end);
        foreach my $i (0..$#matchexpressions) {
            if ($line =~ /$matchexpressions[$i][0]/) {
                $errline = $matchexpressions[$i][1];
                $begin = $-[$matchexpressions[$i][2]] + $offset;
                $end = $+[$matchexpressions[$i][2]] + $offset;
                last;
            }
        }
        unless (defined $errline) {
            ++$valid_cnt;
            ++$valid_cnt_glob;
            next;
        }
        $line = $oldline;

        my $arrow = colored("<----", 'bright_red');
        $errline = colored($errline, 'red');
        chomp $line;
        $line = substr($line,0,$begin) .
                colored(substr($line,$begin,$end-$begin), 'on_red') .
                substr($line,$end,);

        ++$err_cnt;
        ++$err_cnt_glob;

        unless ($init || defined $opt_silent) {
            print "\n";
            print color 'bright_blue';
            print "File: $filename\n";
            print color 'reset';
            $init = 1;
        }

        print "$filename : ($line_cnt:$begin-$end): $line   $arrow $errline\n";
    }
    close(FILE);
}

exit if (defined $opt_silent && !(defined $opt_summary));

format TABLE =

------------------------------------------------------------------------------
  Total files processed: @>>>>>>
$file_cnt
  Total files checked:   @>>>>>>
$file_checked_cnt
  Total lines checked:   @>>>>>>
$line_cnt_glob
  Comment lines skipped: @>>>>>>
$comment_cnt_glob
  Valid lines skipped:   @>>>>>>
$valid_cnt_glob
  Errors found:          @>>>>>>
$err_cnt_glob
.
format_name STDOUT "TABLE";
write STDOUT;


__END__

=head1 NAME

checkstyle - check code style for common style issues

=head1 SYNOPSIS

 checkstyle [-hmqsiv] [-c=configfile] [-l=language] file1,file2,...

 Code files have to be supported by configuration file:
   - line comment marker
   - block comment markers
   - regexes to check for style issues with infostring

=head1 DESCRIPTION

B<checkstyle> will read the given input file(s) and check coding style.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--quiet>

Only output style errors and status summary.

=item B<--silent>

Only output list of style errors. Implies --quiet.

=item B<--summary>

Explicitly output summary. Use this with --silent.

=item B<--language>

Force specific language (file extension).

=item B<--config>

Path to alternate configuration file. (default: $HOME/.checkstylerc)

=back

=cut
