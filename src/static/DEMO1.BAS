LET twoAgo = 0; LET oneAgo = 1;
PRINT "Fibonacci sequence: "; PRINT twoAgo + " "; PRINT oneAgo + " ";

FOR i = 1 TO 20;
    LET current = twoAgo + oneAgo;
    PRINT current + " ";
    LET twoAgo = oneAgo;
    LET oneAgo = current;

    LET frequencyNumber = 100 + current;
    BEEPW frequencyNumber, 30;
NEXT i;
