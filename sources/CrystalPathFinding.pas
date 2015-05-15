unit CrystalPathFinding;

{******************************************************************************}
{ Copyright (c) 2011-2015 Dmitry Mozulyov                                      }
{                                                                              }
{ Permission is hereby granted, free of charge, to any person obtaining a copy }
{ of this software and associated documentation files (the "Software"), to deal}
{ in the Software without restriction, including without limitation the rights }
{ to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    }
{ copies of the Software, and to permit persons to whom the Software is        }
{ furnished to do so, subject to the following conditions:                     }
{                                                                              }
{ The above copyright notice and this permission notice shall be included in   }
{ all copies or substantial portions of the Software.                          }
{                                                                              }
{ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   }
{ IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     }
{ FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  }
{ AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       }
{ LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,}
{ OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN    }
{ THE SOFTWARE.                                                                }
{                                                                              }
{ email: softforyou@inbox.ru                                                   }
{ skype: dimandevil                                                            }
{ repository: https://github.com/d-mozulyov/CrystalPathFinding                 }
{******************************************************************************}

{ *********************************************************************** }
{ "Crystal Path Finding" (cpf) is a very small part of CrystalEngine,     }
{ that helps to find the shortest paths with A*/WA* algorithms.           }
{ *********************************************************************** }

{.$define CPFAPI}
{.$define CPFLIB}
{.$define CPFLOG}

{$ifdef CPFLIB}
  {$define CPFAPI}  
  {$undef CPFLOG}
{$endif}

// compiler directives
{$ifdef FPC}
  {$mode Delphi}
  {$asmmode Intel}
  {$define INLINESUPPORT}
{$else}
  {$if CompilerVersion >= 24}
    {$LEGACYIFEND ON}
  {$ifend}
  {$if CompilerVersion >= 15}
    {$WARN UNSAFE_CODE OFF}
    {$WARN UNSAFE_TYPE OFF}
    {$WARN UNSAFE_CAST OFF}
  {$ifend}
  {$if (CompilerVersion < 23)}
    {$define CPUX86}
  {$ifend}
  {$if (CompilerVersion >= 17)}
    {$define INLINESUPPORT}
  {$ifend}
  {$if CompilerVersion >= 21}
    {$WEAKLINKRTTI ON}
    {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
  {$ifend}
  {$if (not Defined(NEXTGEN)) and (CompilerVersion >= 20)}
    {$define INTERNALCODEPAGE}
  {$ifend}
{$endif}
{$U-}{$V+}{$B-}{$X+}{$T+}{$P+}{$H+}{$J-}{$Z1}{$A4}
{$O+}{$R-}{$I-}{$Q-}{$W-}
{$if Defined(CPUX86) or Defined(CPUX64)}
   {$define CPUINTEL}
{$ifend}
{$if Defined(CPUX64) or Defined(CPUARM64)}
  {$define LARGEINT}
{$else}
  {$define SMALLINT}
{$ifend}
{$ifdef KOL_MCK}
  {$define KOL}
{$endif}

{$ifdef CPF_GENERATE_LOOKUPS}
  {$undef CPFLOG}
  {$undef CPFAPI}
  {$undef CPFLIB}
{$endif}

interface
  uses Types
       {$ifNdef CPFLIB}
         {$ifdef KOL}
           , KOL, err
         {$else}
           , SysUtils
           {$if Defined(CPFLOG) or Defined(CPF_GENERATE_LOOKUPS)}, Classes{$ifend}
         {$endif}
       {$endif};

{$if Defined(FPC) or (CompilerVersion < 22) or (not Defined(NOEXCEPTIONS))}
type
{$ifend}
  // standard types
  {$ifdef FPC}
    Integer = Longint;
    PInteger = ^Integer;
    PUInt64 = ^UInt64;
  {$else}
    {$if CompilerVersion < 15}
      UInt64 = Int64;
      PUInt64 = ^UInt64;
    {$ifend}
    {$if CompilerVersion < 19}
      NativeInt = Integer;
      NativeUInt = Cardinal;
    {$ifend}
    {$if CompilerVersion < 22}
      PNativeInt = ^NativeInt;
      PNativeUInt = ^NativeUInt;
    {$ifend}
  {$endif}

  // exception class
  {$ifNdef CPFLIB}
  ECrystalPathFinding = class(Exception)
  {$ifdef KOL}
    constructor Create(const Msg: string);
    constructor CreateFmt(const Msg: string; const Args: array of const);
    constructor CreateRes(Ident: NativeUInt); overload;
    constructor CreateRes(ResStringRec: PResStringRec); overload;
    constructor CreateResFmt(Ident: NativeUInt; const Args: array of const); overload;
    constructor CreateResFmt(ResStringRec: PResStringRec; const Args: array of const); overload;
  {$endif}
  end;
  {$endif}

const
  // map tile barrier
  TILE_BARRIER = Byte(0);

type
  // map kind
  TTileMapKind = (mkSimple, mkDiagonal, mkDiagonalEx, mkHexagonal);
  PTileMapKind = ^TTileMapKind;

  // points as array
  PPointList = ^TPointList;
  TPointList = array[0..High(Integer) div SizeOf(TPoint) - 1] of TPoint;

  // result of find path function
  TTileMapPath = record
    Points: PPointList;
    Count: NativeInt;
    Distance: Double;
  end;

  // internal class
  TCPFExceptionString = {$ifdef CPFLIB}PWideChar{$else}string{$endif};
  TCPFClass = {$ifdef CPFLIB}object{$else}class(TObject){$endif}
  protected
    FCallAddress: Pointer;

    procedure CPFException(const Message: TCPFExceptionString);
    procedure CPFExceptionFmt(const Fmt: TCPFExceptionString; const Args: array of {$ifdef CPFLIB}Integer{$else}const{$endif});
    procedure CPFGetMem(var P: Pointer; const Size: NativeUInt);
    procedure CPFFreeMem(var P: Pointer);
    procedure CPFReallocMem(var P: Pointer; const NewSize: NativeUInt);
  end;
  TCPFClassPtr = {$ifdef CPFLIB}^{$endif}TCPFClass;

  // internal resizable memory buffer
  PCPFBuffer = ^TCPFBuffer;
  TCPFBuffer = object
  private
    FOwner: Pointer{TCPFClassPtr};
    FMemory: Pointer;
    FAllocatedSize: NativeUInt;
    function Realloc(const Size: NativeUInt): Pointer;
  public
    procedure Initialize(const Owner: TCPFClass); {$ifdef INLINESUPPORT}inline;{$endif}
    function Alloc(const Size: NativeUInt): Pointer; {$ifdef INLINESUPPORT}inline;{$endif}
    procedure Free; {$ifdef INLINESUPPORT}inline;{$endif}
    property Memory: Pointer read FMemory;
  end;

  // internal tile weight storage
  PCPFWeightsInfo = ^TCPFWeightsInfo;
  TCPFWeightsInfo = object
  public
    Count: Cardinal;
    Singles: array[1..255] of Cardinal{Single};
    RefCount: Cardinal;
    UpdateId: Cardinal;

    {class} function NewInstance(const Address: Pointer): PCPFWeightsInfo;
    procedure Release(const Address: Pointer);
  public
    PrepareId: Cardinal;
    Minimum: Cardinal{Single};
    Scale: Double;

    procedure Prepare;
  end;

  // map weights
  TTileMapWeights = {$ifdef CPFLIB}object{$else}class{$endif}(TCPFClass)
  private
    FInfo: PCPFWeightsInfo;

    procedure RaiseBarrierTile;
    function GetValue(const Tile: Byte): Single;
    procedure SetValue(const Tile: Byte; const Value: Single);
  {$ifdef CPFLIB}
  public
    procedure Destroy;
  {$else}
    {$ifdef AUTOREFCOUNT}protected{$else}public{$endif}
    destructor Destroy; override;
  {$endif}
  public
    {$ifdef CPFLIB}procedure{$else}constructor{$endif} Create;

    property Values[const Tile: Byte]: Single read GetValue write SetValue; default;
  end;
  TTileMapWeightsPtr = {$ifdef CPFLIB}^{$endif}TTileMapWeights;


  // compact cell coordinates
  PCPFPoint = ^TCPFPoint;
  TCPFPoint = packed record
    Y: Word;
    X: Word;
  end;

  // map cell
  TCPFCell = packed record
  case Boolean of
    False:
    (
       AllocatedFlags: Byte;
       Mask: Byte;
       _: Byte;
       Tile: Byte;
    );
    True: (NodePtr: Cardinal);
  end;
  PCPFCell = ^TCPFCell;
  TCPFCellArray = array[0..0] of TCPFCell;
  PCPFCellArray = ^TCPFCellArray;

  // node type
  PCPFNode = ^TCPFNode;
  TCPFNode = packed record
  case Boolean of
    False: (
              SortValue: Cardinal; // path + heuristics to finish point
              Path: Cardinal; // path from start point to the cell
              Prev, Next: PCPFNode;
              Coordinates: TCPFPoint;
              case Integer of
              0: (
                   ParentAndFlags: Byte
                   {
                     Parent:3;
                     case Boolean of
                       False: (Way:3);
                        True: (KnownChild:3);
                     end;
                     KnownPath:1;
                     Attainable:1;
                   };
                   Mask: Byte;
                   ParentMask: Byte;
                   Tile: Byte;
                 );
              1: (NodeInfo: Cardinal);
            );
    True:  (
              nAttainableLength, _{Path}: Cardinal;
              AttainableDistance: Double;
           );
  end;

  PCPFOffsets = ^TCPFOffsets;
  TCPFOffsets = array[0..7] of NativeInt;

  TCPFInfo = record
    CellArray: PCPFCellArray;
    MapWidth: NativeInt;
    HeuristicsLine: NativeInt;
    HeuristicsDiagonal: NativeInt;
    TileWeights: array[0..1] of Pointer;
    CellOffsets: TCPFOffsets;
    FinishPoint: TCPFPoint;
    NodeAllocator: record
      NewNode: PCPFNode;
      NewNodeLimit: PCPFNode;
      {$ifdef LARGEINT}
      LargeModifier: NativeInt;
      {$endif}
      Count: NativeUInt;
      Buffers: array[0..31] of Pointer;
    end;
  end;
  TCPFNodeBuffers = array[0..31] of NativeUInt;
  PCPFNodeBuffers = ^TCPFNodeBuffers;

  TCPFStart = record
    X: Integer;
    Y: Integer;
    Node: PCPFNode;
    AttainableNode: PCPFNode;
    Distance: Double;
  end;
  PCPFStart = ^TCPFStart;
  TCPFStartArray = array[0..0] of TCPFStart;
  PCPFStartArray = ^TCPFStartArray;

  // path finding parameters
  TTileMapParams = record
    Starts: PPoint;
    StartsCount: NativeUInt;
    Finish: TPoint;
    Weights: TTileMapWeightsPtr;
    Excludes: PPoint;
    ExcludesCount: NativeUInt;
  end;
  PTileMapParams = ^TTileMapParams;

  // main path finding class
  TTileMap = {$ifdef CPFLIB}object{$else}class{$endif}(TCPFClass)
  private
    FInfo: TCPFInfo;
    FWidth: Word;
    FHeight: Word;
    FCellCount: NativeUInt;
    FKind: TTileMapKind;
    FSectorTest: Boolean;
    FCaching: Boolean;
    FSameDiagonalWeight: Boolean;
    FSectorOffsets: TCPFOffsets;
    FTileWeightScale: Double;
    FTileWeightScaleDiagonal: Double;
    FTileWeightLimit: Cardinal;
    FTileWeightLimitDiagonal: Cardinal;
    FTileWeightMinimum: Cardinal;
    FTileWeightMinimumDiagonal: Cardinal;
    DEFAULT_WEIGHT_VALUE_DIAGONAL: Cardinal;
    FTileDefaultWeight: Cardinal;
    FTileDefaultWeightDiagonal: Cardinal;

    procedure RaiseCoordinates(const X, Y: Integer; const Id: TCPFExceptionString);
    procedure UpdateCellMasks(const ChangedArea: TRect);
    function GetTile(const X, Y: Word): Byte;
    procedure SetTile(const X, Y: Word; Value: Byte);
    procedure GrowNodeAllocator(var Buffer: TCPFInfo);
//    function AllocateNode(const X, Y: NativeInt): PCPFNode;
    function CalculateHeuristics(const Start, Finish: TPoint): NativeInt;
//    procedure ClearMapCells(Node: PCPFNode; Count: NativeUInt); overload;
//    procedure ClearMapCells(Node: PCPFNode{as list}); overload;
    function DoFindPathLoop(StartNode: PCPFNode): PCPFNode;
    function DoFindPath(const Params: TTileMapParams): TTileMapPath;
  private
    FNodes: record
      Storage: record
        Buffers: array[0..31] of Pointer;
        Count: NativeUInt;
      end;
      Heuristed: record
        First: TCPFNode;
        Last: TCPFNode;
      end;
    end;
    FActualInfo: record
      TilesChanged: Boolean;
      Sectors: PByte;
      SectorsChanged: Boolean;
      FinishPoint: TPoint;
      PathlessFinishPoint: TPoint;

      Weights: record
        Current: PCPFWeightsInfo;
        UpdateId: Cardinal;
        Count: Cardinal;

        Cardinals: array[0..255] of Cardinal;
        CardinalsDiagonal: array[0..255] of Cardinal;
        Singles: array[0..255] of Single;
        SinglesDiagonal: array[0..255] of Single;
      end;
      Starts: record
        Buffer: TCPFBuffer;
        Count: NativeUInt;
      end;
      Excludes: record
        Buffer: TCPFBuffer;
        Count: NativeUInt;
      end;
      FoundPath: record
        Buffer: TCPFBuffer;
        Length: NativeUInt;
        Distance: Double;
      end;
    end;

    function ActualizeWeights(Weights: PCPFWeightsInfo; Compare: Boolean): Boolean;
    function ActualizeStarts(Points: PPoint; Count: NativeUInt; Compare: Boolean): Boolean;
    function ActualizeExcludes(Points: PPoint; Count: NativeUInt; Compare: Boolean): Boolean;
    procedure ActualizeSectors;
    procedure AddHeuristedNodes(const First, Last: PCPFNode);
    procedure ReleaseAttainableNodes;
    procedure ReleaseHeuristedNodes;
    // procedure ReleaseAllocatedNodes;
  {$ifdef CPFLIB}
  public
    procedure Destroy;
  {$else}
    {$ifdef AUTOREFCOUNT}protected{$else}public{$endif}
    destructor Destroy; override;
  {$endif}
  public
    {$ifdef CPFLIB}procedure{$else}constructor{$endif}
      Create(const AWidth, AHeight: Word; const AKind: TTileMapKind; const ASameDiagonalWeight: Boolean = False);
    procedure Clear();
    procedure Update(const ATiles: PByte; const X, Y, AWidth, AHeight: Word; const Pitch: NativeInt = 0);

    property Width: Word read FWidth;
    property Height: Word read FHeight;
    property Kind: TTileMapKind read FKind;
    property SectorTest: Boolean read FSectorTest write FSectorTest;
    property Caching: Boolean read FCaching write FCaching;
    property Tiles[const X, Y: Word]: Byte read GetTile write SetTile; default;

    function FindPath(const Params: TTileMapParams): TTileMapPath; overload;
    function FindPath(const Start, Finish: TPoint; const Weights: TTileMapWeightsPtr = nil;
      const Excludes: PPoint = nil; const ExcludesCount: NativeUInt = 0): TTileMapPath; overload;
    function FindPath(const Starts: PPoint; const StartsCount: NativeUInt;
      const Finish: TPoint; const Weights: TTileMapWeightsPtr = nil;
      const Excludes: PPoint = nil; const ExcludesCount: NativeUInt = 0): TTileMapPath; overload;
  end;
  TTileMapPtr = {$ifdef CPFLIB}^{$endif}TTileMap;


{$ifdef CPFAPI}
type
  PCPFHandle = ^TCPFHandle;
  TCPFHandle = type NativeUInt;

  {$ifdef CPFLIB}
  TCPFAlloc = function(Size: NativeUInt): Pointer; cdecl;
  TCPFFree = function(P: Pointer): Boolean; cdecl;
  TCPFRealloc = function(P: Pointer; Size: NativeUInt): Pointer; cdecl;
  TCPFException = procedure(Message: PWideChar; Address: Pointer); cdecl;
  TCPFCallbacks = packed record
    Alloc: TCPFAlloc;
    Free: TCPFFree;
    Realloc: TCPFRealloc;
    Exception: TCPFException;
  end;
  procedure cpfInitialize(const Callbacks: TCPFCallbacks); cdecl;
  {$endif}

  function  cpfCreateWeights(): TCPFHandle; cdecl;
  procedure cpfDestroyWeights(var HWeights: TCPFHandle); cdecl;
  function  cpfWeightGet(HWeights: TCPFHandle; Tile: Byte): Single; cdecl;
  procedure cpfWeightSet(HWeights: TCPFHandle; Tile: Byte; Value: Single); cdecl;
  function  cpfCreateMap(Width, Height: Word; Kind: TTileMapKind; SameDiagonalWeight: Boolean = False): TCPFHandle; cdecl;
  procedure cpfDestroyMap(var HMap: TCPFHandle); cdecl;
  procedure cpfMapClear(HMap: TCPFHandle); cdecl;
  procedure cpfMapUpdate(HMap: TCPFHandle; Tiles: PByte; X, Y, Width, Height: Word; Pitch: NativeInt = 0); cdecl;
  function  cpfMapGetTile(HMap: TCPFHandle; X, Y: Word): Byte; cdecl;
  procedure cpfMapSetTile(HMap: TCPFHandle; X, Y: Word; Value: Byte); cdecl;
  function  cpfFindPath(HMap: TCPFHandle; Params: PTileMapParams; SectorTest: Boolean = False; Caching: Boolean = True): TTileMapPath; cdecl;
{$endif}

implementation
{$ifNdef CPFLIB}
  {$ifNdef KOL}uses SysConst{$endif};

var
  MemoryManager: {$if Defined(FPC) or (CompilerVersion < 18)}TMemoryManager{$else}TMemoryManagerEx{$ifend};
{$endif}

const
  SQRT2: Double = 1.4142135623730950488016887242097;
  HALF: Double = 0.5;


{ ECrystalPathFinding }

{$if Defined(KOL) and (not Defined(CPFLIB)))}
constructor ECrystalPathFinding.Create(const Msg: string);
begin
  inherited Create(e_Custom, Msg);
end;

constructor ECrystalPathFinding.CreateFmt(const Msg: string;
  const Args: array of const);
begin
  inherited CreateFmt(e_Custom, Msg, Args);
end;

type
  PStrData = ^TStrData;
  TStrData = record
    Ident: Integer;
    Str: string;
  end;

function EnumStringModules(Instance: NativeInt; Data: Pointer): Boolean;
var
  Buffer: array [0..1023] of Char;
begin
  with PStrData(Data)^ do
  begin
    SetString(Str, Buffer, Windows.LoadString(Instance, Ident, Buffer, sizeof(Buffer)));
    Result := Str = '';
  end;
end;

function FindStringResource(Ident: Integer): string;
var
  StrData: TStrData;
  Func: TEnumModuleFunc;
begin
  StrData.Ident := Ident;
  StrData.Str := '';
  Pointer(@Func) := @EnumStringModules;
  EnumResourceModules(Func, @StrData);
  Result := StrData.Str;
end;

function LoadStr(Ident: Integer): string;
begin
  Result := FindStringResource(Ident);
end;

constructor ECrystalPathFinding.CreateRes(Ident: NativeUInt);
begin
  inherited Create(e_Custom, LoadStr(Ident));
end;

constructor ECrystalPathFinding.CreateRes(ResStringRec: PResStringRec);
begin
  inherited Create(e_Custom, System.LoadResString(ResStringRec));
end;

constructor ECrystalPathFinding.CreateResFmt(Ident: NativeUInt;
  const Args: array of const);
begin
  inherited CreateFmt(e_Custom, LoadStr(Ident), Args);
end;

constructor ECrystalPathFinding.CreateResFmt(ResStringRec: PResStringRec;
  const Args: array of const);
begin
  inherited CreateFmt(e_Custom, System.LoadResString(ResStringRec), Args);
end;
{$ifend}


{$if Defined(FPC) or (CompilerVersion < 23)}
// todo PFC
function ReturnAddress: Pointer;
asm
  mov eax, [ebp+4]
end;
{$ifend}

procedure ZeroMemory(Destination: Pointer; Length: NativeUInt);
{$if Defined(CPFLIB)}
label
  _2, done;
var
  P: PByte;
begin
  P := Destination;

  while (Length >= SizeOf(NativeUInt)) do
  begin
    PNativeUInt(P)^ := 0;

    Dec(Length, SizeOf(NativeUInt));
    Inc(P, SizeOf(NativeUInt));
  end;

  {$ifdef LARGEINT}
  if (Length >= SizeOf(Cardinal)) then
  begin
    Cardinal(P)^ := 0;

    Dec(Length, SizeOf(Cardinal));
    Inc(P, SizeOf(Cardinal));
  end;
  {$endif}

  if (Length <> 0) then
  begin
    if (Length and 1 <> 0) then
    begin
      P^ := 0;
      Inc(P);
      if (Length and 2 = 0) then goto done;
      goto _2;
    end else
    begin
      _2:
      PWord(P)^ := 0;
    end;
  end;
done:
end;
{$elseif Defined(INLINESUPPORT)} inline;
begin
  FillChar(Destination^, Length, 0);
end;
{$else .CPUX86}
asm
  xor ecx, ecx
  jmp System.@FillChar
end;
{$ifend}

{$ifdef CPFLIB}
procedure Move(const Source; var Dest; Count: NativeUInt);
label
  _2, done;
var
  S, D: PByte;
begin
  S := @Source;
  D := @Dest;

  while (Count >= SizeOf(NativeUInt)) do
  begin
    PNativeUInt(D)^ := PNativeUInt(S)^;

    Dec(Count, SizeOf(NativeUInt));
    Inc(S, SizeOf(NativeUInt));
    Inc(D, SizeOf(NativeUInt));
  end;

  {$ifdef LARGEINT}
  if (Count >= SizeOf(Cardinal)) then
  begin
    PCardinal(D)^ := PCardinal(S)^;

    Dec(Count, SizeOf(Cardinal));
    Inc(S, SizeOf(Cardinal));
    Inc(D, SizeOf(Cardinal));
  end;
  {$endif}

  if (Count <> 0) then
  begin
    if (Count and 1 <> 0) then
    begin
      D^ := S^;
      Inc(S);
      Inc(D);
      if (Count and 2 = 0) then goto done;
      goto _2;
    end else
    begin
      _2:
      PWord(D)^ := PWord(S)^;
    end;
  end;

done:
end;
{$endif}

procedure FillCardinal(Destination: PCardinal; Count, Value: NativeUInt);
begin
  {$ifdef LARGEINT}
    Value := Value or (Value shl 32);

    while (Count > 1) do
    begin
      PNativeUInt(Destination)^ := Value;

      Dec(Count, 2);
      Inc(Destination, 2);
    end;

    if (Count <> 0) then
      Destination^ := Value;
  {$else .SMALLINT}
    while (Count <> 0) do
    begin
      Destination^ := Value;

      Dec(Count);
      Inc(Destination);
    end;
  {$endif}
end;

{$if Defined(CPFLIB) or Defined(KOL)}
function CompareMem(_P1, _P2: Pointer; Length: NativeUInt): Boolean;
label
  _2, done, fail;
var
  P1, P2: PByte;
begin
  P1 := _P1;
  P2 := _P2;

  while (Length >= SizeOf(NativeUInt)) do
  begin
    if (PNativeUInt(P1)^ <> PNativeUInt(P2)^) then goto fail;

    Dec(Length, SizeOf(NativeUInt));
    Inc(P2, SizeOf(NativeUInt));
    Inc(P1, SizeOf(NativeUInt));
  end;

  {$ifdef LARGEINT}
  if (Length >= SizeOf(Cardinal)) then
  begin
    if (PCardinal(P1)^ <> PCardinal(P2)^) then goto fail;

    Dec(Length, SizeOf(Cardinal));
    Inc(P2, SizeOf(Cardinal));
    Inc(P1, SizeOf(Cardinal));
  end;
  {$endif}

  if (Length <> 0) then
  begin
    if (Length and 1 <> 0) then
    begin
      if (P1^ <> P2^) then goto fail;
      Inc(P2);
      Inc(P1);
      if (Length and 2 = 0) then goto done;
      goto _2;
    end else
    begin
      _2:
      if (PWord(P1)^ <> PWord(P2)^) then goto fail;
    end;
  end;

done:
  Result := True;
  Exit;
fail:
  Result := False;
end;
{$ifend}

function CPFRound(const X: Double): Integer; {$ifdef INLINESUPPORT}inline;{$endif}
const
  ROUND_CONST: Double = 6755399441055744.0;
var
  Buffer: Double;
begin
  Buffer := X + ROUND_CONST;
  Result := PInteger(@Buffer)^;
end;


{$ifdef CPFLIB}
var
  CPFCallbacks: TCPFCallbacks;
{$endif}

procedure CPFException(const Message: TCPFExceptionString; const Address: Pointer);
begin
  {$ifdef CPFLIB}
    if Assigned(CPFCallbacks.Exception) then
      CPFCallbacks.Exception(Message, Address);

     // guaranteed halt (Assert)
     System.ErrorAddr := Address;
     if (System.ExitCode = 0) then System.ExitCode := 207{reInvalidOp};
     System.Halt;
  {$else}
     raise ECrystalPathFinding.Create(Message) at Address;
  {$endif}
end;

{$ifdef CPFLIB}
procedure CPFExceptionFmt(const Fmt: PWideChar; const Args: array of Integer;
   const Address: Pointer);
var
  TextBuffer: array[0..2048 - 1] of WideChar;
  Dest, Src: PWideChar;
  X: Cardinal;
  Arg: Integer;
  L, R: PWideChar;
  C: WideChar;
begin
  Dest := @TextBuffer[0];
  Src := Fmt;
  Arg := 0;

  if (Src <> nil) then
  while (Src^ <> #0) do
  begin
    if (Src^ = '%') then
    begin
      if (Word(Src[1]) or $20 = Word('d')) and (Arg <= High(Args)) then
      begin
        Inc(Src, 2);
        X := Args[Arg];
        Inc(Arg);

        // sign
        if (Integer(X) < 0) then
        begin
          Dest^ := '-';
          Inc(Dest);
          X := Cardinal(-Integer(X));
        end;

        // fill inverted
        L := Dest;
        repeat
          PWord(Dest)^ := Word('0') + X mod 10;
          Inc(Dest);
          X := X div 10;
        until (X = 0);

        // invert
        R := Dest;
        Dec(R);
        while (NativeUInt(L) < NativeUInt(R)) do
        begin
          C := R^;
          R^ := L^;
          L^ := C;

          Inc(L);
          Dec(R);
        end;

        // scan next
        Continue;
      end;
    end;

    Dest^ := Src^;
    Inc(Src);
    Inc(Dest);
  end;

  Dest^ := #0;
  CPFException(@TextBuffer[0], Address);
end;
{$else !CPFLIB}
procedure CPFExceptionFmt(const Fmt: string; const Args: array of const;
   const Address: Pointer);
begin
  CPFException(Format(Fmt, Args), Address);
end;
{$endif}

{$ifdef CPFLIB}
procedure RaiseCallbacks(const Address: Pointer);
begin
  CPFException('Callbacks not defined', Address);
end;
{$endif}

procedure RaiseOutOfMemory(const Address: Pointer);
begin
{$ifdef CPFLIB}
  System.ExitCode := 203{reOutOfMemory};
  CPFException('Out of memory', Address);
{$else}
  {$ifdef KOL}
    raise Exception.Create(e_OutOfMem, SOutOfMemory) at Address;
  {$else}
    raise EOutOfMemory.Create(SOutOfMemory) at Address;
  {$endif}
{$endif}
end;

procedure RaiseInvalidPointer(const Address: Pointer);
begin
{$ifdef CPFLIB}
  System.ExitCode := 204{reInvalidPtr};
  CPFException('Invalid pointer operation', Address);
{$else}
  {$ifdef KOL}
    raise Exception.Create(e_InvalidPointer, SInvalidPointer) at Address;
  {$else}
    raise EInvalidPointer.Create(SInvalidPointer) at Address;
  {$endif}
{$endif}
end;

function CPFAlloc(const Size: NativeUInt; const Address: Pointer): Pointer;
begin
  if (Size = 0) then
  begin
    Result := nil;
    Exit;
  end;

  {$ifdef CPFLIB}
    if not Assigned(CPFCallbacks.Alloc) then
      RaiseCallbacks(Address);

    Result := CPFCallbacks.Alloc(Size);
  {$else}
    Result := MemoryManager.GetMem(Size);
  {$endif}

  if (Result = nil) then
    RaiseOutOfMemory(Address);
end;

procedure CPFFree(const P: Pointer; const Address: Pointer);
begin
  if (P <> nil) then
  begin
  {$ifdef CPFLIB}
    if not Assigned(CPFCallbacks.Free) then
      RaiseCallbacks(Address);

    if (not CPFCallbacks.Free(P)) then
      RaiseInvalidPointer(Address);
  {$else}
    if (MemoryManager.FreeMem(P) <> 0) then
      RaiseInvalidPointer(Address);
  {$endif}
  end;
end;

function CPFRealloc({$ifNdef FPC}const{$endif} P: Pointer; const Size: NativeUInt; const Address: Pointer): Pointer;
begin
  if (P = nil) then
  begin
    Result := CPFAlloc(Size, Address);
  end else
  if (Size = 0) then
  begin
    CPFFree(P, Address);
    Result := nil;
  end else
  begin
    {$ifdef CPFLIB}
      if not Assigned(CPFCallbacks.Realloc) then
        RaiseCallbacks(Address);

      Result := CPFCallbacks.Realloc(P, Size);
    {$else}
      Result := MemoryManager.ReallocMem(P, Size);
    {$endif}

    if (Result = nil) then
      RaiseOutOfMemory(Address);
  end;
end;


{$ifdef CPFLIB}
procedure cpfInitialize(const Callbacks: TCPFCallbacks); cdecl;
var
  Address: Pointer;
  Done: Boolean;
begin
  Address := ReturnAddress;

  with Callbacks do
  Done := Assigned(Alloc) and Assigned(Free) and Assigned(Realloc) and (Assigned(Exception));

  if (not Done) then
  begin
    if (not Assigned(CPFCallbacks.Exception)) then
      CPFCallbacks.Exception := Callbacks.Exception;

    RaiseCallbacks(Address);
  end;

  CPFCallbacks := Callbacks;
end;
{$endif .CPFLIB}


{$ifdef CPFAPI}

function NewCPFClassInstance(AClass: {$ifNdef CPFLIB}TClass{$else}NativeUInt{$endif};
  Address: Pointer): TCPFHandle;
begin
  {$ifdef CPFLIB}
    Result := TCPFHandle(CPFAlloc(AClass, Address));
    ZeroMemory(Pointer(Result), AClass);
  {$else}
    Result := TCPFHandle(AClass.NewInstance);
  {$endif}
  TCPFClassPtr(Result).FCallAddress := Address;
end;

function  cpfCreateWeights(): TCPFHandle; cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  Result := NewCPFClassInstance({$ifdef CPFLIB}SizeOf{$endif}(TTileMapWeights), Address);
  TTileMapWeightsPtr(Result).Create;
end;

procedure cpfDestroyWeights(var HWeights: TCPFHandle); cdecl;
var
  Address: Pointer;
  Weights: Pointer;
begin
  Address := ReturnAddress;
  Weights := Pointer(HWeights);
  HWeights := 0;

  if (Weights <> nil) then
  begin
    TTileMapWeightsPtr(Weights).FCallAddress := Address;
    {$if Defined(AUTOREFCOUNT) and not Defined(CPFLIB)}
      TTileMapWeightsPtr(Weights).__ObjRelease;
    {$else}
      TTileMapWeightsPtr(Weights).Destroy;
      {$ifdef CPFLIB}
        CPFFree(Weights, Address);
      {$endif}
    {$ifend}
  end;
end;

function  cpfWeightGet(HWeights: TCPFHandle; Tile: Byte): Single; cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HWeights <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HWeights).FCallAddress := Address;

  Result := TTileMapWeightsPtr(HWeights).Values[Tile];
end;

procedure cpfWeightSet(HWeights: TCPFHandle; Tile: Byte; Value: Single); cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HWeights <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HWeights).FCallAddress := Address;

  TTileMapWeightsPtr(HWeights).Values[Tile] := Value;
end;

function  cpfCreateMap(Width, Height: Word; Kind: TTileMapKind;
  SameDiagonalWeight: Boolean): TCPFHandle; cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  Result := NewCPFClassInstance({$ifdef CPFLIB}SizeOf{$endif}(TTileMap), Address);
  TTileMapPtr(Result).Create(Width, Height, Kind, SameDiagonalWeight);
end;

procedure cpfDestroyMap(var HMap: TCPFHandle); cdecl;
var
  Address: Pointer;
  Map: Pointer;
begin
  Address := ReturnAddress;
  Map := Pointer(HMap);
  HMap := 0;

  if (Map <> nil) then
  begin
    TTileMapWeightsPtr(Map).FCallAddress := Address;
    {$if Defined(AUTOREFCOUNT) and not Defined(CPFLIB)}
      TTileMapWeightsPtr(Map).__ObjRelease;
    {$else}
      TTileMapWeightsPtr(Map).Destroy;
      {$ifdef CPFLIB}
        CPFFree(Map, Address);
      {$endif}
    {$ifend}
  end;
end;

procedure cpfMapClear(HMap: TCPFHandle); cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HMap <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HMap).FCallAddress := Address;

  TTileMapPtr(HMap).Clear;
end;

procedure cpfMapUpdate(HMap: TCPFHandle; Tiles: PByte; X, Y, Width, Height: Word; Pitch: NativeInt = 0); cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HMap <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HMap).FCallAddress := Address;

  TTileMapPtr(HMap).Update(Tiles, X, Y, Width, Height, Pitch);
end;

function  cpfMapGetTile(HMap: TCPFHandle; X, Y: Word): Byte; cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HMap <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HMap).FCallAddress := Address;

  Result := TTileMapPtr(HMap).Tiles[X, Y];
end;

procedure cpfMapSetTile(HMap: TCPFHandle; X, Y: Word; Value: Byte); cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HMap <= $ffff) then RaiseInvalidPointer(Address);
  TCPFClassPtr(HMap).FCallAddress := Address;

  TTileMapPtr(HMap).Tiles[X, Y] := Value;
end;

function  cpfFindPath(HMap: TCPFHandle; Params: PTileMapParams; SectorTest: Boolean = False; Caching: Boolean = True): TTileMapPath; cdecl;
var
  Address: Pointer;
begin
  Address := ReturnAddress;
  if (HMap <= $ffff) then RaiseInvalidPointer(Address);

  if (Params = nil) then
  begin
    Result.Points := nil;
    Result.Count := 0;
    Result.Distance := 0;
    Exit;
  end;
  if (NativeUInt(Params) <= $ffff) then RaiseInvalidPointer(Address);

  TCPFClassPtr(HMap).FCallAddress := Address;
  TTileMapPtr(HMap).SectorTest := SectorTest;
  TTileMapPtr(HMap).Caching := Caching;
  Result := TTileMapPtr(HMap).DoFindPath(Params^);
end;
{$endif .CPFAPI}


{ TCPFClass }

procedure TCPFClass.CPFException(const Message: TCPFExceptionString);
begin
  CrystalPathFinding.CPFException(Message, FCallAddress);
end;

procedure TCPFClass.CPFExceptionFmt(const Fmt: TCPFExceptionString;
  const Args: array of {$ifdef CPFLIB}Integer{$else}const{$endif});
begin
  CrystalPathFinding.CPFExceptionFmt(Fmt, Args, FCallAddress);
end;

type
  PAligned16Info = ^TAligned16Info;
  TAligned16Info = record
    Handle: Pointer;
    Size: NativeUInt;
  end;

// aligned 16 alloc
procedure TCPFClass.CPFGetMem(var P: Pointer; const Size: NativeUInt);
var
  Handle: Pointer;
  V: PAligned16Info;
begin
  if (Size = 0) then
  begin
    P := nil;
  end else
  begin
    // allocate
    Handle := CrystalPathFinding.CPFAlloc(Size + SizeOf(TAligned16Info) + 16, FCallAddress);

    // allocate and align 16
    V := Pointer((NativeInt(Handle) + SizeOf(TAligned16Info) + 15) and -16);
    P := V;

    // store information
    Dec(V);
    V.Handle := Handle;
    V.Size := Size;
  end;
end;

// aligned 16 free
procedure TCPFClass.CPFFreeMem(var P: Pointer);
var
  V: PAligned16Info;
begin
  V := P;
  if (V <> nil) then
  begin
    P := nil;
    Dec(V);
    CrystalPathFinding.CPFFree(V.Handle, FCallAddress);
  end;
end;

// aligned 16 realloc
procedure TCPFClass.CPFReallocMem(var P: Pointer; const NewSize: NativeUInt);
var
  V: PAligned16Info;
  Info: TAligned16Info;
  Handle: Pointer;
  CopySize: NativeUInt;
begin
  V := P;
  if (V = nil) then
  begin
    CPFGetMem(P, NewSize);
  end else
  if (NewSize = 0) then
  begin
    CPFFreeMem(P);
  end else
  begin
    // store last information
    Dec(V);
    Info := V^;

    // try to realloc
    Handle := CrystalPathFinding.CPFRealloc(Info.Handle, NewSize + SizeOf(TAligned16Info) + 16, FCallAddress);
    V := Pointer(NativeUInt(Handle) + (NativeUInt(V) - NativeUInt(Info.Handle)));
    V.Handle := Handle;
    V.Size := NewSize;
    Inc(V);
    P := V;

    // failure align 16
    if ((NativeUInt(Handle) and 15) <> (NativeUInt(Info.Handle) and 15)) then
    begin
      CPFGetMem(P, NewSize);

      CopySize := Info.Size;
      if (NewSize < CopySize) then CopySize := NewSize;
      Move(V^, P^, CopySize);

      CrystalPathFinding.CPFFree(Handle, FCallAddress);
    end;
  end;
end;


{ TCPFBuffer }

procedure TCPFBuffer.Initialize(const Owner: TCPFClass);
begin
  FOwner := Pointer({$ifdef CPFLIB}@{$endif}Owner);
  FMemory := nil;
  FAllocatedSize := 0;
end;

function TCPFBuffer.Realloc(const Size: NativeUInt): Pointer;
begin
  if (FMemory <> nil) then
    TCPFClassPtr(FOwner).CPFFreeMem(FMemory);

  case Size of
       0..64: FAllocatedSize := 64;
     65..256: FAllocatedSize := 256;
    257..512: FAllocatedSize := 512;
  else
    FAllocatedSize := NativeUInt((NativeInt(Size) + 1023) and -1024);
  end;

  TCPFClassPtr(FOwner).CPFGetMem(FMemory, FAllocatedSize);
  Result := FMemory;
end;

function TCPFBuffer.Alloc(const Size: NativeUInt): Pointer;
begin
  if (Size <= FAllocatedSize) then
  begin
    Result := FMemory;
  end else
  begin
    Result := Realloc(Size);
  end;
end;

procedure TCPFBuffer.Free;
begin
  TCPFClassPtr(FOwner).CPFFreeMem(FMemory);
end;


type
  TYXSmallPoint = record
    y: SmallInt;
    x: SmallInt;
  end;

  TChildArray = array[0..7] of Word;
  PChildArray = ^TChildArray;

const
  NODESTORAGE_INFO: array[0..31] of packed record
    Count: Cardinal;
    Previous: Cardinal;
  end = (
    { 0} (Count:     512; Previous:        0),
    { 1} (Count:     512; Previous:      512),
    { 2} (Count:    1024; Previous:     1024),
    { 3} (Count:    1024; Previous:     2048),
    { 4} (Count:    2048; Previous:     3072),
    { 5} (Count:    2048; Previous:     5120),
    { 6} (Count:    4096; Previous:     7168),
    { 7} (Count:    4096; Previous:    11264),
    { 8} (Count:    8192; Previous:    15360),
    { 9} (Count:    8192; Previous:    23552),
    {10} (Count:   16384; Previous:    31744),
    {11} (Count:   16384; Previous:    48128),
    {12} (Count:   32768; Previous:    64512),
    {13} (Count:   32768; Previous:    97280),
    {14} (Count:   32768; Previous:   130048),
    {15} (Count:   32768; Previous:   162816),
    {16} (Count:   65536; Previous:   195584),
    {17} (Count:   65536; Previous:   261120),
    {18} (Count:  131072; Previous:   326656),
    {19} (Count:  131072; Previous:   457728),
    {20} (Count:  262144; Previous:   588800),
    {21} (Count:  262144; Previous:   850944),
    {22} (Count:  524288; Previous:  1113088),
    {23} (Count:  524288; Previous:  1637376),
    {24} (Count: 1048576; Previous:  2161664),
    {25} (Count: 1048576; Previous:  3210240),
    {26} (Count: 1255424; Previous:  4258816),
    {27} (Count: 2097152; Previous:  5514240),
    {28} (Count: 2097152; Previous:  7611392),
    {29} (Count: 2097152; Previous:  9708544),
    {30} (Count: 2097152; Previous: 11805696),
    {31} (Count: 2097152; Previous: 13902848)
  );

  CELLCOUNT_LIMIT = 16*1000*1000;
  PATHLENGTH_LIMIT = 6666667;
  NATTANABLE_LENGTH_LIMIT = not Cardinal(PATHLENGTH_LIMIT);
  SORTVALUE_LIMIT = NATTANABLE_LENGTH_LIMIT - 1;

  FLAG_KNOWN_PATH = 1 shl 6;
  FLAG_ATTAINABLE = 1 shl 7;
  PATHLESS_TILE_WEIGHT = High(Cardinal) shr 1;

  {$ifdef LARGEINT}
    LARGE_NODEPTR_OFFSET = 32 - {0..31}5;
  {$endif}

  NODEPTR_FLAG_ALLOCATED = 1;
  NODEPTR_FLAG_HEURISTED = 2;
  NODEPTR_CLEAN_MASK = Integer((not 7) {$ifdef LARGEINT} and ((1 shl LARGE_NODEPTR_OFFSET) - 1){$endif});

  SECTOR_EMPTY = 0;
  SECTOR_PATHLESS = 1;

  {$ifdef LARGEINT}
    HIGH_NATIVE_BIT = 63;
  {$else}
    HIGH_NATIVE_BIT = 31;
  {$endif}

  _0 = (1 shl 0);
  _1 = (1 shl 1);
  _2 = (1 shl 2);
  _3 = (1 shl 3);
  _4 = (1 shl 4);
  _5 = (1 shl 5);
  _6 = (1 shl 6);
  _7 = (1 shl 7);

  DEFAULT_MASKS: array[TTileMapKind] of Word = (
    {mkSimple}     (_1 or _3 or _5 or _7) * $0101,
    {mkDiagonal}   $FF * $0101,
    {mkDiagonalEx} $FF * $0101,
    {mkHexagonal}  (_0 or _1 or _3 or _5 or _6 or _7) * $0100 +
                   (_1 or _2 or _3 or _4 or _5 or _7)
  );

  POINT_OFFSETS: array[0..7] of TYXSmallPoint = (
    {0} (y: -1; x: -1),
    {1} (y: -1; x:  0),
    {2} (y: -1; x: +1),
    {3} (y:  0; x: +1),
    {4} (y: +1; x: +1),
    {5} (y: +1; x:  0),
    {6} (y: +1; x: -1),
    {7} (y:  0; x: -1)
  );

  POINT_OFFSETS_INVERT: array[0..7] of TYXSmallPoint = (
    {0 --> 4} (y: +1; x: +1),
    {1 --> 5} (y: +1; x:  0),
    {2 --> 6} (y: +1; x: -1),
    {3 --> 7} (y:  0; x: -1),
    {4 --> 0} (y: -1; x: -1),
    {5 --> 1} (y: -1; x:  0),
    {6 --> 2} (y: -1; x: +1),
    {7 --> 3} (y:  0; x: +1)
  );

  MIN_WEIGHT_VALUE = Cardinal($3DCCCCCD){0.1};
  MAX_WEIGHT_VALUE = Cardinal($42480000){50.0};
  DEFAULT_WEIGHT_VALUE = Cardinal($3F800000){1.0};
  ERROR_WEIGHT_VALUE = 'Invalid weight value. 0,0..0,1 - pathless, 0,1..50 - correct';

  CHILD_ARRAYS: array[0..11{4 diagonal + 4 clockwise optional}] of TChildArray = (
   ($0100, $8070, $0210, $4060, $0420, $2050, $0830, $1040),
   ($0210, $0100, $0420, $8070, $0830, $4060, $1040, $2050),
   ($0210, $0420, $0100, $0830, $8070, $1040, $4060, $2050),
   ($0420, $0830, $0210, $1040, $0100, $2050, $8070, $4060),
   ($0830, $0420, $1040, $0210, $2050, $0100, $4060, $8070),
   ($0830, $1040, $0420, $2050, $0210, $4060, $0100, $8070),
   ($1040, $2050, $0830, $4060, $0420, $8070, $0210, $0100),
   ($2050, $1040, $4060, $0830, $8070, $0420, $0100, $0210),
   ($2050, $4060, $1040, $8070, $0830, $0100, $0420, $0210),
   ($4060, $2050, $8070, $1040, $0100, $0830, $0210, $0420),
   ($8070, $4060, $0100, $2050, $0210, $1040, $0420, $0830),
   ($8070, $0100, $4060, $0210, $2050, $0420, $1040, $0830)
  );

  CHILD_ARRAYS_OFFSETS: array[0..63{parent:3,way:3}] of Byte = (
    $B0, $B0, $B0, $A0, $A0, $A0, $A0, $A0,
    $40, $40, $40, $40, $50, $50, $50, $40,
    $10, $10, $20, $20, $20, $10, $10, $10,
    $00, $00, $00, $00, $00, $00, $00, $00,
    $30, $30, $30, $30, $30, $30, $30, $30,
    $60, $60, $60, $60, $60, $60, $60, $60,
    $90, $90, $90, $90, $90, $90, $90, $90,
    $60, $60, $60, $60, $60, $60, $60, $60
  );

  PARENT_BITS: array[0..31{oddy:1;hexagonal:1;child:3}] of NativeUInt = (
    $00C70004, $00C70004, $00C70004, $00000004,
    $00070005, $00070005, $004F0005, $00970005,
    $001F0006, $001F0006, $00000006, $001F0006,
    $001C0007, $001C0007, $003E0007, $005D0007,
    $007C0000, $007C0000, $00000000, $007C0000,
    $00700001, $00700001, $00790001, $00F40001,
    $00F10002, $00F10002, $00F10002, $00000002,
    $00C10003, $00C10003, $00D50003, $00E30003
  );

  ROUNDED_MASKS: array[Byte] of Byte = (
    $00, $00, $02, $02, $00, $00, $02, $02, $08, $08, $0A, $0A, $08, $08, $0E, $0E,
    $00, $00, $02, $02, $00, $00, $02, $02, $08, $08, $0A, $0A, $08, $08, $0E, $0E,
    $20, $20, $22, $22, $20, $20, $22, $22, $28, $28, $2A, $2A, $28, $28, $2E, $2E,
    $20, $20, $22, $22, $20, $20, $22, $22, $38, $38, $3A, $3A, $38, $38, $3E, $3E,
    $00, $00, $02, $02, $00, $00, $02, $02, $08, $08, $0A, $0A, $08, $08, $0E, $0E,
    $00, $00, $02, $02, $00, $00, $02, $02, $08, $08, $0A, $0A, $08, $08, $0E, $0E,
    $20, $20, $22, $22, $20, $20, $22, $22, $28, $28, $2A, $2A, $28, $28, $2E, $2E,
    $20, $20, $22, $22, $20, $20, $22, $22, $38, $38, $3A, $3A, $38, $38, $3E, $3E,
    $80, $80, $82, $83, $80, $80, $82, $83, $88, $88, $8A, $8B, $88, $88, $8E, $8F,
    $80, $80, $82, $83, $80, $80, $82, $83, $88, $88, $8A, $8B, $88, $88, $8E, $8F,
    $A0, $A0, $A2, $A3, $A0, $A0, $A2, $A3, $A8, $A8, $AA, $AB, $A8, $A8, $AE, $AF,
    $A0, $A0, $A2, $A3, $A0, $A0, $A2, $A3, $B8, $B8, $BA, $BB, $B8, $B8, $BE, $BF,
    $80, $80, $82, $83, $80, $80, $82, $83, $88, $88, $8A, $8B, $88, $88, $8E, $8F,
    $80, $80, $82, $83, $80, $80, $82, $83, $88, $88, $8A, $8B, $88, $88, $8E, $8F,
    $E0, $E0, $E2, $E3, $E0, $E0, $E2, $E3, $E8, $E8, $EA, $EB, $E8, $E8, $EE, $EF,
    $E0, $E0, $E2, $E3, $E0, $E0, $E2, $E3, $F8, $F8, $FA, $FB, $F8, $F8, $FE, $FF
  );


{$ifdef CPF_GENERATE_LOOKUPS}
var
  LookupsText: TStringList;

procedure LookupLine(const Line: string); overload;
begin
  LookupsText.Add('  ' + Line);
end;

procedure LookupLine; overload;
begin
  LookupsText.Add('');
end;

procedure LookupLineFmt(const FmtStr: string; const Args: array of const);
begin
  LookupLine(Format(FmtStr, Args));
end;

procedure AddChildArray(Base: Integer; Clockwise, Finalize: Boolean);
const
  CHILD_VALUES: array[0..7] of Word = (
    ((1 shl 0) shl 8) or (0 shl 4),
    ((1 shl 1) shl 8) or (1 shl 4),
    ((1 shl 2) shl 8) or (2 shl 4),
    ((1 shl 3) shl 8) or (3 shl 4),
    ((1 shl 4) shl 8) or (4 shl 4),
    ((1 shl 5) shl 8) or (5 shl 4),
    ((1 shl 6) shl 8) or (6 shl 4),
    ((1 shl 7) shl 8) or (7 shl 4)
  );

var
  S: string;
  i, Sign: integer;
  ChildArray: TChildArray;
  Child: PWord;

  procedure AddChild(const N: Integer);
  begin
    Child^ := CHILD_VALUES[(N + 8) and 7];
    Inc(Child);
  end;
begin
  Sign := 1;
  if (not Clockwise) then Sign := -1;

  Child := @ChildArray[0];
  AddChild(Base);
  for i := 1 to 3 do
  begin
    AddChild(Base + Sign * i);
    AddChild(Base - Sign * i);
  end;
  AddChild(Base + 4);

  S := Format(' ($%0.4x, $%0.4x, $%0.4x, $%0.4x, $%0.4x, $%0.4x, $%0.4x, $%0.4x)',
    [ChildArray[0], ChildArray[1], ChildArray[2], ChildArray[3],
     ChildArray[4], ChildArray[5], ChildArray[6], ChildArray[7]]);

  if (not Finalize) then S := S + ',';
  LookupLine(S);
end;

procedure AddTwoChildArrays(Base: Integer; Finalize: Boolean);
begin
  AddChildArray(Base, False, False);
  AddChildArray(Base, True, Finalize);
end;

procedure AddChildArrayOffsets(WayX, WayY: Integer; Finalize: Boolean);
var
  Buffer: array[0..7] of Byte;
  Offset: PByte;
  S: string;
  Parent, WayChild: Integer;
  N: Byte;
begin
  if (WayX = 1) then WayX := -1
  else
  if (WayX = 2) then WayX := 1;

  if (WayY = 1) then WayY := -1
  else
  if (WayY = 2) then WayY := 1;


  if (WayX < 0) then
  begin
    if (WayY < 0) then
    begin
      WayChild := 0;
    end else
    if (WayY = 0) then
    begin
      WayChild := 7;
    end else
    // (WayY > 0) then
    begin
      WayChild := 6;
    end;
  end else
  if (WayX = 0) then
  begin
    if (WayY < 0) then WayChild := 1
    else WayChild := 4;
  end else
  // (WayX > 0) then
  begin
    if (WayY < 0) then
    begin
      WayChild := 2;
    end else
    if (WayY = 0) then
    begin
      WayChild := 3;
    end else
    // (WayY > 0) then
    begin
      WayChild := 4;
    end;
  end;

  Offset := @Buffer[0];
  for Parent := 0 to 7 do
  begin
    N := (WayChild shr 1) * 3;

    if (WayChild and 1 <> 0) then
    begin
      Inc(N);

      if (Parent = ((WayChild - 1 + 4) and 7)) or
        (Parent = ((WayChild - 2 + 4) and 7)) or
        (Parent = ((WayChild - 3 + 4) and 7)) then
        Inc(N);
    end;

    Offset^ := N * SizeOf(TChildArray);
    Inc(Offset);
  end;

  S := Format('  $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x',
    [Buffer[0], Buffer[1], Buffer[2], Buffer[3],
     Buffer[4], Buffer[5], Buffer[6], Buffer[7]]);

  if (not Finalize) then S := S + ',';
  LookupLine(S);
end;

procedure AddParentBits(Child: Integer; Finalize: Boolean);
var
  Parent: Integer;
  Buffer: array[0..3] of Cardinal;
  Hexagonal, OddY: Boolean;
  Item: PCardinal;
  S: string;

  procedure AddParentMask(ExcludedChilds: Byte);
  begin
    Item^ := (Cardinal(Byte(not ExcludedChilds)) shl 16) or Cardinal(Parent);
    Inc(Item);
  end;
begin
  Parent := (Child + 4) and 7;
  Item := @Buffer[0];

  for Hexagonal := False to True do
  for OddY := False to True do
  begin
    if (not Hexagonal) then
    begin
      case Child of
        0: AddParentMask(_3 or _4 or _5);
        1: AddParentMask(_3 or _4 or _5 or _6 or _7);
        2: AddParentMask(_5 or _6 or _7);
        3: AddParentMask(_5 or _6 or _7 or _0 or _1);
        4: AddParentMask(_7 or _0 or _1);
        5: AddParentMask(_0 or _1 or _2 or _3 or _7);
        6: AddParentMask(_1 or _2 or _3);
        7: AddParentMask(_1 or _2 or _3 or _4 or _5);
      end;
    end else
    if (not OddY) then
    begin
      case Child of
        6: AddParentMask(_1 or _2 or _3);
        7: AddParentMask(_1 or _3 or _5);
        0: AddParentMask(_3 or _4 or _5);
        1: AddParentMask(_4 or _5 or _7);
        3: AddParentMask(_6 or _7 or _0);
        5: AddParentMask(_7 or _1 or _2);
      else
        AddParentMask($FF);
      end;
    end else
    begin
      case Child of
        7: AddParentMask(_2 or _3 or _4);
        1: AddParentMask(_3 or _5 or _6);
        2: AddParentMask(_5 or _6 or _7);
        3: AddParentMask(_1 or _5 or _7);
        4: AddParentMask(_0 or _1 or _7);
        5: AddParentMask(_0 or _1 or _3);
      else
        AddParentMask($FF);
      end;
    end;
  end;

  S := Format('  $%0.8x, $%0.8x, $%0.8x, $%0.8x',
    [Buffer[0], Buffer[1], Buffer[2], Buffer[3]]);

  if (not Finalize) then S := S + ',';
  LookupLine(S);
end;

procedure AddRoundMasks(Line: Integer; Finalize: Boolean);
const
  NOT_TOP_MASK = not (_0 or _1 or _2);
  NOT_RIGHT_MASK = not (_2 or _3 or _4);
  NOT_BOTTOM_MASK = not (_4 or _5 or _6);
  NOT_LEFT_MASK = not (_6 or _7 or _0);
var
  i: Integer;
  Buffer: array[0..15] of Byte;
  Mask: Byte;
  S: string;
begin
  for i := 0 to 15 do
  begin
    Mask := Line * 16 + i;

    if (Mask and (1 shl 1) = 0) then Mask := Mask and NOT_TOP_MASK;
    if (Mask and (1 shl 3) = 0) then Mask := Mask and NOT_RIGHT_MASK;
    if (Mask and (1 shl 5) = 0) then Mask := Mask and NOT_BOTTOM_MASK;
    if (Mask and (1 shl 7) = 0) then Mask := Mask and NOT_LEFT_MASK;

    Buffer[i] := Mask;
  end;

  S := Format('  $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x'+
              ', $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x, $%0.2x',
    [Buffer[0], Buffer[1], Buffer[2], Buffer[3], Buffer[4], Buffer[5], Buffer[6], Buffer[7],
     Buffer[8], Buffer[9], Buffer[10], Buffer[11], Buffer[12], Buffer[13], Buffer[14], Buffer[15]]);

  if (not Finalize) then S := S + ',';
  LookupLine(S);
end;

procedure GenerateLookups;
const
  MIN_WEIGHT_VALUE: Single = 0.1;
  MAX_WEIGHT_VALUE: Single = 50;
  DEFAULT_WEIGHT_VALUE: Single = 1;
var
  Way, WayX, WayY: Integer;
  Child: Integer;
  Line: Integer;
begin
  LookupsText := TStringList.Create;
  try
    LookupsText.Add('const');

    // weight consts
    FormatSettings.DecimalSeparator := '.';
    LookupLineFmt('MIN_WEIGHT_VALUE = Cardinal($%8x){%0.1f};', [PCardinal(@MIN_WEIGHT_VALUE)^, MIN_WEIGHT_VALUE]);
    LookupLineFmt('MAX_WEIGHT_VALUE = Cardinal($%8x){%0.1f};', [PCardinal(@MAX_WEIGHT_VALUE)^, MAX_WEIGHT_VALUE]);
    LookupLineFmt('DEFAULT_WEIGHT_VALUE = Cardinal($%8x){%0.1f};', [PCardinal(@DEFAULT_WEIGHT_VALUE)^, DEFAULT_WEIGHT_VALUE]);
    FormatSettings.DecimalSeparator := ',';
    LookupLineFmt('ERROR_WEIGHT_VALUE = ''Invalid weight value. 0,0..%0.1f - pathless, %0.1f..%0.0f - correct'';',
      [MIN_WEIGHT_VALUE, MIN_WEIGHT_VALUE, MAX_WEIGHT_VALUE]);

    // CHILD_ARRAYS
    LookupLine;
    LookupLine('CHILD_ARRAYS: array[0..11{4 diagonal + 4 clockwise optional}] of TChildArray = (');
    begin
      AddChildArray(0, False, False);
      AddTwoChildArrays(1, False);
      AddChildArray(2, True, False);
      AddTwoChildArrays(3, False);
      AddChildArray(4, True, False);
      AddTwoChildArrays(5, False);
      AddChildArray(6, False, False);
      AddTwoChildArrays(7, True);
    end;
    LookupLine(');');

    // CHILD_ARRAYS_OFFSETS
    LookupLine;
    LookupLine('CHILD_ARRAYS_OFFSETS: array[0..63{parent:3,way:3}] of Byte = (');
    for Way := 0 to 7 do
    begin
      WayX := (Way + 1) mod 3;
      WayY := (Way + 1) div 3;

      AddChildArrayOffsets(WayX, WayY, Way = 7);
    end;
    LookupLine(');');

    // PARENT_BITS
    LookupLine;
    LookupLine('PARENT_BITS: array[0..31{oddy:1;hexagonal:1;child:3}] of NativeUInt = (');
    for Child := 0 to 7 do
    begin
      AddParentBits(Child, Child = 7);
    end;
    LookupLine(');');

    // ROUNDED_MASKS
    LookupLine;
    LookupLine('ROUNDED_MASKS: array[Byte] of Byte = (');
    for Line := 0 to 15 do
    begin
      AddRoundMasks(Line, Line = 15);
    end;
    LookupLine(');');

    LookupsText.SaveToFile('Lookup.txt');
  finally
    LookupsText.Free;
  end;
end;
{$endif}


{ TCPFWeightsInfo }

{class} function TCPFWeightsInfo.NewInstance(const Address: Pointer): PCPFWeightsInfo;
begin
  // allocate
  Result := CPFAlloc(SizeOf(TCPFWeightsInfo), Address);

  // fill
  Result.RefCount := 1;
  Result.UpdateId := 1;
  Result.PrepareId := 1;
  Result.Count := 0;
  Result.Scale := 1.0;

  // default values
  FillCardinal(@Result.Singles[1], Length(Result.Singles), DEFAULT_WEIGHT_VALUE);
end;

procedure TCPFWeightsInfo.Release(const Address: Pointer);
var
  Cnt: Cardinal;
begin
  if (@Self = nil) then Exit;

  Cnt := Self.RefCount;
  if (Cnt <> 1) then
  begin
    Dec(Cnt);
    Self.RefCount := Cnt;
  end else
  begin
    CPFFree(@Self, Address);
  end;
end;

procedure TCPFWeightsInfo.Prepare;
var
  Min: Cardinal{Single};
  Max: Cardinal{Single};
  PValue, PHighValue: PCardinal;
  Value: Cardinal;
  MinSingle, MaxSingle: Single;
begin
  if (UpdateId = PrepareId) then Exit;
  PrepareId := UpdateId;

  PValue := @Singles[1];
  PHighValue := @Singles[Count + 1];
  Min := DEFAULT_WEIGHT_VALUE;
  Max := DEFAULT_WEIGHT_VALUE;
  while (PValue <> PHighValue) do
  begin
    Value := PValue^;

    if (Value <> 0) then
    begin
      if (Value >= Max) then Max := Value
      else
      if (Value < Min) then Min := Value;
    end;

    Inc(PValue);
  end;

  PCardinal(@MinSingle)^ := Min;
  PCardinal(@MaxSingle)^ := Max;
  Minimum := Min;
  Scale := MinSingle / MaxSingle;
end;

{ TTileMapWeights }

{$ifdef CPFLIB}procedure{$else}constructor{$endif} TTileMapWeights.Create;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
    inherited Create;
  {$endif}

  FInfo := PCPFWeightsInfo(nil).NewInstance(FCallAddress)
end;

{$ifdef CPFLIB}procedure{$else}destructor{$endif}
  TTileMapWeights.Destroy;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

  FInfo.Release(FCallAddress);

  {$ifNdef CPFLIB}
    inherited;
  {$endif}
end;

procedure TTileMapWeights.RaiseBarrierTile;
begin
  CPFException('Invalid tile index 0, it means a barrier (TILE_BARRIER)');
end;

function TTileMapWeights.GetValue(const Tile: Byte): Single;
begin
  if (Tile = TILE_BARRIER) then
  begin
    {$ifNdef CPFLIB}
      FCallAddress := ReturnAddress;
    {$endif}
    RaiseBarrierTile;
    Result := 0;
  end else
  begin
    Result := PSingle(@FInfo.Singles[Tile])^;
  end;
end;

procedure TTileMapWeights.SetValue(const Tile: Byte;
  const Value: Single);
label
  fillcount;
var
  PValue: PCardinal;
  V: Cardinal;
  Index: NativeUInt;
  Info: PCPFWeightsInfo;
begin
  V := PCardinal(@Value)^;
  if (Tile = TILE_BARRIER) or (V > MAX_WEIGHT_VALUE) then
  begin
    {$ifNdef CPFLIB}
      FCallAddress := ReturnAddress;
    {$endif}
    if (Tile = TILE_BARRIER) then
    begin
      RaiseBarrierTile;
    end else
    begin
      CPFException(ERROR_WEIGHT_VALUE);
    end;
  end else
  begin
    Info := FInfo;
    V := V and (Integer(Byte(V < MIN_WEIGHT_VALUE)) - 1); // 0..0,1 --> 0
    Index := Tile;
    PValue := @Info.Singles[Index];

    if (PValue^ <> V) then
    begin
      PValue^ := V;
      Inc(Info.UpdateId);

      if (V = DEFAULT_WEIGHT_VALUE) then
      begin
        if (Index = Info.Count) then
        begin
          repeat
            Dec(PValue);
            Dec(Index);
            if (PValue = @Info.Count{Index = 0}) or
              (PValue^ <> DEFAULT_WEIGHT_VALUE) then Break;
          until (False);

          goto fillcount;
        end;
      end else
      if (Index > Info.Count) then
      begin
        fillcount:
        Info.Count := Index;
      end;
    end;
  end;
end;


{ TTileMap }

{$ifdef CPFLIB}procedure{$else}constructor{$endif}
  TTileMap.Create(const AWidth, AHeight: Word; const AKind: TTileMapKind;
    const ASameDiagonalWeight: Boolean);
var
  i: NativeInt;
  Size: NativeUInt;
  Max, Min, PathLengthLimit: NativeUInt;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
    inherited Create;
  {$endif}

  // arguments test
  begin
    FCellCount := NativeUInt(AWidth) * NativeUInt(AHeight);

    if (AWidth <= 1) or (AHeight <= 1) then
      // ToDo: 1 line map
      CPFExceptionFmt('Incorrect map size: %dx%d', [AWidth, AHeight]);

    if (FCellCount > CELLCOUNT_LIMIT) then
      CPFExceptionFmt('Too large map size %dx%d, cell count limit is %d', [AWidth, AHeight, CELLCOUNT_LIMIT]);

    if (Ord(AKind) > Ord(High(TTileMapKind))) then
      CPFExceptionFmt('Incorrect map kind: %d, high value mkHexagonal is %d', [Ord(AKind), Ord(High(TTileMapKind))]);
  end;

  // fill params
  FWidth := AWidth;
  FHeight := AHeight;
  FKind := AKind;
  FInfo.MapWidth := AWidth;
  FSectorTest := False;
  FCaching := True;

  // offsets
  for i := 0 to 7 do
  begin
    FSectorOffsets[i] := POINT_OFFSETS[i].y * FInfo.MapWidth + POINT_OFFSETS[i].x;
    FInfo.CellOffsets[i] := SizeOf(TCPFCell) * FSectorOffsets[i];
  end;

  // path/weight limit params
  FSameDiagonalWeight := (not (AKind in [mkDiagonal, mkDiagonalEx])) or ASameDiagonalWeight;
  Max := AWidth;
  Min := AHeight;
  if (Max < Min) then
  begin
    Max := AHeight;
    Min := AWidth;
  end;
  PathLengthLimit := ((Min + 1) shr 1) * Max + (Min shr 1);
  FTileWeightScale := SORTVALUE_LIMIT / PathLengthLimit;
  FTileWeightLimit := CPFRound(FTileWeightScale) - 1;
  FTileDefaultWeight := CPFRound({1 *} FTileWeightScale);
  FInfo.TileWeights[1] := @FActualInfo.Weights.Cardinals;
  if (FSameDiagonalWeight) then
  begin
    FTileWeightScaleDiagonal := FTileWeightScale;
    DEFAULT_WEIGHT_VALUE_DIAGONAL := DEFAULT_WEIGHT_VALUE;
    FTileDefaultWeightDiagonal := FTileDefaultWeight;
    FTileWeightLimitDiagonal := FTileWeightLimit;
    FTileWeightMinimum := 1;
    FTileWeightMinimumDiagonal := 1;
    FInfo.TileWeights[0] := FInfo.TileWeights[1];
  end else
  begin
    FTileWeightScaleDiagonal := SQRT2 * FTileWeightScale;
    PSingle(@DEFAULT_WEIGHT_VALUE_DIAGONAL)^ := SQRT2;
    FTileDefaultWeightDiagonal := CPFRound({1 *} FTileWeightScaleDiagonal);
    FTileWeightLimitDiagonal := CPFRound(FTileWeightLimit * SQRT2);
    FTileWeightMinimum := 2;
    FTileWeightMinimumDiagonal := 3;
    FInfo.TileWeights[1] := @FActualInfo.Weights.CardinalsDiagonal;
  end;
  if (FTileDefaultWeight > FTileWeightLimit) then FTileDefaultWeight := FTileWeightLimit
  else
  if (FTileDefaultWeight < FTileWeightMinimum) then FTileDefaultWeight := FTileWeightMinimum;
  if (FTileDefaultWeightDiagonal < FTileWeightMinimum) then FTileDefaultWeightDiagonal := FTileWeightMinimum;

  // "actual" information
  FActualInfo.TilesChanged := True;
  FActualInfo.FinishPoint.X := -1;
  FActualInfo.FinishPoint.Y := -1;
  FActualInfo.Weights.Count := 255;

  // internal buffers
  FActualInfo.Starts.Buffer.Initialize(Self);
  FActualInfo.Excludes.Buffer.Initialize(Self);
  FActualInfo.FoundPath.Buffer.Initialize(Self);

  // allocate and fill cells
  Size := FCellCount * SizeOf(TCPFCell);
  CPFGetMem(Pointer(FInfo.CellArray), Size);
  ZeroMemory(FInfo.CellArray, Size);
  Clear;

  // nodes initialization
  FNodes.Heuristed.First.Next := @FNodes.Heuristed.Last;
  FNodes.Heuristed.Last.Prev := @FNodes.Heuristed.First;
  GrowNodeAllocator(FInfo);
end;

{$ifdef CPFLIB}procedure{$else}destructor{$endif}
  TTileMap.Destroy;
var
  i: NativeInt;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

  // tile Weights
  FActualInfo.Weights.Current.Release(FCallAddress);

  // internal buffers
  FActualInfo.Starts.Buffer.Free;
  FActualInfo.Excludes.Buffer.Free;
  FActualInfo.FoundPath.Buffer.Free;

  // node storage
  for i := NativeInt(FNodes.Storage.Count) - 1 downto 0 do
    CPFFreeMem(FNodes.Storage.Buffers[i]);

  // cells
  CPFFreeMem(Pointer(FInfo.CellArray));

  // sectors
  CPFFreeMem(Pointer(FActualInfo.Sectors));

  {$ifNdef CPFLIB}
    inherited;
  {$endif}
end;

procedure TTileMap.RaiseCoordinates(const X, Y: Integer; const Id: TCPFExceptionString);
const
  PREFIX = 'Invalid ';
  POSTFIX = ' point (%d, %d) on the %dx%d map';
{$ifNdef CPFLIB}
begin
  CPFExceptionFmt(PREFIX + Id + POSTFIX, [X, Y, Self.Width, Self.Height]);
end;
{$else}
var
  Buffer: array[0..1023] of WideChar;
  S: PWideChar;

  procedure IncludeString(Value: PWideChar);
  begin
    while (Value^ <> #0) do
    begin
      S^ := Value^;
      Inc(Value);
      Inc(S);
    end;
  end;
begin
  S := @Buffer[0];

  IncludeString(PREFIX);
  IncludeString(Id);
  IncludeString(POSTFIX);
  S^ := #0;

  CPFExceptionFmt(@Buffer[0], [X, Y, Self.Width, Self.Height]);
end;
{$endif}

procedure TTileMap.UpdateCellMasks(const ChangedArea: TRect);
label
  clearbit, fillmask, nextcell;
var
  MaxI, MaxJ: Integer;
  X, Y, Left, Top, Right, Bottom: Integer;
  Rounded: Boolean;
  CellOffsets: PCPFOffsets;
  Cell: PCPFCell;
  FlagHexagonal: Integer;
  CellLineOffset: NativeUInt;

  i, j: Integer;
  CellInfo: NativeUInt;
  DefaultMask, Mask, Flags: Integer;

  {$ifdef LARGEINT}
    NodeBuffers: PCPFNodeBuffers;
  {$endif}
begin
  MaxI := Self.Width - 1;
  MaxJ := Self.Height - 1;
  Rounded := (Self.Kind = mkDiagonalEx);
  CellOffsets := @Self.FInfo.CellOffsets;
  Cell := @Self.FInfo.CellArray[0];
  FlagHexagonal := Ord(Self.Kind = mkHexagonal);
  DefaultMask := DEFAULT_MASKS[Self.Kind];

  {$ifdef LARGEINT}
  NodeBuffers := Pointer(@FInfo.NodeAllocator.Buffers);
  {$endif}

  // around area
  X := ChangedArea.Right;
  Right := X + Ord(X <= MaxI);
  X := ChangedArea.Bottom;
  Bottom := X + Ord(X <= MaxJ);
  X := ChangedArea.Left;
  Left := X - Ord(X <> 0);
  X := ChangedArea.Top;
  Top := X;
  Dec(Top, Ord(X <> 0));

  // each cell loop
  X := MaxI + 1{Width};
  Inc(Cell, Top * X{Width} + Left);
  CellLineOffset := (X{Width} - (Right - Left)) * SizeOf(TCPFCell);
  // for j := Top to Bottom - 1 do
  j := Top;
  repeat
    //for i := Left to Right - 1 do
    i := Left;
    repeat
      // tile barier test
      CellInfo := Cell.NodePtr;
      if (CellInfo and NODEPTR_FLAG_ALLOCATED = 0) then
      begin
        if {$ifdef LARGEINT}
             (CellInfo <= $ffffff)
           {$else}
             (CellInfo and Integer($ff000000){Tile} = 0{TILE_BARIER})
           {$endif} then
        begin
          Cell.Mask := 0;
          goto nextcell;
        end;
      end else
      begin
        with PCPFNode(
            {$ifdef LARGEINT}NodeBuffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
            CellInfo and NODEPTR_CLEAN_MASK
             )^ do
        if (Tile = 0) then
        begin
          Mask := 0;
          goto nextcell;
        end;
      end;

      // default mask
      Mask := DefaultMask;
      if (FlagHexagonal and j <> 0) then
      begin
        Mask := Mask shl 8;
        if (i = MaxI) then goto fillmask{Mask = 0};
      end;
      Mask := Mask and $ff00;

      // each child loop
      Flags := (1 shl 8){bit} + 0{child};
      repeat
        if (Mask and Flags <> 0) then
        begin
          CellInfo := Flags and 7;

          X := POINT_OFFSETS[CellInfo].x;
          Y := POINT_OFFSETS[CellInfo].y;
          Inc(Y, j);
          Inc(X, i);

          if (Cardinal(Y) > Cardinal(MaxJ)) or
             (Cardinal(X) > Cardinal(MaxI - (FlagHexagonal and Y))) then
            goto clearbit;

          // tile barier
          CellInfo := PCPFCell(NativeInt(Cell) + CellOffsets[{$ifdef CPUX86}Flags and 7{$else}CellInfo{$endif}]).NodePtr;
          if (CellInfo and NODEPTR_FLAG_ALLOCATED = 0) then
          begin
            if {$ifdef LARGEINT}
                 (CellInfo <= $ffffff)
               {$else}
                 (CellInfo and Integer($ff000000){Tile} = 0{TILE_BARIER})
               {$endif} then goto clearbit;
          end else
          begin
            if (PCPFNode(
                {$ifdef LARGEINT}NodeBuffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
                CellInfo and NODEPTR_CLEAN_MASK
                ).Tile = 0) then
            begin
              clearbit:
              Mask := (Mask xor Flags) and -8;
            end;
          end;
        end;

        X := Flags and -8;
        Inc(Flags);
        Inc(Flags, X);
      until (Mask < Flags);

      // mask to byte
      Mask := Mask shr 8;

      // rounded
      if (Rounded) then
      begin
        Mask := ROUNDED_MASKS[Mask];
      end;

    fillmask:
      CellInfo := Cell.NodePtr;
      if (CellInfo and NODEPTR_FLAG_ALLOCATED <> 0) then
      begin
        PCPFNode(
            {$ifdef LARGEINT}NodeBuffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
            CellInfo and NODEPTR_CLEAN_MASK
          ).Mask := Mask;
      end else
      begin
        Cell.Mask := Mask;
      end;

    nextcell:
      {$ifdef CPUX86}
        X := i + 1;
        Inc(Cell);
        i := X;
        if (X = Right) then Break;
      {$else}
        Inc(i);
        Inc(Cell);
        if (i = Right) then Break;
      {$endif}
    until (False);

    // next line
    {$ifdef CPUX86}
      X := j + 1;
      Inc(NativeUInt(Cell), CellLineOffset);
      j := X;
      if (X = Bottom) then Break;
    {$else}
      Inc(j);
      Inc(NativeUInt(Cell), CellLineOffset);
      if (j = Bottom) then Break;
    {$endif}
  until (False);
end;

procedure TTileMap.Clear;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}


end;

function TTileMap.GetTile(const X, Y: Word): Byte;
var
  _X, _Y: Word;
  _Self: Pointer;
  CellInfo: NativeUInt;
begin
  if (X >= Width) or (Y >= Height)  then
  begin
    _Self := Pointer({$ifdef CPFLIB}@Self{$else}Self{$endif});
    _X := X;
    _Y := Y;

    {$ifNdef CPFLIB}
      TTileMapPtr(_Self).FCallAddress := ReturnAddress;
    {$endif}

    TTileMapPtr(_Self).RaiseCoordinates(_X, _Y, 'tile');
    Result := 0;
  end else
  begin
    CellInfo := Self.FInfo.CellArray[Width * Y + X].NodePtr;
    if (CellInfo and NODEPTR_FLAG_ALLOCATED <> 0) then
    begin
      Result := PCPFNode(
                {$ifdef LARGEINT}FInfo.NodeAllocator.Buffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
                CellInfo and NODEPTR_CLEAN_MASK
                 ).Tile;
    end else
    begin
      Result := CellInfo shr 24;
    end;
  end;
end;

procedure TTileMap.SetTile(const X, Y: Word; Value: Byte);
var
  _X, _Y: Word;
  _Self: Pointer;
  Cell: PCPFCell;
  Node: PCPFNode;
  CellInfo, ValueInfo: NativeUInt;
  ChangedArea: TRect;
begin
  CellInfo := Width;
  if (X >= Word(CellInfo){Width}) or (Y >= Height)  then
  begin
    _Self := Pointer({$ifdef CPFLIB}@Self{$else}Self{$endif});
    _X := X;
    _Y := Y;

    {$ifNdef CPFLIB}
      TTileMapPtr(_Self).FCallAddress := ReturnAddress;
    {$endif}

    TTileMapPtr(_Self).RaiseCoordinates(_X, _Y, 'tile');
  end else
  begin
    ChangedArea.Left := X;
    ChangedArea.Top := Y;
    Cell := Pointer(CellInfo{Width} * Y + X);
    Inc(NativeUInt(Cell), NativeUInt(Self.FInfo.CellArray));

    CellInfo := Cell.NodePtr;
    if (CellInfo and NODEPTR_FLAG_ALLOCATED <> 0) then
    begin
      Node := PCPFNode(
                {$ifdef LARGEINT}FInfo.NodeAllocator.Buffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
                CellInfo and NODEPTR_CLEAN_MASK
                 );
      CellInfo := Node.NodeInfo shr 24;
      ValueInfo := Value;
      if (CellInfo = ValueInfo) then Exit;
      Node.Tile := ValueInfo;
    end else
    begin
      CellInfo := CellInfo shr 24;
      ValueInfo := Value;
      if (CellInfo = ValueInfo) then Exit;
      Cell.Tile := ValueInfo;
    end;

    Dec(CellInfo);
    Dec(ValueInfo);
    FActualInfo.TilesChanged := True;
    CellInfo := CellInfo or ValueInfo;
    if (NativeInt(CellInfo) = -1) then
    begin
      ChangedArea.Right := ChangedArea.Left;
      ChangedArea.Bottom := ChangedArea.Top;
      FActualInfo.SectorsChanged := True;
      UpdateCellMasks(ChangedArea);
    end;
  end;
end;

procedure TTileMap.Update(const ATiles: PByte; const X, Y, AWidth,
  AHeight: Word; const Pitch: NativeInt);
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

end;

procedure TTileMap.GrowNodeAllocator(var Buffer: TCPFInfo);
var
  AllocatorCount: NativeUInt;
  Count: NativeUInt;
  LastItem: Boolean;
  Node: PCPFNode;
begin
  // check data
  AllocatorCount := Buffer.NodeAllocator.Count;
  if (@Buffer <> @FInfo) then
  if (Buffer.NodeAllocator.NewNode <> FInfo.NodeAllocator.NewNodeLimit) or
     (AllocatorCount <> FInfo.NodeAllocator.Count) then
    CPFException('Incorrect node allocator data');

  if (AllocatorCount >= High(FNodes.Storage.Buffers)) then
    RaiseOutOfMemory(FCallAddress);

  // nodes count in storage item
  Count := NODESTORAGE_INFO[AllocatorCount].Previous + NODESTORAGE_INFO[AllocatorCount].Count;
  LastItem := (Count >= FCellCount);
  if (LastItem) then Count := FCellCount;
  Dec(Count, NODESTORAGE_INFO[AllocatorCount].Previous);

  // allocate if needed
  if (AllocatorCount = FNodes.Storage.Count) then
  begin
    CPFGetMem(FNodes.Storage.Buffers[AllocatorCount] , Count * SizeOf(TCPFNode));
    Inc(FNodes.Storage.Count);
  end;
  FInfo.NodeAllocator.Buffers[AllocatorCount] := FNodes.Storage.Buffers[AllocatorCount];

  // params
  Node := FInfo.NodeAllocator.Buffers[AllocatorCount];
  Inc(FInfo.NodeAllocator.Count);
  FInfo.NodeAllocator.NewNode := Node;
  {$ifdef LARGEINT}
    FInfo.NodeAllocator.LargeModifier :=
      (NativeInt(AllocatorCount) shl LARGE_NODEPTR_OFFSET) - NativeInt(Node);
  {$endif}
  Inc(Node, NativeInt(Count) - 1 + Ord(LastItem));
  FInfo.NodeAllocator.NewNodeLimit := Node;

  //  copy to buffer
  if (@Buffer <> @FInfo) then
  begin
    Buffer.NodeAllocator.NewNode := FInfo.NodeAllocator.NewNode;
    Buffer.NodeAllocator.NewNodeLimit := FInfo.NodeAllocator.NewNodeLimit;
    Buffer.NodeAllocator.Count := FInfo.NodeAllocator.Count;
    {$ifdef LARGEINT}
      Buffer.NodeAllocator.LargeModifier := FInfo.NodeAllocator.LargeModifier;
    {$endif}
    Buffer.NodeAllocator.Buffers[AllocatorCount] := FInfo.NodeAllocator.Buffers[AllocatorCount];
  end;
end;

(*function TTileMap.AllocateNode(const X, Y: NativeInt): PCPFNode;
var
  Coordinates: NativeUInt;
  Cell: PCPFCell;
  ChildNode: PCPFNode;
  NodeInfo: NativeUInt;

  {$ifdef LARGEINT}
    NodeBuffers: PCPFNodeBuffers;
    NODEPTR_MODIFIER: NativeInt;
  {$else}
const
    NODEPTR_MODIFIER = NODEPTR_FLAG_CALCULATED;
  {$endif}
begin
  Coordinates := Y + (X shl 16);
  Cell := @FInfo.Cells[X + FInfo.MapWidth * Y];

  // clear bits?
  ChildNode := Pointer(NativeUInt(Cell.NodePtr));
  if (NativeInt(ChildNode) and NODEPTR_FLAG_CALCULATED = 0) then
  begin
    Result := FInfo.NodeAllocator.NewNode;
    Cardinal(Result.Coordinates) := Coordinates;
    {$ifdef LARGEINT}
      Cell.NodePtr := NativeUInt(NativeInt(Result) + FInfo.NodeAllocator.LargeModifier);
    {$else}
      Cell.NodePtr := NativeUInt(Result);
    {$endif}

    // tile, mask --> (0, mask, 0, tile)
    NodeInfo := PWord(Cell)^;
    NodeInfo := (NodeInfo + (NodeInfo shl 24)) and Integer($00ff00ff);
    Result.NodeInfo := NodeInfo;

    // set next allocable node
    if (Result = FInfo.NodeAllocator.NewNodeLimit) then
    begin
      GrowNodeAllocator(FInfo.NodeAllocator);
    end else
    begin
      Inc(Result);
      FInfo.NodeAllocator.NewNode := Result;
      Dec(Result);
    end;



  end else
  begin
    // NodePtr --> Pointer
    {$ifdef LARGEINT}
      NodeBuffers := Pointer(@FInfo.NodeAllocator.Buffers);
      ChildNode := Pointer(
        (NodeBuffers[NativeUInt(ChildNode) shr LARGE_NODEPTR_OFFSET]) +
        (NativeUInt(ChildNode) and NODEPTR_CLEAN_MASK) );
    {$else}
      ChildNode := Pointer(NativeInt(ChildNode) and NODEPTR_CLEAN_MASK);
    {$endif}
  end;

  Result := ChildNode;
end; *)

function TTileMap.CalculateHeuristics(const Start, Finish: TPoint): NativeInt;
var
  dX, dY, X, Y: NativeInt;
  Mask: NativeInt;
begin
  dY := Start.Y - Finish.Y;
  dX := Start.X - Finish.X;

  // Y := Abs(dY)
  Mask := -(dY shr HIGH_NATIVE_BIT);
  Y := (dY xor Mask) - Mask;

  // X := Abs(dY)
  Mask := -(dX shr HIGH_NATIVE_BIT);
  X := (dX xor Mask) - Mask;

  if (Self.FKind < mkHexagonal) then
  begin
    if (X <= Y) then
    begin
      Result := X * FInfo.HeuristicsDiagonal + (Y - X) * FInfo.HeuristicsLine;
    end else
    begin
      Result := Y * FInfo.HeuristicsDiagonal + (X - Y) * FInfo.HeuristicsLine;
    end;
  end else
  begin
    X := X - ((Mask xor Finish.Y) and Y and 1) - (Y shr 1);
    Result := Y + (X and ((X shr HIGH_NATIVE_BIT) - 1));
    Result := Result * FInfo.HeuristicsLine;
  end;
end;

(*procedure TTileMap.ClearMapCells(Node: PCPFNode; Count: NativeUInt);
var
  TopNode: PCPFNode;
  NodeInfo{XY}: NativeUInt;
  MapWidth: NativeInt;
  Cells: PCPFCellArray;
begin
  TopNode := Node;
  Inc(TopNode, Count);

  Cells := FInfo.Cells;
  MapWidth := FInfo.MapWidth;

  while (Node <> TopNode) do
  begin
    NodeInfo{XY} := Cardinal(Node.Coordinates);
    Cells[(NativeInt(NodeInfo) shr 16){X} + MapWidth * {Y}Word(NodeInfo)].NodePtr := 0;

    Inc(Node);
  end;
end;

procedure TTileMap.ClearMapCells(Node: PCPFNode{as list});
var
  NodeInfo{XY}: NativeUInt;
  MapWidth: NativeInt;
  Cells: PCPFCellArray;
begin
  Cells := FInfo.Cells;
  MapWidth := FInfo.MapWidth;

  while (Node <> nil) do
  begin
    NodeInfo{XY} := Cardinal(Node.Coordinates);
    Cells[(NativeInt(NodeInfo) shr 16){X} + MapWidth * {Y}Word(NodeInfo)].NodePtr := 0;

    Node := Node.Next;
  end;
end; *)

function TTileMap.ActualizeWeights(Weights: PCPFWeightsInfo; Compare: Boolean): Boolean;
label
  return_false;
var
  LastCount, Count: Cardinal;
  V: Cardinal;
  i: NativeUInt;
  PWeight: PSingle;
begin
  LastCount := FActualInfo.Weights.Count;

  if (Weights = nil) then
  begin
    if (LastCount = 0) then
    begin
      Result := True;
      Exit;
    end;

    // release
    if (FActualInfo.Weights.Current <> nil) then
    begin
      FActualInfo.Weights.Current.Release(FCallAddress);
      FActualInfo.Weights.Current := nil;
    end;

    Count := 0;
  end else
  if (FActualInfo.Weights.Current = Weights) and
    (FActualInfo.Weights.UpdateId = Weights.UpdateId) then
  begin
    Result := True;
    Exit;
  end else
  begin
    // prepair scale
    if (Weights.PrepareId <> Weights.UpdateId) then
      Weights.Prepare;

    // release/addref
    if (FActualInfo.Weights.Current <> Weights) then
    begin
      if (FActualInfo.Weights.Current <> nil) then
        FActualInfo.Weights.Current.Release(FCallAddress);
    end;
    FActualInfo.Weights.Current := Weights;
    Inc(Weights.RefCount);
    FActualInfo.Weights.UpdateId := Weights.UpdateId;

    // compare
    Count := Weights.Count;
    if (Compare) and (LastCount = Count) and
      (CompareMem(@FActualInfo.Weights.Singles, @Weights.Singles, SizeOf(Single) * Count)) then
    begin
      Result := True;
      Exit;
    end;
  end;
  FActualInfo.Weights.Count := Count;

  // fill default values
  if (Count < LastCount) then
  begin
    V := LastCount - Count;
    Inc(LastCount);

    FillCardinal(Pointer(@FActualInfo.Weights.Singles[LastCount]), V, DEFAULT_WEIGHT_VALUE);
    FillCardinal(Pointer(@FActualInfo.Weights.SinglesDiagonal[LastCount]), V, DEFAULT_WEIGHT_VALUE_DIAGONAL);

    FillCardinal(@FActualInfo.Weights.Cardinals[LastCount], V, FTileDefaultWeight);
    FillCardinal(@FActualInfo.Weights.CardinalsDiagonal[LastCount], V, FTileDefaultWeightDiagonal);
  end;

  // copy and calculate weights
  if (Count <> 0) then
  begin
    Move(Weights.Singles[1], FActualInfo.Weights.Singles[1], SizeOf(Single) * Count);

    for i := Count downto 1 do      
    begin
      PWeight := @FActualInfo.Weights.Singles[i];
      if (PCardinal(PWeight)^ = 0) then
      begin
        FActualInfo.Weights.Cardinals[i] := PATHLESS_TILE_WEIGHT;
        FActualInfo.Weights.CardinalsDiagonal[i] := PATHLESS_TILE_WEIGHT;
        Continue;
      end;

      V := CPFRound(PWeight^ * FTileWeightScale);
      if (V > FTileWeightLimit) then V := FTileWeightLimit
      else
      if (V < FTileWeightMinimum) then V := FTileWeightMinimum;
      FActualInfo.Weights.Cardinals[i] := V;

      if (FSameDiagonalWeight) then
      begin
        FActualInfo.Weights.SinglesDiagonal[i] := PWeight^;
        FActualInfo.Weights.CardinalsDiagonal[i] := V;
      end else
      begin
        FActualInfo.Weights.SinglesDiagonal[i] := SQRT2 * PWeight^;

        V := CPFRound(PWeight^ * FTileWeightScaleDiagonal);
        if (V < FTileWeightMinimumDiagonal) then V := FTileWeightMinimumDiagonal;
        FActualInfo.Weights.CardinalsDiagonal[i] := V;
      end;
    end;

    // heuristics
    V := CPFRound(PSingle(@Weights.Minimum)^ * FTileWeightScale);
    if (V > FTileWeightLimit) then FInfo.HeuristicsLine := FTileWeightLimit
    else
    if (V < FTileWeightMinimum) then FInfo.HeuristicsLine := FTileWeightMinimum
    else
    FInfo.HeuristicsLine := V;

    V := CPFRound(PSingle(@Weights.Minimum)^ * FTileWeightScaleDiagonal);
    if (V < FTileWeightMinimumDiagonal) then FInfo.HeuristicsDiagonal := FTileWeightMinimumDiagonal
    else
    FInfo.HeuristicsDiagonal := V;
  end else
  begin
    // default heuristics
    FInfo.HeuristicsLine := FTileDefaultWeight;
    FInfo.HeuristicsDiagonal := FTileDefaultWeightDiagonal;
  end;

  // simple map heuristics correction
  if (Self.Kind = mkSimple) then
    FInfo.HeuristicsDiagonal := FInfo.HeuristicsLine * 2;

return_false:
  Result := False;
end;

function TTileMap.ActualizeStarts(Points: PPoint; Count: NativeUInt; Compare: Boolean): Boolean;
var
  CompareBits: Integer;
  Point: PPoint;
  Start: PCPFStart;
begin
  Point := Points;
  CompareBits := Byte(FActualInfo.Starts.Count <> Count){0 if the same};

  Start := FActualInfo.Starts.Buffer.Alloc(SizeOf(TCPFStart) * Count);
  while (Count <> 0) do
  begin
    CompareBits := CompareBits or (Start.X - Point.X) or (Start.Y - Point.Y);

    Start.X := Point.X;
    Start.Y := Point.Y;

    Dec(Count);
    Inc(Point);
    Inc(Start);
  end;

  Result := (CompareBits = 0);
end;

function TTileMap.ActualizeExcludes(Points: PPoint; Count: NativeUInt; Compare: Boolean): Boolean;
var
  Size: NativeUInt;
begin
  Size := SizeOf(TPoint) * Count;

  if (Compare) and (Count = FActualInfo.Excludes.Count) and
    CompareMem(Points, FActualInfo.Excludes.Buffer.Memory, Size) then
  begin
    Result := True;
    Exit;
  end;

  FActualInfo.Excludes.Count := Count;
  Move(Points^, FActualInfo.Excludes.Buffer.Alloc(Size)^, Size);

  Result := False;
end;

procedure FloodTileMapSectors(Cell: PCPFCell; Sector: PByte;
  const Offsets: TCPFOffsets
  {$ifdef LARGEINT}; NodeBuffers: PCPFNodeBuffers{$endif});
label
  clearbit;
var
  SectorValue: Byte;
  Mask, Flags: NativeUInt;

  Offset: NativeInt;
  ChildSector: PByte;
begin
  SectorValue := Sector^;

  // mask
  Mask := Cell.NodePtr;
  if (Mask and NODEPTR_FLAG_ALLOCATED <> 0) then
  begin
    Mask := PCPFNode
      (
        {$ifdef LARGEINT}NodeBuffers[Mask shr LARGE_NODEPTR_OFFSET] +{$endif}
        Mask and NODEPTR_CLEAN_MASK
      ).NodeInfo;
  end;
  Mask := Mask and $ff00;

  // check loop
  Flags := (1 shl 8){bit} + 0{child};
  repeat
    if (Mask and Flags <> 0) then
    begin
      Offset := Offsets[Flags and 7];
      ChildSector := Sector;
      Inc(NativeInt(ChildSector), Offset);
      if (ChildSector^ = SECTOR_EMPTY) then
      begin
        Offset := {ChildCell.NodePtr}PCPFCell(NativeInt(Cell) + Offset * SizeOf(TCPFCell)).NodePtr;
        if (Offset and NODEPTR_FLAG_ALLOCATED <> 0) then
        begin
          Offset := PCPFNode
            (
              {$ifdef LARGEINT}NodeBuffers[Offset shr LARGE_NODEPTR_OFFSET] +{$endif}
              Offset and NODEPTR_CLEAN_MASK
            ).NodeInfo;
        end;

        if {$ifdef LARGEINT}
             (Offset > $ffffff)
           {$else}
             (Offset and Integer($ff000000){Tile} <> 0{TILE_BARIER})
           {$endif} and
           (Offset and $ff00{Mask} <> 0) then
        begin
          ChildSector^ := SectorValue;
        end else
        begin
          ChildSector^ := SECTOR_PATHLESS;
          goto clearbit;
        end;
      end else
      begin
        clearbit:
        Mask := (Mask xor Flags) and -8;
      end;
    end;

    // bit << 1, child++
    if (Flags = (1 shl (8+7)) + 7) then Break;
    Offset := Flags and -8;
    Inc(Flags);
    Inc(Flags, Offset);
  until (False);

  // recursion loop
  Flags := (1 shl 8){bit} + 0{child};
  while (Mask <> 0) do
  begin
    if (Mask and Flags <> 0) then
    begin
      Offset := Offsets[Flags and 7];

      FloodTileMapSectors(
        {ChildCell} PCPFCell(NativeInt(Cell) + Offset * SizeOf(TCPFCell)),
        {ChildSector} PByte(NativeInt(Sector) + Offset),
        Offsets{$ifdef LARGEINT}, NodeBuffers{$endif});
    end;

    Mask := (Mask xor Flags) and -8;
    Offset := Flags and -8;
    Inc(Flags);
    Inc(Flags, Offset);
  end;
end;

procedure TTileMap.ActualizeSectors;
var
  i: NativeUInt;
  Cell: PCPFCell;
  CellInfo: NativeUInt;
  Sector: PByte;
  CurrentSector, SectorOverflow: NativeUInt;
  SectorOffsets: TCPFOffsets;
  {$ifdef LARGEINT}
    NodeBuffers: PCPFNodeBuffers;
  {$endif}
begin
  if (FActualInfo.Sectors = nil) then
    CPFGetMem(Pointer(FActualInfo.Sectors), SizeOf(Byte) * FCellCount);

  ZeroMemory(FActualInfo.Sectors, SizeOf(Byte) * FCellCount);
  FActualInfo.SectorsChanged := False;

  {$ifdef LARGEINT}
  NodeBuffers := Pointer(@FInfo.NodeAllocator.Buffers);
  {$endif}

  SectorOffsets := FSectorOffsets;
  Cell := @FInfo.CellArray[0];
  Sector := FActualInfo.Sectors;
  CurrentSector := 0;
  for i := 1 to FCellCount do
  begin
    if (Sector^ = SECTOR_EMPTY{0}) then
    begin
      CellInfo := Cell.NodePtr;
      if (CellInfo and NODEPTR_FLAG_ALLOCATED <> 0) then
      begin
        CellInfo := PCPFNode
          (
            {$ifdef LARGEINT}NodeBuffers[CellInfo shr LARGE_NODEPTR_OFFSET] +{$endif}
            CellInfo and NODEPTR_CLEAN_MASK
          ).NodeInfo;
      end;

      if {$ifdef LARGEINT}
           (CellInfo <= $ffffff)
         {$else}
           (CellInfo and Integer($ff000000){Tile} = 0{TILE_BARIER})
         {$endif} or
         (CellInfo and $ff00{Mask} = 0) then
      begin
        Sector^ := SECTOR_PATHLESS;
      end else
      begin
        // *Sector = CurrentSector==0xff?2:CurrentSector+1;
        SectorOverflow := ((CurrentSector + 1) shr 7) and 2;
        Inc(CurrentSector);
        Inc(CurrentSector, SectorOverflow);
        Sector^ := CurrentSector;
          FloodTileMapSectors(Cell, Sector, SectorOffsets{$ifdef LARGEINT}, NodeBuffers{$endif});
        CurrentSector := Sector^;
      end;
    end;

    Inc(Cell);
    Inc(Sector);
  end;
end;

procedure TTileMap.AddHeuristedNodes(const First, Last: PCPFNode);
var
  Next: PCPFNode;
begin
  Next := FNodes.Heuristed.First.Next;

  // FNodes.Heuristed.First + First
  FNodes.Heuristed.First.Next := First;
  First.Prev := @FNodes.Heuristed.First;

  // Last + Next
  Last.Next := Next;
  Next.Prev := Last;
end;

procedure TTileMap.ReleaseAttainableNodes;
begin
  // todo
end;

procedure TTileMap.ReleaseHeuristedNodes;
var
  Node: PCPFNode;
  Cells: PCPFCellArray;
  Cell: PCPFCell;
  Coordinates, MapWidth: NativeInt;
begin
  // take node list
  Node := FNodes.Heuristed.First.Next;
  if (Node = @FNodes.Heuristed.Last) then Exit;
  FNodes.Heuristed.First.Next := @FNodes.Heuristed.Last;
  FNodes.Heuristed.Last.Prev := @FNodes.Heuristed.First;

  // clear flag loop
  Cells := FInfo.CellArray;
  MapWidth := FInfo.MapWidth;
  while (Node <> nil) do
  begin
    Coordinates := Cardinal(Node.Coordinates);
    Node := Node.Next;

    Cell := @Cells[(Coordinates shr 16){X} + MapWidth * {Y}Word(Coordinates)];
    Cell.NodePtr := Cell.NodePtr and (not NODEPTR_FLAG_HEURISTED);
  end;
end;

(*procedure TTileMap.ReleaseAllocatedNodes;
begin
  // todo
end;*)

function TTileMap.DoFindPathLoop(StartNode: PCPFNode): PCPFNode;
label
  nextchild_continue, nextchild,
  heuristics_data,
  next_current, current_initialize;
const
  NODEPTR_FLAGS = NODEPTR_FLAG_HEURISTED + NODEPTR_FLAG_ALLOCATED;
  PARENT_BITS_CLEAR_MASK = not Cardinal($00ff000 + 7);
  COUNTER_OFFSET = 16;
type
  TMapNodeBuffer = array[0..7] of PCPFNode;
  PMapNodeBuffer = ^TMapNodeBuffer;
  TCardinalList = array[0..High(Integer) div SizeOf(Cardinal) - 1] of Cardinal;
  PCardinalList = ^TCardinalList;
var
  Node: PCPFNode;
  NodeInfo: NativeUInt;
  ChildList: PWord;
  Child: NativeUInt;
  Cell: PCPFCell;
  ParentBits: NativeUInt;
  ChildNodeInfo: NativeUInt;
  ChildNode: PCPFNode;
  TileWeights: PCardinalList;
  Path: Cardinal;
  NodeXY, OffsetXY, ChildXY: Cardinal;
  X, Y, Mask: NativeInt;

  ChildSortValue: Cardinal;
  PBufferHigh, PBufferBase, PBufferCurrent: ^PCPFNode;
  Right: PCPFNode;
  {$if (not Defined(CPUX86)) or Defined(FPC)}
    Left: PCPFNode;
  {$ifend}

  Store: record
    Buffer: TMapNodeBuffer;
    Self: Pointer;
    HexagonalFlag: NativeUInt;
    Info: TCPFInfo;

    {$ifdef CPUX86}
    ChildList: PWord;
    TopGreatherNode: PCPFNode;
    {$endif}

    Current: record
      Node: PCPFNode;
      Cell: PCPFCell;
      Coordinates: TCPFPoint;
      SortValue: Cardinal;
      Path: Cardinal;
    end;
    Top: record
      Node: PCPFNode;
      SortValue: Cardinal;
    end;
  end;

  {$ifNdef CPUX86}
    Buffer: PMapNodeBuffer;
    TopGreatherNode: PCPFNode;
  {$endif}

  {$ifdef LARGEINT}
    NodeBuffers: PCPFNodeBuffers;
    NODEPTR_MODIFIER: NativeInt;
  {$endif}
begin
  Store.Self := Pointer({$ifdef CPFLIB}@Self{$else}Self{$endif});
  Store.HexagonalFlag := NativeUInt(Self.FKind = mkHexagonal) * 2;
  Move(Self.FInfo, Store.Info,
    (SizeOf(Store.Info) - 32 * SizeOf(Pointer)) +
    (Self.FInfo.NodeAllocator.Count * SizeOf(Pointer)) );

  {$ifNdef CPUX86}
    Buffer := @Store.Buffer;
  {$endif}

  {$ifdef LARGEINT}
    NODEPTR_MODIFIER := Store.Info.NodeAllocator.LargeModifier + NODEPTR_FLAGS;
  {$endif}

  // Top initialization
  Node := StartNode.Next;
  Store.Top.Node := Node;
  Node.Prev := StartNode;
  Store.Top.SortValue := SORTVALUE_LIMIT;

  // finding loop from Start to Finish
  Node := StartNode;
  goto current_initialize;
  repeat
    // lock
    Node.ParentMask := 0;

    // next top node and sort value
    if (ChildSortValue = Store.Top.SortValue){Node = Store.Top.Node} then
    begin
      repeat
        Node := Node.Next;
        Path := Node.SortValue;
      until (Path > ChildSortValue);

      Store.Top.Node := Node;
      Store.Top.SortValue := Path;
    end;

    // child list
    ChildList := Pointer(NativeUInt(CHILD_ARRAYS_OFFSETS[NodeInfo and 63]));
    Inc(NativeUInt(ChildList), NativeUInt(@CHILD_ARRAYS));

    // reinitialize NodeInfo (from parentflags, mask, parentmask, tile):
    //   - bit hexagonal << 1
    //   - mask
    //   - stored childs counter
    //   - tile
    NodeInfo := ((NodeInfo and (NodeInfo shr 8)) and Integer($ff00ff00)) or Store.HexagonalFlag;

    // each child cell loop
    goto nextchild;
    nextchild_continue:
    if (NodeInfo and $ff00 <> 0) then
    repeat
      // first available
      {$ifdef CPUX86}
      ChildList := Store.ChildList;
      {$endif}
      nextchild:
      Child := ChildList^;
      Inc(ChildList);
      if (NodeInfo and Child = 0) then goto nextchild;
      {$ifdef CPUX86}
      Store.ChildList := ChildList;
      {$endif}

      // clear child bit, get child number
      NodeInfo := NodeInfo and (not Child);
      Child := (Child shr 4) and 7;

      // child map cell
      Cell := Store.Current.Cell;
      Inc(NativeInt(Cell), Store.Info.CellOffsets[Child]);

      // parent bits
      Child := Child shl 2;
      Child := Child + (NodeInfo and 2) + (NativeUInt(Cardinal(Store.Current.Coordinates)) and 1);
      ParentBits := PARENT_BITS[Child];

      // allocated new or use exists
      ChildNodeInfo := Cell.NodePtr;
      if (ChildNodeInfo and NODEPTR_FLAG_HEURISTED = 0) then
      begin
        if (ChildNodeInfo and NODEPTR_FLAG_ALLOCATED = 0) then
        begin
          // child node info (without heuristics data)
          ChildNodeInfo := ChildNodeInfo and Integer($ff00ff00);
          ParentBits := ParentBits or ChildNodeInfo;
          if (ParentBits and (ChildNodeInfo shl 8) = 0) then goto nextchild_continue;

          // child path
          TileWeights := Store.Info.TileWeights[ParentBits and 1];
          Path := TileWeights[NodeInfo shr 24];
          Inc(Path, TileWeights[ParentBits shr 24]);
          if (Path > PATHLESS_TILE_WEIGHT) then goto nextchild_continue;
          Path := (Path shr 1) + Store.Current.Path;

          // allocate new node
          ChildNode := Store.Info.NodeAllocator.NewNode;
          {$ifdef LARGEINT}
            Cell.NodePtr := NativeUInt(NativeInt(ChildNode) + NODEPTR_MODIFIER);
          {$else}
            Cell.NodePtr := NativeUInt(ChildNode) + NODEPTR_FLAGS;
          {$endif}
          ChildNode.Path := Path;
          ChildNode.NodeInfo := ParentBits;

          // child coordinates
          OffsetXY := Cardinal(POINT_OFFSETS_INVERT[ParentBits and 7]);
          NodeXY := Cardinal(Store.Current.Coordinates);
          ChildXY := NodeXY + OffsetXY;
          OffsetXY := OffsetXY and $ffff0000;
          NodeXY := NodeXY and $ffff0000;
          ChildXY := Word(ChildXY) + NodeXY + OffsetXY;
          Cardinal(ChildNode.Coordinates) := ChildXY;

          // set next allocable node
          if (ChildNode <> Store.Info.NodeAllocator.NewNodeLimit) then
          begin
            Inc(ChildNode);
            Store.Info.NodeAllocator.NewNode := ChildNode;
            Dec(ChildNode);
          end else
          begin
            {$ifdef CPUX86}
              NativeUInt(Store.TopGreatherNode) := NodeInfo;
            {$endif}
            TTileMapPtr(Store.Self).GrowNodeAllocator(Store.Info);
            {$ifdef LARGEINT}
              NODEPTR_MODIFIER := Store.Info.NodeAllocator.LargeModifier + NODEPTR_FLAGS;
            {$endif}
            {$ifdef CPUX86}
              NodeInfo := NativeUInt(Store.TopGreatherNode);
            {$endif}
          end;
          goto heuristics_data;
        end else
        begin
          // already node allocated and coordinates filled
          // need to fill path/parent and heuristics/way data
          {$ifdef LARGEINT}
            NodeBuffers := Pointer(@Store.Info.NodeAllocator.Buffers);
            ChildNode := Pointer(
              (NodeBuffers[ChildNodeInfo shr LARGE_NODEPTR_OFFSET]) +
              (ChildNodeInfo and NODEPTR_CLEAN_MASK) );
          {$else}
            ChildNode := Pointer(ChildNodeInfo and NODEPTR_CLEAN_MASK);
          {$endif}

          // child node info (without heuristics data)
          TileWeights{ChildNodeInfo} := Pointer(NativeUInt(ChildNode.NodeInfo) and Integer($ff00ff00));
          ParentBits := ParentBits or NativeUInt(TileWeights){ChildNodeInfo};
          if (ParentBits and (NativeUInt(TileWeights){ChildNodeInfo} shl 8) = 0) then goto nextchild_continue;

          // child path
          TileWeights := Store.Info.TileWeights[ParentBits and 1];
          Path := TileWeights[NodeInfo shr 24];
          Inc(Path, TileWeights[ParentBits shr 24]);
          if (Path > PATHLESS_TILE_WEIGHT) then goto nextchild_continue;
          Path := (Path shr 1) + Store.Current.Path;

          // heuristed flag
          {$ifdef CPUX86}
            ChildNode := Pointer(Cell.NodePtr);
            Cell.NodePtr := Cardinal(ChildNode) + NODEPTR_FLAG_HEURISTED;
            ChildNode := Pointer(Cardinal(ChildNode) and NODEPTR_CLEAN_MASK);
          {$else}
            Cell.NodePtr := ChildNodeInfo + NODEPTR_FLAG_HEURISTED;
          {$endif}
          ChildNode.Path := Path;
          ChildNode.NodeInfo := ParentBits;

        heuristics_data:
          // (dX, dY) = ChildNode.Coordinates - Store.Info.FinishPoint;
          X := Cardinal(ChildNode.Coordinates);
          Y := Word(X);
          X := X shr 16;
          Mask := Cardinal(Store.Info.FinishPoint);
          Y := Y - Word(Mask);
          X := X - (Mask shr 16);

          // Way
          Mask := 2*Byte(Y > 0) + (Y shr HIGH_NATIVE_BIT);
          Mask := Mask * 3;
          Mask := Mask + 2*Byte(X > 0);
          Mask := Mask - 1 + (X shr {$ifdef CPUX86}31{$else}HIGH_NATIVE_BIT{$endif}); // Delphi compiler optimization bug
          ChildNode.NodeInfo := ChildNode.NodeInfo or Cardinal(Mask shl 3);

          // Y := Abs(dY)
          Mask := -(Y shr HIGH_NATIVE_BIT);
          Y := Y xor Mask;
          Dec(Y, Mask);

          // X := Abs(dX)
          Mask := -(X shr HIGH_NATIVE_BIT);
          X := X xor Mask;
          Dec(X, Mask);

          // calculate
          if (Store.HexagonalFlag and 1 = 0) then
          begin
            if (X <= Y) then
            begin
              ChildNode.SortValue := {$ifdef CPUX86}ChildNode.{$endif}Path +
                 Cardinal(X * Store.Info.HeuristicsDiagonal + (Y - X) * Store.Info.HeuristicsLine);
            end else
            begin
              ChildNode.SortValue := {$ifdef CPUX86}ChildNode.{$endif}Path +
                 Cardinal(Y * Store.Info.HeuristicsDiagonal + (X - Y) * Store.Info.HeuristicsLine);
            end;
          end else
          begin
            X := X - ((Mask xor PNativeInt(@Store.Info.FinishPoint)^) and Y and 1) - (Y shr 1);
            ChildNode.SortValue := {$ifdef CPUX86}ChildNode.{$endif}Path +
               Cardinal(Store.Info.HeuristicsLine * (Y + (X and ((X shr HIGH_NATIVE_BIT) - 1))));
          end;
        end;
      end else
      begin
        {$ifdef LARGEINT}
          NodeBuffers := Pointer(@Store.Info.NodeAllocator.Buffers);
          ChildNode := Pointer(
            (NodeBuffers[ChildNodeInfo shr LARGE_NODEPTR_OFFSET]) +
            (ChildNodeInfo and NODEPTR_CLEAN_MASK) );
        {$else}
          ChildNode := Pointer(ChildNodeInfo and NODEPTR_CLEAN_MASK);
        {$endif}

        // child node info (with new parent bits)
        ChildNodeInfo := ChildNode.NodeInfo;
        ParentBits := ParentBits + (ChildNodeInfo and PARENT_BITS_CLEAR_MASK);
        if (ParentBits and ((ChildNodeInfo and $ff00) shl 8) = 0) then goto nextchild_continue;

        // child path
        Cell{TileWeights} := Store.Info.TileWeights[ParentBits and 1];
        Path := PCardinalList(Cell{TileWeights})[NodeInfo shr 24] +
                PCardinalList(Cell{TileWeights})[ParentBits shr 24];
        Path := (Path shr 1) + Store.Current.Path;

        // continue if the path is shorter
        NodeXY{ChildPath} := ChildNode.Path;
        if (Path >= NodeXY{ChildPath}) then goto nextchild_continue;

        // new parameters
        ChildNode.NodeInfo := ParentBits;
        ChildXY{ChildSortValue} := ChildNode.SortValue;
        ChildNode.Path := Path;
        ChildNode.SortValue := Path + {heuristics}(ChildXY{ChildSortValue} - NodeXY{ChildPath});

        // remove from opened list
        if (ChildXY{ChildSortValue} < NATTANABLE_LENGTH_LIMIT) then
        begin
          Node{Left} := ChildNode.Prev;
          Right := ChildNode.Next;
          Node{Left}.Next := Right;
          Right.Prev := Node{Left};
        end;
      end;

      // add child node to buffer
      {$ifdef CPUX86}Store.{$endif}Buffer[(NodeInfo shr COUNTER_OFFSET) and 7] := ChildNode;
      Inc(NodeInfo, (1 shl COUNTER_OFFSET));

      // goto nextchild_continue;
      if (NodeInfo and $ff00 = 0) then Break;
    until (False);

    // move buffered nodes to opened list
    if (NodeInfo and ($f shl COUNTER_OFFSET) = 0) then
      goto next_current;

    // internal child buffer sort by SortValue
    {
       for i = 1 to Count - 1 do
       begin
         for j := i-1 downto 0 do
         if (Buffer[j].SortValue > Buffer[j+1].SortValue) then
         begin
           Swap(Buffer[j], Buffer[j+1]);
         end else
         begin
           Break;
         end;
       end;
    }
    PBufferHigh := @{$ifdef CPUX86}Store.{$endif}Buffer[(NodeInfo shr COUNTER_OFFSET) and $f];
    PBufferBase := @{$ifdef CPUX86}Store.{$endif}Buffer[1];
    PBufferCurrent := @{$ifdef CPUX86}Store.{$endif}Buffer[0];
    while (PBufferBase <> PBufferHigh) do
    begin
      ChildNode := PBufferBase^;
      ChildSortValue := ChildNode.SortValue;

      Node := PBufferCurrent^;
      if (Node.SortValue > ChildSortValue) then
      begin
       repeat
          PMapNodeBuffer(PBufferCurrent)[1] := Node;
          if (PBufferCurrent = @{$ifdef CPUX86}Store.{$endif}Buffer[0]) then Break;

          Dec(PBufferCurrent);
          Node := PBufferCurrent^;
          if (Node.SortValue > ChildSortValue) then Continue;
          Inc(PBufferCurrent);
          Break;
        until (False);

        PBufferCurrent^ := ChildNode;
      end;

      PBufferCurrent := PBufferBase;
      Inc(PBufferBase);
    end;

    // insert sorted nodes
    {$ifdef CPUX86}Store.{$endif}TopGreatherNode := Store.Top.Node;
    PBufferCurrent := @{$ifdef CPUX86}Store.{$endif}Buffer[0];
    repeat
      // make same sort value list (ChildNode..Node)
      ChildNode := PBufferCurrent^;
      Inc(PBufferCurrent);
      Node := ChildNode;
      ChildSortValue := ChildNode.SortValue;
      while (PBufferCurrent <> PBufferHigh) do
      begin
        Right := PBufferCurrent^;
        if (Right.SortValue <> ChildSortValue) then Break;

        Node.Next := Right;
        Right.Prev := Node;

        Inc(PBufferCurrent);
        Node := Right;
      end;

      // insertion kinds
      if (ChildSortValue > Store.Current.SortValue) then
      begin
        if (ChildSortValue <= Store.Top.SortValue) then
        begin
          // before top
          Right := Store.Top.Node;
          Store.Top.Node := ChildNode;
          Store.Top.SortValue := ChildSortValue;
        end else
        begin
          // greater then top
          Right := {$ifdef CPUX86}Store.{$endif}TopGreatherNode;
          while (Right.SortValue < ChildSortValue) do Right := Right.Next;
          {$ifdef CPUX86}Store.{$endif}TopGreatherNode := Right;
        end;
      end else
      begin
        // after current
        Right := Store.Current.Node.Next;
      end;

      // insertion
      {$if (not Defined(CPUX86)) or Defined(FPC)}
        Left := Right.Prev;
        Node.Next := Right;
        ChildNode.Prev := Left;
        Left.Next := ChildNode;
        Right.Prev := Node;
      {$else}
        Node.Next := Right;
        with Right^ do
        begin
          ChildNode.Prev := Prev{Left};
          ChildNode.Prev{Left}.Next := ChildNode;
          Prev := Node;
        end;
      {$ifend}
    until (PBufferCurrent = PBufferHigh);

    // next opened node
  next_current:
    Node := Store.Current.Node.Next;
  current_initialize:
    // cell
    NodeInfo{XY} := Cardinal(Node.Coordinates);
    Cardinal(Store.Current.Coordinates) := NodeInfo{XY};
    Cell := @Store.Info.CellArray[(NativeInt(NodeInfo) shr 16){X} + Store.Info.MapWidth * {Y}Word(NodeInfo)];
    Store.Current.Cell := Cell;

    // store pointer and path
    Store.Current.Node := Node;
    Store.Current.Path := Node.Path;
    ChildSortValue := Node.SortValue;
    Store.Current.SortValue := ChildSortValue;

    // node info
    NodeInfo := Cardinal(Node.NodeInfo);
    if (NodeInfo and FLAG_KNOWN_PATH <> 0) then Break;
  until (False);

  // Result
  Result := Node;

  // actualize node allocator (new node pointer)
  TTileMapPtr(Store.Self).FInfo.NodeAllocator.NewNode := Store.Info.NodeAllocator.NewNode;
end;

function TTileMap.DoFindPath(const Params: TTileMapParams): TTileMapPath;
var
  i: NativeUInt;
  MapWidth, MapHeight: Cardinal;
  FinishX, FinishY: Integer;
  S: PPoint;
  Actual, R, ActualFinish, ActualStarts: Boolean;
begin
  // test start points coordinates
  MapWidth := Self.Width;
  MapHeight := Self.Height;
  S := Params.Starts;
  if (Params.StartsCount <> 0) then
  for i := 0 to Params.StartsCount - 1 do
  begin
    if (Cardinal(S.X) >= MapWidth) or (Cardinal(S.Y) >= MapHeight) then
      RaiseCoordinates(S.X, S.Y, 'start');

    Inc(S);
  end;

  // test finish point coordinates
  S := @Params.Finish;
  if (Cardinal(S.X) >= MapWidth) or (Cardinal(S.Y) >= MapHeight) then
    RaiseCoordinates(S.X, S.Y, 'finish');

  // test excluded points coordinates
  S := Params.Excludes;
  if (Params.ExcludesCount <> 0) then
  for i := 0 to Params.ExcludesCount - 1 do
  begin
    if (Cardinal(S.X) >= MapWidth) or (Cardinal(S.Y) >= MapHeight) then
      RaiseCoordinates(S.X, S.Y, 'excluded');

    Inc(S);
  end;

  // no start points case
  if (Params.StartsCount = 0) then
  begin
    Result.Points := nil;
    Result.Count := 0;
    Result.Distance := 0;
    Exit;
  end;

  // start is finish case
  FinishX := Params.Finish.X;
  FinishY := Params.Finish.Y;
  S := Params.Starts;
  for i := 0 to Params.StartsCount - 1 do
  begin
    if (S.X = FinishX) and (S.Y = FinishY) then
    begin
      FActualInfo.PathlessFinishPoint.X := FinishX;
      FActualInfo.PathlessFinishPoint.Y := FinishY;
      Result.Points := Pointer(@FActualInfo.PathlessFinishPoint);
      Result.Count := 1;
      Result.Distance := 0;
      Exit;
    end;

    Inc(S);
  end;

  // actualization
  Actual := FCaching;
  begin
    ActualFinish := (FinishX = Self.FActualInfo.FinishPoint.X) and
                    (FinishY = Self.FActualInfo.FinishPoint.Y);
    Actual := Actual and ActualFinish;

    // update id
    R := (not FActualInfo.TilesChanged);
    FActualInfo.TilesChanged := False;
    Actual := R and Actual;

    // tile weights
    if (Params.Weights = nil) then
    begin
      if (FActualInfo.Weights.Count <> 0) then
      begin
        R := ActualizeWeights(nil, Actual);
        Actual := R and Actual;
      end;
    end else
    if (FActualInfo.Weights.Current <> Params.Weights.FInfo) or
      (FActualInfo.Weights.UpdateId <> Params.Weights.FInfo.PrepareId) then
    begin
      R := ActualizeWeights(Params.Weights.FInfo, Actual);
      Actual := R and Actual;
    end;

    // excluded points
    if (FActualInfo.Excludes.Count + Params.ExcludesCount <> 0) then
    begin
      R := ActualizeExcludes(Params.Excludes, Params.ExcludesCount, Actual);
      Actual := R and Actual;
    end;

    // attainable points
    if (not Actual) then
      ReleaseAttainableNodes;

    // actualize finish point
    FActualInfo.FinishPoint.X := FinishX;
    FActualInfo.FinishPoint.Y := FinishY;
    FInfo.FinishPoint.X := FinishX;
    FInfo.FinishPoint.Y := FinishY;

    // heuristics points
    if (not ActualFinish) then
      ReleaseHeuristedNodes;

    // alloc start points
    ActualStarts := ActualizeStarts(Params.Starts, Params.StartsCount, Actual);

    // path is already exists case
    if (Actual) and (ActualStarts) then
    begin
      Result.Points := FActualInfo.FoundPath.Buffer.Memory;
      Result.Count := FActualInfo.FoundPath.Length;
      Result.Distance := FActualInfo.FoundPath.Distance;
      Exit;
    end;

    // sectors
    if (SectorTest) then
    begin
      if (FActualInfo.Sectors = nil) or (FActualInfo.SectorsChanged) then
        ActualizeSectors;
    end else
    begin
      if (FActualInfo.Sectors <> nil) then
        CPFFreeMem(Pointer(FActualInfo.Sectors));
    end;
  end;

  // excluded points todo
  if (not Actual) then
  begin
    // todo
  end;

  // start points
  // todo


  // found path
  //Result := FFindResult;
end;
(*label
  calculate_result;
var
  StartNode, FinishNode, Node: PCPFNode;
  FailureNode: TCPFNode;
  Start: PPoint;
begin
  // todo

  Start := Params.Starts;

  // todo

  // get and inspect/fill start node
  StartNode := nil;//AllocateNode(Start.X, Start.Y);
  if (StartNode.NodeInfo and FLAG_KNOWN_PATH <> 0) then
  begin
    Node := StartNode;
    goto calculate_result;
  end;
  // todo
  StartNode.Path := 0;
  StartNode.SortValue := 0{Path} + CalculateHeuristics(Start^, Params.Finish);

  // cache finish point and mark as known attainable
  FinishNode := nil;//AllocateNode(Start.X, Start.Y);
  FinishNode.NodeInfo := FLAG_KNOWN_PATH or FLAG_ATTAINABLE;

  // run finding loop
  FailureNode.NodeInfo := FLAG_KNOWN_PATH {+ !FLAG_ATTAINABLE};
  StartNode.Next := @FailureNode;
  FailureNode.Prev := StartNode;
  Node := DoFindPathLoop(StartNode);
  if (FCaching) then
  begin
    // MarkCachedPath(StartNode,
  end else
  begin
    // ?
  end;

calculate_result:
  if (Node.NodeInfo and FLAG_ATTAINABLE = 0) then
  begin
    Result := nil;
  end else
  begin
    Result := @FFindResult;
    // ToDo

    // todo calculate
  end;
end; *)

function TTileMap.FindPath(const Params: TTileMapParams): TTileMapPath;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

  Result := DoFindPath(Params);
end;

function TTileMap.FindPath(const Start, Finish: TPoint;
  const Weights: TTileMapWeightsPtr; const Excludes: PPoint;
  const ExcludesCount: NativeUInt): TTileMapPath;
var
  Params: TTileMapParams;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

  Params.Starts := @Start;
  Params.StartsCount := 1;
  Params.Finish := Finish;
  Params.Weights := Weights;
  Params.Excludes := Excludes;
  Params.ExcludesCount := ExcludesCount;

  Result := FindPath(Params);
end;

function TTileMap.FindPath(const Starts: PPoint; const StartsCount: NativeUInt;
   const Finish: TPoint; const Weights: TTileMapWeightsPtr = nil;
   const Excludes: PPoint = nil; const ExcludesCount: NativeUInt = 0): TTileMapPath;
var
  Params: TTileMapParams;
begin
  {$ifNdef CPFLIB}
    FCallAddress := ReturnAddress;
  {$endif}

  Params.Starts := Starts;
  Params.StartsCount := StartsCount;
  Params.Finish := Finish;
  Params.Weights := Weights;
  Params.Excludes := Excludes;
  Params.ExcludesCount := ExcludesCount;

  Result := FindPath(Params);
end;





initialization
  {$ifdef CPF_GENERATE_LOOKUPS}
    GenerateLookups;
    Halt;
  {$endif}
  {$ifNdef CPFLIB}
    {$WARNINGS OFF} // deprecated warning bug fix (like Delphi 2010 compiler)
    System.GetMemoryManager(MemoryManager);
  {$endif}
  {$if Defined(DEBUG) and not Defined(CPFLIB)}
    TTileMap(nil).SetTile(0, 0, 1);

    TTileMap(nil).UpdateCellMasks(Rect(0, 0, 0, 0));

  // anti hint
  // TTileMap(nil).DoFindPath(TTileMapParams(nil^));
  TTileMapPtr(nil).DoFindPathLoop(nil);
  TTileMapPtr(nil).CalculateHeuristics(PPoint(nil)^, PPoint(nil)^);
  TTileMapPtr(nil).AddHeuristedNodes(nil, nil);
  {$ifend}

end.
