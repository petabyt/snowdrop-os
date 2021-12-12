AT 6, 19; PRINT "+----------------------------------------+";
AT 17, 19; PRINT "+----------------------------------------+";

FOR i = 1 TO 10;
    AT 6 + i, 19;
    PRINT "|                                        |";
NEXT i;

AT 18, 32; PRINT "CTRL-Q to exit";

loop:
    LET col = RND 40; LET col = col + 20;
    LET row = RND 10; LET row = row + 7;
    LET background = RND 7; LET background = background + 1;
    LET font = RND 16;
    COLOURS font, background;
    AT row, col; PRINT CHR 2;
    PAUSE 1;
    GOTO loop;