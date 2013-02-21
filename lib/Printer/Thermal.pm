package Printer::Thermal;

use 5.010;
use Moose;
use POSIX;

use Device::SerialPort;
use IO::File;
use IO::Socket;
use Parse::BBCode;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 NAME

Printer::Thermal - Interface for Thermal (and some dot-matrix and inkjet) Printers that support ESC/POS specification. Which as it happens, includes most receipt/kitchen printers in market.

=head1 SYNOPSIS

  use Printer::Thermal;

  #For Network Printers $port is 9100 in most cases but might differ depending on how you have configured your printer
  $printer = Printer::Thermal->new(device_ip=>$printer_ip,device_port=>$port);

  #These commands won't actually send anything to the printer but it will store all the merged data including control codes to send to printer in $printer->print_string variable.
  $printer->write("Blah Blah \nReceipt Details\nFooter");
  $printer->bold_on();
  $printer->write("Bold Text");
  $printer->bold_off();
  $printer->print(); ##Sends the above set of code to the printer. Clears the buffer text in module.
  
  #For local printer connected on serial port, check syslog(Usually under /var/log/syslog) for what device file was created for your printer when you connect it to your system(For plug and play printers).
  my $path = '/dev/ttyACM0';
  $printer2 = Printer::Thermal->new(serial_device_path=$path);
  $printer->write("Blah Blah \nReceipt Details\nFooter");
  $printer->bold_on();
  $printer->write("Bold Text");
  $printer->bold_off();
  $printer->print();

  #For local printer connected on usb port, check syslog(Usually under /var/log/syslog) for what device file was created for your printer when you connect it to your system(For plug and play printers).
  my $path = '/dev/usb/lp0';
  $printer2 = Printer::Thermal->new(usb_device_path=$path);
  $printer->write("Blah Blah \nReceipt Details\nFooter");
  $printer->bold_on();
  $printer->write("Bold Text");
  $printer->bold_off();
  $printer->print();

=head1 DESCRIPTION

Some might not find the module name accurate since ESC/P was developed initially for dot matrix and inkjet printers, however today most Thermal Receipt Printers use these codes for control. Most people(i.e. like me when I started looking for Thermal Printer stuff) who look for Thermal Printer codes don't know Thermal Printers use certain set of ESC codes to acheive a bunch of functions, so I didnt want to name it Printer::ESC::P. This module provides an Object oriented interface for interacting with Thermal Printers. Maybe I will refactor it later with subclasses. I used Moose, I apologize!! 
For ESC/P codes refer the guide from Epson http://support.epson.ru/upload/library_file/14/esc-p.pdf

=cut

#################### main pod documentation end ###################

=head1 METHODS 

=head3 $printer->usb_device_path

This variable contains the path for the printer device file when connected as a usb device on UNIX-like systems. I haven't added support for Windows and it probably wont work in doz as a local printer without some modifications. Feel free to try it out and let me know what happens. This must be passed in the constructor

=cut

has usb_device_path => (
  is => 'ro',
  isa => 'Str',
);

=head3 $printer->serial_device_path

This variable contains the path for the printer device file when connected as a serial device on UNIX-like systems. I haven't added support for Windows and it probably wont work in doz as a local printer without some modifications. Feel free to try it out and let me know what happens. This must be passed in the constructor

=cut

has serial_device_path => (
  is => 'ro',
  isa => 'Str',
);

=head3 $printer->device_ip

Contains the IP address of the device when its a network printer. The module creates IO:Socket::INET object to connect to the printer. This can be passed in the constructor.

=cut

has device_ip => (
  is => 'ro',
  isa => 'Str',
);

=head3 $printer->device_port

Contains the network port of the device when its a network printer. The module creates IO:Socket::INET object to connect to the printer. This can be passed in the constructor.

=cut

has device_port => (
  is => 'ro',
  isa => 'Int',
);

=head3 $printer->baudrate

When used as a local serial device you can set the baudrate of the printer too. However default should usually work. let me know if it doesn't for you.

=cut

has baudrate => (
  is => 'ro',
  isa => 'Int',
  default => 38400,
);

has read_char_time => (
  is => 'ro',
  isa => 'Int',
  default => 30,
);

has read_const_time => (
  is => 'ro',
  isa => 'Int',
  default => 3000,
);

has black_threshold => (
  is => 'ro',
  isa => 'Int',
  default => 48,
);

has alpha_threshold => (
  is => 'ro',
  isa => 'Int',
  default => 127,
);

has heatTime => (
  is  => 'ro',
  isa => 'Int',
  default => 120,
);

has heatInterval => (
  is  => 'ro',
  isa => 'Int',
  default => 50,
);

has heatingDots => (
  is  => 'ro',
  isa => 'Int',
  default => 7,
);

has printer => (
  is         => 'ro',
  #isa     => 'IO::Handle',
  lazy_build => 1,
);

has print_string => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);

has font => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has underline => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has emphasized => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has double_height => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

has double_width => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);


my $_ESC = chr(27);
my $_GS  = chr(29);

sub _build_printer {
  my ($self) = @_;
  my $printer;
  if( $self->serial_device_path ) {
    $printer = Device::SerialPort->new( $self->serial_device_path );
    $printer->baudrate( $self->baudrate );
  } elsif( $self->usb_device_path ) {
    $printer = new IO::File ">>" . $self->usb_device_path ;
  } else {
    $printer = IO::Socket::INET->new(
      Proto     => "tcp",
      PeerAddr  => $self->device_ip,
      PeerPort  => $self->device_port,
      Timeout   => 1,
    ) or die " Can't connect to printer";
  }
  $printer->write($_ESC);
  $printer->write(chr(64)); # @ initialize
  $printer->write($_ESC);
  $printer->write(chr(55)); # 7 - print settings
  $printer->write( chr( $self->heatingDots ) ); # Heating dots (20=balance of darkness vs no jams) default = 20

  # Description of print density from page 23 of the manual:
  # DC2 # n Set printing density
  # Decimal: 18 35 n
  # D4..D0 of n is used to set the printing density. Density is 50% + 5% * n(D4-D0) printing density.
  # D7..D5 of n is used to set the printing break time. Break time is n(D7-D5)*250us.
  my $printDensity = 15; # 120% (? can go higher, text is darker but fuzzy)
  my $printBreakTime = 15; # 500 uS
  $printer->write($_GS);
  $printer->write(chr(40));
  $printer->write(chr(78));
  return $printer;
}

=head2 $printer->print();

Sends the accumulated commands to the printer. All commands below need to be followed by a print() to send the data from buffer to the printer. You may call more than one printer command and then call print to send them all to printer together.
The following bunch of commands print a text to a printer, move down one line, and cut the receipt paper.
  $printer->write("hello Printer\n");
  $printer->linefeed();
  $printer->cutpaper();
  $pritner->print(); # Sends the all the commands before this to the printer in one go. 

=cut

sub print {
  my ($self,$string) = @_;
  my $printer = $self->printer;
  print "\nPrinting : " . $self->print_string . "\n";
  $printer->write( $self->print_string );
  $self->print_string("");
}

=head2 $printer->write("some text\n");

Writes a bunch of text that you pass here to the module buffer. 
Note that this will not be passed to the printer till you call $printer->print()

=cut

sub write {
  my ($self,$string) = @_;
  $self->print_string($self->print_string . $string);
}

=head2 $printer->left_margin($nl,$nh);

Sets the left margin code to the printer. takes two single byte parameters, $nl and $nh.
To determine the value of these two bytes, use the INT and MOD conventions. INT indicates the integer (or whole number) part of a number, while MOD indicates the
remainder of a division operation.
For example, to break the value 520 into two bytes, use the following two equations:
nH = INT 520/256
nL = MOD 520/256

=cut

sub left_margin {
  my ($self,$nl,$nh) = @_;
  $self->linefeed();
  $self->write($_GS);
  $self->write(chr(76));
  $self->write(chr($nl));
  $self->write(chr($nh));
}

=head2 $printer->reset()

Resets the printer 

=cut

sub reset {
  my ($self) = @_;
  my $printer = $self->printer;
  $printer->write($_ESC);
  $printer->write(chr(64));
}

=head2 $printer->right_side_charachter_spacing($spacing)

Takes a one byte number, spacing as a parameter

=cut

sub right_side_charachter_spacing {
  my ($self,$spacing) = @_;
  if($spacing <= 255 && $spacing >=0){
    $self->write($_ESC);
    $self->write(chr(32));
    $self->write(chr($spacing));
  }
}

=head2 $printer->horiz_tab()

=cut

sub horiz_tab{
  my ($self) = @_;
  $self->write(chr(9));
}

=head2 $printer->line_spacing($value)

=cut

sub line_spacing {
  my ($self,$value) = @_;
  if ( $value
    && ($value <= 255 && $value >=0) ){
    $self->write($_ESC);
    $self->write(chr(51));
    $self->write(chr($value));
  }else{
    #reset to default spacing
    $self->write($_ESC);
    $self->write(chr(50));
  }
}

=head2 $printer->linefeed()

=cut

sub linefeed {
  my ($self) = @_;
  $self->write(chr(10));
}

=head2 $printer->justify($alignment)

$alignment can be either 'L','C' or 'R' for left center and right justified printing

=cut

sub justify {
  my ($self,$align) = @_;
  my $pos = 0;
  if( $align eq "L" ){
    $pos = 0;
  }elsif( $align eq "C" ){
    $pos = 1;
  }elsif( $align eq "R" ){
    $pos = 2;
  }
  $self->write($_ESC);
  $self->write(chr(97));
  $self->write(chr($pos));
}

=head2 $printer->bold_off();

=cut

sub bold_off {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(69));
  $self->write(chr(0));
}

=head2 $printer->bold_on();

=cut

sub bold_on {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(69));
  $self->write(chr(1));
}

=head2 $printer->doublestrike_off();

=cut

sub doublestrike_off {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(71));
  $self->write(chr(0));
}

=head2 $printer->doublestrike_on();

=cut

sub doublestrike_on {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(71));
  $self->write(chr(1));
}

=head2 $printer->emphasize_off();

=cut

sub emphasize_off {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(69));
  $self->write(chr(0));
}

=head2 $printer->emphasize_on();

=cut

sub emphasize_on {
  my ($self) = @_;
  $self->write($_ESC);
  $self->write(chr(69));
  $self->write(chr(255));
}

=head2 $printer->font_size($n);

Defined Region
0 ≤ n ≤ 255
However, 1 ≤ vertical direction magnification ratio ≤ 8, 1 ≤ horizontal direction magnification ratio ≤ 8
Initial Value n=0
Function Specifies the character size (magnification ratio in the vertical and horizontal directions).

=cut

sub font_size {
  my ($self,$size) = @_;
  $self->write($_GS);
  $self->write(chr(33));
  $self->write(chr($size));
}

sub font_size_esc {
  my ($self,$size) = @_;
  $self->write($_ESC);
  $self->write(chr(33));
  $self->write(chr($size));
}

=head2 $printer->font_b();

=cut

sub font_b {
  my ($self) = @_;
  #$self->write($_ESC);
  #$self->write(chr(77));
  #$self->write(chr(1));
  $self->font(1);
  $self->apply_printmode();
}

=head2 $printer->font_a();

=cut

sub font_a {
  my ($self) = @_;
  #$self->write($_ESC);
  #$self->write(chr(77));
  #$self->write(chr(0));
  $self->font(0);
  $self->apply_printmode();
}

=head2 $printer->printmode($font_number, $double_height_mode, $double_width_mode);

0 or 1,

=cut

sub _printmode{
  my ($self, $font_number, $double_height_mode, $double_width_mode) = @_;
  if(
    ($font_number eq 1 || $font_number eq 0)
    && ($double_height_mode eq 1 || $double_height_mode eq 0)
    && ($double_width_mode eq 1 || $double_width_mode eq 0)
    ){
    my $value = $font_number 
      + ($double_height_mode * 16)
      + ($double_height_mode * 32);
    $self->write($_ESC);
    $self->write(chr(33));
    $self->write(chr($value));
  }
}

sub apply_printmode{
  my ($self) = @_;
  my $font = $self->font;
  my $underline = $self->underline;
  my $emphasized = $self->emphasized;
  my $double_height = $self->double_height;
  my $double_width  = $self->double_width;
  my $value = $font 
      + ($emphasized * 8)
      + ($double_height * 16)
      + ($double_width * 32)
      + ($underline * 128);
  $self->write($_ESC);
  $self->write(chr(33));
  $self->write(chr($value));
}

=head2 $printer->underline_off();

=cut

sub underline_off {
  my ($self) = @_;
  #$self->write($_ESC);
  #$self->write(chr(45));
  #$self->write(chr(0));
  $self->underline(0);
  $self->apply_printmode();
}

=head2 $printer->underline_on();

=cut

sub underline_on {
  my ($self) = @_;
  #$self->write($_ESC);
  #$self->write(chr(45));
  #$self->write(chr(1));
  $self->underline(1);
  $self->apply_printmode();
}

=head2 $printer->inverse_off();

=cut

sub inverse_off {
  my ($self) = @_;
  $self->write($_GS);
  $self->write(chr(66));
  $self->write(chr(0));
}

=head2 $printer->inverse_on();

=cut

sub inverse_on {
  my ($self) = @_;
  $self->write($_GS);
  $self->write(chr(66));
  $self->write(chr(1));
}

=head2 $printer->barcode_height($height);

=cut

sub barcode_height {
  my ($self,$height) = @_;
  $self->write($_GS);
  $self->write(chr(104));
  $self->write(chr($height));
}

=head2 $printer->print_barcode($type,$string)

=cut

sub print_barcode {
  my ($self,$type,$string) = @_;
  $self->write($_GS);
  $self->write(chr(107));
  $self->write(chr(65));
  $self->write(chr($type));
  $self->write($string);
}

=head2 $printer->print_text($msg,$chars_per_line);

Print some text defined by msg. If chars_per_line is defined, inserts newlines after the given amount. Use normal '\n' line breaks for empty lines.

=cut

sub print_text {
  my ($self, $msg, $chars_per_line) = @_;
  if ($chars_per_line){
    my $le = length($msg);
    my @substrings;
    push @substrings, substr $msg,0,$chars_per_line,'' while length $msg;
    $self->write(join "\n",@substrings);
  } else {
    $self->write($msg);
  }
}

=head2 print_markup_bbcode

Print text with markup for styling.

Keyword arguments:
markup -- text with a left column of markup as follows:
first character denotes style (n=normal, b=bold, u=underline, i=inverse, f=font B) 
second character denotes justification (l=left, c=centre, r=right)
third character must be a space, followed by the text of the line

=cut

sub print_markup_bbcode {
  my ($self, $markup) = @_;
  my $p = Parse::BBCode->new(
    {
      tags => {
        b => '[b]%{parse}s[/b]', #bold
        u => '[u]%{parse}s[/u]', #bold
        i => '[i]%{parse}s[/i]', #bold
        L => '[L]%{parse}s[/L]', #bold
        R => '[R]%{parse}s[/R]', #bold
        C => '[C]%{parse}s[/C]', #bold
      },
    }
  );
  my $tree = $p->parse($markup);
  $self->_walk_bbcode_tags($tree);
}

sub _walk_bbcode_tags {
  my ($self,$tag) = @_;
  my $tagname = $tag->get_name();

  if($tagname eq 'b'){
      $self->bold_on(); 
  }elsif($tagname eq 'u'){
      $self->underline_on(); 
  }elsif($tagname eq 'i'){
      $self->inverse_on(); 
  }elsif($tagname eq 'L'){
      $self->justify('L'); 
  }elsif($tagname eq 'R'){
      $self->justify('R'); 
  }elsif($tagname eq 'C'){
      $self->justify('C'); 
  }

  for my $content ( @{ $tag->get_content() } ){
    if( ref $content eq 'Parse::BBCode::Tag' ) {
      $self->_walk_bbcode_tags($content);
    }else{ 
      $self->write($content);
    }
  }

  if($tagname eq 'b'){
      $self->bold_off(); 
  }elsif($tagname eq 'u'){
      $self->underline_off(); 
  }elsif($tagname eq 'i'){
      $self->inverse_off(); 
  }elsif($tagname eq 'L'){
      $self->justify('L'); 
  }elsif($tagname eq 'R'){
      $self->justify('L'); 
  }elsif($tagname eq 'C'){
      $self->justify('L'); 
  }

}

sub print_bitmap {
  my ($self,$pixels,$w,$h,$output_png) = @_;
  my $counter = 0;
  if( $output_png ){
  }
  $self->linefeed();
  $self->write($_GS);
  $self->write(chr(118));
  $self->write(chr(48));
  $self->write(chr(48));
  $self->write(chr(50));
  $self->write(chr(50));
}

=head2 $printer->color_1()

Prints in first color for dual color printers

=cut

sub color_1{
  my ($self,$color) = @_;
  $self->linefeed();
  $self->write($_ESC);
  $self->write(chr(114));
  $self->write(chr(0));
}

=head2 $printer->color_2()

Prints in second color for dual color printers

=cut

sub color_2{
  my ($self,$color) = @_;
  $self->linefeed();
  $self->write($_ESC);
  $self->write(chr(114));
  $self->write(chr(1));
}

=head2 $printer->cutpaper()

Cuts the paper. Most Thermal receipt printers support the facility to cut the receipt using this command once printing is done.

=cut

sub cutpaper {
  my ($self) = @_;
  $self->linefeed();
  $self->write($_GS);
  $self->write(chr(86));
  $self->write(chr(0));
  $self->write(chr(255));
}

=head2 $printer->test()

Prints a bunch of test strings to see if your printer is working fine/connected properly. Don't worry if some things like emphasized and double strike looks the same, it happened with my printer too.

=cut

sub test {
  my ($self) = @_;
  $self->write("Write Stuff before linefeed");

  $self->left_margin(1,0);
  $self->write("Set left margin 1,0");
  $self->left_margin(20,0);
  $self->write("Set left margin 20,0");
  $self->left_margin(1,0);

  #$self->barcode_height(68);
  #$self->print_barcode();

  $self->right_side_charachter_spacing(1);
  $self->write("Rgt chr space: 1 space");
  $self->right_side_charachter_spacing(8);
  $self->write(" 8 space");
  $self->right_side_charachter_spacing(0);
  $self->linefeed();

  $self->horiz_tab();
  $self->write("Tab before this line");
  $self->linefeed();

  $self->write("Part of this line ");
  $self->bold_on();
  $self->write("is bold");
  $self->bold_off();
  $self->linefeed();

  $self->write("default ");
  $self->doublestrike_on();
  $self->write("doublestrike on ");
  $self->doublestrike_off();
  $self->write("doublestrike off");
  $self->linefeed();

  $self->write("default ");
  $self->emphasize_on();
  $self->write("emphasize on ");
  $self->emphasize_off();
  $self->write("emphasize off");
  $self->linefeed();

  $self->write("default ");
  $self->font_b();
  $self->write("font b ");
  $self->font_a();
  $self->write("font a");
  $self->linefeed();
  
  $self->write("default ");
  $self->underline_on();
  $self->write("underline on");
  $self->underline_off();
  $self->write(" underline off");
  $self->linefeed();

  $self->write("default ");
  $self->inverse_on();
  $self->write("inverse on");
  $self->inverse_off();
  $self->write(" inverse off");
  $self->linefeed();

  $self->write("This line is in default color");
  $self->color_2();
  $self->write("This line is in color 2");
  $self->color_1();
  $self->write("This line is in color 1");
  $self->linefeed();
  
  $self->print_text("Sizes");
  $self->linefeed();
  $self->font_size(0);
  $self->print_text("Size 0");
  $self->linefeed();
  $self->font_size(16);
  $self->print_text("Size 16");
  $self->linefeed();
  $self->font_size(32);
  $self->print_text("Size 32");
  $self->linefeed();
  $self->font_size(48);
  $self->print_text("Size 48");
  $self->linefeed();
  $self->font_size(64);
  $self->print_text("Size 64");
  $self->linefeed();
  $self->font_size(80);
  $self->print_text("Size 80");
  $self->linefeed();
  $self->font_size(96);
  $self->print_text("Size 96");
  $self->linefeed();
  $self->font_size(112);
  $self->print_text("Size 112");
  $self->linefeed();
  $self->font_size(200);
  $self->print_text("Max 200");
  $self->linefeed();
  $self->font_size(255);
  $self->print_text("Max 255");
  $self->linefeed();
  $self->font_size(0);
  
  $self->print_text("ESC Sizes");
  $self->linefeed();
  $self->font_size_esc(0);
  $self->print_text("Size 0");
  $self->linefeed();
  $self->font_size_esc(16);
  $self->print_text("Size 16");
  $self->linefeed();
  $self->font_size_esc(32);
  $self->print_text("Size 32");
  $self->linefeed();
  $self->font_size_esc(48);
  $self->print_text("Size 48");
  $self->linefeed();
  $self->font_size(0);
  
  $self->print_string("");
  
  $self->write("default ");
  $self->font_b();
  $self->write("font b ");
  $self->font_a();
  $self->write("font a");

  $self->write("default ");
  $self->underline_on();
  $self->write("underline on");
  $self->underline_off();
  $self->write(" underline off");
  $self->linefeed();

  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  
  $self->cutpaper();

  $self->print();
  return;
  $self->bold_on();
  $self->print_text("line is bold\n");
  $self->bold_off();
  $self->printmode(0,0,1);
  $self->print_text("Part of this ");
  $self->printmode(0,1,0);
  $self->print_text("Part of this \n");
  $self->printmode(0,0,0);
  $self->print_text("Part of this ");
  $self->printmode(1,0,0);
  $self->print_text("line is fontB\n");
  $self->printmode(0,0,0);
  $self->print_text("Part of this ");
  $self->font_b(1,0,0);
  $self->print_text("line is fontB\n");
  $self->print_text("Part of this is different font\n");
  $self->font_size(0);
  $self->print_text("Sizes\n");
  $self->font_size(16);
  $self->print_text("Sizes\n");
  $self->font_size(32);
  $self->print_text("Sizes\n");
  $self->font_size(48);
  $self->print_text("Sizes\n");
  $self->font_size(64);
  $self->print_text("Sizes\n");
  $self->font_size(80);
  $self->print_text("Sizes\n");
  $self->font_size(96);
  $self->print_text("Sizes\n");
  $self->font_size(112);
  $self->print_text("Sizes\n");
  $self->font_size(0);
  $self->font_a(0,0,0);
  $self->print_text("Part of this ");
  $self->emphasize_on();
  $self->print_text("line is Emphasized\n");
  $self->emphasize_off();
  $self->print_text("Part of this ");
  $self->doublestrike_on();
  $self->print_text("line is double striked\n");
  $self->doublestrike_off();
  $self->print_text("Part of this ");
  $self->inverse_on();
  $self->print_text("line is Inverted\n");
  $self->inverse_off();
  $self->justify("R");
  $self->print_text("right justified\n");
  $self->justify("C");
  $self->print_text("centered\n");
  $self->justify("L"); # justify("L") works too
  $self->print_text("left justified\n");
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  #$self->print_string("");
  $self->linefeed();
  $self->color_2();
  $self->print_text("Part of this\n");
  $self->color_1();
  $self->print_text("is in a different color\n");
  $self->color_2();
  $self->print_text("is in a different color\n");
  $self->linefeed();
  #$self->print_string("");
  $self->write($_ESC);
  $self->write(chr(30));
  $self->write(chr(67));
  $self->write(chr(48));
  $self->linefeed();
  $self->write($_ESC);
  $self->write(chr(52));
  $self->linefeed();
  $self->print_text("is in a different color\n");
  $self->linefeed();
  $self->write($_ESC);
  $self->write(chr(53));
  $self->linefeed();
  $self->print_text("is in a different color\n");
  $self->linefeed();
  $self->write($_ESC);
  $self->write(chr(52));
  $self->linefeed();
  $self->print_text("is in a different color\n");
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->linefeed();
  $self->cutpaper();
  $self->print();

}

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 BUGS

None at the moment

=head1 SUPPORT

shantanu att cpan dott org

=head1 HISTORY

0.01 Tue Feb 19 10:02:07 2013
    - original version; created by ExtUtils::ModuleMaker 0.51

=head1 AUTHOR

    Shantanu Bhadoria
    CPAN ID: SHANTANU
    shantanu att cpan dottt org
    www.shantanubhadoria.com

=head1 COPYRIGHT

This program is free software licensed under the...

	The General Public License (GPL)
	Version 2, June 1991

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

perl(1).

=cut
1;

