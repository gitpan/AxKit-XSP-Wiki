package AxKit::XSP::Wiki;

use strict;

use Apache::AxKit::Language::XSP::TaglibHelper;
use vars qw($VERSION $NS @ISA @EXPORT_TAGLIB);

$VERSION = '0.06';

# The namespace associated with this taglib.
$NS = 'http://axkit.org/NS/xsp/wiki/1';
# Using TaglibHelper:
@ISA = qw(Apache::AxKit::Language::XSP::TaglibHelper);

@EXPORT_TAGLIB = (
    'display_page($dbpath,$db,$page,$action;$id):as_xml=1',
    'preview_page($dbpath,$db,$page,$text,$texttype):as_xml=1',
);

use DBI;
use XML::SAX::Writer;
use Pod::SAX;
use XML::LibXML::SAX::Parser;
use Text::WikiFormat::SAX;

sub _mkdb {
    my ($dbpath, $dbname) = @_;
    my $db = DBI->connect(
        'DBI:SQLite:dbname='. $dbpath . '/wiki-' . $dbname . '.db',
        '', '', { AutoCommit => 1, RaiseError => 1 }
    );
    
    eval {
	$db->do('select * from Page, Formatter, History where 1 = 2');
    };
    if ($@) {
	create_db($db);
    }
    
    return $db;
}

sub display_page ($$$$$) {
    my ($dbpath, $dbname, $page, $action, $id) = @_;
    
    my $db = _mkdb($dbpath, $dbname);
    
    if ($action eq 'edit') {
	return edit_page($db, $page);
    }
    elsif ($action eq 'history') {
	return show_history($db, $page);
    }
    elsif ($action eq 'historypage') {
	return show_history_page($db, $page, $id);
    }
    if ($action eq 'view') {
	return view_page($db, $page);
    }
    else {
        warn("Unrecognised action. Falling back to 'view'");
        return view_page($db, $page);
    }
}

sub preview_page ($$$$$) {
    my ($dbpath, $dbname, $page, $text, $texttype) = @_;
    my $db = _mkdb($dbpath, $dbname);
    my $sth = $db->prepare(<<'EOT');
  SELECT Formatter.module
  FROM Formatter
  WHERE Formatter.id = ?
EOT
    $sth->execute($texttype);
    
    my $output = '';
    my $handler = XML::SAX::Writer->new(Output => \$output);
    while ( my $row = $sth->fetch ) {
        # create the parser
        my $parser = $row->[0]->new(Handler => $handler);
        eval {
            $parser->parse_string($text);
        };
        if ($@) {
            $output = '<pod>
  <para>
    Error parsing the page: ' . xml_escape($@) . '
  </para>
</pod>
  ';
        }
        last;
    }
    if (!$output) {
        $output = <<'EOT';
<pod>
  <para>
Eek.
  </para>
</pod>
EOT
    }

    $output =~ s/^<\?xml\s.*?\?>//s;

    # Now add edit stuff
    $output .= '<edit><text>';
    $output .= xml_escape($text);
    $output .= '</text><texttypes>';
    
    $sth = $db->prepare(<<'EOT');
  SELECT Formatter.id, Formatter.name
  FROM Formatter
EOT
    $sth->execute();
    while (my $row = $sth->fetch) {
        $output .= '<texttype id="'. xml_escape($row->[0]) . 
          ($texttype == $row->[0] ? '" selected="selected">' : '">') . 
          xml_escape($row->[1]) . '</texttype>';
    }
    $sth->finish;
    
    $output .= '</texttypes></edit>';

    return $output;
} # preview

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
	    $output = '<pod>
  <para>
    Error parsing the page: ' . xml_escape($@) . '
  </para>
</pod>
  ';
	}
	last;
    }
    if (!$output) {
	$output = <<'EOT';
<newpage/>
EOT
    }
    $output =~ s/^<\?xml\s.*?\?>//s;
    AxKit::Debug(10, "Wiki Got: $output");
    return $output;
}

sub xml_escape {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/]]>/]]&gt;/g;
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
    my ($dbpath, $dbname, $page, $contents, $texttype, $ip, $rss) = @_;
    $rss = [$rss, _mkrssheader($dbname)];
    my $db = _mkdb($dbpath, $dbname);
    _save_page($db, $page, $contents, $texttype, $ip, $rss);
}

sub _save_page {
    my ($db, $page, $contents, $texttype, $ip, $rss) = @_;
    # NB fix hard coded formatterid
    my $last_modified = time;
    local $db->{AutoCommit} = 0;
    my (@row) = $db->selectrow_array("SELECT * FROM Page WHERE name = ?", {}, $page);
    if (@row) {
        # store history
        shift @row; # Remove id
        $db->do('INSERT INTO History (name, formatterid, content, modified, ip_address)
                 VALUES (?, ?, ?, ?, ?)', {}, @row);
    }
    else {
        # New page
        if ($rss->[0]) {
            use Fatal qw(open close);
            open(RSS, ">$rss->[0]");
            flock(RSS, 2); # lock ex
            print RSS $rss->[1];
            my $sth = $db->prepare('SELECT * FROM Page ORDER BY last_modified DESC');
            $sth->execute;
            while (my $row = $sth->fetch) {
                print RSS <<"EOT";
<item>
<title>$row->[1]</title>
</item>
EOT
            }
            print RSS "</rdf:RDF>\n";
            flock(RSS, 8); # unlock
            close(RSS);
        }
    }
    my $sth = $db->prepare(<<'EOT');
  INSERT OR REPLACE INTO Page ( name, formatterid, content, last_modified, ip_address )
  VALUES ( ?, ?, ?, ?, ? )
EOT
    $sth->execute($page, $texttype, $contents, $last_modified, $ip);
    $db->commit;
}

sub _mkrssheader {
    my ($dbname) = @_;
    return <<"EOT";
<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns="http://purl.org/rss/1.0/"
>

 <channel rdf:about="http://take23.org/view/$dbname">
   <title>$dbname</title>
   <link>http://take23.org/view/$dbname</link>
   <description>
     Take23 $dbname
   </description>

EOT
}

sub show_history {
    my ($db, $page) = @_;
    my $sth = $db->prepare('SELECT * FROM History WHERE name = ? ORDER BY modified DESC');
    $sth->execute($page);
    my $hist = '<history>';
    while (my $row = $sth->fetch) {
        $hist .= '<entry>';
        $hist .= '<id>' . xml_escape($row->[0]) . '</id>';
        $hist .= '<modified>' . xml_escape(scalar gmtime($row->[4])) . '</modified>';
        $hist .= '<ip-address>' . xml_escape($row->[5]) . '</ip-address>';
        $hist .= '<bytes>' . xml_escape(length($row->[3])) . '</bytes>';
        $hist .= '</entry>';
    }
    $hist .= '</history>';
    return $hist;
}

sub show_history_page {
    my ($db, $page, $id) = @_;
    my $sth = $db->prepare(<<'EOT');
  SELECT History.content, Formatter.module,
         History.ip_address, History.modified
  FROM History, Formatter
  WHERE History.formatterid = Formatter.id
  AND   History.name = ?
  AND   History.id = ?
EOT
    $sth->execute($page, $id);
    
    my $output = '';
    my $handler = XML::SAX::Writer->new(Output => \$output);
    my ($ip, $modified);
    while ( my $row = $sth->fetch ) {
        ($ip, $modified) = ($row->[2], scalar(gmtime($row->[3])));
	# create the parser
	my $parser = $row->[1]->new(Handler => $handler);
	eval {
	    $parser->parse_string($row->[0]);
	};
	if ($@) {
	    $output = '<pod>
  <para>
    Error parsing the page: ' . xml_escape($@) . '
  </para>
</pod>
  ';
	}
	last;
    }
    if (!$output) {
	$output = <<'EOT';
<pod>
  <para>
Unable to find that history page, or unable to find formatter module
  </para>
</pod>
EOT
    }
    $output =~ s/^<\?xml\s.*?\?>\s*//s;
    $output = "<?ip-address " . xml_escape($ip) . "?>\n" .
              "<?modified " . xml_escape($modified) . "?>\n" .
              $output;
    return $output;
}

sub restore_page {
    my ($dbpath, $dbname, $page, $ip, $id) = @_;
    
    my $db = _mkdb($dbpath, $dbname);
    my $sth = $db->prepare('SELECT * FROM History WHERE name = ? and id = ?');
    $sth->execute($page, $id);
    my $row = $sth->fetch;
    die "No such row" unless $row;
    $sth->finish;
    my ($texttype, $contents) = ($row->[2], $row->[3]);
    _save_page($db, $page, $contents, $texttype, $ip);
}

sub create_db {
    my ($db) = @_;
    
    $db->do(q{
	create table Page ( 
			   id INTEGER PRIMARY KEY,
			   name NOT NULL,
			   formatterid NOT NULL,
			   content,
			   last_modified,
                           ip_address
			   )
    });
    $db->do(q{
        create table History (
                              id INTEGER PRIMARY KEY, 
                              name NOT NULL, 
                              formatterid NOT NULL,
                              content,
                              modified,
                              ip_address
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
	     });
    $db->do(q{
	insert into Formatter (module, name) values ('Text::WikiFormat::SAX', 'wiki text')
	     });
    $db->do(q{
	insert into Formatter (module, name) values ('XML::LibXML::SAX::Parser', 'xml (freeform)')
	     });
    $db->commit;
}

sub extract_page_info {
    my ($path_info) = @_;
    $path_info =~ s/^\///;
    my ($db, $page) = split("/", $path_info, 2);
    $page ||= ''; # can't have page named 0. Ah well.

    if (!$db) {
      return ('', '');
    }
    elsif ($db !~ /^[A-Z][A-Za-z0-9:_-]+$/) {
      die "Invalid db name: $db";
    }
    elsif (length($page) && $page !~ /^[A-Z][A-Za-z0-9:_-]+$/) {
      die "Invalid page name: $page";
    }
    return ($db, $page);
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
