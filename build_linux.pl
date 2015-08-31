#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use File::Find qw( find );
use Digest::MD5;

require "remove_unwanted_addins.pl";
require "apply_monodevelop_patches.pl";

my $buildRepoRoot = File::Spec->rel2abs( dirname($0) );
my $root = File::Spec->rel2abs( File::Spec->updir() );
my $mdSource = "$root/monodevelop/main/build";
my $nant = "mono --runtime=v4.0.30319 $buildRepoRoot/dependencies/nant-0.93-nightly-2015-02-12/bin/NAnt.exe";
my $MONO_SGEN_MD5 = "0a6bdaaf2ddd28124d2c6166840e06d4";
my $MONO_VERSION_BUILD_MACHINE = "4.0.2";

main();

sub main {
	prepare_sources();

	# Apply patches (if any) to MonoDevelop and Mono framework
	apply_mono_develop_patches($root, $buildRepoRoot);

	# Build MonoDevelop
	build_monodevelop();
	reverse_mono_develop_patches($root, $buildRepoRoot);
    remove_unwanted_addins(); 

	# Build Unity Add-ins
	build_debugger_addin();
	build_boo();
	build_boo_extensions();
	build_unityscript();
	build_boo_unity_addins();

	package_monodevelop();
}

sub prepare_sources {
	chdir $root;
	die ("Must grab MonoDevelop checkout from github first") if !-d "monodevelop";
	die ("Must grab Unity MonoDevelop Soft Debugger source from github first") if !-d "MonoDevelop.Debugger.Soft.Unity";
	die ("Must grab Unity Add-ins for Boo and Unity source from github first") if !-d "MonoDevelop.Boo.UnityScript.Addins";
	die ("Must grab Boo implementation") if !-d "boo";
	die ("Must grab Boo extensions") if !-d "boo-extensions";
	die ("Must grab Unityscript implementation") if !-d "unityscript";
}

sub build_monodevelop 
{
	chdir "$root/monodevelop";

	system("./configure --profile=stable");

	# If NuGet fails it might be necessary to install these certificates as root
	# $ sudo mozroots --import --machine --sync
	# $ sudo certmgr -ssl -m https://go.microsoft.com
	# $ sudo certmgr -ssl -m https://nugetgallery.blob.core.windows.net
	# $ sudo certmgr -ssl -m https://nuget.org

	system("mono main/external/nuget-binary/NuGet.exe install main/src/addins/NUnit/packages.config");

	system("make clean all") && die("Failed building MonoDevelop");
	mkpath("main/build/bin/branding");
	copy("$buildRepoRoot/dependencies/Branding.xml", "main/build/bin/branding/Branding.xml") or die("failed copying branding");
}

sub build_debugger_addin 
{
	my $addinsdir = "$root/monodevelop/main/build/AddIns/";
	chdir "$root/MonoDevelop.Debugger.Soft.Unity";
	mkpath "$addinsdir/MonoDevelop.Debugger.Soft.Unity";
	system("xbuild /property:Configuration=Release /t:Rebuild /p:OutputPath=\"$addinsdir/MonoDevelop.Debugger.Soft.Unity\"") && die("Failed building Unity debugger addin");
}

sub build_boo {
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";
	chdir "$root/boo";
	system("$nant rebuild") && die ("Failed to build Boo");
	mkpath "$externalDir/Boo";
	system("rsync -av --exclude=*.mdb  \"$root/boo/build/\" \"$externalDir/Boo\"");
}

sub build_boo_extensions {
	chdir "$root/boo-extensions";
	system("$nant rebuild") && die ("Failed to build Boo");
}

sub build_unityscript {
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";
	chdir "$root/unityscript";
	rmtree "$root/unityscript/bin";
	system("$nant rebuild") && die ("Failed to build UnityScript");
	mkpath "$externalDir/UnityScript";
	system("rsync -av --exclude=*.mdb --exclude=*Tests* --exclude=nunit* \"$root/unityscript/bin/\" \"$externalDir/UnityScript\"");
}

sub build_boo_unity_addins {
	my $addinsdir = "$root/monodevelop/main/build/AddIns/";
	chdir "$root/MonoDevelop.Boo.UnityScript.Addins";
	mkpath "$addinsdir/MonoDevelop.Boo.UnityScript.Addins";
	system("xbuild /property:Configuration=Release /t:Rebuild /p:OutputPath=\"$addinsdir/MonoDevelop.Boo.UnityScript.Addins\"") && die("Failed building Unity debugger addin");
}

sub package_monodevelop {
	my $buildresult = "$buildRepoRoot/buildresult";
	system("rm -rf $buildresult") if (-d $buildresult);
	mkpath($buildresult);

	chdir "$mdSource";
	unlink "MonoDevelop.tar.gz";
	system("tar cfz MonoDevelop.tar.gz AddIns bin data locale");
	move "MonoDevelop.tar.gz", "$buildresult";
}
