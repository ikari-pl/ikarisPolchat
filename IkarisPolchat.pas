unit IkarisPolchat;
// Ikari's POLCHAT3 component, v. 7

interface

uses
  Windows, SysUtils, Classes, JclUnicode, Graphics,
  IniFIles, WSocket, HTTPProt, extctrls;

CONST
 MAX_BUFFER = 10*1024; // 10kB


type
  TPolchatEvent = procedure(Sender: TComponent; Text : string) of object;
  TRoomEvent = procedure(Sender: TComponent; Text: string; Room: String) of object;
  TPrivEvent = procedure(Sender: TComponent; text, nad, odb: string) of object;
  TAdsEvent = procedure(Sender: TComponent;  banref, butref : word; ban_s, ban_t, but_s, but_t : string) of object;

  TSendFlags = (sfNone, sfToModerate, sfModerated);
  ArrOfStr = array of string;

  TPakiet = class
  private
    Fni: Word;
    Fns: Word;
    Fti: array of Word;
    Fts: array of string;
    function GetInteger(Index: Word): Word;
    function GetNI: Word;
    function GetNS: Word;
    function GetSize: DWord;
    function GetString(Index: Word): string;
    procedure SetInteger(Index: Word; const Value: Word);
    procedure SetNI(const Value: Word);
    procedure SetNS(const Value: Word);
    procedure SetString(Index: Word; const Value: string);
  public
    property ti[Index: Word]: Word read GetInteger write SetInteger;
    property ts[Index: Word]: string read GetString write SetString;
  published
    function LoadFromStream(Stream: TStream): integer;
    function SaveToStream(Stream: TStream): integer;
    function LoadFromBuffer(const Buffer; BufferSize: integer): integer;
    function SaveToBuffer(var Buffer; BufferSize: LongInt): LongInt;
    property Size: DWord read GetSize;
    property ni: Word read GetNI write SetNI;
    property ns: Word read GetNS write SetNS;
  end;

  TChatRoom = class
  Private
    FName: WideString;
    FDesc: WideString;
    FPeople: TStringList;
    FFlag1: word; // ?!
    FFlag2: word;
    function GetPeopleCount: word; // ?!x2
    procedure SetInfo(Name: Widestring; Desc: WideString = ''; Flag1: word = 0; Flag2: word=0);
  public
    constructor Create(Name: WideString; Desc: WideString = ''; Flag1: word = 0; Flag2: word=0);
    destructor Destroy; override;
    property Name : widestring read FName;
    property Description : Widestring read FDesc;
    property NickList : TStringList read FPeople;
    property Flag1: word read FFlag1 write FFlag1;
    property Flag2: word read FFlag2 write FFlag2;
    property PplCount: word read GetPeopleCount;
  end;

  TOsoba = class
  private
    FNick : widestring;
    FNormalizedUniqueNick: string;
    FStatusGlobal : Byte;
    FStatusIndivid: Byte;
    function GetBuddy: boolean;
    function GetBusy: boolean;
    function GetGuest: boolean;
    function GetGuestNum: byte;
    function GetIgnored: boolean;
    function GetOp: Boolean;
    function GetSelf: Boolean;
  public
    FExtra: Pointer;
    constructor Create(Nick: WideString; GlobalStatus, IndividialStatus: byte);
    procedure SetGlobalStatus(Status: Byte);
    procedure SetIndivStatus(Status: Byte);
  published
    property Nick : widestring read FNick;
    property GuestNum : byte read GetGuestNum;
    property isBuddy : boolean read GetBuddy;
    property isIgnored : boolean read GetIgnored;
    property isBusy: boolean read GetBusy;
    property isGuest: boolean read GetGuest;
    property isOp: Boolean read GetOp;
    property isSelf: Boolean read GetSelf;
    property NickNormalized: string read FNormalizedUniqueNick;
    property GlobalStatus: Byte read FStatusGlobal;
    property IndividualStatus: Byte read FStatusIndivid;
   end;

  TServerPrefs = class(TPersistent)
  private
   FColUs , FColOp : TColor;
   FColGuest : array of TColor;
   FPassProt, FRoomCreate : boolean;
   FConvTable : string;
   FCategories: string;
   procedure SetNothingStr(Value: string);
   procedure SetNothingBool(Value: Boolean);
    function GetColorGuest(Index: integer): TColor;
    function GetColorCount: integer;
  Public
    Constructor create(AOwner : TComponent);
    property color_guest[Index: Integer]: TColor read GetColorGuest stored False;
    property color_guest_count: integer read GetColorCount stored False;
  published
   property color_user : TColor read FcolUs stored False;
   property color_op : TColor read FColOp stored False;
   property password_protection : boolean read FPassProt write SetNothingBool stored False default true;
   property room_creation : boolean read FRoomCreate write SetNothingBool stored False default true;
   property conv_table : string read FConvTable write SetNothingStr stored False;
   property Categories : string read FCategories write SetNothingStr stored False;
  end;

  TUserPrefs = class(TPersistent)
  private
   FFN : string;
   FFS : Integer;
   FignPrv, FignCol, FignImg : boolean;
   FJLMsg, FBeep, FSepWin : boolean;
   FParent : TComponent;
   procedure SetFN(Value: string);
   procedure SetFS(Value: integer);
   procedure SetIgnCol(Value: boolean);
   procedure SetIgnPrv(Value: boolean);
   procedure SetIgnImg(Value: boolean);
   procedure SetJLMsg(Value: boolean);
   procedure SetBeepNew(Value: boolean);
   procedure SetSepWin(Value: boolean);
  Public
   Constructor create(AOwner : TComponent);
  published
   property FontName : string read FFN write SetFN stored False;
   property FontSize : integer read FFS write SetFS stored False;
   property IgnPrivs : boolean read FIgnPrv write SetIgnPrv stored False default false;
   property IgnColors : boolean read FIgnCol write SetIgnCol stored False default false;
   property IgnImg : boolean read FIgnImg write SetIgnImg stored False default false;
   property JoinLeaveMsg : boolean read FJLMsg write SetJLMsg stored False default true;
   property BeepNew : boolean read FBeep write SetBeepNew stored False default false;
   property SepWindows : boolean read FSepWin write SetSepWin stored False default true;
  end;

  TSocksPrefs = class(TPersistent)
  private
   FUseProxy : boolean;
   FProxyAddr: String;
   FProxyPort: Integer;
   FSocksVer : Integer;
  public
   Constructor Create(AOwner: TComponent);
  published
   property UseProxy : boolean read FUseProxy write FUseProxy default false;
   property ProxyAddress : string read FProxyAddr write FProxyAddr;
   property ProxyPort : Integer read FProxyPort write FproxyPort default 1080;
   property SocksVer : Integer Read FSocksVer write FSocksVer default 5;
  end;

  TIkarisPolchat = class(TComponent)
  private
    strumien, Odpowiedz : TStringStream;
    HTTPTimer: TTimer;
    FHTTP: THTTPCli;
    FClientSocket: TWSocket;
    StosOut: THashedStringList;
    Stos: THashedStringList;
    wait4rest : boolean;
    prevtext  : string;

    FNick, FPass, FRoom,
    FLink, FServ : String;
    FSPrefs      : TServerPrefs;
    FUPrefs      : TUserPrefs;
    FSocks       : TSocksPrefs;

    //FNicks: TStrings;
    //FIlOsob : integer;
    //FRoomName, FRoomDesc : string;

    FAutoPrefs : boolean;
    FPort     : Integer;
    FEncoding : boolean;
    FHTTPConn: boolean;

    FChatRooms: TStringList;
    FPolchatVersion : integer;

    FVerDetect: TNotifyEvent;
    FPolchatConnected : TSessionConnected;
    FError : TPolchatEvent;
    FPingRcvd : TNotifyEvent;
    FWiadPrv : TPrivEvent;
    FPrefsRcvd, FExtPrefs : TNotifyEvent;
    FNickList : TRoomEvent;
    FWiadMain : TRoomEvent;
    FRoomList : TPolchatEvent;
    FEntrance, FDeparture : TRoomEvent;
    FStatChng : TRoomEvent;
    FRoomInfo : TRoomEvent;
    FRozlacz : TPolchatEvent;
    FWchodze, FWychodze : TRoomEvent;
    FModerateStart : TNotifyEvent;
    FModerateStop  : TNotifyEvent;
    FModerateText  : TRoomEvent;
    FAdsReceived : TAdsEvent;
    { Private declarations }
     procedure Interpretuj(pakiet: TPakiet);
     procedure Pong;
     procedure HTTP_Settings(pakiet: TPakiet);
     procedure Main(pakiet: TPakiet);
     procedure Priv(pakiet: TPakiet);
     procedure RoomList(pakiet: TPakiet);
     procedure Prefs(pakiet: TPakiet);
     procedure Departure(pakiet: TPakiet);
     procedure Entrance(pakiet: TPakiet);
     procedure People(pakiet: TPakiet);
     procedure StatusPublic(pakiet: TPakiet);
     procedure StatusPrivate(pakiet: TPakiet);
     procedure ExtPrefs(pakiet: TPakiet);
     procedure RoomInfo(pakiet: TPakiet);
     procedure Wchodze(pakiet: TPakiet);
     procedure Wychodze(pakiet: TPakiet);
     procedure Rozlacz(pakiet: TPakiet);
     procedure OtwModer;
     procedure ZamModer;
     procedure Reklamy(pakiet: TPakiet);
     procedure Moderuj(pakiet: TPakiet);

     procedure SetRoom(Value : string);
     procedure SetPass(Value: string);
     function GetConnected: Boolean;
     procedure SetConnected(const Value: Boolean);
     procedure SetHTTPConn(const Value: Boolean);
    procedure MakeHTTPQuery(Sender: TObject);
    procedure OdczytDanych(Sender: TObject; Error: Word);
(*
    procedure Pobierz;
    procedure RozklecPakiet(data: string);
    function SklecPakiet(text: string): string;
*)
    procedure Rozlaczyl(Sender: TObject; Error: Word);
//    procedure Wyslij(text: string);
    procedure BladGniazdka(Sender: TObject);
    procedure RequestDone(Sender: TObject; RqType: THttpRequest;
      Error: Word);
    function GetNickList(pokoj: WideString): TStringList;
    procedure DetermineRoom(var pokoj: WideString; pakiet: TPakiet);
    procedure DetermineNickList(pokoj: WideString; var Nicks: TStringList);
  protected
    checkValue: Integer;
    con: Integer;
    proc: Integer;
   procedure PolchatConnected(Sender: TObject; Error: Word);
   procedure ErrorMessage(text : string);
  public
   goodbye   : string;
   constructor Create(AOwner: TComponent); override;
   destructor Destroy; override;
   procedure Open;
   procedure Close(WaitForClose: boolean);
   function dekoduj(text: string):widestring;
   function zakoduj(text: widestring):string;
   function BoolToInt(wart: boolean): integer;
   function BoolToStr(wart: boolean): string;
   function IntToBool(wart: integer): boolean;
    { Public declarations }
  published
   {wlasciwosci}
//   property ClientSocket : TWSocket read FClientSOcket write FClientSocket;
   property HTTPConnection : Boolean read FHTTPConn write SetHTTPConn;
   property Connected : Boolean read GetConnected Write SetConnected;

   property ChatRooms: TStringList read FChatRooms;
   property PolchatVersion: integer read FPolchatVersion;

   property AutoSendPrefs : boolean read FAutoPrefs write FAutoPrefs default false;
   property Nick : String read Fnick write FNick;
   property Password : String read FPass write SetPass;
   property Room : string read FRoom write SetRoom;
   property Link : String read FLink write Flink;
   property Server : string read FServ write FServ;
   property ServerPort : integer read FPort write FPort;

   //property Nicks : TStrings read Fnicks write SetNothingStrs stored False;
   property ServerPrefs : TServerPrefs read FSPrefs write FSprefs stored False;
   property UserPrefs : TUserPrefs read FUPrefs write FUPrefs stored False;
   property SOCKS : TSocksPrefs read FSocks write FSocks;

   property Encoding : Boolean read FEnCoding write FEnCoding;

   //property Il_Osob : integer read FIlOsob write SetNothingInt stored False default 0;
   //property Current_room : string read FRoomName write SetRoom stored False;
   //property Current_Descr: string read FRoomDesc write SetNothingStr stored False;

   {zdarzenia}
   property OnPolchatConnected: TSessionConnected read FPolchatConnected write FPolchatConnected;
   property OnErrorMsg : TPolchatEvent read Ferror write FError;
   property OnPing : TNotifyEvent read FPingRcvd write FPingRcvd;
   property OnMsgMain : TRoomEvent read FWiadMain write FWiadMain;
   property OnMsgPriv : TPrivEvent read FWiadPrv write FWiadPrv;
   property OnGotRoomList : TPolchatEvent read FRoomList write FRoomList;
   property OnPreferencesRcvd : TNotifyEvent read FPrefsRcvd write FPrefsRcvd;
   property OnEntrance : TRoomEvent read FEntrance write FEntrance;
   property OnDeparture : TRoomEvent read FDeparture write FDeparture;
   property OnNicksRcvd : TRoomEvent read FNickList write FNickList;
   property OnStatusChange : TRoomEvent read FStatChng write FStatChng;
   property OnServerPrefs : TNotifyEvent read FExtPrefs write FExtPrefs;
   property OnRoomInfo : TRoomEvent read FRoomInfo write FRoomInfo;
   property OnRoomEnter : TRoomEvent read FWchodze write FWchodze;
   property OnRoomLeave : TRoomEvent read FWychodze write FWychodze;
   property OnPolchatDisconnected : TPolchatEvent read FRozlacz write FRozlacz;
   property OnModerateStart : TNotifyEvent read FModerateStart write FModerateStart;
   property OnModerateStop  : TNotifyEvent read FModerateStop write FModerateStop;
   property OnModerateText  : TRoomEvent read FModerateText write FModerateText;

   property OnAdsReceived : TAdsEvent read FAdsReceived write FAdsReceived;
   property OnPolchatVersionDetected : TNotifyEvent read FVerDetect write FVerDetect;
    { Published declarations }
   function CutString(text, after, before: string): string;
   procedure WyslijMsg(Text: String; Room: string = ''; flags: TSendFlags = sfNone);
   procedure PoprosListe(NazwaKategorii: String; lp_num : word = 7; lp_desc : word = 65535);
   procedure ZmienStatus(OtwartePrivy: boolean);
   procedure UtworzPokoj(Name: string; Descr : string = ''; Pref : string = ''; CategoryName : string = '');

   procedure QueuePacket(Pakiet: TPakiet);
   procedure SendPacket(Pakiet: TPakiet);
   function  SetPrefs: boolean;
  end;

procedure Register;
function NormalizeNick(Nick: widestring): string;
function HTMLToColor(str : string): TColor;
function SwapInt(Value: LongWord): LongWord; assembler; register;
function SwapWord(Value: Word): Word; assembler; register;

implementation

var CopyRightStr : string = 'Ikari''s Polchat Component 7; by Ikari';
    Command : string = '(c)2002-2005 by Ikari';
    i : integer;

procedure Register;
begin
  RegisterComponents('Custom', [TIkarisPolchat]);
end;


{swap 4 Bytes Intel, Little/Big Endian Conversion}
function SwapInt(Value: LongWord): LongWord; assembler; register;
asm
       XCHG  AH,AL
       ROL   EAX,16
       XCHG  AH,AL
end;

function SwapWord(Value: Word): Word; assembler; register;
asm
       XCHG  AH,AL
end;


function HTMLToColor(str : string): TColor;
begin
  Result := StrToInt('$'+str[6]+str[7]+str[4]+str[5]+str[2]+str[3]);
end;

function explode(sPart, sInput: string): TStringList;
begin
  Result := TStringList.Create;
  while Pos(sPart, sInput) <> 0 do
  begin
    Result.Add(copy(sInput, 0, Pos(sPart, sInput) - 1));
    Delete(sInput, 1, Pos(sPart, sInput));
  end;
  Result.Add (sInput);
end;

function implode(sPart: string; arrInp: TStringList): string;
var
  i: Integer;
begin
  if arrInp.Count <= 1 then Result := arrInp[0]
  else
  begin
    for i := 0 to arrInp.Count - 2 do Result := Result + arrInp[i] + sPart;
    Result := Result + arrInp[arrInp.count - 1];
  end;
end;


procedure SetNothingInt(Value: Integer);
begin
 //fall through
end;

procedure SetNothingBool(Value: Boolean);
begin
 //fall through
end;

procedure SetNothingStr(Value: String);
begin
 //fall through
end;

procedure SetNothingStrs(Value: TStrings);
begin
 //fall through
end;



{TIkarisPolchat}
constructor TIkarisPolchat.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);

 Stos   := THashedStringList.Create;
 StosOut:= THashedStringList.Create;
 Strumien := TStringStream.create('');
 Odpowiedz := TStringStream.Create('');
 Stos.Sorted := False;
 StosOut.Sorted := False;
 FClientSocket := TWSocket.Create(Self);
 FHTTP := THTTPCli.Create(Self);
 FHTTP.MultiThreaded := True;
 FHTTP.OnRequestDone := RequestDone;
 FClientSocket.SetSubComponent(True);
 FClientSocket.Name := 'Gniazdko';
 FClientSocket.OnSessionConnected := PolchatConnected;
 FClientSocket.OnSessionClosed := Rozlaczyl;
 FClientSocket.OnDataAvailable := OdczytDanych;
 FClientSocket.OnError := BladGniazdka;

 FEncoding := False;

 Wait4rest := false; prevtext := '';

 //FNicks := TStringList.Create;
 FChatRooms := TStringList.Create;
 FPolChatVersion := 2;

 FSPrefs := TServerPrefs.create(Self);
 FUPrefs := TUserPrefs.create(self);
 FSocks := TSocksPrefs.Create(Self);

 FServ := 'http://s9.polchat.pl/';
 FRoom := 'ikari';
 FLink := 'http://www.polchat.pl/chat/room.phtml/?room=ikari';

 FPort := 14003;
end;

destructor TIkarisPolchat.Destroy;
var
  I: Integer;
begin
 Stos.Clear;
 Stos.Free;
 StosOut.Clear;
 StosOut.Free;
   for I := 0 to FChatRooms.Count - 1 do    // Iterate
   begin
    FChatRooms.Objects[i].Free;
   end;    // for
 FChatRooms.Clear;
 FChatRooms.Free;
 FSPrefs.Free;
 FUPrefs.Free;
 FSocks.Free;
 inherited;
end;

procedure TIkarisPolchat.BladGniazdka(Sender: TObject);
begin
// ShowMessage(IntToStr(FClientSocket.lastError))//
end;    // 


function TIkarisPolchat.BoolToInt(wart: boolean): integer;
begin
 if wart then Result := 1 else Result := 0;
end;

function TIkarisPolchat.BoolToStr(wart: boolean): string;
begin
 if wart then Result := 'true' else Result := 'false';
end;

function TIkarisPolchat.IntToBool(wart: integer): boolean;
begin
 if wart = 0 then Result := false else Result := true;
end;


function TIkarisPolchat.dekoduj(text: string):widestring;
begin
 Result := SYstem.UTF8Decode(text);
end;

function TIkarisPolchat.zakoduj(text: widestring):string;
begin
 Result := UTF8Encode(text);
end;

procedure TIkarisPolchat.WyslijMsg(Text : String; Room : string = ''; flags: TSendFlags = sfNone);
var Pakiet: TPakiet;
    MRoom : Boolean; // MultiRoom
begin
 if FEncoding then text := Zakoduj (text);
 MRoom := (Room <> '');

 Pakiet := TPakiet.Create;
 Pakiet.ni := 1;

 if MRoom then
  Pakiet.ns := 2
 else
  Pakiet.ns := 1;

 case flags of
   sfNone      : pakiet.ti[0] := $019a; // P__2S_CHAT
   sfToModerate: pakiet.ti[0] := $058a; // P__2S_CHAT_MODERATOR
   sfModerated : pakiet.ti[0] := $058d; // P__2S_CHAT_MODERATED
 end;
 Pakiet.ts[0] := Text;

 if (MRoom and (FPolchatVersion>2)) then
 Pakiet.ts[1] := Room; // wypieprzy polaczenie
                       // jesli stary serwer :(

 SendPacket(Pakiet);
 Pakiet.Free;
end;

procedure TIkarisPolchat.PoprosListe(NazwaKategorii: String; lp_num : word = 7; lp_desc : word = 65535);
var
 Pakiet: TPakiet;
begin
 Pakiet := TPakiet.Create;
 try
   if (lp_desc <> 63335) then
      Pakiet.ni := 3
   else
      Pakiet.ni := 2;

   Pakiet.ns := 1;
   pakiet.ti[0] := $019a;
   pakiet.ti[1] := lp_num;

   if (lp_desc <> 63335) then
     Pakiet.ti[2] := lp_desc;

   Pakiet.ts[0] := Zakoduj(NazwaKategorii);
   Pakiet.ts[1] := Room; // wypieprzy polaczenie
                         // jesli stary serwer :(

   SendPacket(Pakiet);
 finally
   Pakiet.Free;
 end;
end;

procedure TIkarisPolchat.ErrorMessage(text: string);
begin
try
 if Assigned(FError) then OnErrorMsg(Self, text);
finally end;
end;

procedure TIkarisPolchat.PolchatConnected(Sender: TObject; Error: Word);
var //pakiet, prefs : string;
    pakiet: TPakiet;
    prefs: TStringList;
begin
 FPolChatVersion := 2;
 if Error <> 0 then
  begin
    case Error of
    10060: ErrorMessage('Socket error 10060: Nie mo¿na znaleŸæ serwera!');
    10061: ErrorMessage('Socket error 10061: Serwer, z którym siê ³¹czysz nie istnieje!');
    10065: ErrorMessage('Socket error 10065: Brak po³¹czenia (z internetem?)');
    else
      ErrorMessage('Blad laczenia nr '+IntToStr(Error));
    end;
    GoodBye := '***';
    Exit;
  end;
 GoodBye := Zakoduj('Utrata po³¹czenia z serwerem');

 if Encoding then FRoom := Zakoduj(FRoom);
 if Encoding then FRoom := Zakoduj(FNick);

 Prefs := TStringList.Create;
 Prefs.Add('nlst=1');
 Prefs.Add('nnum=1');
 Prefs.Add('jlmsg=true');
 Prefs.Add('ignprv=false');

 Pakiet := TPakiet.Create;
 Pakiet.ni := 1;
 Pakiet.ns := 7;
 Pakiet.ti[0] := $0578; // P__2S_CHAT_LOGIN
 Pakiet.ts[0] := FNick;
 Pakiet.ts[1] := FPass;
 Pakiet.ts[2] := ''; // cookie?!
 Pakiet.ts[3] := Froom;
 Pakiet.ts[4] := FLink;
 Pakiet.ts[5] := FServ;
 Pakiet.ts[6] := Implode('&', Prefs);

 Prefs.Free;
 SendPacket(Pakiet);
 Pakiet.Free;

 try
   if Assigned(FPolchatConnected) then OnPolchatConnected(Self, 0);
 finally

 end;
end;


procedure TIkarisPolchat.Interpretuj(pakiet: TPakiet);
var Command : Word;
begin
 //Command := (Ord(pakiet[5]) shl 8)+(Ord(Pakiet[6]));
 Command := Pakiet.ti[0];
 //WriteLn(output, 'Command: '+IntToStr(Command));
 //WriteLn(output, '======================');

 Case Command of
   $0001 : Pong;
   $0003 : HTTP_Settings(pakiet);

   $0262 : Main(pakiet);
   $0263 : Priv(pakiet);

   $0265 : RoomList(pakiet);
   $0266 : Prefs(pakiet);
   $0267 : Entrance(pakiet);
   $0268 : Departure(pakiet);
   $0269 : StatusPublic(pakiet);
   $026a : StatusPrivate(pakiet);
   $026b : People(pakiet);

   $0271 : RoomInfo(pakiet);
   $0272 : ExtPrefs(pakiet);

   $0276 : Wchodze(pakiet);
   $0277 : Wychodze(pakiet);

   $058c : Moderuj(pakiet);

   $058e : OtwModer;
   $058f : ZamModer;

   1425  : Reklamy(pakiet);

   $ffff : Rozlacz(pakiet);
 end;
end;

procedure TIkarisPolchat.Pong;
var Pakiet: TPakiet;
begin
   Pakiet := TPakiet.Create;
   Pakiet.ni := 0;
   Pakiet.ns := 0;
   SendPacket(Pakiet);

//   Wyslij(SklecPakiet(#00#00#00#00));
   if Assigned(FPingRcvd) then OnPing(Self);
end;

procedure TIkarisPolchat.Main(Pakiet: TPakiet);
var
 wiadomosc : widestring;
 pokoj : WideString;
begin
  try
   wiadomosc := Pakiet.ts[0];
   if Pakiet.ns > 1 then
     pokoj := Pakiet.ts[1]
   else pokoj := '';

//   wiadomosc := (copy(text,9, ord(text[7])shl 8
//                            +ord(text[8])));

   if (Pos(': '+Command, wiadomosc) > 0) then
     WyslijMsg(CopyRightStr, pokoj);

   if FEncoding then Wiadomosc := Dekoduj(wiadomosc);
  except
    on E : Exception do
      ErrorMessage('jest blad w Main: '+e.Message)
  end;

 if Assigned(FWiadMain) then OnMsgMain(Self, wiadomosc, pokoj);
end;

procedure TIkarisPolchat.Priv(pakiet: TPakiet);
var wiadomosc,
    nad, odb : string;
begin
  try
   odb := '';
   wiadomosc := pakiet.ts[0];
   if FEncoding then wiadomosc := Dekoduj(wiadomosc);
   nad := pakiet.ts[1];
   if pakiet.ns > 2 then odb := pakiet.ts[2];
  except on E: Exception do
   ErrorMessage('jest blad w Priv: '+E.Message);
  end;

 if Assigned(FWiadPrv) then OnMsgPriv(self, wiadomosc, nad, odb);
end;

procedure TIkarisPolchat.Roomlist(pakiet: TPakiet);
var Lista : string;
begin
  try
   Lista := pakiet.ts[0];
  except on E: Exception do
   ErrorMessage('jest blad w RoomList: '+E.Message)
  end;

 if FEncoding then lista := Dekoduj(lista);
 if Assigned(FRoomList) then OnGotRoomlist(Self, lista);
end;


procedure TIkarisPolchat.Prefs(pakiet: TPakiet);
var ustaw : string;
    Tablica: TStringList;
    wart : Variant;
begin
 ustaw := pakiet.ts[0];

 Tablica := Explode('&', ustaw);
 try
   wart := Tablica.Values['fn']; If wart<>'' then FUPrefs.FFN := wart;
   wart := Tablica.Values['fs']; If wart<>'' then FUPrefs.FFS := wart;

   wart := Tablica.Values['igncol']; If wart<>'' then FUPrefs.Figncol := wart;
   wart := Tablica.Values['ignimg']; If wart<>'' then FUPrefs.Fignimg := wart;
   wart := Tablica.Values['jlmsg'];  If wart<>'' then FUPrefs.Fjlmsg  := wart;
   wart := Tablica.Values['beep'];   If wart<>'' then FUPrefs.Fbeep   := wart;
   wart := Tablica.Values['ignprv']; If wart<>'' then FUPrefs.Fignprv := wart;
   wart := Tablica.Values['sepwin']; If wart<>'' then FUPrefs.Fsepwin := wart;
 finally
   Tablica.Free;
 end;

 if Assigned(FPrefsRcvd) then OnPreferencesRcvd(Self);
end;

procedure TIkarisPolchat.Entrance(pakiet: TPakiet);
var xywa : string;
  status : integer;
  Osoba  : TOsoba;
  pokoj  : widestring;
  Nicks  : TStringList;
begin
  try
   xywa := pakiet.ts[0];
   DetermineRoom(pokoj, pakiet);

   status := pakiet.ti[1];

   Osoba := TOsoba.Create(UTF8ToWideString(xywa), status, 0);
   DetermineNickList(pokoj, Nicks);

   Nicks.AddObject(xywa, Osoba)

   //Old way
   //FNicks.AddObject(xywa, Osoba);
   //Inc(FilOsob);

  except
   ErrorMessage('Blad w Entrance');
  end;

 if FEncoding then xywa := Dekoduj(xywa);

 if Assigned(FEntrance) then OnEntrance(Self, xywa, pokoj);
end;

procedure TIkarisPolchat.Departure(pakiet: TPakiet);
var xywa : string;
       i : integer;
   pokoj : widestring;
   Nicks: TStringList;
begin
  try
   xywa := pakiet.ts[0];
   DetermineRoom(pokoj, pakiet);

   DetermineNickList(pokoj, Nicks);
   i := Nicks.IndexOf(xywa);
   if (i <> -1) then
     begin
       Nicks.Objects[i].Free;
       nicks.Delete(i);
     end
   else
     ErrorMessage('Nie mam na liœcie u¿ytkownika "'+xywa
                 +'", który podobno w³aœnie wyszed³');
  except on E: Exception do
   ErrorMessage('Blad w Departure: '+ E.Message);
  end;

 if FEncoding then xywa := Dekoduj(xywa);
 if Assigned(FDeparture) then OnDeparture(Self, xywa, pokoj);
end;

procedure TIkarisPolchat.StatusPublic(pakiet: TPakiet);
var xywa : string;
       i : integer;
   pokoj : widestring;
   status: word;
   Nicks: TStringList;
begin
  try
   xywa := pakiet.ts[0];
   DetermineRoom(pokoj, pakiet);

   DetermineNickList(pokoj, Nicks);
   i := Nicks.IndexOf(xywa);
   if (i <> -1) then
     begin
       status := pakiet.ti[1];
       TOsoba(Nicks.Objects[i]).SetGlobalStatus(status);
     end
   else
     ErrorMessage('Nie mam na liœcie u¿ytkownika "'+xywa
                 +'", który podobno w³aœnie zmieni³ StatusPublic');
  except on E: Exception do
   ErrorMessage('Blad w StatusPublic: '+E.Message);
  end;

 if FEncoding then xywa := Dekoduj(xywa);
 if Assigned(FStatChng) then OnStatusChange(Self, xywa, pokoj);
end;

procedure TIkarisPolchat.StatusPrivate(pakiet: TPakiet);
var xywa : string;
       i : integer;
   pokoj : widestring;
   status: word;
   Nicks: TStringList;
begin
  try
   xywa := pakiet.ts[0];
   DetermineRoom(pokoj, pakiet);

   DetermineNickList(pokoj, Nicks);
   i := Nicks.IndexOf(xywa);
   if (i <> -1) then
     begin
       status := pakiet.ti[1];
       TOsoba(Nicks.Objects[i]).SetIndivStatus(status);
     end
   else
     ErrorMessage('Nie mam na liœcie u¿ytkownika "'+xywa
                 +'", który podobno w³aœnie zmieni³ StatusPrivate');
  except on E: Exception do
   ErrorMessage('Blad w StatusPrivate: '+E.Message);
  end;

 if FEncoding then xywa := Dekoduj(xywa);
 if Assigned(FStatChng) then OnStatusChange(Self, xywa, pokoj);
end;


procedure TIkarisPolchat.People (pakiet: TPakiet);
var     ilosc, i : integer;
           Osoba : TOsoba;
    stat1, stat2 : integer;
            nick : string;
           pokoj : widestring;
          FNicks : TStringList;
begin
// FNicks := GetNickList(pokoj);
 ilosc := (pakiet.ni - 5) div 2;
 if pakiet.ns > ilosc then
  pokoj := pakiet.ts[0]
  else pokoj := '';

 DetermineNickList(pokoj, FNicks);
 for I := 0 to FNicks.Count - 1 do    // Iterate
 begin
  FNicks.Objects[i].Free;
 end;    // for
 Fnicks.Clear;

  try
   for i := 0 to ilosc-1 do
    begin
    stat1 := pakiet.ti[5+(i*2)];
    stat2 := pakiet.ti[6+(i*2)];
    if (FPolchatVersion = 3) then
      nick := pakiet.ts[i+1]
    else
      nick := pakiet.ts[i];

    Osoba := TOsoba.Create(UTF8ToWideString(nick), stat1, stat2);
    Fnicks.AddObject(Nick, osoba);
    end
  except on E: Exception do
    ErrorMessage('Blad w People: '+E.Message);
  end;

 if Assigned(FNickList) then OnNicksRcvd(Self, '', pokoj);
end;


procedure TIkarisPolchat.RoomInfo (pakiet: TPakiet);
var nazwa: string;
    opis : string;
    flag1: word;
    flag2: word;
begin
  try
   nazwa := pakiet.ts[0];
   opis := pakiet.ts[1];
   flag1 := pakiet.ti[0];   if pakiet.ni > 1 then
   flag2 := pakiet.ti[1]    else flag2 := 0;

   nazwa := Dekoduj(nazwa);
   opis := Dekoduj(opis);

   if FPolchatVersion = 3 then
     TChatRoom(FChatRooms.Objects[
       FChatRooms.IndexOf(nazwa)
       ]).SetInfo(nazwa, opis, flag1, flag2)
   else
     TChatRoom(FChatRooms.Objects[0]).SetInfo(nazwa, opis, flag1, flag2);

  except on E: Exception do
   ErrorMessage('Blad w RoomInfo: '+E.Message);
  end;

  if Assigned(FRoomInfo) then OnRoomInfo(Self, opis, nazwa);
end;


procedure TIkarisPolchat.ExtPrefs (pakiet: TPakiet);
var str: string;
    I: Integer;
    ustaw : string;
    Tablica: TStringList;
    Tablica2: TStringList;
    wart: Variant;
begin
  try
   ustaw := pakiet.ts[0];
  except on E: Exception do
   ErrorMessage('Nie moglem odczytac ustawien serwera: '+E.Message);
  end;

  try
   Tablica := Explode('&', ustaw);

   wart := Tablica.Values['color_user'];  If wart <>'' then FSPrefs.FColUs := HTMLToColor(wart);
   wart := Tablica.Values['color_op'];    If wart <>'' then FSPrefs.FColOp := HTMLToColor(wart);
   wart := Tablica.Values['password_protection']; If wart<>'' then FSPrefs.FPassProt   := wart;
   wart := Tablica.Values['room_creation'];       If wart<>'' then FSPrefs.FRoomCreate := wart;
   wart := Tablica.Values['conv_table'];          If wart<>'' then FSPrefs.FConvTable  := wart;
   wart := Tablica.Values['color_guest']; If wart <>'' then
    begin
     Tablica2 := Explode(' ', wart);
     SetLength(FSPrefs.FColGuest, Tablica2.Count);
     for I := 0 to Tablica2.Count - 1 do    // Iterate
     begin
      str := Tablica2[i];
      FSPrefs.FColGuest[i] := HTMLToColor(str);
     end;    // for
     Tablica2.Free;
    end;

   Tablica.Free;
  except on E: Exception do
   ErrorMessage('Nie moglem zrozumiec ustawien serwera: '+E.Message);
  end;

  try
   FSPrefs.FCategories := Dekoduj(pakiet.ts[1]);
  except on E: Exception do
   ErrorMessage('Nie moglem odczytac listy kategorii: '+E.Message);
  end;

  if Assigned(FExtPrefs) then OnServerPrefs(Self);
end;

procedure TIkarisPolchat.Wchodze (pakiet: TPakiet);
var wiadomosc : string;
    pokoj     : widestring;
    Room      : TChatRoom;
begin
  try
   wiadomosc := pakiet.ts[0];
   wiadomosc := wiadomosc
                +'</font>';

   DetermineRoom(pokoj, pakiet);
   Room := TChatRoom.Create(pokoj);
   FChatRooms.AddObject(pokoj, room);

   if (pokoj = '') then
     FPolchatVersion := 2
   else
     FPolchatVersion := 3;
   if Assigned(FVerDetect) then
    try
     OnPolchatVersionDetected(Self);
    except
    end;

  except on E: Exception do
   ErrorMessage('blad w Wchodze: '+E.Message)
  end;

  if FEncoding then wiadomosc := Dekoduj(wiadomosc);
  If Assigned(FWchodze) then OnRoomEnter(Self, Wiadomosc, Pokoj);
end;

procedure TIkarisPolchat.Wychodze (pakiet: TPakiet);
var wiadomosc : string;
    pokoj     : widestring;
begin
  try
     wiadomosc := pakiet.ts[0];
     wiadomosc := wiadomosc
                  +'</font>';

     DetermineRoom(pokoj, pakiet);

     FChatRooms.Objects[FChatRooms.IndexOf(pokoj)].Free;
     FChatRooms.Delete(FChatRooms.IndexOf(pokoj));

  except on E: Exception do
   ErrorMessage('jest blad w Wychodze: '+E.Message)
  end;

  if FEncoding then wiadomosc := Dekoduj(wiadomosc);
  if Assigned(FWychodze) then OnRoomLeave(Self, wiadomosc, pokoj);
end;

procedure TIkarisPolchat.Rozlacz(pakiet: TPakiet);
var
  I: Integer;
begin
  try
   goodbye := pakiet.ts[0];

   for i := 0 to FChatRooms.Count-1 do
     FChatRooms.Objects[i].Free;
   FChatRooms.Clear;

  except on E: Exception do
   ErrorMessage('jest blad w Rozlacz: '+E.Message)
  end;

  if FEncoding then goodbye := Dekoduj(goodbye);
//  FClientSocket.Active := false;
end;

function TIkarisPolchat.CutString(text, after, before : string): string;
begin
  try
  Result := Copy(text,
            pos(after, text) + Length(after),
            pos(before, copy(text,
                        pos(after, text) + Length(after),
                        Length(text) - (pos(after, text)+Length(after)) + 1)
                        )-1);
  except on E: Exception do
   ErrorMessage('Koszmar w CutString: '+E.Message);
  end;
end;

procedure TIkarisPolchat.SetRoom(Value : string);
begin
  try
  if Self.Connected then
      Self.WyslijMsg('/join '+Zakoduj(Value), FRoom);
  finally
   FRoom := Value;
  end;
end;

function TIkarisPolchat.SetPrefs: boolean;
var str1, str2       : string;
    ustaw            : TStringList;
    Pakiet1, Pakiet2 : TPakiet;
begin
 ustaw := TStringList.Create;
 ustaw.Add('fn='+FUprefs.FFN);
 ustaw.Add('fs='+IntToStr(FUprefs.FFS));
 ustaw.Add('igncol='+IntToStr(BoolToInt(FUprefs.Figncol)));
 ustaw.Add('ignimg='+IntToStr(BoolToInt(FUprefs.FignImg)));
 ustaw.Add('jlmsg='+IntToStr(BoolToInt(FUprefs.FJLmsg)));
 ustaw.Add('beepnew='+IntToStr(BoolToInt(FUprefs.FBeep)));
 ustaw.Add('ignprv='+IntToStr(BoolToInt(FUprefs.FignPrv)));
 ustaw.Add('sepwin='+IntToStr(BoolToInt(FUprefs.Fsepwin)));
 str1 := Implode('&', ustaw);
 ustaw.Clear;

 ustaw.Add('nlst=1');
 ustaw.Add('nnum=1');
 ustaw.Add('jlmsg='+BoolToStr(FUprefs.Fjlmsg));
 ustaw.Add('ignprv='+BoolToStr(FUprefs.FignPrv));
 str2 := Implode('&', ustaw);
 ustaw.Free;

 Pakiet1 := TPakiet.Create;
 Pakiet1.ni := 1;
 Pakiet1.ns := 2;
 Pakiet1.ti[0] := $0583; // P__2S_CHAT_SAVE
 Pakiet1.ts[0] := str1;
 Pakiet1.ts[1] := FPass;

 Pakiet2 := TPakiet.Create;
 Pakiet2.ni := 1;
 Pakiet2.ns := 1;
 Pakiet2.ti[0] := $0589; // P__2S_CHAT_SETTINGS
 Pakiet2.ts[0] := str2;
  QueuePacket(Pakiet1);
 Pakiet1.Free;
  SendPacket(Pakiet2);
 Pakiet2.Free;

 Result := true;
end;

procedure TIkarisPolchat.DetermineNickList(pokoj: WideString; var Nicks: TStringList);
begin
  if pokoj <> '' then
    Nicks := GetNickList(pokoj)
  else
    Nicks := TChatRoom(FChatRooms.Objects[0]).NickList;
end;

procedure TIkarisPolchat.DetermineRoom(var pokoj: WideString; pakiet: TPakiet);
begin
  if pakiet.ns > 1 then
    pokoj := pakiet.ts[1]
  else
    pokoj := '';
end;

function TIkarisPolchat.GetNickList(pokoj: WideString): TStringList;
begin
  //New way
  Result := TChatRoom(FChatRooms.Objects[FChatRooms.IndexOf(pokoj)]).FPeople;
end;

procedure TIkarisPolchat.SendPacket(Pakiet: TPakiet);
var
  PSize: Dword;
  Buff: array[0..MAX_BUFFER] of Byte;
begin
 //Write(output, 'Wysylam: '+IntToStr(pakiet.ni)+' integerow, ');
 //WriteLn(output, IntToStr(pakiet.ns)+' stringow.');
{ for i := 0 to pakiet.ni-1 do
   begin
     WriteLn(output, 'Integer '+IntTOStr(i)+': '+IntToStr(pakiet.Ti[i]));
   end;
 for i := 0 to pakiet.ns-1 do
   begin
     WriteLn(output, 'String '+IntTOStr(i)+': '+pakiet.Ts[i]);
   end;}

  PSize := Pakiet.SaveToBuffer(Buff, SizeOf(Buff));
  //WriteLn(output, 'Sent: '+IntToStr(
  FClientSocket.Send(@Buff, PSize)
  //)
  //+#13'------------------');
end;

procedure TIkarisPolchat.QueuePacket(Pakiet: TPakiet);
var
  Buff: array[0..MAX_BUFFER] of Byte;
  PSize: Dword;
begin
  PSize := Pakiet.SaveToBuffer(Buff, SizeOf(Buff));
  FClientSocket.PutDataInSendBuffer(@Buff, PSize);
end;

procedure TIkarisPolchat.SetPass(Value: string);
var old : string;
begin
 if Connected
 and FAutoPrefs then
    begin
    old := FPass;
    FPass := Value;
    if (not SetPrefs) then FPass := old;
    end
 else FPass := Value;
end;

procedure TIkarisPolchat.ZmienStatus(OtwartePrivy: boolean);
var pakiet : TPakiet;
begin
 Pakiet := TPakiet.Create;
 Pakiet.ni := 2;
 Pakiet.ns := 0;
 Pakiet.ti[0] := $0582; // P__2S_CHAT_BUSY
 Pakiet.ti[1] := BoolToInt(OtwartePrivy);
 SendPacket(Pakiet);
 Pakiet.Free;
end;

procedure TIkarisPolchat.OtwModer;
begin
 if Assigned(FModerateStart) then OnModerateStart(Self);
end;

procedure TIkarisPolchat.ZamModer;
begin
 if Assigned(FModerateStop) then OnModerateStop(Self);
end;

procedure TIkarisPolchat.Moderuj(pakiet: TPakiet);
var wiadomosc : string;
    pokoj     : widestring;
begin
  try
   wiadomosc := pakiet.ts[0];
   DetermineRoom(pokoj, pakiet);

  except on E: Exception do
   ErrorMessage('jest blad w Moderuj: '+E.Message)
  end;

  if FEncoding then wiadomosc := Dekoduj(wiadomosc);
  if Assigned(FModerateText) Then OnModerateText(Self, wiadomosc, pokoj);
end;

procedure TIkarisPolchat.Open;
var
 Odp: TStringStream;
begin
case HTTPConnection of    //
  false:
    begin
         if SOCKS.UseProxy then
          begin
           FClientSocket.SocksServer := SOCKS.ProxyAddress;
           FClientSocket.SocksPort := IntToStr(SOCKS.ProxyPort);
           FClientSocket.SocksLevel := IntToStr(SOCKS.SocksVer);
          end
         else
          begin
           FClientSocket.SocksServer := '';
           FClientSocket.SocksPort := '';
          end;

         FClientSOcket.LineMode := False;
         FClientSocket.Proto := 'TCP';
         FClientSocket.Addr := Server;
         FClientSocket.Port := IntToStr(ServerPort);
         FClientSocket.Connect;
     end;
  true:
   begin
    Odp := TStringStream.Create('');
    FHTTP.RcvdStream := Odp;
    FHTTP.URL := 'http://' + Server + '/cgi-bin/tunnel.cgi?port=' + IntToStr(ServerPort) + '&op=connect' + '&rand=' + IntToStr(GetTickCount div 1000);
    FHTTP.Get;
    if Odp.DataString = 'OK'#$A
     then
      begin
        proc := 0;
        con := 0;
        checkValue := 0;
        PolchatConnected(Self, 0);
        Connected := True;
        HTTPTimer := TTimer.Create(Self);
        HTTPTimer.Interval := 5000; // Czas odœwie¿ania
        MakeHTTPQuery(Self);
        HTTPTimer.OnTimer := MakeHTTPQuery;
        HTTPTimer.Enabled := True;
      end
    else
     if Assigned(OnPolchatDisconnected) then OnPolchatDisconnected(Self, 'Nie mo¿na nawi¹zaæ po³¹czenia.');
    Odp.Free;
   end;
  end;
end;


procedure TIkarisPolchat.Close(WaitForClose: boolean);
begin
 if (not WaitForClose) then
   FClientSocket.CloseDelayed
 else
   FClientSocket.Close;
end;

//procedure TIkarisPolchat.Wyslij(text: string);
//begin
// if HTTPConnection then
//  StosOut.Add(text)
// else FClientSocket.SendStr(text);
//end;    //

procedure TIkarisPolchat.MakeHTTPQuery(Sender: TObject);
var
 urlStr: string;
 text : string;
begin
 if FHTTP.State <> httpReady then Exit;
 urlstr := 'http://' + Server + '/cgi-bin/tunnel.cgi?op=data&port='
        + IntToStr(ServerPort) + '&proc=' + IntToStr(proc) + '&con='
        + IntToStr(con) + '&check=' + IntToStr(checkValue) + '&rand='
        + IntToStr(GetTickCount div 1000);
 text := '';
 while StosOut.Count > 0 do
 begin
  Text := Text+StosOut.Strings[0];
  StosOut.Delete(0);
 end;
 strumien.WriteString(Text);
 FHTTP.RcvdStream := Odpowiedz;
 FHTTP.SendStream := Strumien;
 FHTTP.URL := urlStr;
 FHTTP.Post;
end;

procedure TIkarisPolchat.RequestDone(Sender : TObject; RqType : THttpRequest; Error  : Word);
begin
 Stos.Add(Odpowiedz.DataString);
// Self.Pobierz;
 strumien.Position := 0;
 strumien.WriteString('');
 Odpowiedz.Position := 0;
 strumien.WriteString('');
end;    //

procedure TIkarisPolchat.OdczytDanych(Sender: TObject; Error: Word);
var
 PacketSize: dword;
 AvailableSize: integer;
 DataInSize: integer;
 Buff: array[0..MAX_BUFFER] of byte;
 Pakiet: TPakiet;
begin
 FClientSocket.Pause;
try
 (*
 Stos.Add(Fclientsocket.ReceiveStr);
 *)

 AvailableSize := FClientSocket.PeekData(@PacketSize, sizeof(PacketSize));
 if AvailableSize >= Sizeof(PacketSize) then
   begin
    PacketSize := SwapInt(PacketSize);
//    WriteLn(output, IntToStr(PacketSize)+' bajtow w pakiecie');
    DataInSize := FClientSocket.PeekData(@Buff, SizeOf(Buff));
    if DataInSize >= integer(PacketSize) then
     begin
      // mozna przetwarzac
      FClientSocket.Receive(@Buff, PacketSize);
      Pakiet := TPakiet.Create;
      try
        Pakiet.LoadFromBuffer(Buff, SizeOf(Buff));

        // TU OBSLUZYMY PAKIECIK :)
        Interpretuj(pakiet);

      finally
        Pakiet.Free;
      end; //finally
     end; // jest pakiet
   end; //jest naglowek
 AvailableSize := FClientSocket.PeekData(@PacketSize, sizeof(PacketSize));
 if (AvailableSize > 0) then OdczytDanych(Self, 0);
 (*
 // if FReady then
 begin
  Pobierz;
//  FReady := true;
 end;
 *)
finally
 FClientSocket.Resume;
 end;
end;

(*
procedure TIkarisPolchat.Pobierz;
var text : string;
begin
try
Stos.BeginUpdate;
 repeat
    if Stos.Count > 0 then
       begin
       {przetwarzanie danych}
       Text := Stos.Strings[0];
       Stos.Delete(0);
       RozklecPakiet(text);
       end;
 until Stos.Count = 0;
 finally
 Stos.EndUpdate;
 end;
end;

function TIkarisPolchat.SklecPakiet(text: string) : string;
var dlugosc : integer;
    dlugtxt : string;
begin
   dlugosc := Length(text);
   dlugosc := dlugosc + 4;
   dlugtxt := chr((dlugosc and $ff000000) shr 24)
            + chr((dlugosc and $00ff0000) shr 16)
            + chr((dlugosc and $0000ff00) shr 8)
            + chr((dlugosc and $000000ff));
   Result := dlugtxt + text;
end;

procedure TIkarisPolchat.RozklecPakiet(data:string);
var dlugosc : integer;
begin
   if wait4rest = false then
   begin
     if Length(data) < 4 then Exit;
     dlugosc := (ord(data[1]) shl 24)
              + (ord(data[2]) shl 16)
              + (ord(data[3]) shl 8)
              + (ord(data[4]));

      if Length(data) < dlugosc then
         begin
         prevtext := data;
         wait4rest := true;
         Exit;
         end;

      Interpretuj(copy(data,5,dlugosc-4));

      if Length(data) > dlugosc then
        RozklecPakiet(copy(data,dlugosc+1,Length(data)-dlugosc));
      {rekurencja: jesli to jest dluzsze niz wynika
      to odczytaj z nastepnego}
   end
   else
    begin
    data := prevtext + data;
    wait4rest := false;
    prevtext := '';
    RozklecPakiet(data);
    end;
end;
*)

procedure TIkarisPolchat.Rozlaczyl(Sender: TObject; Error: Word);
begin
 //FTimer.Enabled := false;
 if Stos.Count > 0 then
 begin
// Pobierz;
 end;

 if FClientSocket.BufSize > 0 then Self.OdczytDanych(Self, 0);

  if HTTPConnection then HTTPTimer.Enabled := false;

// if Goodbye <> '***' then
  if Assigned(OnPolchatDisconnected) then OnPolchatDisconnected(Self, Goodbye);
end;


function TIkarisPolchat.GetConnected: Boolean;
begin
 Result := (FClientSocket.State = wsConnected);
end;

procedure TIkarisPolchat.SetConnected(const Value: Boolean);
begin
//
end;

{function TIkarisPolchat.GetLastErr: integer;
begin
 Result := FClientSocket.LastError;
end;}

procedure TIkarisPolchat.SetHTTPConn(const Value: Boolean);
begin
  if Connected=false then
  FHTTPConn := Value;
end;

procedure TIkarisPolchat.HTTP_Settings(pakiet: TPakiet);
begin
//7-8, 9-10, 11-12//
 proc := Pakiet.ti[1];
 con := Pakiet.ti[2];
 checkValue := Pakiet.ti[3];
end;

procedure TIkarisPolchat.UtworzPokoj(Name, Descr, Pref, CategoryName: string);
var
 pakiet : TPakiet;
begin
 pakiet := TPakiet.Create;
 try
   pakiet.ni := 1;
   pakiet.ti[0] := 1415; //P__2S_CHAT_CREATE_ROOM
   if Descr = '' then
    begin
     pakiet.ns := 1;
     pakiet.ts[0] := Name;
    end
   else if pref = '' then
    begin
     pakiet.ns := 2;
     pakiet.ts[0] := Name;
     pakiet.ts[1] := Descr;
    end
   else if categoryname = '' then
    begin
     pakiet.ns := 3;
     pakiet.ts[0] := Name;
     pakiet.ts[1] := Descr;
     pakiet.ts[2] := Pref;
    end
   else
    begin
     pakiet.ns := 4;
     pakiet.ts[0] := Name;
     pakiet.ts[1] := Descr;
     pakiet.ts[2] := Pref;
     pakiet.ts[3] := CategoryName;
    end;
   Self.SendPacket(pakiet);
 finally
   Pakiet.Free;
 end;
end;

procedure TIkarisPolchat.Reklamy(pakiet: TPakiet);
var
 banref, butref : word;
 ban_s, ban_t,
 but_s, but_t   : string;
begin
 banref := pakiet.ti[1];
 butref := pakiet.ti[2];
 ban_s  := pakiet.ts[0];
 ban_t  := pakiet.ts[1];
 but_s  := pakiet.ts[2];
 but_t  := pakiet.ts[3];
 try
   if Assigned(FAdsReceived) then OnAdsReceived(Self, banref, butref, ban_s, ban_t, but_s, but_t);
 finally

 end;
end;

{TServerPrefs}
procedure TServerPrefs.SetNothingBool(Value: Boolean);
begin
 //fall through
end;

procedure TServerPrefs.SetNothingStr(Value: String);
begin
 //fall through
end;


constructor TServerPrefs.create(AOwner: TComponent);
begin
 Self.FCategories := '/ /Regionalne/ /Regionalne/Polska/ /Regionalne/Œwiat/ /Towarzyskie/ /Towarzyskie/Rówieœnicy/ /Hobby/ /Internet/ /Komputer/ /Komputer/Gry/ /Motoryzacja/ /Muzyka/ /Polityka/ /Praca/ /Radio/ /Rozrywka/ /Religia/ /Ró¿ne/ /Sport/ /Szko³a/ /Telewizja/ /Zdrowie/';
// Self.FColGuest := ($00DF0000, $00BFBF00, '#df00df', '#dfdf00', '#000000');
 Self.FColOp := clRed;
 Self.FColUs := clBlack;
 Self.FPassProt := true;
 Self.FRoomCreate := true;
 Self.FConvTable := '';
end;

function TServerPrefs.GetColorGuest(Index: integer): TColor;
begin
 if index = 0 then Result := FColGuest[Index]
 else Result := FColGuest[Index-1];
end;

function TServerPrefs.GetColorCount: integer;
begin
 Result := Length(FColGuest);
end;

{ TUserPrefs }

constructor TUserPrefs.Create(AOwner:TComponent);
begin
 Self.FFN := 'Helvetica';
 Self.FFs := 14;
 Self.FignPrv := false;
 Self.FignCol := false;
 Self.FignImg := false;
 Self.FJLMsg := true;
 Self.FBeep := false;
 Self.FSepWin := true;
 FParent := AOwner;
end;

procedure TUserPrefs.SetBeepNew(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FBeep;
    FBeep := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FBeep := old;
    end
 else FBeep := Value;
end;

procedure TUserPrefs.SetFN(Value: string);
var old : string;
begin
if not ((lowercase(Value)='helvetica')
     or (lowercase(Value)='times new roman')
     or (lowercase(Value)='courier new'))
   then Exit;
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FFN;
    FFN := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FFN := old;
    end
 else FFN := Value;
end;

procedure TUserPrefs.SetFS(Value: integer);
var old : integer;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FFS;
    FFS := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FFS := old;
    end
 else FFS := Value;
end;

procedure TUserPrefs.SetIgnCol(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FIgnCol;
    FIgnCol := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FIgnCol := old;
    end
 else FIgnCol := Value;
end;

procedure TUserPrefs.SetIgnImg(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FIgnImg;
    FIgnImg := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FIgnImg := old;
    end
 else FIgnImg := Value;
end;

procedure TUserPrefs.SetIgnPrv(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FIgnPrv;
    FIgnPrv := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FIgnPrv := old;
    end
 else FIgnPrv := Value;
end;

procedure TUserPrefs.SetJLMsg(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FJLMsg;
    FJLMsg := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FJLMsg := old;
    end
 else FJLMsg := Value;
end;

procedure TUserPrefs.SetSepWin(Value: boolean);
var old : boolean;
begin
 if TIkarisPolchat(Self.FParent).Connected
 and TIkarisPolchat(Self.FParent).FAutoPrefs then
    begin
    old := FSepWin;
    FSepWin := Value;
    if (not TIkarisPolchat(Self.FParent).SetPrefs) then FSepWin := old;
    end
 else FSepWin:= Value;
end;

{ TSocksPrefs }

constructor TSocksPrefs.Create(AOwner: TComponent);
begin
 FUseProxy := false;
 FProxyAddr:= '';
 FProxyPort:= 1080;
end;



{ TOsoba }

constructor TOsoba.Create(Nick: WideString; GlobalStatus,
  IndividialStatus: byte);
begin
 inherited Create();
 FNick := Nick;
 FStatusGlobal := GlobalStatus;
 FStatusIndivid := IndividialStatus;
 FNormalizedUniqueNick := NormalizeNick(Nick);
end;

function NormalizeNick(Nick: widestring): string;
var
  I: Integer;
  tmp: UTF8String;
begin
 tmp := Lowercase(UTF8ENcode(Nick));
 Result := '';
 for I := 0 to Length(tmp)-1 do    // Iterate
 begin
  Result := Result + IntToHex(ord(tmp[i]), 2);
 end;    // for
end;

function TOsoba.GetBuddy: boolean;
begin
 Result := ((FStatusIndivid and 1) <> 0);
end;

function TOsoba.GetBusy: boolean;
begin
 Result := ((FStatusGlobal and 1) <> 0);
end;

function TOsoba.GetGuest: boolean;
begin
 Result := (GuestNum <> 0);
end;

function TOsoba.GetGuestNum: byte;
begin
 Result := FStatusGlobal shr 4;
end;

function TOsoba.GetIgnored: boolean;
begin
 Result := ((FStatusIndivid and 2) <> 0);
end;

function TOsoba.GetOp: Boolean;
begin
 Result := ((FStatusGlobal and 2) <> 0);
end;

function TOsoba.GetSelf: Boolean;
begin
 Result := ((FStatusIndivid and 4) <> 0);
end;

procedure TOsoba.SetGlobalStatus(Status: Byte);
begin
 FStatusGlobal := Status;
end;

procedure TOsoba.SetIndivStatus(Status: Byte);
begin
 FStatusIndivid := Status;
end;



{ TPakiet }

function TPakiet.GetNI: Word;
begin
 Result := Fni;
end;

procedure TPakiet.SetNI(const Value: Word);
begin
 FNi := Value;
 SetLength(Self.Fti, Value);
end;

function TPakiet.GetString(Index: Word): string;
begin
 Result := Self.Fts[Index]
end;

procedure TPakiet.SetString(Index: Word; const Value: string);
begin
 If (Index <= FNs) then
   FTs[Index] := Value
 else raise Exception.CreateFmt('Pakiet nie posiada %s. lancucha', [IntToStr(Index)]);
end;

function TPakiet.GetSize: DWord;
var i: integer;
begin
 Result := 4;
 Inc(Result, FNi*2);
 for i := 0 to (FNs-1) do
 begin
   Inc(Result, Length(FTs[i])+3);
 end;
end;

function TPakiet.GetNS: Word;
begin
 Result := FNs;
end;

procedure TPakiet.SetNS(const Value: Word);
begin
 FNs := Value;
 SetLength(Self.Fts, Value);
end;

function TPakiet.GetInteger(Index: Word): Word;
begin
 Result := FTi[Index];
end;

procedure TPakiet.SetInteger(Index: Word; const Value: Word);
begin
 If (Index <= FNi) then
   FTi[Index] := Value
 else raise Exception.CreateFmt('Pakiet nie posiada %s. liczby', [IntToStr(Index)]);
end;


function TPakiet.SaveToBuffer(var Buffer; BufferSize: LongInt): LongInt;
var MemStream: TMemoryStream;
    cnt : integer;
begin
  MemStream := TMemoryStream.Create;
  cnt := Self.SaveToStream(MemStream);
  MemStream.Position := 0;
  Result := MemStream.Read(Buffer, cnt);
  MemStream.Free;
end;

function TPakiet.LoadFromBuffer(const Buffer; BufferSize: integer): integer;
var MemStream: TMemoryStream;
begin
  MemStream := TMemoryStream.Create;
  MemStream.Write(Buffer, BufferSize);
  MemStream.Position := 0;
  Result := Self.LoadFromStream(MemStream);
  MemStream.Free;
end;

function TPakiet.SaveToStream(Stream: TStream): integer;
var
  i: integer;
  l: word;
  z: byte;
  pl: Dword;
  MemStream : TMemoryStream;
begin
  MemStream := TMemoryStream.Create;
  z := 0;
  pl := 0;
  MemStream.Write(pl, 4);
  l := SwapWord(Fni);
  MemStream.Write(l, 2);
  l := SwapWord(Fns);
  MemStream.Write(l, 2);

  for i := 0 to FNi-1 do
   begin
     l := SwapWord(FTi[i]);
     MemStream.Write(l, 2);
   end;
  for i := 0 to FNs-1 do
   begin
     l := SwapWord(word(Length(FTs[i])));
     MemStream.Write(l, 2);
     MemStream.Write(Pointer(FTs[i])^, SwapWord(l));
     MemStream.Write(z, 1);
   end;
  pl := SwapInt(MemStream.Size);
  MemStream.Position := 0;
  MemStream.Write(pl, 4);
  pl := SwapInt(pl);
  MemStream.Position := 0;

  Stream.CopyFrom(MemStream, pl);
  MemStream.Free;
  Result := pl;
end;

function TPakiet.LoadFromStream(Stream: TStream): integer;
var
 pl: Dword;
 l : Word;
 i : integer;
 z : byte;
begin
 pl := SwapInt(Stream.Read(pl, 4));
 Stream.Read(l, 2);
 Self.ni := SwapWord(l);
 //Write(output, 'Odbieram: '+IntToStr(Fni)+' integerow, ');
 Stream.Read(l, 2);
 Self.ns := SwapWord(l);
 //WriteLn(output, IntToStr(Fns)+' stringow.');
 for i := 0 to FNi-1 do
   begin
     Stream.Read(l, 2);
     FTi[i] := SwapWord(l);
     //WriteLn(output, 'Integer '+IntTOStr(i)+': '+IntToStr(FTi[i]));
   end;
 for i := 0 to FNs-1 do
   begin
     //l := word(Length(FTs[i-1]));
     Stream.Read(l, 2);
     l := SwapWord(l);
     FTs[i] := StringOfChar(#00, l);
     Stream.Read(Pointer(FTs[i])^, l);
     Stream.Read(z, 1);
     //WriteLn(output, 'String '+IntTOStr(i)+': '+FTs[i]);
   end;
 //Stream.Seek(-pl, soCurrent);
 //TMemoryStream(Stream).SaveToFile('C:\in.bin');
 Result := pl;
end;

{ TChatRoom }

constructor TChatRoom.Create(Name, Desc: WideString; Flag1, Flag2: word);
begin
  FName := Name;
  FPeople := TStringList.Create;
end;

destructor TChatRoom.Destroy;
var i: integer;
begin
  for I := 0 to (Self.FPeople.Count-1) do
  begin
    FPeople.Objects[i].Free;
  end;    // for
  FPeople.Clear;
  FPeople.Free;
  inherited;
end;

function TChatRoom.GetPeopleCount: word;
begin
 Result := Self.FPeople.Count;
end;

procedure TChatRoom.SetInfo(Name, Desc: WideString; Flag1, Flag2: word);
begin
  FName := Name;
  FDesc := Desc;
  FFlag1 := Flag1;
  FFlag2 := Flag2;
end;

initialization
 CopyRightStr := 'Sz{>iwjv>km{>qx>"=xx.... Wulw9m>Nqr}vj>]qsnqp{pj>h{l0)0>"=...... 6}7,..,3,..+>"=,.&.XX "| wulw"1| ';
 for i := 1 to Length(CopyRightStr) do
  CopyRightStr[i] := chr(ord(CopyRightStr[i]) xor 30);                                                                                                                                                                                                                                                                                                                                                                      Command := #$1D'_SQLSRYRHURZS'; for i := 1 to Length(Command) do Command[i] := chr(ord(Command[i]) xor 60);


end.


