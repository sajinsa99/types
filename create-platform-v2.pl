#### standard perl could be use no need to install any specific perl module


##############################################################################
##############################################################################
##### declare uses
# for code quality
use strict;
use warnings;
use diagnostics;
use Carp qw(cluck confess); # to use instead of (warn die)

# for the script itself
use Getopt::Long;
use File::Copy;
use File::Find;
use FindBin;
use lib $FindBin::Bin;



##############################################################################
##############################################################################
##### declare vars

use vars qw (
    $currentDir
    $referencePlatform
    $orig_param_platforms
    %hPlatforms
);

# for options/parameters
use vars qw (
    $param_platforms
    $opt_Create
    $opt_UpdateTypeFile
    $opt_Force
    $opt_Delete
    $opt_Help
);

##############################################################################
##############################################################################
##### declare functions
sub checkDuplicates();
sub getListTemplateFiles($$);
sub createNewPlatform($$);
sub createNewFile($$$);
sub cleanPlatform($);
sub updateTypePropertyFile($$$);
sub displayHelp();



##############################################################################
##############################################################################
##### get options/parameters
$Getopt::Long::ignorecase = 0;
GetOptions(
    "r=s"   =>\$referencePlatform,
    "p=s"   =>\$param_platforms,
    "C"     =>\$opt_Create,
    "U"     =>\$opt_UpdateTypeFile,
    "F"     =>\$opt_Force,
    "D"     =>\$opt_Delete,
    "help"  =>\$opt_Help,
);



##############################################################################
##############################################################################
##### inits & checks
$currentDir          = $FindBin::Bin;
$referencePlatform ||= "linuxx86_64" ; # use linuxx86_64 by default

if($opt_Help) {
    displayHelp();
    exit 0;
}

unless($param_platforms) {
    print "\n\nERRROR : need to specify the platforms -p=..., see help for more details\n\n";
    displayHelp();
    exit 1;
}

$orig_param_platforms = $param_platforms ;
checkDuplicates();



##############################################################################
##############################################################################
##### MAIN

# 1 get list of existing properties files used as templates
#find(\&getListTemplateFiles, $currentDir);
foreach my $ref_platform (sort keys %hPlatforms) {
	print $ref_platform , "\n";
	my $listTemplateFiles;
	find(\&getListTemplateFiles($ref_platform,\$listTemplateFiles), $currentDir);
	if( scalar keys %listTemplateFiles > 0 ) {
	}  else  {
		warn "WARNING : no properties file found for $ref_platform:$!";
		print "\n";
	}
	foreach my $elem (sort keys %{$hPlatforms{$ref_platform}} ) {
		print "\t" , $elem , "\n";
		foreach my $new_platform (sort @{$hPlatforms{$ref_platform}{$elem}} ) {
			print "\t\t" , $new_platform , "\n";
		}
	}
}


exit 0;



##############################################################################
##############################################################################
##### functions
sub checkDuplicates() {
    ($param_platforms) =~ s-\s+--g;     # if people want to add spaces for more readable
    ($param_platforms) =~ s-\=-:-g;     # if people prefer '=' instead of ':'
    ($param_platforms) =~ s-\(|\{-[-g;  # if people prefer () or {}
    ($param_platforms) =~ s-\)|\}-]-g;  # if people prefer () or {}

    my %checkDuplicateNewPlatforms;
    foreach my $key_list (split ';' , $param_platforms) {
        my ($ref_platform,$tmp_platforms);
        ($ref_platform,$tmp_platforms) = $key_list =~ /^\[(.+?)\:(.+?)\]$/i;
        if( ! defined $ref_platform) {
            $ref_platform    = $referencePlatform;
            ($tmp_platforms) = $key_list =~ /^\[\:(.+?)\]$/i;
        }
        my @new_platforms = split ',' , $tmp_platforms ;
        # search variant
        my $variant       = $ref_platform;
        my $flag          = 0;
        foreach my $platform (@new_platforms) {
            if($platform =~ /\|(.+?)$/i) {
                $variant = $1;
                $flag    = 1 ;
                last;
            }
        }
        if($flag == 1) {
            my $last_elem = pop @new_platforms;
            ($last_elem)  =~ s-\|.+?$--i;
            push @new_platforms , $last_elem ;
        }
        # search duplicate
        foreach my $platform (@new_platforms) {
            if( ! defined $checkDuplicateNewPlatforms{$platform} ) {
                $checkDuplicateNewPlatforms{$platform} = 1 ;
            }  else  {
                confess "\nERROR : $platform already listed in $orig_param_platforms : $!";
            }
        }
        push @{$hPlatforms{$ref_platform}{variant}} , $variant;
        if(scalar @{$hPlatforms{$ref_platform}{variant}} > 1) {
            confess "\nERROR : there is more than 1 variant for $ref_platform in $orig_param_platforms : $!";
        }
        push @{$hPlatforms{$ref_platform}{new_platforms}} , @new_platforms;
    }
}
sub getListTemplateFiles($) {
    my ($referencePlatform) = @_ ;
    # search all files with buildruntime=reference_platform
    return unless( -f $File::Find::name );                 # skip folders
    return if( $File::Find::name !~ /\.properties$/i );    # ensure file is a .properties file
    return if( $File::Find::name =~ /P4\_$/i );            # skip P4, should not exist but in case . . .
    return if( $File::Find::name =~ /type.properties$/i ); # skip this special file, managed later
    if(open my $file_handle , '<' , $File::Find::name) {
        while(<$file_handle>) {
            if( $_ =~ /buildruntime\=\"$referencePlatform\"/ ) {
                (my $finalFile = $File::Find::name) =~ s-^$currentDir\/--i; # remove the base folder, for the display.
                (my $type = $finalFile) =~ s-\/.+?$--;
                push @{$listTemplates{$type}} , $finalFile ;
                last;
            }
        }
        close $file_handle;
    }
}

sub createNewPlatform($$) {
    my ($this_new_platform, $this_variant) = @_ ;
    foreach my $type ( sort keys %listTemplateFiles ) {
        print "\n\t$type\n";
        foreach my $templateFile ( sort @{$listTemplateFiles{$type}} )  {
            (my $newFile = $templateFile) =~ s-$referencePlatform-$this_new_platform-;
            print "new file : $newFile\n";
            if( -e "$currentDir/$newFile") {
                print "WARNING : $newFile already exists !!!\n";
                if($optForce) {
                    print "  as -F is set, $newFile will be overriden !!!\n";
                    createNewFile($this_new_platform, $templateFile, $newFile);
                }
            }  else  {
                createNewFile($this_new_platform, $templateFile, $newFile);
            }
        }
        if( -e "$currentDir/$type/type.properties") {
            if($optUpdateTypeFile) {
                updateTypePropertyFile($this_new_platform , $this_variant , "$type/type.properties");
            }  else  {
                print "\nWARNING : don't forget to update, or not, $type/type.properties.\n";
            }
        }
    }
    print "\nWARNING : don't forget to update as well : jobbase/extensions/typedefs/BuildRuntime.properties !!!\n\n";
}

sub createNewFile($$$) {
    my ($this_platform, $this_TemplateFile, $this_NewFile) = @_ ;
    if(open my $newFile_handle , '>' , "$currentDir/$this_NewFile") {
        if(open my $templateFile_handle , '<' , "$currentDir/$this_TemplateFile") {
            while(<$templateFile_handle>) {
                if(/\"$referencePlatform\"/i) {
                    s-\"$referencePlatform\"-\"$this_platform\"-;
                }
                print $newFile_handle $_ ;
            }
            close $templateFile_handle;
        }
        close $newFile_handle;
    }  else  {
        cluck "\tWARNING : cannot create '$this_NewFile' : $!";
        print "\n";
    }
}

sub updateTypePropertyFile($$$) {
    my ($this_platform, $this_variant, $this_typePropertyFile) = @_ ;
    my $linesToAdd = "
additional.variant.$this_platform.buildruntime=$this_platform
additional.variant.$this_platform.buildoptions=-V platform\=$this_variant -V mode\=opt
";
    my $ref_property_file = "$currentDir/$this_typePropertyFile";
    if( -e "$currentDir/$this_typePropertyFile.new") {
        $ref_property_file = "$currentDir/$this_typePropertyFile.new.orig";
        system "cp -pf $currentDir/$this_typePropertyFile.new $currentDir/$this_typePropertyFile.new.orig"
    }
    if(open my $File_handle , '<' , "$ref_property_file") {
        if(open my $newFile_handle , '>' , "$currentDir/$this_typePropertyFile.new") {
            while(<$File_handle>) {
                print $newFile_handle $_;
            }
            print $newFile_handle "\n";
            print $newFile_handle $linesToAdd;
            close $newFile_handle;
        }
        close $File_handle;
        system "rm -f $currentDir/$this_typePropertyFile.new.orig";
        if($optForce) {
            rename "$currentDir/$this_typePropertyFile.new" , "$currentDir/$this_typePropertyFile"
                or cluck "WARNING : cannot rename '$this_typePropertyFile.new' to '$this_typePropertyFile' : $!";
                print "\n";
        }  else  {
            print "$this_typePropertyFile.new created, please merge/rename it in/to $this_typePropertyFile.\n";
        }
    }
}

sub cleanPlatform($) {
    my ($this_platform) = @_ ;
    foreach my $type ( sort keys %listTemplateFiles ) {
        print "\n\t$type\n";
        foreach my $templateFile ( sort @{$listTemplateFiles{$type}} ) {
            (my $newFile = $templateFile) =~ s-$referencePlatform-$this_platform-;
            if( -e "$currentDir/$newFile" ) {
                print "file to clean : $newFile\n";
                unlink "$currentDir/$newFile"
                    or cluck "WARNING : cannot unlink '$currentDir/$newFile' : $!";
                print "\n";
            }
        }
        if( -e "$currentDir/$type/type.properties.new") {
            print "file to clean : $type/type.properties.new\n";
            unlink "$currentDir/$type/type.properties.new"
                or cluck "WARNING : cannot unlink '$currentDir/$type/type.properties.new' : $!";
            print "\n";
        }  else  {
            print "WARNING : maybe you have to revert yourself : $type/type.properties !!!\n";
        }
    }
}

sub displayHelp() {
    print <<FIN_USAGE;

[synopsis]
$0 permit to create new platform (new buildruntime) in the jobbase.
It concists to create .properties files in jobbase/builds/types/<TYPE>/jobs/
It is based on a reference platform (by default : linuxx86_64) for creating new platform.

[options]
    -h  : to display this help
    -rp : to choose a specific reference platform, MANDATORY
    -np : to choose the new platform, MANDATORY
    -C  : ACTION : to create
          if -D is set as well, $0 will run only -D
    -U  : works with -C, update as well <type>/type.properties file, eg update as well GIT_DEV/type.properties file.
          $0 will create type.properties.new file, up to you to merge/move in/to type.properties file.
          if -F is set, it will move from type.properties.new to type.properties
    -F  : works with -C, if .properties files of new platform or <type>/type.properties already exist, to override them.
    -D  : ACTION : if .properties files of new platform already exist, to delete them, and exit.
          if -C or -U or -F are set as well, they will be ignored.

FIN_USAGE
}
