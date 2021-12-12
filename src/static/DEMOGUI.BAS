REM "This program showcases some of BASIC's GUI capabilities";

LET allElementsCleared = 0;

GUIBEGIN "BASIC GUI TEST";

LET button1 = GUIBUTTONADD "BUTTON 1", 8, 20;
LET button2 = GUIBUTTONADD "BUTTON 2", 108, 20;
LET btnStatusImg = GUIIMAGEASCIIADD "-", 295, 21;
GUIIMAGEDISABLE btnStatusImg;

LET checkbox1 = GUICHECKBOXADD "CHECKBOX 1", 8, 45;
LET checkbox2 = GUICHECKBOXADD "CHECKBOX 2", 8, 60;
LET chckbxStatusImage = GUIIMAGEASCIIADD "-------------------------", 100, 50;
GUIIMAGEDISABLE chckbxStatusImage;

GUISETCURRENTRADIOGROUP 1;
LET radio1 = GUIRADIOADD "RADIO1", 8, 80;
LET radio2 = GUIRADIOADD "RADIO2", 8, 95;
GUISETCURRENTRADIOGROUP 2;
LET radio21 = GUIRADIOADD "RADIO21", 80, 80;
LET radio22 = GUIRADIOADD "RADIO22", 80, 95;
LET radio1StatusImage = GUIIMAGEASCIIADD "RADIO1: NOT SELECTED", 150, 83;
GUIIMAGEDISABLE radio1StatusImage;

LET timerTickImage = GUIIMAGEASCIIADD "-----", 220, 111;
GUIIMAGEDISABLE timerTickImage;

LET image1 = GUIIMAGEASCIIADD "IMAGE 1", 8, 135;
LET image2 = GUIIMAGEASCIIADD "IMAGE 2", 90, 135;
LET selectedInfoImage1 = GUIIMAGEASCIIADD "IMAGE 1 IS NOT SELECTED", 8, 155;
LET selectedInfoImage2 = GUIIMAGEASCIIADD "IMAGE 2 IS NOT SELECTED", 8, 170;
GUIIMAGEDISABLE selectedInfoImage1;
GUIIMAGEDISABLE selectedInfoImage2;

LET lastLClickImg = GUIIMAGEASCIIADD "-", 295, 127;
GUIIMAGEDISABLE lastLClickImg;

LET lastRClickImg = GUIIMAGEASCIIADD "-", 295, 142;
GUIIMAGEDISABLE lastRClickImg;

LET clearAllButton = GUIBUTTONADD "CLEAR ALL", 235, 162;
LET exitButton = GUIBUTTONADD "EXIT", 275, 180;

GUIAT 400, 300;
GUIPRINT "THIS SHOULD NOT BE VISIBLE";
GUIRECTANGLEERASETO 610, 310;

LET ticks = 0;
YIELD;

REM "=====================================================================";
REM "Control has now been given to the GUI framework";
REM "=====================================================================";

REM "=====================================================================";
REM "The labels below are entered whenever an event takes place in the GUI";
REM "Such events include an automatic timer, button clicks, etc.";
REM "=====================================================================";

timerTickEvent:
  REM "We do nothing if all elements have been cleared";
  IF allElementsCleared <> 0 THEN YIELD;
  IF ticks = 32767 THEN LET ticks = 0;
  
  LET ticks = ticks + 1;
  LET ticksString = "" + ticks;
  GUIIMAGEASCIISETTEXT timerTickImage, ticksString;
  YIELD;

buttonClickEvent: 
  IF GUIACTIVEELEMENTID = button1 THEN GUIIMAGEASCIISETTEXT btnStatusImg, "1";
  IF GUIACTIVEELEMENTID = button2 THEN GUIIMAGEASCIISETTEXT btnStatusImg, "2";
  IF GUIACTIVEELEMENTID = exitButton THEN STOP;
  IF GUIACTIVEELEMENTID = clearAllButton THEN CALL clearAll;
  YIELD;
  
checkboxChangeEvent:
  LET message = "CHECKBOX ";
  LET activeCheckbox = GUIACTIVEELEMENTID;
  
  LET nextPart = "2";
  IF activeCheckbox = checkbox1 THEN LET nextPart = "1";
  LET message = message + nextPart;
  
  LET nextPart = " IS NOT CHECKED";
  IF GUICHECKBOXISCHECKED activeCheckbox THEN LET nextPart = " IS CHECKED";
  LET message = message + nextPart;
  
  GUIIMAGEASCIISETTEXT chckbxStatusImage, message;
  YIELD;
  
radioChangeEvent:
  LET text = "RADIO1: NOT SELECTED";
  IF GUIRADIOISSELECTED radio1 THEN LET text = "RADIO1: SELECTED";
  GUIIMAGEASCIISETTEXT radio1StatusImage, text;
  YIELD;
  
imageLeftClickedEvent: 
  IF GUIACTIVEELEMENTID = image1 THEN GUIIMAGEASCIISETTEXT lastLClickImg, "1";
  IF GUIACTIVEELEMENTID = image2 THEN GUIIMAGEASCIISETTEXT lastLClickImg, "2";
  YIELD;
  
imageRightClickedEvent: 
  IF GUIACTIVEELEMENTID = image1 THEN GUIIMAGEASCIISETTEXT lastRClickImg, "1";
  IF GUIACTIVEELEMENTID = image2 THEN GUIIMAGEASCIISETTEXT lastRClickImg, "2";
  YIELD;
  
imageSelectedChangeEvent:
  LET text = "IMAGE 1 IS NOT SELECTED";
  IF GUIIMAGEISSELECTED image1 THEN LET text = "IMAGE 1 IS SELECTED";
  GUIIMAGEASCIISETTEXT selectedInfoImage1, text;
  
  LET text = "IMAGE 2 IS NOT SELECTED";
  IF GUIIMAGEISSELECTED image2 THEN LET text = "IMAGE 2 IS SELECTED";
  GUIIMAGEASCIISETTEXT selectedInfoImage2, text;
  YIELD;

  REM "This event is entered every time the screen is redrawn";
  REM "This is where we draw any custom graphics or text";
guiRefreshEvent:
  REM "We draw no text if we have just cleared all elements";
  IF allElementsCleared = 1 THEN YIELD;

  GUIAT 190, 25;
  GUIPRINT "LAST CLICKED:";

  GUIAT 8, 115;
  GUIPRINT "TICKS SINCE PROGRAM START:";

  GUIAT 190, 130;
  GUIPRINT "LAST L-CLICK:";

  GUIAT 190, 145;
  GUIPRINT "LAST R-CLICK:";
  YIELD;

clearAll:
  LET allElementsCleared = 1;
  GUICLEARALL;
  RETURN;
