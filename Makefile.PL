

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Printer::Thermal',
    VERSION_FROM => 'lib/Printer/Thermal.pm', # finds \$VERSION
    AUTHOR       => 'Shantanu Bhadoria (shantanu att cpan dottt org)',
    ABSTRACT     => 'A High Level Interface to Thermal (and some dot-matrix) receipt/kitchen printers supporting Epson\'s ESC/POS specification',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                     'Moose'        => 2.00,
                     'Device::SerialPort' => 1.00,
                     'IO::Socket'         => 1.25,
                     'IO::File'           => 0,
                     'Parse::BBCode'      => 0,
                    },
);
