#! /usr/env perl -w

use strict;
#use utf8::all;

use LWP::UserAgent;
use JSON;
use Template;
use Data::Printer;
use IO::All -utf8;
use HTTP::Headers;
use JSON;
use Text::CSV qw{csv};




# 解析headers文本，返回LWP可用的HTTP::Header
sub parse_header  {
	my $header_file  = shift;
	my @lines = io($header_file)->slurp;
	
	my $headers = {};
    my $path = '';
    my $version = '';
    my $req_method = '';
    
    for my $line (@lines) {
        if ($line =~ /^(\S+):\s+(.+)$/) {
	        $headers->{"$1"} = $2;
	        #$headers->{"$1"} = undef if !$2;
        } else {
            if ($line =~ /(GET||POST)\s+(\S+)\s+(\S+)/) {
            $req_method = $1;
	        $path = $2;
	        $version = $3;
	        }
        }
    }

    my $url = 'http://' . $headers->{Host} . $path;
    
    my $h = HTTP::Headers->new( %$headers );
    
    return ($h, $url, $req_method, $version);
}

# 配置url，根据样式+参数拼凑出可用的url
sub setup_url {
    my $url = shift;
    my $pattern = shift;
    my $param = shift;
    
    #print "Url: $url\n";
    #$pattern = qr/personId=/;
    
    #$param = '41990081452658';
    
    $url =~ m/$pattern/;
    #print $match;
    #print $';
    $url =~ s/$'/$param/;
    return $url;
}

# 获取json，设置header，cookie向url发送get请求，返回解码后的json
sub get_json {
    my $method = shift;
    my $url = shift;
    my $headers = shift;
    
    #p $headers;
    my $ua = LWP::UserAgent->new(timeout=>10);
    $ua->default_headers($headers);
    
    my $req = HTTP::Request->new($method => $url);
    
    my $response = $ua->request($req);
    
    my $content = $response->decoded_content;
    my $len = length($content);
    #p $content;

    my $json = JSON->new->allow_nonref;
    my ($perl_scalar, $characters) = $json->decode_prefix($content);
    
    if ($characters == $len) {
        my $data_scalar = $json->decode($content) or undef;

        return $data_scalar;
    } else {
        return;
    }
    
    
}

# 生成数据，由给定json生成账户信息数据
sub gen_data {
    my $json = shift;
    
    my $obj = $json->{bankUses}->[0];
    
    my $sn = $obj->{aaz010};
    my $name = $obj->{aic143};
    my $id_card = $obj->{aic145};
    my $tel = $obj->{aae005};
    my $addr = $obj->{aae006};
    my $stat = $obj->{bank}->{aae100};
    my $acc_num = $obj->{bank}->{aae010};
    my $bank = $obj->{bank}->{aaf200};
    
    my @index = qw/个人编号 姓名 身份证号 电话 住址 发放状态 银行账号 发放银行/;
    
    my @data = ($sn, $name, $id_card, $tel, $addr, $stat, $acc_num, $bank);
    
    my $result = [\@index, \@data];
    
    #return $result;
    return \@data;
    
}

# 写入文件，将生成的数据写入指定的文件内
sub write_file {
    my $file = shift;
    my $data = shift;
}

my @http_ = parse_header('header.txt');

#p $http_;

my $url_ = $http_[1];
my $method_ = $http_[2];
my $headers_ = $http_[0];

#print @http_[1],"\n";

#my $url_1 = setup_url($url_,qr/personId=/,'41990082228232');


#print $url_1;
#my $json_  = get_json($method_,$url_1,$headers_);
#p $json_;

#my $rest_ = gen_data($json_);

#p $rest_;

my $sn_file = 'sn_1.csv';
my $aoa = csv (in=>$sn_file);
#p $aoa;
my $rows_ = [];

my $csv = Text::CSV->new ({ blank_is_undef => 1 });
open my $fh,">", "new.csv" or die "new.csv: $!";
print $fh 'sn,name,id,tel,addr,stat,account,bank',"\n";

my $i = 0;

for my $ar (@$aoa) {
    my $sn_ = $ar->[0];
    my $url_n = setup_url($url_,qr/personId=/,$sn_);
    my $json_ = get_json($method_,$url_n,$headers_);
    
    
    #p $rest_ar;
    #push  @$rows_, $rest_ar;
    if ($json_) {
        my $rest_ar = gen_data( $json_ ) ;
        $csv->say ($fh, $rest_ar);
        ++$i;
        print "\[$i\]    $sn_ :账号数据写入成功。\n";
    } else {
        ++$i;
        print "\[$i\]    $sn_ :账号数据写入失败！";
    }
    sleep 1;
}
#csv ( in => $rows_, out => 'new.csv', headers => ['sn', 'name', 'id', 'tel', 'addr', 'stat', 'account', 'bank'] );
#p $aoa_;


#$csv->say ($fh, $_) for @$rows_;
close $fh or die "new.csv: $!";
print "文件写入完毕！\n\n";

__END__


