#!/usr/bin/env raku
# -*- Mode: Raku; indent-tabs-mode: nil; coding: utf-8 -*-
# vim: set et ts=4 sw=4:

use v6.d;

# test with:
# raku jeongoon/ch-2.raku 2 1 4 1 2 5 # exmaple 1
# raku jeongoon/ch-2.raku 3 1 3 1 1 5 # exmaple 2
# raku jeongoon/ch-2.raku 1 2 3 4 3 1 # a mountain: no rain trapped

unit sub MAIN ( *@T where { @T.elems > 0 and @T.all ~~ UInt } );
#@T = @T».UInt; # unnecessary here. but note that thery are IntStr

enum territory-stage
<terri-nothing  terri-wall  terri-mountain  terri-lake>;

role lake {
    method get-capacity-info( $territory-data = self ) {
        my ( $range, $terri ) = $territory-data.kv; # k: Range, v: List
        # we need at least 3 data to build a water reservoir
        $terri.elems < 3 and (Nil => 0).return;
        with $terri {
            my $water-level = min( .head, .tail );
            my @t = .[ 1 .. * -2 ];
            #@t.max > $water-level and (Nil => 0).return;
            ($range.[1 .. * -2] => ($water-level X- @t).cache ).return;
            # k: Range, v: capacity
        }
    }
 }

my $terri = class TerriInfo {
    has ( $.left, $.right, $.start, territory-stage $.stage ) is rw;
    method export-lake(@T, $x) { ((self.start..$x)
                                  => (@T[ self.start..$x ])) does lake }
}.new( :left(0):start(0):stage(terri-nothing) );

my @lakes;
# we can do some brute-force for any combinations of region but
# let's scan the territory and find proper lake region
for @T.kv -> $x, $h {
    given $terri {
        when .stage before terri-wall {
            ( .left, .start, .stage ) = $h, $x, terri-wall;
        }
        when .stage before terri-mountain {
            if .left <= $h {  # no useful data on the left hand side
                              # -> update left boundary and position
                ( .left, .start ) = $h, $x;
            }
            else { # has at lesast one lower height than left boundary
                ( .right, .stage ) = $h, terri-mountain;
            }
        }
        when  .left < $h { # and .stage eq terri-mountain
            # found a lake
            @lakes.push( .export-lake( @T, $x ) );
            # right boundary is higher than left one and has valley
            # -> start new scan with right boundary as new left boundary
            $_ = TerriInfo.new( :start($x):left($h):stage( terri-wall ) );
            next;
        }
        default { # .left >= $h
            # second-tallest height -> become a  temporary right boundary
            .right < $h and .right = $h;

            # otherwise we may have some water bucket here
            # but still unsure until reach the right boundary
        }
    }

    LAST {
        # check if any possble lake remained
        .stage eq terri-mountain
        and @lakes.push( .export-lake( @T, $x ) ) with $terri;
    }
}

dd @lakes;
my @lakes-info = @lakes».get-capacity-info;
say "Total capacity: ", ([+] @lakes-info».value».sum),"\n";

sub ssprintf ( UInt:D $w, $str ) { sprintf( "%#{$w}s", $str ) }

# print histogram
my @histo;
my $mh = max @T;
my $ww = $mh.chars + 1;
for $mh ... 1 -> $y {
    my $line = ssprintf( $ww, $y ) ~ '│';
    for @T.kv -> $x, $h {
        my $ch = " "; # assume air (can be changed later)
        if $h >= $y {
            $ch = "#";
        }
        else {
            my ( $range, $cap ) = @lakes-info.first( $x ∈ *.key ).kv;
            with $cap andthen $cap.[ $x -$range.[0] ] {
                    $_ + $h >= $y and $ch = "≈";
            }
        }
        $line ~= ssprintf( $ww, $ch );
    }
    @histo.push($line);
}

@histo.join("\n").say;

say ssprintf( $ww, " " ) ~ '└' ~ ( "─" x ( $ww * @T.elems ) );
say ssprintf( $ww, " " ) ~ ' ' ~ [~] @T.map( -> $h { ssprintf( $ww, $h ) });
