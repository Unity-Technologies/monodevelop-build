#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use Digest::MD5;

require "remove_unwanted_addins.pl";
require "apply_monodevelop_patches.pl";

my $GTK_VERSION = "2.12";
my $GTK_INSTALLER = "gtk-sharp-2.12.25.msi";
my $GTK_SHARP_DLL_MD5 = "813407a0961a7848257874102f4d33ff";

my $MONO_LIBRARIES_VERSION = "2.6";
my $MONO_LIBRARIES_INSTALLER = "MonoLibraries.msi";

my $SevenZip = '"C:\Program Files (x86)\7-Zip\7z"';
my $gtkPath = "$ENV{ProgramFiles}/GtkSharp/$GTK_VERSION";
my $monolibPath = "$ENV{ProgramFiles}/MonoLibraries/$MONO_LIBRARIES_VERSION";

my $buildRepoRoot = File::Spec->rel2abs( dirname($0) );
my $root = File::Spec->rel2abs( File::Spec->updir() );

my $mdSource = "$root/monodevelop/main/build";

my $nant = "";
my $incremental = "/t:Rebuild";

main();

sub main {
	prepare_sources();
	install_gkt_sharp();
	install_mono_libraries();
	setup_nant();

	# Build MonoDevelop
	apply_mono_develop_patches($root, $buildRepoRoot);
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

sub install_mono_libraries {

	if (!-d $monolibPath)
	{
		print "== Installing Mono Libraries $MONO_LIBRARIES_VERSION\n";
		system("msiexec /i $root\\monodevelop-build\\dependencies\\$MONO_LIBRARIES_INSTALLER /passive") && die("Failed to install mono libraries");
	}
	else
	{
		print "== Mono Libraries $MONO_LIBRARIES_VERSION already installed\n";
	}
}

sub install_gkt_sharp {

	my $gtkSharpDll = "$gtkPath/lib/gtk-sharp-2.0/gtk-sharp.dll";
	my $gtkSharpDllMD5 = "";


	if (-e "$gtkSharpDll")
	{
		open my $fh, '<', "$gtkSharpDll";
		$gtkSharpDllMD5 = Digest::MD5->new->addfile($fh)->hexdigest;
		close $fh;
	}

	if (!-e "$gtkSharpDll" or $gtkSharpDllMD5 ne $GTK_SHARP_DLL_MD5)
	{
		print "== Installing GTK Sharp $GTK_VERSION. The machine must be restarted for it to work properly.\n";
		system("msiexec /i $root\\monodevelop-build\\dependencies\\$GTK_INSTALLER /passive /promptrestart") && die("Failed to install GTK");
	}
	else
	{
		print "== GTK Sharp $GTK_VERSION already installed\n";
	}
}

sub setup_nant {
	$nant = "\"$buildRepoRoot/dependencies/nant-0.93-nightly-2015-02-12/bin/NAnt.exe\"";
}

sub build_monodevelop 
{
	copy "$root/monodevelop/main/theme-icons/Windows/monodevelop.ico", "$buildRepoRoot/dependencies/monodevelop-original.ico";
	copy "$buildRepoRoot/dependencies/monodevelop.ico", "$root/monodevelop/main/theme-icons/Windows/monodevelop.ico";

	system("\"$ENV{VS100COMNTOOLS}/vsvars32.bat\" && msbuild $root\\monodevelop\\main\\Main.sln  /p:ExcludeFromBuild=\"po\"/p:Configuration=DebugWin32 $incremental") && die ("Failed to compile MonoDevelop");

	copy "$buildRepoRoot/dependencies/monodevelop-original.ico", "$root/monodevelop/main/theme-icons/Windows/monodevelop.ico";
	unlink "$buildRepoRoot/dependencies/monodevelop-original.ico";
}

sub build_debugger_addin 
{
	my $addinsdir = "$root\\monodevelop\\main\\build\\Addins";
	mkpath "$addinsdir\\MMonoDevelop.Debugger.Soft.Unity";

	system("\"$ENV{VS100COMNTOOLS}/vsvars32.bat\" && msbuild $root\\MonoDevelop.Debugger.Soft.Unity\\MonoDevelop.Debugger.Soft.Unity.sln /p:OutputPath=\"$addinsdir\\MonoDevelop.Debugger.Soft.Unity\" /p:Configuration=Release $incremental") && die ("Failed to compile MonoDevelop debugger add-in");
}

sub	build_boo()
{
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";

	chdir "$root/boo";
	print "nant $nant";

	system("$nant -t:net-4.0 rebuild") && die ("Failed to build Boo");

	mkpath "$externalDir/Boo";

	system("xcopy /s /y \"$root/boo/build\" \"$externalDir/Boo\"");
	unlink glob "$externalDir/Boo/*.pdb" or die ("unlink fail");
}

sub build_boo_extensions()
{
	chdir "$root/boo-extensions";
	system("$nant -t:net-4.0 rebuild") && die ("Failed to build Boo extensions monodevelop");
}

sub build_unityscript()
{
	my $externalDir = "$root/MonoDevelop.Boo.UnityScript.Addins/external";
	
	chdir "$root/unityscript";
	rmtree "$root/unityscript/bin";

	mkpath "$externalDir/UnityScript";

	system("$nant -t:net-4.0 rebuild") && die ("Failed to build UnityScript");

	system("xcopy /s /y \"$root/unityscript/bin\" \"$externalDir/UnityScript\"");

	unlink glob "$externalDir/UnityScript/*.pdb" or die ("unlink fail");
	unlink "$externalDir/UnityScript/nunit.framework.dll" or die ("unlink fail");
}

sub build_boo_unity_addins()
{
	my $addinsdir = "$root\\monodevelop\\main\\build\\Addins";
	mkpath "$addinsdir\\MonoDevelop.Boo.UnityScript.Addins";

	system("\"$ENV{VS100COMNTOOLS}/vsvars32.bat\" && msbuild $root\\MonoDevelop.Boo.UnityScript.Addins\\MonoDevelop.Boo.UnityScript.Addins.sln /p:OutputPath=\"$addinsdir\\MonoDevelop.Boo.UnityScript.Addins\" /p:Configuration=Release $incremental") && die ("Failed to compile MonoDevelop UnityScript/Boo add-ins");
}

sub package_monodevelop 
{
	my $mdRoot = "$buildRepoRoot/buildresult/MonoDevelop";

	rmtree "$mdRoot";

	mkpath "$mdRoot/bin";
	mkpath "$mdRoot/Addins";
	mkpath "$mdRoot/data/options";
	mkpath("$mdRoot/bin/branding");
	
	copy("$buildRepoRoot/dependencies/Branding.xml", "$mdRoot/bin/branding/Branding.xml") or die("failed copying branding");

	system("xcopy /s \"$mdSource/bin\" \"$mdRoot/bin\"");
	system("xcopy /s \"$mdSource/Addins\" \"$mdRoot/Addins\"");
	system("xcopy /s \"$mdSource/data\" \"$mdRoot/data\"");

	mkpath "$mdRoot/lib";
	mkpath "$mdRoot/etc";
	mkpath "$mdRoot/share";
	system("xcopy /s /y \"$gtkPath/bin\" \"$mdRoot/bin\"");
	system("xcopy /s /y \"$gtkPath/lib\" \"$mdRoot/lib\"");
	system("xcopy /s /y \"$gtkPath/etc\" \"$mdRoot/etc\"");
	system("xcopy /s /y \"$gtkPath/share\" \"$mdRoot/share\"");
	system("xcopy /s /y \"$gtkPath/lib/Mono.Posix\" \"$mdRoot/bin\"");
	system("xcopy /s /y \"$gtkPath/lib/gtk-sharp-2.0\" \"$mdRoot/bin\"");
	system("xcopy /s /y \"$gtkPath/lib/Mono.Cairo\" \"$mdRoot/bin\"");
	# TODO: An installer should execute "gdk-pixbuf-query-loaders.exe > ../etc/gtk-2.0/gdk-pixbuf.loaders" after installing files to get a proper loader file
	copy "$root/monodevelop/dependencies/gdk-pixbuf.loaders", "$mdRoot/etc/gtk-2.0";
	copy "$root/monodevelop/dependencies/monodoc.dll", "$mdRoot/bin";

	# Mono Libraries dependency files

	my $monoLib;
	foreach $monoLib (('ICSharpCode.SharpZipLib.dll', 'Mono.GetOptions.dll', 'Mono.Security.dll'))
	{
		copy "$monolibPath/$monoLib", "$mdRoot/bin";
	}

	chdir "$buildRepoRoot/buildResult";
	unlink "$buildRepoRoot/buildResult/MonoDevelop.zip";
	system("$SevenZip a -r \"$buildRepoRoot/buildResult/MonoDevelop.zip\" *.*");
}