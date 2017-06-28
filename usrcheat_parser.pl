#!/usr/bin/perl

# Copyright (C) 2017 - Wilson E. Alvarez
#
# You should have received a copy of the GNU General Public License along with this parser.
# If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use utf8;
#use diagnostics;
use POSIX;
use Getopt::Long;
use XML::Parser;
use Data::Dumper;

# We need to print some utf8 characters.
binmode STDOUT, ':utf8';

# Envrionment variables:
my $input_filename;
my $help;

GetOptions ("input-file|i=s"   => \$input_filename,
	"help|h"  => \$help)
	or die $!;

sub usage {
	print << "	EOF"
	Description:
	usrcheat.xml converter to libretro cheat codes.

	Usage:
	-i, --input-filename <filename>			Input file.

	$0 --input-file foo.cpp

	EOF

}

if ( defined $help )
{
	usage();
	exit;
}

if ( ! defined $input_filename )
{
	print "Input file, -i, must be given";
	usage();
	exit;

}

use XML::Parser;
my $p = XML::Parser->new(Style => 'Tree');
my $tree = $p->parsefile($input_filename);

# Debug:
#print Dumper $tree;
#exit 0;

my $current_game_name;
my $current_folder_name;
my $current_cheat_name;
my $current_cheat_code;

my $found_game;
my $found_game_name;
my $found_cheat;
my $found_cheat_name;
my $found_folder;
my $found_folder_name;
my $found_cheat_codes;


# Note: since we should not how many cheats we are going to spit out, we have to make the body of the file first, and add the heading at the end.
# Create the file in-memory. The writing to a file with the game name as its filename.

# .cht format for the libretro databse. This is what we want each file to look like:
 
#cheats = 3
#
#cheat0_desc = "Enable Code (Must Be On)"
#cheat0_code = "00007358+000A+100092B8+0007"
#cheat0_enable = false 
#
#cheat1_desc = "Infinite Health"
#cheat1_code = "3200074A+0008"
#cheat1_enable = false 
#
#cheat2_desc = "Have All Weapons"
#cheat2_code = "8201ED74+0FFF"
#cheat2_enable = false 

my $cheat_count = -1; # Note: folder names count as cheats in terms of the format of that .cht file, and for parsing purposes. Just makes it a lot easier to transform the XML that way.
my $game_count = 0;
my $output_file;
my $current_cheat_file;
my $output_filehandle;
my $filename;

sub dump_in_memory_cht_to_disk
{
	# Remove non ASCII characters from the filename:
	$current_game_name =~ s/[^[:ascii:]]//g;

	# Some game names have a forward slash. Switch it to a space.
	$current_game_name =~ s/\// /g;

	# Generate final filename:
	my $output_filename = "./cheats/" . $current_game_name . ".cht";

	open my $output_filehandle, ">", $output_filename or die $!;

	# Update the cheat count one last time:
	++$cheat_count;

	# Generate the total cheat lines:
	print $output_filehandle "cheats = " . $cheat_count . "\n\n";

	# Remove non ASCII characters from the cheat file:
	$current_cheat_file =~ s/[^[:ascii:]]//g;

	# Dump the generated cht file to disk:
	print $output_filehandle $current_cheat_file;

	close $output_filehandle;
}

sub loop_recursively_over_array
{
	my @array = @{$_[0]};

	foreach my $value ( @array )
	{
		if ( ref($value) eq "ARRAY" )
		{
			#print "\nFound array reference\n";
			loop_recursively_over_array($value);
		}
		else
		{
			## Debug: only print important values
			#if ( ref($value) ne "HASH" && $value ne "0" && $value !~ /^\s+$/  )
			#{
			#	print "value is: $value\n";
			#	next;
			#}

			# Skip unnecessary values. Remove the noise:
			if ( ! ( ref($value) ne "HASH" && $value ne "0" && $value !~ /^\s+$/ )  )
			{
				next;
			}

			# In some rare cases we have to clean all the states in order to
			# properly find the game name. This <game> tag has the highest
			# priority when parsing this database in XML form.
			if ( $value eq "game" )
			{
				$found_game = 1;
				undef $found_game_name;
				undef $found_cheat;
				undef $found_cheat_name;
				undef $found_folder;
				undef $found_folder_name;
				undef $found_cheat_codes;

				if ( $game_count > 0 )
				{
					# Debug:
					#print "Filename: " . $current_game_name . ".cht\n\n";
					#print "cheats = " . $cheat_count . "\n\n";
					#print $current_cheat_file;
					#print "\n\n";

					# Dump the whole in-memory .cht file into disk here.
					dump_in_memory_cht_to_disk();

					# Reset variables: 
					$cheat_count = -1;
					$current_cheat_file = "";
				}

				++$game_count;
				next;
			}

			# ======= CHEAT TAG CODE BLOCK BEGINS ==========
			if ( defined $found_cheat  && defined $found_cheat_name )
			{
				undef $found_cheat_name;

				if ( $value eq "cheat" || $value eq "codes" )
				{
					# Nope, there was an empty field somewhere. We didn't find anything.
					next;
				}

				# Debug:
				#print "Cheat name is: $value\n";

				$current_cheat_name = $value;

				# Line to construct:
				#cheat0_desc = "Enable Code (Must Be On)"

				++$cheat_count;
				$current_cheat_file .= "cheat" . $cheat_count . "_desc = \"" . $current_cheat_name . "\"\n";

				next;
			}
			elsif ( defined $found_cheat  && defined $found_cheat_codes )
			{
				undef $found_cheat_codes;

				if ( $value eq "cheat" || $value eq "codes" )
				{
					# Nope, there was an empty field somewhere. We didn't find anything.
					next;
				}

				# Debug:
				#print "Cheat code is: $value\n";
				$current_cheat_code = $value;
				$current_cheat_code =~ s/\s+/+/g;

				# Lines to construct here:
				#cheat0_code = "00007358+000A+100092B8+0007"
				#cheat0_enable = false 

				$current_cheat_file .= "cheat" . $cheat_count . "_code = \"" . $current_cheat_code . "\"\n";
				$current_cheat_file .= "cheat" . $cheat_count . "_enable = false\n\n";

				next;
			}
			# ======= CHEAT TAG CODE BLOCK BEGINS ==========

			# ======= FOLDER TAG CODE BLOCK BEGINS ==========
			elsif ( defined $found_folder  && defined $found_folder_name )
			{
				undef $found_folder;

				# Debug:
				#print "Folder name is: $value\n";
				$current_folder_name = $value;

				# Lines to construct here:
				#cheat0_code = "00007358+000A+100092B8+0007"

				++$cheat_count;
				$current_cheat_file .= "cheat" . $cheat_count . "_desc = \"" . $current_folder_name . "\"\n\n";

				next;
			}
			# ======= FOLDER TAG CODE BLOCK ENDS ==========


			# ======= GAME TAG CODE BLOCK BEGINS ==========
			elsif ( defined $found_game && defined $found_game_name )
			{
				undef $found_game;

				# Debug:
				#print "Found game: $value\n";
				$current_game_name = $value;
				next;
			}
			# ======= GAME TAG CODE BLOCK ENDS ==========




			# IMPORTANT: Related to the architecture of this loop:
			# We are activating the above code blocks in a backwards manner: i.e., from bottom to top. The last if-else code block 
			# above gets activated by the first code block of the if-else statements blocks below, in a LIFO manner.
			# This makes it easier to parse the XML tags in this case, but the loop can hard to understand the first time without any information.



			
			# ======= GAME TAG CODE BLOCK BEGINS ==========
			if ( defined $found_game && $value eq "name" ) # then the next value will be the game name
			{
				$found_game_name = 1;
				#print "foundgamename\n";
				next;
			}
			# ======= GAME TAG CODE BLOCK ENDS ==========



			# ======= FOLDER TAG CODE BLOCK BEGINS ==========
			elsif ( $value eq "folder" )
			{
				$found_folder = 1;
				undef $found_folder_name;
				#print "foundfolder\n";
				next;
			}
			elsif ( defined $found_folder && $value eq "name" ) # then the next value will be the folder name
			{
				$found_folder_name = 1;
				#print "foundfoldername\n";
				next;
			}
			# ======= FOLDER TAG CODE BLOCK ENDS ==========



			# ======= CHEAT TAG BLOCK BEGINS ==========
			elsif ( $value eq "cheat" )
			{
				$found_cheat = 1;
				#print "foundcheat\n";
				next;
			}
			elsif ( defined $found_cheat && $value eq "name" ) # then the next value will be the cheat name
			{
				$found_cheat_name = 1;
				#print "foundcheatname\n";
				next;
			}
			elsif ( defined $found_cheat && $value eq "codes" ) # then the next value will be the codes
			{
				$found_cheat_codes = 1;
				#print "foundcheatcode\n";
				next;
			}
			# ======= CHEAT TAG BLOCK ENDS ==========
		}
	}
}

loop_recursively_over_array( $tree );

# The last game has not been printed. Dump the memory contents to disk:
dump_in_memory_cht_to_disk();
