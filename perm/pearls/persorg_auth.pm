package persorg_auth;

use strict;
use Gedafe::Pearl qw(format_desc date_print);
use POSIX qw(strftime);
use vars qw(@ISA);
@ISA = qw(Gedafe::Pearl);

use DBIx::PearlReports;

# something about me
sub info($){
    # my $self = shift;
    return "P Funktionsinhaber - Berechtigungen",
           "Alle vergebenen und aktiven Berechtigungen fuer einen Benutzer";
}

# what information do I need to go into action
sub template ($){
    # my $self = shift;
    # return a list of lists with the following elements
    #         name      desc                        widget
    return [
            [ 'fid',    'Funktionsinhaber',           'idcombo(combo=persorg_combo,ref=persorg)', '','\d+'  ],
#            [ 'start',  'Start Datum',                'text',                      '1900-01-01', '\d+-\d+-\d+' ],
#            [ 'end',    'End Datum',                  'text',                      '2100-12-31', '\d+-\d+-\d+' ],          
            [ 'desc',   'Beschreibung Berechtigung',  'checkbox',                  '',           '.*'          ],
            [ 'wrap',   'Zeilenumbruch Beschreibung', 'checkbox',                  '',           '.*'          ],
           ];
}

sub run ($$){
    my $self = shift;
    my $s    = shift;
    my $sort ='';
    $self->SUPER::run($s);
    # run the parent ( this will set the params)

    my $persord = "";
    my $p = $self->{param};
    my $rep = DBIx::PearlReports::new
      (
       -handle => $s->{dbh},
       -query => <<SQL,

    SELECT  auth_id,
            org_hid         AS org,
            pers_hid        AS pers,
            category_hid    AS category,
            subcategory_hid AS subcategory,
            element_name    AS element,
            auth_desc,
            auth_start,
            auth_end
    FROM persorg
         LEFT JOIN org         ON (persorg_org    = org_id)
         LEFT JOIN pers        ON (persorg_pers   = pers_id)
         LEFT JOIN auth        ON (persorg_id     = auth_id)
         LEFT JOIN element     ON (auth_element   = element_id)
         LEFT JOIN subcategory ON (element_subcategory  = subcategory_id)
         LEFT JOIN category    ON (subcategory_category = category_id)
    WHERE auth_id IS NOT NULL
      AND persorg_id = ?
--      AND auth_start >= ?
--      AND auth_end   <= ?
  ORDER BY org_hid, element_name;
SQL

      -param => [$p->{fid}]

    );

    my $report_width = 140;

    $rep->group(  # title
        -trigger => sub { 1 },
        -head    => sub {
                        my $now  = strftime "%d.%m.%Y - %H:%M", localtime();
                        my $out  = "Alle Berechtigungen fuer Funktionsinhaber";
                           $out .= "vom $p->{start} bis $p->{end}\n";
                           $out .= '='x50 . "\n";                           
                           $out .= "(Auflistung erstellt am: $now)\n\n";
                    },
    );

    $rep->group(  #  legend
        -trigger => sub { 1 },
        -head    => sub {
            my $out;
            $out .= sprintf " %6s",    'Ber-ID';
            $out .= sprintf " %-10s",  'Start';
            $out .= sprintf " %-12s",  'Organisation';
            $out .= sprintf " %-12s",  'Mitarbeiter';
            $out .= sprintf " %-10s",  'Kategorie';
            $out .= sprintf " %-15s",  'Subkategorie';
            $out .= sprintf " %-20s",  'Element';
            $out .=  "\n" . ('-' x $report_width)."\n";
        },
    );


    $rep->body( # content
         -contents => sub {
            my $out;
            $out .= sprintf " %-6s",   $field{auth_id};
            $out .= sprintf " %-10s",  $field{auth_start};
            $out .= sprintf " %-12s",  $field{org};
            $out .= sprintf " %-12s",  $field{pers};
            $out .= sprintf " %-10s",  $field{category};
            $out .= sprintf " %-15s",  $field{subcategory};
            $out .= sprintf " %-20s",  $field{element};
            $out .= "\n";

            if ($p->{desc}){
                my $descout = '        ';
                # description field
                my $desc = "[".$field{auth_desc}."]";
                $desc =~ s/^\s+//;
                my $desc_width = $report_width-16-length($descout);
                $desc = $p->{wrap}
                    ? format_desc($desc, length($descout), $desc_width)
                    : substr $desc, 0, $desc_width;
                $descout .= $desc."\n";
                $out .= $descout;
            }
            return $out;
        },
    );
    return 'text/plain',
        join '', (map { defined $_ ? $_ : '' } $rep->makereport);
}

1;

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:

# vim: et sw=4
