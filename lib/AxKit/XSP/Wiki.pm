package AxKit::XSP::Wiki;

use strict;

use Apache::AxKit::Language::XSP::TaglibHelper;
use vars qw($VERSION $NS @ISA @EXPORT_TAGLIB);

$VERSION = '0.03';

# The namespace associated with this taglib.
$NS = 'http://axkit.org/NS/xsp/wiki/1';
# Using TaglibHelper:
@ISA = qw(Apache::AxKit::Language::XSP::TaglibHelper);

@EXPORT_TAGLIB = (
    'display_page($dbpath,$db,$page,$action):as_xml=1',
);

use DBI;
use XML::SAX::Writer;
use Pod::SAX;
use XML::LibXML::SAX::Parser;
use Text::WikiFormat::SAX;

sub display_page ($$$$) {
    my ($dbpath, $dbname, $page, $action) = @_;
    
    my $db;
    $db = DBI->connect('DBI:SQLite:dbname='. $dbpath . '/wiki-' . $dbname . '.db',
		       '', '', { AutoCommit => 0, RaiseError => 1 }
		       );
    
    eval {
	$db->do('select * from Page, Formatter where 1 = 2');
    };
    if ($@) {
	create_db($db);
    }
    
    if ($action eq 'view') {
	return view_page($db, $page);
    }
    elsif ($action eq 'edit') {
	return edit_page($db, $page);
    }
    else {
	die "Unknown action: $action";
    }
}

sub view_page {
    my ($db, $page) = @_;
    my $sth = $db->prepare(<<'EOT');
  SELECT Page.content, Formatter.module
  FROM Page, Formatter
  WHERE Page.formatterid = Formatter.id
  AND   Page.name = ?
EOT
    $sth->execute($page);
    
    my $output = '';
    my $handler = XML::SAX::Writer->new(Output => \$output);
    while ( my $row = $sth->fetch ) {
	# create the parser
	my $parser = $row->[1]->new(Handler => $handler);
	eval {
	    $parser->parse_string($row->[0]);
	};
	if ($@) {
	    $output = <<EOT;
<pod>
  <para>
    Error parsing the page: $@
  </para>
</pod>
EOT
	}
	last;
    }
    if (!$output) {
	$output = <<'EOT';
<pod>
  <para>
New page
  </para>
</pod>
EOT
    }
    $output =~ s/^<\?xml\s.*?\?>//s;
    return $output;
}

sub xml_escape {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    return $text;
}

sub edit_page {
    my ($db, $page) = @_;
    my $sth = $db->prepare(<<'EOT');
  SELECT Page.content, Page.formatterid
  FROM Page
  WHERE Page.name = ?
EOT
    $sth->execute($page);
    
    my $output = '<edit><text>';
    my $formatter = 1;
    while ( my $row = $sth->fetch ) {
	# create the parser
	$output .= xml_escape($row->[0]);
	$formatter = $row->[1];
	last;
    }
    $sth->finish;
    
    $output .= '</text><texttypes>';
    
    $sth = $db->prepare(<<'EOT');
  SELECT Formatter.id, Formatter.name
  FROM Formatter
EOT
    $sth->execute();
    while (my $row = $sth->fetch) {
	$output .= '<texttype id="'. xml_escape($row->[0]) . 
	  ($formatter == $row->[0] ? '" selected="selected">' : '">') . 
	  xml_escape($row->[1]) . '</texttype>';
    }
    $sth->finish;
    
    $output .= '</texttypes></edit>';
    return $output;
}

sub save_page {
    my ($dbpath, $dbname, $page, $contents, $texttype) = @_;
    
    my $db = DBI->connect('DBI:SQLite:dbname='. $dbpath . '/wiki-' . $dbname . '.db',
		       '', '', { AutoCommit => 0, RaiseError => 1 }
		       );

    # NB fix hard coded formatterid
    my $last_modified = time;
    my $sth = $db->prepare(<<'EOT');
  INSERT OR REPLACE INTO Page ( name, formatterid, content, last_modified )
  VALUES ( ?, ?, ?, ? )
EOT
    $sth->execute($page, $texttype, $contents, $last_modified);
    $db->commit;
}

sub create_db {
    my ($db) = @_;
    
    $db->do(q{
	create table Page ( 
			   id INTEGER PRIMARY KEY,
			   name NOT NULL,
			   formatterid NOT NULL,
			   content,
			   last_modified
			   )
    });
    $db->do(q{
	create unique index Page_name on Page ( name )
    });
    $db->do(q{
	create table Formatter ( id INTEGER PRIMARY KEY, module NOT NULL, name NOT NULL)
    });
    $db->do(q{
	insert into Formatter (module, name) values ('Pod::SAX', 'pod - plain old documentation')
	insert into Formatter (module, name) values ('Text::WikiFormat::SAX', 'wiki text')
	insert into Formatter (module, name) values ('XML::LibXML::SAX::Parser', 'xml (freeform)')
    });
    $db->commit;
}

1;

__END__

=head1 NAME

AxKit::XSP::Wiki - An AxKit XSP based Wiki clone

=head1 SYNOPSIS

Follow the instructions in README for installation

=head1 DESCRIPTION

There's not much to say about Wiki's. They're kind cool, writable web sites.

This module implements a wiki that uses (at the moment) POD for it's
editing language.

At the moment there's no version control, user management, search, recent
edits, or pretty much any of the normally expected Wiki-type stuff. But it
will come, eventually.

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org

=head1 LICENSE

This is free software. You may use it and redistribute it under the same
terms as perl itself.

=cut
