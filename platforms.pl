#!/usr/bin/env perl -w
##############################################################################
##############################################################################
##### declare uses
# for code quality
use strict;
use warnings;
use diagnostics;
use Carp qw(cluck confess); # to use instead of (warn die)

# for the script itself
use English qw( -no_match_vars ) ;
#use Fatal qw(open close);
#use autodie;
#use Getopt::Long;
use Getopt::Long qw(:config no_ignore_case);
use File::Copy;
use File::Find;
use FindBin;
use lib $FindBin::Bin;

our $VERSION = '1.0';

##############################################################################
##############################################################################
##### declare vars

my $COMMA                       = q{,};
my $SEMICOLON                   = q{;};
my $EMPTY                       = q{};

my $current_dir                 = $EMPTY;
my $command_line                = $EMPTY;
my $global_ref_platform         = $EMPTY;
my $orig_param_add_platforms    = $EMPTY;
my %h_add_platforms             = ();
my %list_template_files         = ();
my %list_type_files             = ();

# for options/parameters
my %all_ptions             = ();
my $options_parse_status   = $EMPTY;
my $param_add_platforms    = $EMPTY;
my $param_delete_platforms = $EMPTY;
my $opt_help               = $EMPTY;



##############################################################################
##############################################################################
##### declare functions
sub git_status;
sub get_property_files;
sub check_duplicates;
sub add_new_platform;
sub create_property_file;
sub add_new_platform_in_type_file;
sub get_type_files;
sub delete_platform_in_type_file;
sub display_help;


##############################################################################
##############################################################################
##### get options/parameters
$command_line = "$PROGRAM_NAME @ARGV";
if( ! @ARGV ) {
    cluck "WARNING : no parameter/option set in command line: $ERRNO";
    display_help();
    exit 0;
}
%all_ptions = (
    'r'     =>\$global_ref_platform,
    'ap'    =>\$param_add_platforms,
    'dp'    =>\$param_delete_platforms,
    'help'  =>\$opt_help,
);

#$Getopt::Long::ignorecase = 0;
$options_parse_status = GetOptions(\%all_ptions,'r=s', 'ap=s', 'dp=s', 'help');
if($opt_help || ! $options_parse_status) {
    display_help();
    exit 0;
}

##############################################################################
##############################################################################
##### inits & checks
$current_dir          = $FindBin::Bin;
if( ! $global_ref_platform) {
    # use linuxx86_64 by default
    $global_ref_platform = 'linuxx86_64';
}

if($param_add_platforms && $param_delete_platforms) {
    confess "ERROR : options '-ap' & '-dp' cannot be used together : $ERRNO";
}



##############################################################################
##############################################################################
##### MAIN
print "\n";

if($param_add_platforms) {
    $orig_param_add_platforms = $param_add_platforms ;
    check_duplicates();
    print "Add mode.\n";
    foreach my $ref_platform (sort keys %h_add_platforms) {
        #print qq{\nreference     : $ref_platform\n};
        local $ENV{REF_PLATFORM} = $ref_platform;
        local $ENV{variant}      = @{$h_add_platforms{$ref_platform}{variant}}[0];
        #print qq{variant       : $ENV{variant}\n};
        find(\&getlist_template_files, $current_dir);
        foreach my $elem (sort keys %{$h_add_platforms{$ref_platform}} ) {
            next if($elem =~ m/^variant$/ixms);
            (my $display_elem = $elem) =~ s/\_/ /xms;
            #print "$display_elem :\n";
            foreach my $new_platform (sort @{$h_add_platforms{$ref_platform}{$elem}} ) {
                #print "\t\t$new_platform\n";
                add_new_platform($new_platform);
            }
        }
        %list_template_files = ();
        undef $ENV{REF_PLATFORM};
        undef $ENV{variant};
    }
}

if($param_delete_platforms) {
    print "Delete mode.\n";
    find(\&get_type_files, $current_dir);
    foreach my $platform (sort split $COMMA , $param_delete_platforms) {
        local $ENV{PLATFORM_TBD} = $platform;
        find(\&get_property_files, $current_dir);
        foreach my $type_file ( sort keys %list_type_files) {
            delete_platform_in_type_file($type_file)
        }
        undef $ENV{PLATFORM_TBD} ;
    }
}

git_status();

print "END of $PROGRAM_NAME.\n\n";
exit 0;



##############################################################################
##############################################################################
##### functions
sub git_status {
    print "\ngit status\n";
    print   "==========\n";
    system 'git status';
    print "\n\n";
    print "git --no-pager diff GIT*/type.properties\n";
    system 'git --no-pager diff GIT*/type.properties';
    print "\n\n";
    print "WARNING : don't forget to update as well : jobbase/extensions/typedefs/BuildRuntime.properties !!!\n\n";
    print "Now up to you to complete/revert the work.\n\n";
    print "END of $PROGRAM_NAME.\n\n";
    exit 0;
}

sub get_property_files {
    if( ! $File::Find::name )    { return }                        # skip folders
    if( ! -f $File::Find::name ) { return }                        # skip folders
    if( $File::Find::name !~ m/[.]properties$/ixms )   { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/type.properties$/ixms ) { return }  # skip this special file, managed later
    my $file_handle;
    my $flag = 0 ;
    my $this_platform_to_delete = $ENV{PLATFORM_TBD};
    open $file_handle , q{<} , "$File::Find::name" or confess "ERROR : cannot open $File::Find::name : $ERRNO";
    while(<$file_handle>) {
        if( $ARG =~ m/buildruntime\=\"$this_platform_to_delete\"/xms ) {
            $flag = 1;
            last;
        }
    }
    close $file_handle or confess "ERROR : cannot close $file_handle : $ERRNO";
    if($flag==1) {
        unlink "$File::Find::name" or cluck "WARNING : cannot delete $File::Find::name : $ERRNO";
    }
    return;
}

sub check_duplicates {
    ($param_add_platforms) =~ s/\s+//gxms;      # if people want to add spaces for more readable
    ($param_add_platforms) =~ s/[=]/:/gxms;     # if people prefer '=' instead of ':'
    ($param_add_platforms) =~ s/[\(\{]/[/gxms;  # if people prefer () or {}
    ($param_add_platforms) =~ s/[\)\}]/]/gxms;  # if people prefer () or {}

    my %check_duplicate_new_platforms;
    foreach my $key_list (split $SEMICOLON , $param_add_platforms) {
        my ($ref_platform,$tmp_platforms);
        ($ref_platform,$tmp_platforms) = $key_list =~ m/^[\[](.+?)[:](.+?)[\]]$/ixms;
        if( ! defined $ref_platform) {
            $ref_platform    = $global_ref_platform;
            ($tmp_platforms) = $key_list =~ m/^[[:](.+?)[\]]$/ixms;
            ($tmp_platforms) =~ s/[:]//xms;
        }
        my @new_platforms = split $COMMA , $tmp_platforms ;
        # search variant
        my $variant       = $ref_platform;
        my $flag          = 0;
        foreach my $platform (@new_platforms) {
            if($platform =~ m/[|](.+?)$/ixms) {
                $variant = $1;
                $flag    = 1 ;
                last;
            }
        }
        if($flag == 1) {
            my $last_elem = pop @new_platforms;
            ($last_elem)  =~ s/[|].+?$//ixms;
            push @new_platforms , $last_elem ;
        }
        # search duplicate
        foreach my $platform (@new_platforms) {
            if( ! defined $check_duplicate_new_platforms{$platform} ) {
                $check_duplicate_new_platforms{$platform} = 1 ;
            }  else  {
                confess "\nERROR : $platform already listed in $orig_param_add_platforms : $ERRNO";
            }
        }
        push @{$h_add_platforms{$ref_platform}{variant}} , $variant;
        if(scalar @{$h_add_platforms{$ref_platform}{variant}} > 1) {
            confess "\nERROR : there is more than 1 variant for $ref_platform in $orig_param_add_platforms : $ERRNO";
        }
        push @{$h_add_platforms{$ref_platform}{new_platforms}} , @new_platforms;
    }
    return;
}

sub getlist_template_files {
    # search all files with buildruntime=reference_platform
    if( ! -f $File::Find::name ) { return }                         # skip folders
    if( $File::Find::name =~ m/[.]git/ixms ) { return }             # skip .git folder
    if( $File::Find::name !~ m/[.]properties$/ixms )    { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/P4\_$/ixms )            { return }   # skip P4, should not exist but in case . . .
    if( $File::Find::name =~ m/type.properties$/ixms ) { return }   # skip this special file, managed later
    my $this_ref_platform = $ENV{REF_PLATFORM};
    my $file_handle;
    open $file_handle , q{<} , $File::Find::name or confess "ERROR : cannot open $File::Find::name : $ERRNO";
    while(<$file_handle>) {
        if( $ARG =~ m/buildruntime\=\"$this_ref_platform\"/xms ) {
            (my $final_file = $File::Find::name) =~ s/^$current_dir\///ixms; # remove the base folder, for the display.
            (my $type = $final_file) =~ s/\/.+?$//xms;
            push @{$list_template_files{$type}} , $final_file ;
            last;
        }
    }
    close $file_handle or confess "ERROR : cannot close $file_handle : $ERRNO";
    return;
}

sub add_new_platform {
    my ($this_new_platform) = @ARG ;
    foreach my $type ( sort keys %list_template_files ) {
        #print "\t\t- $type\n";
        foreach my $template_file ( sort @{$list_template_files{$type}} )  {
            create_property_file($this_new_platform, $template_file);
        }
        if( -e "$current_dir/$type/type.properties") {
            add_new_platform_in_type_file($this_new_platform , "$type/type.properties");
        }
    }
    return;
}

sub create_property_file {
    my ($this_platform, $this_template_file) = @ARG ;
    my $this_ref_platform = $ENV{REF_PLATFORM};
    (my $tmp_file = $this_template_file) =~ s/\-$this_ref_platform/\-$this_platform/gxms;
    my $template_file = "$current_dir/$this_template_file";
    my $new_file      = "$current_dir/$tmp_file";
    my $file_handle;
    my $new_file_handle;
    open $file_handle     , q{<} , "$template_file" or confess "ERROR : cannot open $template_file : $ERRNO";
    open $new_file_handle , q{>} , "$new_file"      or confess "ERROR : cannot create $new_file : $ERRNO";
    while(<$file_handle>) {
        if(m/\"$this_ref_platform\"/ixms) {
            s/\"$this_ref_platform\"/\"$this_platform\"/xms;
        }
        print {$new_file_handle} "$ARG" or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    }
    close $new_file_handle or confess "ERROR : cannot close $new_file_handle : $ERRNO";
    close $file_handle     or confess "ERROR : cannot close $file_handle : $ERRNO";

    return;
}

sub add_new_platform_in_type_file {
    my ($this_platform, $this_type_property_file) = @ARG ;
    my $this_variant = $ENV{variant};
    my $lines_to_add =  "\n" .
"additional.variant.$this_platform.buildruntime=$this_platform\n" .
"additional.variant.$this_platform.buildoptions=-V platform\=$this_variant -V mode\=opt";
    my $ref_property_file = "$current_dir/$this_type_property_file";
    my $file_handle;
    my $new_file_handle;
    open $file_handle     , q{<} , "$ref_property_file"                        or confess "ERROR : cannot open $ref_property_file : $ERRNO";
    open $new_file_handle , q{>} , "$current_dir/$this_type_property_file.new" or confess "ERROR : cannot create $current_dir/$this_type_property_file.new : $ERRNO";
    while(<$file_handle>) {
        print {$new_file_handle} "$ARG"       or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    }
    print {$new_file_handle} "\n"             or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    print {$new_file_handle} "$lines_to_add"  or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    print {$new_file_handle} "\n"             or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    close $new_file_handle or confess "ERROR : cannot close $new_file_handle : $ERRNO";
    close $file_handle     or confess "ERROR : cannot close $file_handle : $ERRNO";
    rename "$current_dir/$this_type_property_file.new" , "$current_dir/$this_type_property_file"
        or cluck "WARNING : cannot rename '$this_type_property_file.new' to '$this_type_property_file' : $ERRNO\n";
    return;
}

sub get_type_files {
    if( $File::Find::name =~ m/[.]git/ixms ) { return }            # skip .git folder
    if( ! $File::Find::name )    { return }                        # skip folders
    if( ! -f $File::Find::name ) { return }                        # skip folders
    if( $File::Find::name !~ m/[.]properties$/ixms )   { return }  # ensure file is a .properties file
    if( $File::Find::name =~ m/type[.]properties$/ixms ) {
        (my $type_file = $File::Find::name) =~ s/^$current_dir\///xms;
        $list_type_files{$type_file} = 1 ;
        return
    }
    return;
}

sub delete_platform_in_type_file {
    my ($this_type_property_file) = @ARG ;
    my $delete_platform = $ENV{PLATFORM_TBD} ;
    my $ref_property_file = "$current_dir/$this_type_property_file";
    my $file_handle;
    my $new_file_handle;
    open $file_handle     , q{<} , "$ref_property_file"                        or confess "ERROR : cannot open $ref_property_file : $ERRNO";
    open $new_file_handle , q{>} , "$current_dir/$this_type_property_file.new" or confess "ERROR : cannot create $current_dir/$this_type_property_file.new : $ERRNO";
    while(<$file_handle>) {
        if($ARG =~ m/[.]$delete_platform[.]/xms) {
            next ;
        }
        print {$new_file_handle} "$ARG" or confess "ERROR : cannot write in $new_file_handle : $ERRNO";
    }
    close $new_file_handle              or confess "ERROR : cannot close $new_file_handle : $ERRNO";
    close $file_handle                  or confess "ERROR : cannot close $file_handle : $ERRNO";
    rename "$current_dir/$this_type_property_file.new" , "$current_dir/$this_type_property_file"
        or cluck "WARNING : cannot rename '$this_type_property_file.new' to '$this_type_property_file' : $ERRNO\n";
    return;
}

sub display_help {
    my $display_help_message = <<"END_USAGE";

[synopsis]
$PROGRAM_NAME is a tool to add new platform(s) (buildruntime, aka jenkins label),
or to delete platform(s) in the xMake jobbase, see README.md for further details

[options]
    -h  : to display this help
    -ap : to list a set of platforms to add (cannot be used with -dp)
          as there is a special syntax, please follow the README.md for further details.
    -dp : to list of platforms to delete (cannot be used with -ap)
          i.e.: -dp="platformA,platformB"
        , see README.md for further details.

END_USAGE
    print "$display_help_message";
    return;
}
