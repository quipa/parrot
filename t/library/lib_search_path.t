#!perl
# Copyright (C) 2011-2012, Parrot Foundation.

use strict;
use warnings;
use lib qw(lib);

use Test::More;
use Parrot::Config;
use Parrot::Test;
plan tests => 5;

=head1 NAME

t/library/lib_search_path.t - test proper library search path precedence

=head1 SYNOPSIS

This test program verifies that Parrot searches for code in the
proper order.

.include, loadlib, load_bytecode, languages

=head1 DESCRIPTION

Check for proper libpath order.

dynext:
  if parrot is installed:

    $ENV{PARROT_DYNEXT}
    dynext/
    $prefix/parrot/$ver/dynext/
    $Config{dynext_libs}

  if not installed:

    $ENV{PARROT_DYNEXT}
    dynext/
    $build_dir/runtime/parrot/dynext
    $Config{dynext_libs}

library (similar for include):
  if parrot is installed:

    $ENV{PARROT_LIBRARY}
    $prefix/parrot/$ver/library/
    ./

  if not installed:

    $ENV{PARROT_LIBRARY}
    $build_dir/runtime/parrot/library/
    $prefix/parrot/$ver/library/
    ./

LANG does not observe $ENV{PARROT_LIBRARY}

no duplicates

. at end (not for DYNEXT)

=cut

local $ENV{PARROT_LIBRARY} = 'libenvdir';
local $ENV{PARROT_INCLUDE} = 'incenvdir';
local $ENV{PARROT_DYNEXT}  = '/dynenvdir1:/dynenvdir2';

my ($builddir, $versiondir, $libdir, $prefix) = @PConfig{qw(build_dir versiondir libdir)};
my $versionlib = $libdir . $versiondir;
my $what = 'DYNEXT';
my $code = <<"CODE";
.include 'iglobals.pasm'
.include 'libpaths.pasm'

.sub main :main
    .local pmc interp
    getinterp interp
    .local pmc lib_paths
    lib_paths = interp[.IGLOBALS_LIB_PATHS]
    .local pmc path
    path = lib_paths[.PARROT_LIB_PATH_$what]
    .local pmc p
    .local int i, size
    size = path
    i = 0
  while_1:
    p = path[i]
    say p
    i = i + 1
    if i < size goto while_1
.end
CODE

my $dynext = Parrot::Test::_pir_stdin_output_slurp('', $code);
my $dynext_libs = $PConfig{dynext_libs};
my $expected =
"dynext/
/dynenvdir1
/dynenvdir2
$builddir/runtime/parrot/dynext/
$versionlib/dynext/
";
$expected .= join("\n", split /:/, $dynext_libs)."\n" if $dynext_libs;
is ($dynext, $expected, "dynext");

my $library = $code;
$library =~ s/DYNEXT/LIBRARY/;
$library = Parrot::Test::_pir_stdin_output_slurp('', $library);
$expected =
"libenvdir
$builddir/runtime/parrot/library/
$versionlib/library/
./
";
is ($library, $expected, "library");

my $include = $code;
$include =~ s/DYNEXT/INCLUDE/;
$include = Parrot::Test::_pir_stdin_output_slurp('', $include);
$expected =
"incenvdir
$builddir/
$builddir/runtime/parrot/include/
$versionlib/include/
./
";
is ($include, $expected, "include");

my $lang = $code;
$lang =~ s/DYNEXT/LANG/;
$lang = Parrot::Test::_pir_stdin_output_slurp('', $lang);
$expected =
"$builddir/runtime/parrot/languages/
$versionlib/languages/
./
";
is ($lang, $expected, "lang");


pir_output_is( <<'CODE', <<'OUTPUT', ". at end of dynext search path" );
.sub main :main
  load_bytecode 't/pir/testlib/loadtest.pbc'
.end
CODE
loaded
OUTPUT

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
