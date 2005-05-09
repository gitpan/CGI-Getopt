package CGI::Getopt;

# Perl standard modules
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use CGI;
use Getopt::Std;
use Debug::EchoMessage;

our $VERSION = 0.12;
warningsToBrowser(1);

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw(get_inputs read_init_file);
our %EXPORT_TAGS = (
    all  => [@EXPORT_OK]
);

=head1 NAME

CGI::Getopt - Configuration initializer 

=head1 SYNOPSIS

  use CGI::Getopt;

  my $cg = CGI::Getopt->new('ifn', 'my_init.cfg', 'opt', 'vhS:a:');
  my $ar = $cg->get_inputs; 

=head1 DESCRIPTION

This program enables CGI and command line inputs. It uses CGI and 
Getopt::Std modules. 

=cut

=head3 new (ifn => 'file.cfg', opt => 'hvS:')

Input variables:

  $ifn  - input/initial file name. 
  $opt  - options for Getopt::Std

Variables used or routines called:

  None

How to use:

   my $cg = new CGI::Getopt;      # or
   my $cg = CGI::Getopt->new;     # or
   my $cg = CGI::Getopt->new(ifn=>'file.cfg',opt=>'hvS:'); # or
   my $cg = CGI::Getopt->new('ifn', 'file.cfg','opt','hvS:'); 

Return: new empty or initialized CGI::Getopt object.

This method constructs a Perl object and capture any parameters if
specified. It creates and defaults the following variables:
 
  $self->{ifn} = ""
  $self->{opt} = 'hvS:'; 

=cut

sub new {
    my $caller        = shift;
    my $caller_is_obj = ref($caller);
    my $class         = $caller_is_obj || $caller;
    my $self          = bless {}, $class;
    my %arg           = @_;   # convert rest of inputs into hash array
    foreach my $k ( keys %arg ) {
        if ($caller_is_obj) {
            $self->{$k} = $caller->{$k};
        } else {
            $self->{$k} = $arg{$k};
        }
    }
    $self->{ifn} = ""     if ! exists $arg{ifn};
    $self->{opt} = 'hvS:' if ! exists $arg{opt};
    return $self;
}

=head3 get_inputs($ifn, $opt)

Input variables:

  $ifn  - input/initial file name. 
  $opt  - options for Getopt::Std, for instance 'vhS:a:'

Variables used or routines called:

  None

How to use:

  my $ar = $self->get_inputs('/tmp/my_init.cfg','vhS:');

Return: ($q, $ar) where $q is the CGI object and 
$ar is a hash array reference containing parameters from web form,
or command line and/or configuration file if specified.

This method performs the following tasks:

  1) create a CGI object
  2) get input from CGI web form or command line 
  3) read initial file if provided
  4) merge the two inputs into one hash array

This method uses the following rules: 

  1) All parameters in the initial file can not be changed through
     command line or web form;
  2) The "-S" option in command line can be used to set non-single
     char parameters in the format of 
     -S k1=value1:k2=value2
  3) Single char parameters are included only if they are listed
     in $opt input variable.

Some parameters are dfined automatically:

  script_name - $ENV{SCRIPT_NAME} 
  url_dn      - $ENV{HTTP_HOST}
  home_url    - http://$ENV{HTTP_HOST}
  HomeLoc     - http://$ENV{HTTP_HOST}/
  version     - $VERSION
  action      - https://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}
  encoding    - application/x-www-form-urlencoded
  method      - POST

=cut

sub get_inputs {
    my $s = shift;
    my ($ifn, $par) = @_;

    $ifn = $s->{ifn} if !$ifn;
    $par = $s->{opt} if !$par;
    $s->echoMSG("IFN=$ifn\nOPT=$par",3);
    $s->echoMSG("ARGV: @ARGV",3);

    # return () if (!$ENV{'QUERY_STRING'} && !$ENV{'DOCUMENT_URI'} &&
    #      !$ENV{'REMOTE_ADDR'}  && !@ARGV);

    my %opt = ();           # optional inputs
    my %cfg = ();           # configuration parameters
    my $ds = '/';           # dir separator
    my $q = new CGI;        # create CGI object
    my $script_name = "";
       $script_name = $ENV{SCRIPT_NAME} if exists $ENV{SCRIPT_NAME};
    $opt{script_name} = $script_name;
    if (exists $ENV{HTTP_HOST}) {
        $opt{url_dn} = $ENV{HTTP_HOST};
        if (exists $ENV{HTTPS} && $ENV{HTTPS} =~ /^on/i) { 
            $opt{action} = "https://$opt{url_dn}$ENV{SCRIPT_NAME}";
        } else {
            $opt{action} = "http://$opt{url_dn}$ENV{SCRIPT_NAME}";
        }
    } else {
        $opt{url_dn} = ""; 
        $opt{action} = "command line";
    }
    $opt{encoding}  = 'application/x-www-form-urlencoded';
    $opt{method}    = 'POST';
    if (!$ENV{'QUERY_STRING'} || @ARGV) {
        $s->echoMSG("Got ARGV...", 3);
        # since $s->{opt} was set in new, then we have $par
        getopts("$par", \%opt);
        # $s->disp_param(\%opt); 
    } else {
        $s->echoMSG("Got QUERY_STRING...", 3);
        # corresponding to ARGV
        my $p1 = $par;  $p1 =~ s/://g;   # remove ':"
        foreach my $k (split //, $p1) { 
            $opt{$k} = $q->param($k);    # get inputs 
        }
    }
    my @names = ();
    if (exists $ENV{QUERY_STRING} && $ENV{QUERY_STRING}) {
        @names = $q->param;
    }
    if (exists $opt{S} && $opt{S}) {
        foreach my $r (split /\:/, $opt{S}) { 
            my ($k, $v) = (split /=/, $r);
            $opt{$k} = $v if ! exists $opt{$k};
        }
    }
    foreach my $k (@names) { 
        $opt{$k} = $q->param($k) if ! exists $opt{$k}; 
    }
    # check input variables
    $opt{v}  = 'n' if ! exists $opt{v} || !defined($opt{v}); 
    $opt{v}  = ($opt{v} && $opt{v} =~ /^y/i)?1:$opt{v};
    $opt{v}  = ($opt{v} =~ /\d+/)?$opt{v}:0;
    
    %cfg = ($ifn && -f $ifn)?$s->read_init_file($ifn):();
    $cfg{version} = "CGI::Getopt $VERSION";
    
    if (exists $ENV{HTTP_HOST}) {
        $cfg{home_url} = "http://$ENV{HTTP_HOST}"  if !$cfg{home_url}; 
        $cfg{HomeLoc}  = "http://$ENV{HTTP_HOST}/" if !$cfg{HomeLoc}; 
    } else {
        $cfg{home_url} = ""   ; # home URL
        $cfg{HomeLoc}  = "/"  ; # ASP var
    }
    foreach my $k (keys %opt) { 
        $cfg{$k} = $opt{$k} if ! exists $cfg{$k}; 
    }
    return ($q, \%cfg);
}

=head3  read_init_file($fn)

Input variables:

  $fn - full path to a file name

Variables used or routines called:

  None 

How to use:

  my $ar = $self->read_init_file('crop.cfg');

Return: a hash array ref 

This method reads a configuraton file containing parameters in the 
format of key=values. Multiple lines is allowed for values as long
as the lines after the "key=" line are indented as least with two 
blanks. For instance:

  width = 80
  desc  = This is a long
          description about the value

This will create a hash array of 

  ${$ar}{width} = 80
  ${$ar}{desc}  = "This is a long description about the value"

=cut

sub read_init_file {
    my $s = shift;
    my ($fn) = @_;
    if (!$fn)    { carp "    No file name is specified."; return; }
    if (!-f $fn) { carp "    File - $fn does not exist!"; return; }
    
    my ($k, $v, %h);
    open FILE, "< $fn" or
        croak "ERR: could not read to file - $fn: $!\n";
    while (<FILE>) {
        # skip comment and empty lines
        next if $_ =~ /^#/ || $_ =~ /^\s*$/; 
        chomp;               # remove line break
        if ($_ =~ /\s*(\w+)\s*=\s*(.+)/) {
            $k = $1; $v = $2;  $v =~ s/\s*#.*$//;
            $h{$k} = $v;
        } else {
            $v = $_; $v =~ s/^\s+//; $v =~ s/\s+$//; $v =~ s/\s*#.*$//;
            $h{$k} .= " $v";
        }
    }
    close FILE;
    return %h;
}

1;

=head1 HISTORY

=over 4

=item * Version 0.1

This version is to test the concept and routines.

=item * Version 0.11

04/29/2005 (htu) - fixed a few minor things such as module title. 

=item * Version 0.12

Make sure Debug::EchoMessage installed as pre-required.

=cut

=head1 SEE ALSO (some of docs that I check often)

Data::Describe, Oracle::Loader, CGI::Getopt, File::Xcopy,
perltoot(1), perlobj(1), perlbot(1), perlsub(1), perldata(1),
perlsub(1), perlmod(1), perlmodlib(1), perlref(1), perlreftut(1).

=head1 AUTHOR

Copyright (c) 2005 Hanming Tu.  All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty.  It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=cut


