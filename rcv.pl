#! /usr/bin/perl -w

use strict;

use Getopt::Long;
use LWP::UserAgent;
use JSON;
use HTTP::Headers;
use IO::All -utf8;
use Text::CSV qw(csv);
use Data::Printer;

my $header;
my $url;
my $pattern;
my $param_from;
my $dest_file;



GetOptions ("header=s" => \$header,     # numeric
            "from=s"    => \$param_from,
            "dest=s"    => \$dest_file,
            )   # flag
    or die("Error in command line arguments\n");

#$pattern = qr/$pattern/;
$pattern = qr/personId=/;
#p $pattern;


#p $header;
#p $param_from;

sub parse_header {
    my $header_file = shift;
    my @lines = io($header_file)->slurp;
    #p @lines;
    my $http = {};
    my $headers_hr = {};
    my $req_method = '';
    my $url_ = '';
    my $http_version = '';

    for my $line (@lines) {
        if ( $line =~ /^(\S+):\s+(.+)$/ ) {
            $headers_hr->{"$1"} = $2;
            #p $1;
            #p $2;
        } else {
            if ( $line =~ /(GET||POST)\s+(\S+)\s+(\S+)/ ) {
                $req_method = $1;
                $url_ = $2;
                $http_version = $3;
            }
        }
    }

    $http->{headers} = $headers_hr;
    $http->{url} = "http://" .$headers_hr->{Host} .$url_;
    $http->{method} = $req_method;
    $http->{version} = $http_version;
    
    return $http;
}

sub make_url {
    my $url = shift;
    my $pattern = shift;
    my $param = shift;

    $url =~ m/$pattern/;
    $url =~ s/$'/$param/;

    return $url;
}

sub get_param {
    my $param_file = shift;
    
    my $aoa = csv (in => $param_file);
    
    my @flat_arr = map {$_->[0]} @$aoa;

    return \@flat_arr;
}

sub wash_data {
    my $data = shift;
    my $wash = shift;


    if ($wash) {
        return $wash->($data);
    } else {
        return $data;
    }
}


sub write_file {
    my $file_name = shift;
    my $colum_names = shift;
    my $data_ar = shift;

    #open my $fh, ">", $file_name 
    # or die "$file_name: $!";
    #print $fh @$column_names;

    #close $fh or die "$file_name: $!";
    csv (in => $data_ar, out => $file_name, headers => $colum_names)
        or die "$file_name created FAILED!";
}

sub output {
    my $file = shift;
    my $col_names = shift;
    my $data = shift;

}
my $param_ar = get_param($param_from);
my $ua = LWP::UserAgent->new(timeout=>10);
my $http = parse_header($header);
$url = $http->{url};

my $headers = $http->{headers};
$header = HTTP::Headers->new(%$headers);
$ua->default_headers($header);

my $data_ar = [];

my $wash_cr = sub {
    my $data_json = shift;

    my $obj = $data_json->{bankUses}->[0];
    my $sn = $obj->{aaz010};
    my $name = $obj->{aic143};
    my $id_card = $obj->{aic145};
    my $tel = $obj->{aae005};
    my $addr = $obj->{aae006};
    my $stat = $obj->{bank}->{aae100};
    my $acc_num = $obj->{bank}->{aae010};
    my $bank = $obj->{bank}->{aaf200};

    my $data = [$sn, $name, $id_card, $tel, $addr, $stat, $acc_num, $bank];
    
    return  $data;
};

my $col_names = ['sn', 'name', 'id', 'tel', 'addr', 'stat', 'account', 'bank'];

for my $param (@$param_ar) {
    my $url_new = make_url($url, $pattern, $param);
    my $req = HTTP::Request->new($http->{method} => $url_new);
    my $json = JSON->new->allow_nonref;
    my $response = $ua->request($req);
    my $content = $response->decoded_content;
    my $data = $json->decode($content) 
            or undef;
    my $data_washed = wash_data($data, $wash_cr);

    push @$data_ar, $data_washed;
}

write_file($dest_file, $col_names, $data_ar);

__END__
