# Copyright (c) 2011 ToI Inc. All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# $Id$

package EnhancedInclude;

use Digest::MD5 qw( md5_hex );

use strict;
use warnings;

sub _hdlr_include {
    my ($ctx, $arg, $cond) = @_;

    if ($arg->{execute}) {
        return _hdlr_include_execute(@_);
    }
    elsif ($arg->{url}) {
        return _hdlr_include_url(@_);
    }
    else {
	    defined(my $result = $ctx->super_handler($arg, $cond))
		    or return $ctx->error($ctx->errstr);
	    return $result;
    }
}

sub _hdlr_include_execute {
    my ($ctx, $arg, $cond) = @_;
    my $exec = $arg->{execute};
    my $cache_key = md5_hex('include_execute::' . $exec);
    my $params = $arg->{params} || [];
    if (! ref $params) {
        $params = [ $params ];
    }

    if (my $cached = &_get_cache($cache_key, @_)) {
        return $cached;
    }

    my $value = do{ open(my $fh, '-|', $exec, @$params); local $/; <$fh> };

    &_set_cache($cache_key, $value, @_);
}

sub _hdlr_include_url {
    my ($ctx, $arg, $cond) = @_;
    my $url = $arg->{url};
    my $cache_key = md5_hex('include_url::' . $url);

    if (my $cached = &_get_cache($cache_key, @_)) {
        return $cached;
    }

    my $ua = MT->new_ua;
    my $response = $ua->get($url);

    my $value = '';
    if ($response->is_success) {
        $value =
            $response->can('decoded_content')
          ? $response->decoded_content
          : $response->content;
    }
    else {
        return $ctx->error($response->status_line);
    }

    &_set_cache($cache_key, $value, @_);
}

sub _get_cache {
    my ($cache_key, $ctx, $arg, $cond) = @_;

    my $ttl = $arg->{ttl}
        or return '';

    require MT::Cache::Negotiate;
    my $cache_driver = MT::Cache::Negotiate->new( ttl => $ttl );
    $cache_driver->get($cache_key);
}

sub _set_cache {
    my ($cache_key, $value, $ctx, $arg, $cond) = @_;

    if (MT->version_number >= 5.0) {
        Encode::_utf8_on($value);
    }

    my $ttl = $arg->{ttl}
        or return $value;
    require MT::Cache::Negotiate;
    my $cache_driver = MT::Cache::Negotiate->new( ttl => $ttl );
    $cache_driver->replace($cache_key, $value, $ttl);

    $value;
}

1;
