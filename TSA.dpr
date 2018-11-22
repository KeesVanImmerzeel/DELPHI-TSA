program TSA;

uses
  Forms,
  uTSA in 'uTSA.pas' {TSAForm},
  SysUtils,
  Windows,
  IniFiles,
  OpWString,
  Dialogs,
  uError,
  USelectAdoSetDialog in '..\..\ServiceComponents\Triwaco\AdoSets\SelectAdoSetDialog\USelectAdoSetDialog.pas' {AdoSetsForm};

var
  f_ini: TiniFile;
  RunDirStr, GridDirStr, cfgFileStr,
  MapFileStr, DefaultStr, LayerStr, DescriptionStr,
  ResultFileStr, CurrDirBuf: String;
  Delims : CharSet = [','];
  Len: Integer;

{$R *.RES}

begin
  Application.Initialize;
  Application.HelpFile := 'TSA.HLP';
  Application.Title := 'TSA-allokator';
  Application.CreateForm(TTSAForm, TSAForm);
  Application.CreateForm(TAdoSetsForm, AdoSetsForm);
  ResultSetStr := '';
  if ( ParamCount >= 3 ) then begin {-Shell vult een aantal velden in}
    Mode        := Batch;
    RunDirStr   := ParamStr( 1 );
    GridDirStr  := ParamStr( 2 );
    cfgFileStr  := RunDirStr + '\' + ParamStr( 3 );
//    MessageDlg( 'ParamStr( 1 )='+ ParamStr( 1 ), mtInformation, [mbOk], 0);
//    MessageDlg( 'ParamStr( 2 )='+ ParamStr( 2 ), mtInformation, [mbOk], 0);
//    MessageDlg( 'ParamStr( 3 )='+ ParamStr( 3 ), mtInformation, [mbOk], 0);
    f_ini := TiniFile.Create( cfgFileStr );
    MapFileStr     := f_ini.ReadString( 'Allocator', 'datasource', 'Error' );
    DefaultStr     := f_ini.ReadString( 'Allocator', 'default', 'Error' );
    LayerStr  := f_ini.ReadString( 'Allocator',      'layer', 'Error' );
    ResultFileStr  := f_ini.ReadString( 'Allocator', 'resultfile', 'Error' );
    ResultFileStr  := ExtractWord( 1, ResultFileStr, Delims, Len );
    ResultSetStr   := f_ini.ReadString( 'Allocator', 'setname', 'Error' );
    DescriptionStr := f_ini.ReadString( 'Allocator', 'description', 'Error' );
    CurrDirBuf     := GetCurrentDir;
    SetCurrentDir( ExtractFileDir( ResultFileStr ) );
    f_ini.Free;

    with TSAForm do begin
      EditKeyFileName.Text := MapFileStr;

      EditINPUT_TSA.Text   := LayerStr;
      KeySetName           := uppercase( JustName( EditKeyFileName.Text ) );
      SaveDialog.FileName  := ResultFileStr;
      NoKeyValue           := StrToFloat( Trim( DefaultStr ) );
      EditNoKeyValue.Text  := FloatToStr( NoKeyValue );
      if ( StrIComp( PChar( LayerStr ), 'UDSI' ) = 0 )  then
        CheckBoxUDSI.Checked := true
      else
        CheckBoxUDSI.Checked := false;
      if ExtractFileExt( StrUpper( PChar( EditKeyFileName.Text ) ) ) = '.INI' then begin
        RadioButtonKeyAdoFile.Checked := false;
        RadioButtonIniFile.Checked    := true;
      end else begin
        RadioButtonKeyAdoFile.Checked := true;
        RadioButtonIniFile.Checked    := false;
      end;
    end; {-with}

    if pos( 'DEBUG', Uppercase( DescriptionStr ) ) <> 0 then
      Mode := Interactive;
  end; {-if}

  if ( Mode = Interactive ) then begin
    {MessageDlg( 'Interactive', mtInformation, [mbOk], 0);}
    Application.Run;
  end else begin
    {MessageDlg( 'Batch', mtInformation, [mbOk], 0);}
    TSAForm.GoButton.Click;
  end;
  SetCurrentDir( CurrDirBuf );
end.
