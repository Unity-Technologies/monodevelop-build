#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Copy;
use File::Path;
use Cwd;

sub apply_mono_develop_patches()
{
	my $root = $_[0];
	my $buildRepoRoot = $_[1];

	print "Applying monodevelop.patch\n";
	chdir "$root/monodevelop";
	system("git apply --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/monodevelop.patch") && die("Failed to apply monodevelop.patch");
	system("git submodule update main/external/debugger-libs") && die("Failed up update debugger-libs submodule");

	# print "Applying debugger-libs.patch\n";
	# chdir "$root/monodevelop/main/external/debugger-libs";
	# system("git apply --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/debugger-libs.patch") && die("Failed to apply debugger-libs.patch");

	# print "Applying mono-addins.patch\n";
	# chdir "$root/monodevelop/main/external/mono-addins";
	# system("git apply --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/mono-addins.patch") && die("Failed to apply mono-addins.patch");
}

sub reverse_mono_develop_patches()
{
	my $root = $_[0];
	my $buildRepoRoot = $_[1];

	print "Reversing monodevelop.patch\n";
	chdir "$root/monodevelop";
	system("git apply --reverse --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/monodevelop.patch") && die("Failed to reverse monodevelop.patch");
	system("git submodule update main/external/debugger-libs") && die("Failed up update debugger-libs submodule");

	# print "Reversing debugger-libs.patch\n";
	# chdir "$root/monodevelop/main/external/debugger-libs";
	# system("git apply --reverse --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/debugger-libs.patch") && die("Failed to reverse debugger-libs.patch");

	# print "Reversing mono-addins.patch\n";
	# chdir "$root/monodevelop/main/external/mono-addins";
	# system("git apply --reverse --ignore-space-change --ignore-whitespace $buildRepoRoot/patches/mono-addins.patch") && die("Failed to reverse mono-addins.patch");
}

1;