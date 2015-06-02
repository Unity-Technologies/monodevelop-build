use File::Path;
use File::Basename qw(dirname basename fileparse);

my $documentation = <<'END_MESSAGE';

#To run Unity's MonoDevelop on mac, we want to make sure we run it against the same mono framework that upstream mono, and xamarin studio run against.
#However, we do not want to rely on that mono framework to be system installed. We choose to bundle the mono framework with our monodevelop, so we are
#sure we always run against the mono framework we tested against before we shipped. This also allows different versions of Unity to ship with different
#monodevelops, that each run against the mono framework they were tested against.
#
#Turns out that bundling mono with the monodevelop bundle is a challenge, because many parts of mono actually assume that the place it will live
#on the filesystem at runtime is known at compile time. In the upstream mono framework build system, this path is set to be
#/Library/Frameworks/Mono.framework/Versions/4.0.0  (version number will change obviously).
#
#Some of the hardcoded paths inside the mono framework live in text files. (things like mono.config, etc/gtk-2.0/gtkrc). Other hardcoded
#paths live inside some .dylibs  (like libglib-2.0.0.dylib references /Library/Frameworks/Mono.framework/Versions/4.0.0/lib/libintl.8.0.dylib) with a hardcoded
#path. At update_mono_framework.pl time, we remove these hardcoded paths from the dylibs so that dependent libraries wont be loaded from a potentially 
#installed system mono. at runtime we patch the textfiles to point to the correct place where the bundled mono framework is living at this time.
#
#Because the monodevelop bundle is part of the unity bundle, and we want users to be able to move the unity bundle anywhere on their harddrive at any point
#in time, we do this patching every time monodevelop starts. In the monodevelop build process, there is a script update_mono_framework.pl.  This script
#will take your system installed mono, strip the stuff we dont need to make it smaller, and dynamically create a patching script called relocate_mono.sh
#that is able to at runtime patch the mono install to properly work wherever it happens to live on disk at that time. the result we version in the MonoDevevelop.UnityMode-Build
#repository. If you ever want to upgrade the mono framework that we use to run monodevelop, you should install the monoframework you want on your machine, and run the
#update_mono_framework script, and commit the result.
#
#In addition to patching textfiles that have hardcoded paths in them, we also set a bunch of environment variables used by mono and monodevelop to
#point to where the mono framework currently lives so that things like libglib etc can be found. As if this was not brainnumbing enough, there is a tricky
#cornercase with a library called pango. monodevelop uses pango to do text rendering. pango ships with the mono framework. pango has several sub-dynamic
#libraries that add support for different charactersets. it also has a pango.modules file that describe which of these libraries exist, and where they are on disk
#these paths are also hardcoded. pango looks for this pango.modules file also in a hardcoded location. pango is unable to load such libraries
#if they exist in a path with a space. obviously we need to support the unity bundle living on disk in a folder with a space. to untangle all of this,
#we do:
#
#relocate_mono.sh will create a symlink at runtime in the temp directory (which we assume will have no space in the path), to the mono framework.
#in update_mono_framework.pl we add a pango.rc configuration file to the mono framework. this file points to the modules file.
#the pango.modules gets rewritten by relocate_mono.sh to point to the module files through the tempdir symlink, so that that eventual path has no
#space, which causes pango to succeed at actually load these libraries. 

END_MESSAGE

my $scriptDir = File::Spec->rel2abs( dirname($0) );

my $mf = "$scriptDir/template.app/Contents/Frameworks/Mono.framework";

rmtree($mf);

my $current = "$mf/Versions/Current";
system("mkdir -p $current");

die "Cannot find monoframework to copy" if (not -d "/Library/Frameworks/Mono.framework");

system("cp -r /Library/Frameworks/Mono.framework/Versions/4.0.0/* $current");
#rmtree("$current/lib/mono/gac");
#rmtree("$current/lib/mono/xbuild-frameworks");
rmtree("$current/lib/mono/monodroid");
rmtree("$current/lib/mono/monotouch");
rmtree("$current/lib/ironruby");
rmtree("$current/lib/ironpython");
rmtree("$current/lib/mono/boo");
rmtree("$current/lib/mono/Reference Assemblies");
#rmtree("$current/lib/monodoc");
rmtree("$current/include");
#rmtree("$current/share/xml");
rmtree("$current/share/autoconf");
rmtree("$current/share/automake-1.13");
rmtree("$current/share/libtool");
rmtree("$current/share/man");
#rmtree("$current/etc/xml");
#rmtree("$current/lib/mono/xbuild");
rmtree("$current/lib/mono/Microsoft SDKs");
rmtree("$current/lib/mono/Microsoft F#");

#system("rm $current/lib/*.a");
#system("rm -r $current/lib/*.dSYM");
#system("rm -r $current/lib/*llvm.dylib");
#system("rm -r $current/lib/*llvm.0.dylib");
#system("rm -r $current/bin/*.dSYM");
system("rm -r $current/lib/mono/4.5/FSharp.*");
system("rm -r $current/lib/mono/4.0/FSharp.*");
system("rm -r $current/lib/mono/portable-*");
#system("rm -r $current/lib/libLTO.dylib");
#system("find $current/bin ! -name mono -type f -delete");

mkpath("$current/etc/pango");
my $filename = "$current/etc/pango/pangorc";
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
print $fh "[Pango]\n";
print $fh "ModuleFiles = /Library/Frameworks/Mono.framework/Versions/4.0.0/etc/pango/pango.modules\n";
close $fh;

chdir($current);
my @array = `grep -RIl /Library/Frameworks/Mono *`;

my $relocatescript = <<"END_MESSAGE";
#!/bin/sh

# !!!!!!!!!!This is an autogenerated file, generated by update_mono_framework.pl !!!!!!!!!!!!!!!!!!!!
$documentation
END_MESSAGE

$relocatescript .= <<'END_MESSAGE';

MONO_FRAMEWORK_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$MONO_FRAMEWORK_PATH"

export DYLD_FALLBACK_LIBRARY_PATH=$MONO_FRAMEWORK_PATH/lib:/lib:/usr/lib
export MONO_GAC_PREFIX=$MONO_FRAMEWORK_PATH
export MONO_PATH=$MONO_FRAMEWORK_PATH/lib/mono:$MONO_FRAMEWORK_PATH/lib/gtk-sharp-2.0
export MONO_CONFIG=$MONO_FRAMEWORK_PATH/etc/mono/config
export MONO_CFG_DIR=$MONO_FRAMEWORK_PATH/etc
export XDG_DATA_HOME=$MONO_FRAMEWORK_PATH/share
export GDK_PIXBUF_MODULE_FILE=$MONO_FRAMEWORK_PATH/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
export GDK_PIXBUF_MODULEDIR=$MONO_FRAMEWORK_PATH/lib/gtk-2.0/2.10.0/loaders
export GTK_DATA_PREFIX=$MONO_FRAMEWORK_PATH
export GTK_EXE_PREFIX=$MONO_FRAMEWORK_PATH
export GTK_PATH=$MONO_FRAMEWORK_PATH/lib/gtk-2.0:$MONO_FRAMEWORK_PATH/lib/gtk-2.0/2.10.0
export GTK2_RC_FILES=$MONO_FRAMEWORK_PATH/etc/gtk-2.0/gtkrc
export PKG_CONFIG_PATH="$MONO_FRAMEWORK_PATH/lib/pkgconfig:$MONO_FRAMEWORK_PATH/share/pkgconfig:$PKG_CONFIG_PATH"
export PANGO_RC_FILE=$TMPDIR/unity-monodevelop-monoframework/etc/pango/pangorc
END_MESSAGE

foreach $line (@array)
{
	chomp($line);
	system("cp $line $line.in");

	next if ($line =~ /pango.modules$/);
	$relocatescript .= "sed \"s,/Library/Frameworks/Mono.framework/Versions/4.0.0,\$MONO_FRAMEWORK_PATH,g\" \"$line.in\" > \"$line\"\n";
}

$relocatescript .= <<END_MESSAGE;
sed "s,/Library/Frameworks/Mono.framework/Versions/4.0.0,\${TMPDIR}/unity-monodevelop-monoframework,g" "etc/pango/pango.modules.in" > "etc/pango/pango.modules"

MONOFRAMEWORK_SYMLINK=\${TMPDIR}/unity-monodevelop-monoframework

if [ -d "\$MONOFRAMEWORK_SYMLINK" ]; then
  rm "\$MONOFRAMEWORK_SYMLINK"
fi
ln -sf "\$MONO_FRAMEWORK_PATH" "\$MONOFRAMEWORK_SYMLINK"
END_MESSAGE

my $filename = "$current/relocate_mono.sh";
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
print $fh $relocatescript;
close $fh;


#now we will replace all embedded hardcoded paths inside the dylibs with versions without any path, so that OSX's dlopen() will use the normal DYLD_FALLBACK_LIBRARY_PATH that
#we setup, and that all dependent libraries cannot be accidentally be loaded from a system installed mono.
my $libpath = "$current/lib";
my @dylibs = <$libpath/*.dylib>;
foreach $dylib (@dylibs)
{
	print "Analyzing dependencies of dylib: $dylib\n";
	my @array = `otool -L $dylib`;
	foreach $line (@array)
	{
		chomp $line;
		my $prefix = "\t\/Library\/Frameworks\/Mono\.framework\/Versions\/3\.6\.0\/lib\/";
		while($line =~ /$prefix(.*)\.dylib/g) {
			my $regexmatch = $1;
			my $command = "install_name_tool -change $prefix$regexmatch.dylib $regexmatch.dylib $dylib";
			print "About to patch reference $regexmatch with command: $command\n";
			system($command) && die("failed invoking install_name_tool");
		}
	}
}

#print $relocatescript;