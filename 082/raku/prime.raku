#!/usr/bin/env raku
# -*- Mode: Raku; indent-tabs-mode: nil; coding: utf-8 -*-
# vim: set et ts=4 sw=4:

use v6.d;

subset Nat of Int where { $^a > 0 }  # 1 inclusive
# modified from ch-076/ch-1.raku (with little more optimization
# note: 1 is excluive for challenge purpose
sub prime-numbers ( Nat:D $limit ) {
    state %not-prime;

    my Nat @p = 3; # starting point
    my $candi = 3;
    [2..$limit].return   if $limit < 2;
    [2,3].return       if $limit  < 5;

    NEW-NUMBER:
    while ( ($candi += 2) <= $limit ) { # +=2 because skipping even numbers
        for @p -> $p {
            # put more optimization than last implimentation
            next if %not-prime{$p}:exists;
            if ($candi %% $p) { next NEW-NUMBER }
            else {
                # memo possible non-prime values
                for (lazy [\*] [$p,$p...Inf]) -> $np { # non prime
                    # `-> this will produce $p, $p**2, $p**3 ... in lazy way
                    $np > $limit and last;
                    %not-prime{$np} = True;
                }
            }
        }
        push @p, $candi;
    }
    [ 2, |@p ].return; # add 2
}

sub common-prime-factors (*@n) {
    prime-numbers( [gcd] @n     # greatest common divisor
                 ).say;

}

sub MAIN ( Nat:D \M, Nat:D \N ) {
    common-prime-factors(M,N);
=begin comment
    andthen
    flat(
        1, # because common-primes() doesn't contain `1'
        .map(
            {
                gather {
                    for (lazy [\*] [$_,$_...Inf]) -> $k {
                        any(M,N) < $k and last;
                        take $k;
                    }
                }
            })
    ).
    combinations.elems.say;
=end comment
}
