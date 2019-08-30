#!/usr/bin/perl -w

BEGIN {
  use Data::Dumper;
}

use lib "/home/gedafe/thirdparty/lib/perl5";
use lib "/home/gedafe/lib/perl";

use lib "/home/perm/perm/pearls";

use strict;
use CGI::Fast;
#use CGI::Carp qw(fatalsToBrowser);

use Gedafe::Start;

use YAML::XS 'LoadFile';
my $config = LoadFile('db_config.yaml');

$|=1; # do not buffer output

while (my $q = new CGI::Fast) {

   Start(
        $q, # fastcgi handler
        db_datasource     => "dbi:Pg:dbname=$config->{dbname};host=$config->{dbhost};port=$config->{dbport}",
        utf8              => 1,
        allow_javascript  => 1,
        admin_user        => 'perm_master',
        templates         => '/home/perm/perm/templates_all',
        documentation_url => '/home/gedafe/doc',
        gedafe_compat     => '1.1',
        list_rows         => 20,
        list_buttons      => 'top',
        pearl_dir         => '/home/perm/perm/pearls',
   );
}
