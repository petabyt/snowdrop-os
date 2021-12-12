readNumber:
    PRINT "Input a number between 1 and 150: ";
    INPUTN number;
    PRINTLN;
    LET withinLowerBound = number >= 1;
    LET withinUpperBound = number <= 150;
    IF withinLowerBound AND withinUpperBound THEN GOTO valid;
    
    IF NOT withinLowerBound THEN PRINTLN "Too low, try again";
    IF NOT withinUpperBound THEN PRINTLN "Too high, try again";
    GOTO readNumber;
valid:
    LET square = number * number;
    PRINT "Its square is " + square;