CLS; LET shipRow = 20; LET shipCol = 37; LET deltaX = 0;
COLOURS 12, 0; AT shipRow + 3, 24; PRINT "arrow keys to move; CTRL-Q exits";

REM "moving the cursor to 24, 0 hides it"; AT 24, 0; COLOURS 0, 0; PRINT " ";

CALL updateShip;
mainLoop: PAUSE 3; CALL checkLeft; CALL checkRight; AT 24, 0; GOTO mainLoop;
    
checkLeft:
    LET leftArrow = KEY 75; IF NOT leftArrow THEN RETURN;
    LET deltaX = -1; CALL updateShip; RETURN;
checkRight:
    LET rightArrow = KEY 77; IF NOT rightArrow THEN RETURN;
    LET deltaX = 1; CALL updateShip; RETURN;
updateShip:
    AT shipRow, shipCol; PRINT "         ";
    AT shipRow + 1, shipCol; PRINT "         ";
    COLOURS 14, 0; BEEP 2280, 2;
    LET shipCol = shipCol + deltaX;
    IF shipCol < 0 THEN LET shipCol = 0;
    IF shipCol > 75 THEN LET shipCol = 75;
    AT shipRow, shipCol; PRINT "| _ |";
    AT shipRow + 1, shipCol; PRINT "|/_\|";
    RETURN;