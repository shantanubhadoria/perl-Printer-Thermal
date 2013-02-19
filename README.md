Printer-Thermal
===============

Printer::Thermal - Perl interface for Thermal (and some dot-matrix and inkjet) Printers that support ESC/POS specification. Which as it happens, includes most receipt/kitchen printers in market.

NAME
    Printer::Thermal - Interface for Thermal (and some dot-matrix and
    inkjet) Printers that support ESC/POS specification. Which as it
    happens, includes most receipt/kitchen printers in market.

SYNOPSIS
      use Printer::Thermal;

      #For Network Printers $port is 9100 in most cases but might differ depending on how you have configured your printer
      $printer = Printer::Thermal->new(device_ip=>$printer_ip,device_port=>$port);

      #These commands won't actually send anything to the printer but it will store all the merged data including control codes to send to printer in $printer->print_string variable.
      $printer->write("Blah Blah \nReceipt Details\nFooter");
      $printer->bold_on();
      $printer->write("Bold Text");
      $printer->bold_off();
      $printer->print(); ##Sends the above set of code to the printer. Clears the buffer text in module.
  
      #For local printer, check syslog(Usually under /var/log/syslog) for what device file was created for your printer when you connect it to your system(For plug and play printers.
      my $path = '/dev/ttyACM0';
      $printer2 = Printer::Thermal->new(device_path=$path);
      $printer->write("Blah Blah \nReceipt Details\nFooter");
      $printer->bold_on();
      $printer->write("Bold Text");
      $printer->bold_off();
      $printer->print();

DESCRIPTION
    Some might not find the module name accurate since ESC/P was developed
    initially for dot matrix and inkjet printers, however today most Thermal
    Receipt Printers use these codes for control. Most people(i.e. like me
    when I started looking for Thermal Printer stuff) who look for Thermal
    Printer codes don't know Thermal Printers use certain set of ESC codes
    to acheive a bunch of functions, so I didnt want to name it
    Printer::ESC::P. This module provides an Object oriented interface for
    interacting with Thermal Printers. Maybe I will refactor it later with
    subclasses. I used Moose, I apologize!! For ESC/P codes refer the guide
    from Epson http://support.epson.ru/upload/library_file/14/esc-p.pdf

METHODS
   $printer->device_path
    This variable contains the path for the printer device file on UNIX-like
    systems. I haven't added support for Windows and it probably wont work
    doz as a local printer without some modifications. Feel free to try it
    out and let me know what happens. This maybe passed in the constructor

   $printer->device_ip
    Contains the IP address of the device when its a network printer. The
    module creates IO:Socket::INET object to connect to the printer. This
    can be passed in the constructor.

   $printer->device_port
    Contains the network port of the device when its a network printer. The
    module creates IO:Socket::INET object to connect to the printer. This
    can be passed in the constructor.

   $printer->baudrate
    When used as a local serial device you can set the baudrate of the
    printer too. However default should usually work. let me know if it
    doesn't for you.

  $printer->print();
    Sends the accumulated commands to the printer. All commands below need
    to be followed by a print() to send the data from buffer to the printer.
    You may call more than one printer command and then call print to send
    them all to printer together. The following bunch of commands print a
    text to a printer, move down one line, and cut the receipt paper.
    $printer->write("hello Printer\n"); $printer->linefeed();
    $printer->cutpaper(); $pritner->print(); # Sends the all the commands
    before this to the printer in one go.

  $printer->write("some text\n");
    Writes a bunch of text that you pass here to the module buffer. Note
    that this will not be passed to the printer till you call
    $printer->print()

  $printer->left_margin($nl,$nh);
    Sets the left margin code to the printer. takes two single byte
    parameters, $nl and $nh. To determine the value of these two bytes, use
    the INT and MOD conventions. INT indicates the integer (or whole number)
    part of a number, while MOD indicates the remainder of a division
    operation. For example, to break the value 520 into two bytes, use the
    following two equations: nH = INT 520/256 nL = MOD 520/256

  $printer->reset()
    Resets the printer

  $printer->cutpaper()
    Cuts the paper. Most Thermal receipt printers support the facility to
    cut the receipt using this command once printing is done.

  $printer->right_side_charachter_spacing($spacing)
    Takes a one byte number, spacing as a parameter

  $printer->horiz_tab()
  $printer->line_spacing($value)
  $printer->linefeed()
  $printer->justify($alignment)
    $alignment can be either 'L','C' or 'R' for left center and right
    justified printing

  $printer->bold_off();
  $printer->bold_on();
  $printer->doublestrike_off();
  $printer->doublestrike_on();
  $printer->emphasize_off();
  $printer->emphasize_on();
  $printer->font_size($n);
    Defined Region 0 ≤ n ≤ 255 However, 1 ≤ vertical direction
    magnification ratio ≤ 8, 1 ≤ horizontal direction magnification
    ratio ≤ 8 Initial Value n=0 Function Specifies the character size
    (magnification ratio in the vertical and horizontal directions).

  $printer->font_b();
  $printer->font_a();
  $printer->printmode($font_number, $double_height_mode, $double_width_mode);
    0 or 1,

  $printer->underline_off();
  $printer->underline_on();
  $printer->inverse_off();
  $printer->inverse_on();
  $printer->barcode_height($height);
  $printer->print_barcode($type,$string)
  $printer->print_text($msg,$chars_per_line);
    Print some text defined by msg. If chars_per_line is defined, inserts
    newlines after the given amount. Use normal '\n' line breaks for empty
    lines.

  print_markup
    Print text with markup for styling.

    Keyword arguments: markup -- text with a left column of markup as
    follows: first character denotes style (n=normal, b=bold, u=underline,
    i=inverse, f=font B) second character denotes justification (l=left,
    c=centre, r=right) third character must be a space, followed by the text
    of the line

  $printer->test()
    Prints a bunch of test strings to see if your printer is working
    fine/connected properly. Don't worry if some things like emphasized and
    double strike looks the same, it happened with my printer too.

BUGS
    None at the moment

SUPPORT
    shantanu att cpan dott org

HISTORY
    0.01 Tue Feb 19 10:02:07 2013 - original version; created by
    ExtUtils::ModuleMaker 0.51

AUTHOR
        Shantanu Bhadoria
        CPAN ID: SHANTANU
        shantanu att cpan dottt org
        www.shantanubhadoria.com

COPYRIGHT
    This program is free software licensed under the...

            The General Public License (GPL)
            Version 2, June 1991

    The full text of the license can be found in the LICENSE file included
    with this module.

SEE ALSO
    perl(1).

