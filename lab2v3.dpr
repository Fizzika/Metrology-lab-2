program lab2v3;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  Generics.Collections;

type
	TIntStack = TStack<Integer>;
    TText = TList<TStringList>;
    TIntList = TList<Integer>;

var
	IgnoreList, IfList: TStringList;
    NoOpList: TStringList;

function GetTokenList(const aStr: String): TStringList;
const
	CIdentSet: set of AnsiChar = ['A'..'Z', 'a'..'z', '_', '0'..'9', '.'];
	CDelimSet: set of AnsiChar = [' ', #9, ',', ':', #13, #10];
	CStopSet: set of AnsiChar = ['"', ';', '(', ')'];
var
	i: Integer;
	j: Integer;
begin
	Result := TStringList.Create();
	i := 1;
	while (i <= Length(aStr)) do
	begin
		if aStr[i] in ['(', ')', ';'] then
		begin
			Result.Add(aStr[i]);
			Inc(i);
			continue;
		end;
		if aStr[i] = '"' then
		begin
			j := i + 1;
			while (j <= Length(aStr)) and (aStr[j] <> '"') do
				Inc(j);
			//Writeln(Copy(aStr, i, j - i + 1));
			Result.Add(Copy(aStr, i, j - i + 1));
			i := j + 1;
		end;
		if aStr[i] in CDelimSet then
		begin
			Inc(i);
			continue;
		end;
		if aStr[i] in CIdentSet then
		begin
			j := i;
			while (j <= Length(aStr)) and (aStr[j] in CIdentSet)
			and not (aStr[j] in CStopSet)  do
				Inc(j);
			//Writeln(Copy(aStr, i, j - i));
			if (i <> j) then
				Result.Add(Copy(aStr, i, j - i));
			i := j;
		end
		else
		begin
			j := i;
			while (j <= Length(aStr)) and (not (aStr[j] in CIdentSet))
			and (not (aStr[j] in CDelimSet)) and not (aStr[j] in CStopSet) do
				Inc(j);
			//Writeln(Copy(aStr, i, j - i));
			if (i <> j) then
				Result.Add(Copy(aStr, i, j - i));
			i := j;
		end;
	end;
end;

var
    St: TIntStack;
    IsPush: Boolean = True;
    Text: TText;
    CurrPosInText: Integer = 0;

function GetEndIndex: Integer;
var
	CurrIndex: Integer;
    BrcCount: Integer;
    CurrTokenList: TStringList;
begin
    CurrIndex := CurrPosInText;
    while (Text[CurrIndex].IndexOf('{') = -1) do
    	Inc(CurrIndex);
    Inc(CurrIndex); // Now we located in first block after '{'
    BrcCount := 1;
    while (true) do
    begin
        if Text[CurrIndex].IndexOf('{') <> -1 then
        	Inc(BrcCount);
        if Text[CurrIndex].IndexOf('}') <> -1 then
        	Dec(BrcCount);
        if (BrcCount = 0) then
        	break;
        Inc(CurrIndex);
    end;
    // In CurrIndex located latest line with '}'
    Dec(CurrIndex); // Now we ready to find latest index. oh ~shi
    Result := 0;
    while (Result = 0) do
    begin
        CurrTokenList := Text[CurrIndex];
        if CurrTokenList.IndexOf('->') <> -1 then
        	Result := CurrIndex;
        Dec(CurrIndex);
    end;
end;

var
    WhenLastNodeList: TIntList;

procedure Change(const aTokenList: TStringList;
	var aOpCount: Integer; var aDepth: Integer; var aIfCount: Integer);
var
	i: Integer;
    IsFindIF: Boolean;
    IsFindWhen: Boolean;
    //IsPush: Boolean;
    WhenStart, WhenFinish: Integer;
begin
	IsFindIF := False;
    IsFindWhen := False;
	if aTokenList.Count < 1 then
		exit;
	if (IgnoreList.IndexOf(aTokenList[0]) <> -1) then
    	exit;
    {Operators amount}
    Inc(aOpCount);
    if (aTokenList[0] = 'fun') then // fun declaration - no op
    	Dec(aOpCount);
    if (aTokenList[0] = 'when') then
    	Dec(aOpCount); // when decl
    if ((aTokenList[0] = 'var') or (aTokenList[0] = 'val')) then
    begin
        if aTokenList.IndexOf('=') = -1 then //decl without assign
        	Dec(aOpCount);
    end;
    if (aTokenList.IndexOf('else') <> -1) then
    	Dec(aOpCount); // else is no OPERATOR
    if ((aTokenList.IndexOf('if') <> -1) and
       ((aTokenList.IndexOf('else') <> -1))) then   // oneline if else
    begin
    	Inc(aOpCount);
    end;
    if (((aTokenList[0] = '{') or (aTokenList[0] = '}'))
    	and (aTokenList.Count = 1)) then  // for '{\n' or '}\n' strings.
    begin
        Dec(aOpCount);
    end;

    {If calculate}
	for i := 0 to aTokenList.Count - 1 do
	begin
    	if IfList.IndexOf(aTokenList[i]) <> -1 then // find if
        begin
        	if WhenLastNodeList.IndexOf(CurrPosInText) <> -1 then
            	continue; // Skip else block in when
        	if (IsPush) then
            begin
            	St.Push(aDepth); // Save Current level
                IsPush := False;
            end;
            if (aTokenList[i] <> 'else') then
            	Inc(aIfCount);
            Inc(aDepth);
            IsFindIF := True;
        end;
        if aTokenList[i] = '->' then
        begin
            if WhenLastNodeList.IndexOf(CurrPosInText) = -1 then
            begin
                Inc(aDepth);
                Inc(aIfCount);
            end
            else
            	Dec(aOpCount);
            if (i <> aTokenList.Count - 1) then
            	Inc(aOpCount); // For one-line case, such as EXPR -> OPERATOR
        end;
        if aTokenList[i] = '{' then
        begin
        	if (IsPush) then
            begin
                St.Push(aDepth);
            end;
            IsPush := True;
        end;
        if aTokenList[i] = '}' then
        begin
            IsPush := True;
            aDepth := St.Pop;
        end;
        if aTokenList[i] = 'when' then
        begin
        	IsFindWhen := True;
        end;
    end;
    if (not IsFindIF and not IsPush) then
    begin
        aDepth := St.Pop;
        IsPush := True;
    end;
    if (IsFindWhen) then
    begin
    	WhenLastNodeList.Add(GetEndIndex);
    end;
end;

procedure Init;
begin
	Text := TText.Create;
	IgnoreList := TStringList.Create;
    St := TIntStack.Create;
	IgnoreList.LoadFromFile('Ignore.txt');
	IfList := TStringList.Create;
	IfList.LoadFromFile('If.txt');
    NoOpList := TStringList.Create;
    NoOpList.LoadFromFile('NoOp.txt');
    WhenLastNodeList := TIntList.Create;
end;

var
	TokenList: TStringList;
	Str: String;
	InF: TextFile;
	Depth, OpCount, IfCount: Integer;
    MaxDepth: Integer;
    i: Integer;
    //Text: TText;
begin
	Init;
	Assign(InF, 'tests/in.java');
	Reset(InF);
	Depth := -1;
	IfCount := 0;
	OpCount := 0;
    MaxDepth := -1;
	while not EOF(InF) do
	begin
		Readln(InF, Str);
		TokenList := GetTokenList(Str);
        Text.Add(TokenList);
	end;
    CurrPosInText := 0;
    Write('Depth: ');
    while (CurrPosInText < Text.Count) do
    begin
        TokenList := Text[CurrPosInText];
        Change(TokenList, OpCount, Depth, IfCount);
        Write(CurrPosInText + 1, ':', Depth, ' ');
        if Depth > MaxDepth then
        	MaxDepth := Depth;
    	Inc(CurrPosInText);
    end;
    Writeln;
    Writeln('Max Depth : ', MaxDepth);
    Writeln('If count : ', IfCount);
    Writeln('Op count : ', OpCount);
    Writeln('If percentage: ', IfCount/OpCount*100:2:2);
	FreeAndNil(IgnoreList);
	Close(InF);
	Readln;
  { TODO -oUser -cConsole Main : Insert code here }
end.
