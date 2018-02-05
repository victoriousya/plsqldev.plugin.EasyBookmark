{DEFINE DEBUG}

unit Main;

interface

uses
  Windows, SysUtils, PlugInIntf;

const // Description of this Plug-In (as displayed in Plug-In configuration dialog)
  Desc = 'Easy Bookmark 1.0.3';
  Bit0 = 1;
  Bit1 = 2;
  Bit2 = 4;
  Bit3 = 8;
  Bit4 = 16;
  Bit5 = 32;
  Bit6 = 64;
  Bit7 = 128;

  Bit8 = 256;
  Bit9 = 512;
  Bit10 = 1024;
  Bit11 = 2048;
  Bit12 = 4096;
  Bit13 = 8192;
  Bit14 = 16384;
  Bit15 = 32768;

implementation

var
  HookHandle: hHook;
  ShiftIsDown: Boolean;
  CtrlIsDown: Boolean;
  Last_Time: TDateTime;

procedure OutDebug(Str: PChar);
begin
{$IFDEF DEBUG}
  OutputDebugString(Str);
{$ENDIF}
end;


function Same_Key_Hook: Boolean;
var
  Hour, Min, Sec, MSec: Word;
  Hour1, Min1, Sec1, MSec1: Word;
  SecStr: String;
  Secs: Double;
begin
  DecodeTime(Now(), Hour, Min, Sec, MSec);
  DecodeTime(Last_Time, Hour1, Min1, Sec1, MSec1);
  Last_Time:= Now();
  Secs:= Abs((Sec+1/1000*MSec)-(Sec1+1/1000*MSec1));
  SecStr:= FloatToStr(Secs);
  OutDebug(PChar(Format('%s',[SecStr])));
  if (Hour = Hour1) and (Min = Min1) and (Secs < 0.300) then
    Result:= True
  else
    Result:= False;
end;

function IdentifyPlugIn(ID: Integer): PChar; cdecl;
begin
  PlugInID:= ID;
  Result:= Desc;
end;

function GetBitStat(SetWord, BitNum: Word): Boolean;
begin
  GetBitStat:= SetWord and BitNum = BitNum { Если бит установлен }
end;

function Process_Keys(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
var
  KeyInfo: Word;
  IsNotReleasedKey: Boolean;
  procedure GotoBookmark(Index: Integer);
  begin
    IDE_GotoBookmark(Index);
    IDE_SetCursor(IDE_GetCursorX(), IDE_GetCursorY());
  end;
  procedure SetBookmark(Index: Integer);
  var
    X,Y: Integer;
    e_X,e_Y: Integer;
  begin
    if IDE_GetBookmark(Index,X,Y) then begin
      // Если установлена
      e_X:= IDE_GetCursorX();
      e_Y:= IDE_GetCursorY();
      if e_Y = Y then begin
        OutDebug(PChar(Format('Clear %d %d',[e_X, e_Y])));
        // Если курсор стоит в той-же позиции, что и Bookmark - очищаем
        IDE_ClearBookmark(Index)
      end else begin
        // Перемещаем в новую позицию
        OutDebug(PChar(Format('ReSet %d %d',[e_X, e_Y])));
        IDE_SetBookmark(Index, e_X, e_Y);
      end;
    end else begin
      e_X:= IDE_GetCursorX();
      e_Y:= IDE_GetCursorY();
      OutDebug(PChar(Format('Set %d %d',[e_X, e_Y])));
      IDE_SetBookmark(Index, e_X, e_Y);
    end;
  end;
begin
  if Code < 0 then
    Result:= CallNextHookEx(HookHandle, Code, wParam, lParam)
  else begin
    KeyInfo:= HiWord(lParam);
    IsNotReleasedKey:= not GetBitStat(KeyInfo, bit15 );
    if IsNotReleasedKey then begin
      if not ShiftIsDown then ShiftIsDown:= (wParam = VK_SHIFT);
      if not CtrlIsDown then CtrlIsDown:= wParam = VK_CONTROL;
    end else begin
      if ShiftIsDown and CtrlIsDown and ( wParam in [48..57]) and (not Same_Key_Hook) then begin
        SetBookmark(wParam-48);
      end else if CtrlIsDown and ( wParam in [48..57]) and (not Same_Key_Hook) then begin
        GotoBookmark(wParam-48);
      end else begin
        case wParam of
          VK_SHIFT: ShiftIsDown:= False;
          VK_CONTROL: CtrlIsDown:= False;
        end;
      end;
    end;
    Result:= CallNextHookEx(HookHandle, Code, wParam, lParam);
  end;
end;

procedure Start_Monitoring;
var
  TheHandle: HWND;
  TheThread: DWORD;
begin
  ShiftIsDown:= False;
  CtrlIsDown:= False;
  TheHandle:= IDE_GetClientHandle;
  if TheHandle <> 0 then begin
    TheThread:= GetWindowThreadProcessId(TheHandle, nil);
    HookHandle:= SetWindowsHookEx(WH_KEYBOARD, Process_Keys, HInstance, TheThread);
    if HookHandle = 0 then OutDebug( 'Setting Hook Failed.');
  end;
end;

procedure Stop_Monitoring;
begin
  if HookHandle > 0 then UnhookWindowsHookEx(HookHandle);
end;

// Called when child windows change focus

procedure OnWindowChange;
var
  w: Integer;
begin
  w:= IDE_GetWindowType;
  Stop_Monitoring;
  if w in [wtTest, wtProcEdit, wtSQL, wtCommand] then Start_Monitoring;
end;

// Called when the Plug-In is created

procedure OnCreate; cdecl;
begin
  Last_Time:= Now();
end;

// Called when the Plug-In is activated

procedure OnActivate; cdecl;
begin
  OnWindowChange;
  HookHandle:= 0;
end;

// Called when the Plug-In is deactivated

procedure OnDeactivate; cdecl;
begin
  Stop_Monitoring;
  HookHandle:= 0;
end;

// Called when the Plug-In is destroyed

procedure OnDestroy; cdecl;
begin
end;

function About: PChar;
begin
  Result:= Desc+
           #13'©2004-2018 VictoriousSoft Team'
         + #13#13'Borlad IDE Style Bookmarks'
         + #13'Use'#9'Ctrl+Shift+# - set bookmark'
         + #13#9'Ctrl+# - goto bookmark'
         + #13'eMail to author: victorious.soft@gmail.ru'
         + #13'or visit my GitHub page: github.com/victoriousya'
           ;
end;

// All exported functions
exports
  IdentifyPlugIn,
  RegisterCallback,
  OnCreate,
  OnActivate,
  OnDeactivate,
  OnDestroy,
  About,
  OnWindowChange;

end.

