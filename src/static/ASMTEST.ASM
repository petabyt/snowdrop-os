`"This is an example program which can be assembled";
`"to a Snowdrop OS application";

`" Snowdrop app contract:";

`" At startup, the app can assume:";
`"    - the app is loaded at offset 0";
`"    - all segment registers equal CS";
`"    - the stack is valid (SS, SP)";
`"    - BP equals SP";
`"    - direction flag is clear (string operations count up)";

`" The app must:";
`"    - call int 95h to exit";
`"    - not use the entire 64kb memory segment, as its own";
`"      stack begins from offset 0FFFFh, growing upwards";

    org 0;                   `"Snowdrop OS application origin address is 0";
    
    jmp start;               `"skip over data";

CONST ITERATION_COUNT = 3;   `"we'll iterate this many times";    
    
helloMessage:     db "Hello from the ASMTEST application!", 0;
newLine:          db 13, 10, 0;
pressKeyMessage:  db "Press a key from 0 to 9", 13, 10, 0;
printBuffer:      times 2 db 0;
                             `"we will keep changing first character";
                             `"while leaving the string terminator in place";
start:
    mov si, helloMessage;    `"DS:SI now points to message string";
    int 80h;                 `"print string at DS:SI to video hardware";
    mov si, newLine;         `"DS:SI now points to new line string";
    int 80h;                 `"print string at DS:SI to video hardware";

    mov cx, ITERATION_COUNT; `"outer loop counter";

ask_user:
    mov si, pressKeyMessage; `"DS:SI now points to 'press key' string";
    int 80h;                 `"print string at DS:SI to video hardware";
    
    mov ah, 0;               `"function 0: block and wait for key";
    int 16h;                 `"BIOS keyboard routines";
                             `"AL now contains ASCII code of key";
    cmp al, "0";             `"is it lower than ASCII code of 0?";
    jb ask_user;             `"yes, so ask user again";
    
    cmp al, "9";             `"is it higher than ASCII code of 9?";
    ja ask_user;             `"yes, so ask user again";
    
    sub al, "0";             `"AL now contains the actual numeric value";
    push cx;                 `"save outer loop counter";
    
    mov ch, 0;               `"CX will become the inner loop counter";
    mov cl, al;              `"CX now contains the numeric value";
    inc cx;                  `"one iteration for 0, 2 for 1, etc.";
    
    mov al, "0";             `"we'll start displaying from 0";
    mov si, printBuffer;     `"DS:SI now points to print buffer";

display:
    mov byte [cs : printBuffer], al;
                             `"store ASCII value in print buffer";
    int 80h;                 `"print string at DS:SI to video hardware";
    inc al;                  `"next ASCII character";
    loop display;            `"next iteration";
    
    mov si, newLine;         `"DS:SI now points to new line string";
    int 80h;                 `"print string at DS:SI to video hardware";
    
    pop cx;                  `"restore outer loop counter";
    loop ask_user;           `"next iteration";
    
    int 95h;                 `"Snowdrop OS function 'exit program'";
