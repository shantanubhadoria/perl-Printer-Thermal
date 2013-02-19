# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Printer::Thermal' ); }

my $object = Printer::Thermal->new ();
isa_ok ($object, 'Printer::Thermal');


