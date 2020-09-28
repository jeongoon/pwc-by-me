sub MAIN{say((@_,0,Inf).sort.rotor(2=>-1).first({.[0]>-1>[-] $_})[0]+1)}
