#!/usr/bin/perl
use warnings;
use strict;
use File::Basename qw(dirname basename fileparse);
use File::Spec;
use File::Copy;
use File::Path;
use Digest::MD5;

my $GTK_VERSION = "2.12";
my $GTK_INSTALLER = "gtk-sharp-2.12.25.msi";
my $GTK_SHARP_DLL_MD5 = "813407a0961a7848257874102f4d33ff";

my $SevenZip = '"C:\Program Files (x86)\7-Zip\7z"';
my $gtkPath = "$ENV{ProgramFiles}/GtkSharp/$GTK_VERSION";

my $buildRepoRoot = File::Spec->rel2abs( dirname($0) );
my $root = File::Spec->rel2abs( File::Spec->updir() );

my $mdSource = "$root/monodevelop/main/build";

my $nant = "";
my $incremental = "/t:Rebuild";

main();

sub main {
	prepare_sources();
	install_gkt_sharp();
	setup_nant();
	build_monodevelop();
#	remove_unwanted_addins();

	# Build Unity Add-ins
#	build_debugger_addin();
#	build_boo();
#	build_boo_extensions();
#	build_unityscript();
#	build_boo_unity_addins();

#	package_monodevelop();
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

sub install_gkt_sharp {

	my $gtkSharpDll = "$gtkPath/lib/gtk-sharp-2.0/gtk-sharp.dll";
	my $gtkSharpDllMD5 = "";


	if (-e "$gtkSharpDll")
	{
		open my $fh, '<', "$gtkSharpDll";
		$gtkSharpDllMD5 = Digest::MD5->new->addfile($fh)->hexdigest;
		close $fh;
	}

	print "MD5 hash $gtkSharpDllMD5";

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
	system("$SevenZip x -y -o\"$buildRepoRoot/dependencies\" \"$buildRepoRoot/dependencies/nant-0.91-nightly-2011-05-08.zip\"");
	$nant = "\"$buildRepoRoot/dependencies/nant-0.91-nightly-2011-05-08/bin/NAnt.exe\"";
}

sub build_monodevelop {
	my $mdRoot = "$root/tmp/MonoDevelop";

	system("\"$ENV{VS100COMNTOOLS}/vsvars32.bat\" && msbuild $root\\monodevelop\\main\\Main.sln /p:Configuration=DebugWin32 $incremental") && die ("Failed to compile MonoDevelop");
	system("\"$ENV{VS100COMNTOOLS}/vsvars32.bat\" && msbuild $root\\MonoDevelop.Debugger.Soft.Unity\\MonoDevelop.Debugger.Soft.Unity.sln /p:Configuration=Release $incremental") && die ("Failed to compile MonoDevelop");


	mkpath "$mdRoot/bin";
	mkpath "$mdRoot/Addins";
	mkpath "$mdRoot/data/options";
	mkpath("$mdRoot/bin/branding");
	
	copy("$buildRepoRoot/Branding.xml", "$mdRoot/bin/branding/Branding.xml") or die("failed copying branding");

	system("xcopy /s \"$mdSource/bin\" \"$mdRoot/bin\"");
	system("xcopy /s \"$mdSource/Addins\" \"$mdRoot/Addins\"");
	system("xcopy /s \"$mdSource/data\" \"$mdRoot/data\"");
}