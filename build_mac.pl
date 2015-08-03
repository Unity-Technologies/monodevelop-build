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
my $nant = "";
my $MONO_SGEN_MD5 = "0a6bdaaf2ddd28124d2c6166840e06d4";
my $MONO_VERSION_BUILD_MACHINE = "4.0.2";

main();

sub main {
	prepare_sources();
	setup_env();
	setup_nant();

	# Apply patches (if any) to MonoDevelop and Mono framework
	apply_patches();

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

	system("rm -rf $buildRepoRoot/dependencies/Mono.framework");
	system("unzip -d $buildRepoRoot/dependencies $buildRepoRoot/dependencies/monoframework-osx.zip") && die("Failed to unpack monoframework-osx.zip");
}

sub setup_env {

	# Build machines have /Library/Frameworks/Mono.framework/Versions/Current symlink pointing to Mono 2.6.7
	# Here we setup the env variables to use a newer Mono version for building.
	if ($ENV{UNITY_THISISABUILDMACHINE})
	{
		my $MONO_PREFIX = "/Library/Frameworks/Mono.framework/Versions/$MONO_VERSION_BUILD_MACHINE";

		$ENV{DYLD_FALLBACK_LIBRARY_PATH} = "$MONO_PREFIX/lib:/usr/lib/:$ENV{DYLD_FALLBACK_LIBRARY_PATH}";
		$ENV{LD_LIBRARY_PATH} = "$MONO_PREFIX/lib:$ENV{LD_LIBRARY_PATH}";
		$ENV{C_INCLUDE_PATH} = "$MONO_PREFIX/include";
		$ENV{ACLOCAL_PATH} = "$MONO_PREFIX/share/aclocal";
		$ENV{PKG_CONFIG_PATH} = "$MONO_PREFIX/lib/pkgconfig";
		$ENV{PATH} = "$MONO_PREFIX/bin:$ENV{PATH}";
	}
	else
	{
		$ENV{PKG_CONFIG_PATH}="/Library/Frameworks/Mono.framework/Versions/Current/lib/pkgconfig";
	}
}

sub setup_nant 
{
	$nant = "mono --runtime=v4.0.30319 $buildRepoRoot/dependencies/nant-0.93-nightly-2015-02-12/bin/NAnt.exe";
}

sub apply_patches()
{
	chdir "$buildRepoRoot";

	my $monosgen = "dependencies/Mono.framework/Versions/Current/bin/mono-sgen";
	my $monosgenMD5 = "";

	if (-e "$monosgen")
	{
		open my $fh, '<', "$monosgen";
		$monosgenMD5 = Digest::MD5->new->addfile($fh)->hexdigest;
		close $fh;
	}
	else
	{
		die("Could not find $buildRepoRoot/$monosgen");
	}

	if ($monosgenMD5 ne $MONO_SGEN_MD5)
	{
		die("\nERROR: mono-sgen MD5 was $monosgenMD5 expected $MONO_SGEN_MD5.\nDid you update the Mono framework without updating patches/mono-sgen?")
	}

	# Mono framework patches
	system("cp patches/mono-sgen dependencies/Mono.framework/Versions/Current/bin/mono-sgen");

	# MonoDevelop patches
	apply_mono_develop_patches($root, $buildRepoRoot);
}

sub build_monodevelop {
	chdir "$root/monodevelop";

	open(my $fh, '>', 'profiles/unity');
	print $fh "main --disable-update-mimedb --disable-update-desktopdb --disable-gnomeplatform --enable-macplatform --disable-tests --disable-git --disable-subversion\n";
	close $fh;

	system("./configure --profile=unity");

	# monodevelop/main/external/Makefile copies Xamarin.Mac files from the system installed 
	# framework. We remove the Makefile copy and copy our own local copies instead.
	system("cp $buildRepoRoot/dependencies/libxammac.dylib main/external/");
	system("cp $buildRepoRoot/dependencies/Xamarin.Mac.dll main/external/");
	system("cp $buildRepoRoot/dependencies/Xamarin.Mac.dll.mdb main/external/");

	system("cp $buildRepoRoot/dependencies/WelcomePage_Logo.png main/src/core/MonoDevelop.Ide/branding/WelcomePage_Logo.png");

	system("sed -i -e 's/all: Xamarin.Mac.dll/all:/g' main/external/Makefile");

	# Change Xamarin.Mac.dll references to point to our own copy.
	system("sed -i -e 's/\\\\Library\\\\Frameworks\\\\Xamarin.Mac.framework\\\\Versions\\\\Current\\\\lib\\\\i386\\\\full\\\\Xamarin.Mac.dll/..\\\\..\\\\Xamarin.Mac.dll/g' main/external/xwt/Xwt.Mac/Xwt.Mac.csproj");
	system("sed -i -e 's/\\\\Library\\\\Frameworks\\\\Xamarin.Mac.framework\\\\Versions\\\\Current\\\\lib\\\\i386\\\\full\\\\Xamarin.Mac.dll/..\\\\..\\\\Xamarin.Mac.dll/g' main/external/xwt/Xwt.Gtk.Mac/Xwt.Gtk.Mac.csproj");

	system("make clean all") && die("Failed building MonoDevelop");
	mkpath("main/build/bin/branding");
	copy("$buildRepoRoot/dependencies/Branding.xml", "main/build/bin/branding/Branding.xml") or die("failed copying branding");
}

sub build_debugger_addin {
	my $addinsdir = "$root/monodevelop/main/build/Addins/";
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
	my $addinsdir = "$root/monodevelop/main/build/Addins/";
	chdir "$root/MonoDevelop.Boo.UnityScript.Addins";
	mkpath "$addinsdir/MonoDevelop.Boo.UnityScript.Addins";
	system("xbuild /property:Configuration=Release /t:Rebuild /p:OutputPath=\"$addinsdir/MonoDevelop.Boo.UnityScript.Addins\"") && die("Failed building Unity debugger addin");
}

sub package_monodevelop {
	my $buildresult = "$buildRepoRoot/buildresult";
	system("rm -rf $buildresult") if (-d $buildresult);
	mkpath($buildresult);

	my $targetapp = "$buildresult/MonoDevelop.app";
	my $monodevelopbuild = "$root/monodevelop/main/build";
	my $monodeveloptarget = "$targetapp/Contents/MacOS/lib/monodevelop";

	system("cp -R $buildRepoRoot/dependencies/template.app \"$targetapp\"");

	system("mkdir -p \"$targetapp/Contents/Frameworks/\"");
	system("cp -R $buildRepoRoot/dependencies/Mono.framework \"$targetapp/Contents/Frameworks/\"");
	
	mkpath($monodeveloptarget);
	system("cp -r $monodevelopbuild/Addins \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/bin \"$monodeveloptarget/\"");
	system("cp -r $monodevelopbuild/data \"$monodeveloptarget/\"");

	system("rm -rf $buildRepoRoot/dependencies/Mono.framework");

	# Archive the app for placement in unity installer
	chdir "$buildresult";
	unlink "MonoDevelop.dmg", "MonoDevelop.app.tar.gz";

	print "Creating MonoDevelop.app.tar.gz\n";
	system("tar -pczf MonoDevelop.app.tar.gz --exclude=.svn MonoDevelop.app");

	# Create seperate monodevelop installer as well
	chdir "$mdSource/MacOSX/";
	system("sh make-dmg-bundle.sh $buildresult/MonoDevelop.app");

	my $dmg = glob "MonoDevelop-*.dmg";
	move "$mdSource/MacOSX/$dmg", "$buildresult/MonoDevelop.dmg" or die $!;
}
