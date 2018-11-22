unit uTSA;

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, Dialogs,
  StdCtrls, SelectAdoSetDialog, LargeArrays, AdoSets, Mask, OpWString, Math,
  inifiles, ExtCtrls, Dutils;

type
  TTSAForm = class(TForm)
    GroupBoxSelectAdoSet: TGroupBox;
    LabelKeyFileName: TLabel;
    BrowseSelKeyFileButton: TButton;
    EditKeyFileName: TEdit;
    GoButton: TButton;
    KeyAdoSet: TRealAdoSet;
    SelectKeyAdoSetDialog: TSelectRealAdoSetDialog;
    SaveDialog: TSaveDialog;
    EditNoKeyValue: TMaskEdit;
    LabelNoKeyValue: TLabel;
    EditINPUT_TSA: TEdit;
    BrowseSelTSA_File: TButton;
    TSA_label: TLabel;
    OpenTSA_FileDialog: TOpenDialog;
    DbleMtrxColindx: TDbleMtrxColindx;
    ResultAdoSet: TRealAdoSet;
    CheckBoxUDSI: TCheckBox;
    InputRadioGroup1: TRadioGroup;
    RadioButtonKeyAdoFile: TRadioButton;
    RadioButtonIniFile: TRadioButton;
    OpenIniFileDialog: TOpenDialog;
    AvRealAdoSet: TRealAdoSet;
    procedure BrowseSelKeyFileButtonClick(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    procedure BrowseSelTSA_FileClick(Sender: TObject);
    procedure RadioButtonIniFileClick(Sender: TObject);
    procedure RadioButtonKeyAdoFileClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  TSAForm: TTSAForm;
  NoKeyValue: Double;
  KeySetName, ResultSetStr: String;

implementation

uses
  uError;

{$R *.DFM}

procedure TTSAForm.BrowseSelKeyFileButtonClick(Sender: TObject);
var SetNames: TStringList;
begin
  if RadioButtonIniFile.Checked then begin
    with OpenIniFileDialog do begin
      if Execute then
        EditKeyFileName.Text := ExpandFileName( FileName )
    end;
  end else begin
    SetNames := TStringList.Create;
    with SelectKeyAdoSetDialog  do begin
      if Execute( 1, casdDontShowSelectedAdoSets, SetNames ) then begin
        EditKeyFileName.Text := ExpandFileName( FileName );
        KeySetName           := SetNames.Strings[ 0 ];
      end;
    end;
    SetNames.Free;
  end;
end;

procedure TTSAForm.GoButtonClick(Sender: TObject);
var
  f: TextFile;
  LineNr: LongWord;
  Initiated: Boolean;
  i, nrOfTimeSteps, NrOfElements, KeyAdoSetCount: Integer;
  SetStr, FileAndSetName, KeyFileName, KeyFileDir, AvFileName, AvSetName: String;
  ConChar: Char;
  Save_Cursor:TCursor;
  Fi: TiniFile;
  MultipleKeyAdoFiles: Boolean;

Procedure BailOut;
begin
  try
    if MultipleKeyAdoFiles then
      Fi.free;
    //CloseFile( lf );
    CloseFile( f );
    KeyAdoSet.free;
    DbleMtrxColindx.free;
    ResultAdoSet.free;
    AvRealAdoSet.free;
  except; end;
end;

Function InitiateKeyAdoSet: Boolean;
var
  f: TextFile;
begin
  Result := false;

  WriteToLogFile( 'Trying to initiate KeyAdoSet.' );
  WriteToLogFileFmt( '  KeyFileName: "%s"', [KeyFileName] );
  WriteToLogFileFmt( '  KeySetName:  "%s"', [KeySetName] );
  WriteToLogFileFmt( 'Opening file: "%s"', [KeyFileName] );

  if not FileExists( KeyFileName ) then begin
    WriteToLogFileFmt( 'File: "%s" does not exist.', [KeyFileName] );
    if ( Mode = Interactive ) then
      HandleErrorFmt( 'File: "%s" does not exist.', [KeyFileName], true )
    else MessageBeep( MB_ICONASTERISK );
    Exit;
  end;

  try
    AssignFile( f, KeyFileName ); Reset( f );
  except
    WriteToLogFileFmt( 'Unable to open file: "%s".', [KeyFileName] );
    if ( Mode = Interactive ) then
      MessageDlg( 'Unable to open file: "' + KeyFileName + '".', mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    Exit;
  end;
  LineNr := 1;
  KeyAdoSet := TRealAdoSet.InitFromOpenedTextFile( f, KeySetName, self,
               LineNr, Initiated );
  CloseFile( f );
  if not Initiated then begin
    WriteToLogFileFmt( 'Error initiating KeyAdoSet from file: "%s".', [KeyFileName] );
    if ( Mode = Interactive ) then
      MessageDlg( 'Error initiating KeyAdoSet from file: "' + KeyFileName +
                '".' + #13 + 'Check "TSA.log"', mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    Exit;
  end else begin
    if ( KeyAdoSetCount > 0 ) and ( NrOfElements <> KeyAdoSet.NrOfElements ) then begin
      WriteToLogFile( 'Number of elements in KeyAdoSet inconsistant with previous number.' );
      if ( Mode = Interactive ) then
      MessageDlg( 'Number of elements in KeyAdoSet inconsistant with previous number.'
                  + #13 + 'Check "TSA.log"', mtError, [mbOk], 0)
      else MessageBeep( MB_ICONASTERISK );
      Exit;
    end;
  end;

  Inc( KeyAdoSetCount );
  Result := true;
end;

Function CreateResultAdoSet( const SetIndx: Integer ): Boolean;
var
  i, j, k: Integer;
  ResultValue, Time: Double;
  S9: String[9];
begin
  Result := false;

  {-Vervang, indien nodig, de KeyAdoSet}
  if MultipleKeyAdoFiles and ( SetIndx > 1 ) then begin {-Mogelijk nieuwe KeyAdoFile}
    FileAndSetName := Fi.ReadString( 'KeyAdoFilesWithSetNames',
      'TimeStep' + IntToStr( SetIndx ), 'Error' );

    if ( FileAndSetName <> 'Error' ) then begin {-Inderdaad nieuwe KeyAdoFile}
      SplitFileAndSetStr( FileAndSetName, KeyFileName, KeySetName );
      {-Use default directory if directory is not specified}
      if ( ExtractFileDir( KeyFileName ) = '' ) then
        KeyFileName := KeyFileDir + '\' + KeyFileName;

      try KeyAdoSet.free except end;
      if not InitiateKeyAdoSet then
        Exit;
    end;
  end;

  {-Haal waarde uit 1-ste kolom (=tijd(stapnummer))}
  Time := DbleMtrxColindx.GetValue( SetIndx, -MaxDouble );
  if ( Time >= 0 ) then begin {-tijd(stapnummer) > 0: er moet dus een set worden
                            weggeschreven}
    with ResultAdoSet do begin
      if ( ResultSetStr <>'' ) and {-Shell levert set-naam}
         ( not CheckBoxUDSI.Checked ) then begin
        SetIdStr := ResultSetStr;
        if ( nrOfTimeSteps > 1 ) then begin
          // Str( Time:8, S8 );
          S9 := formatfloat('0.000000000', Time);
          SetIdStr := SetIdStr + ',TIME=' + S9; //S8;
        end;
      end else begin
        SetIdStr := SetStr;
        k := Trunc( Time ); {-tijdstapnummer}
        if ( nrOfTimeSteps > 1 ) then
          SetIdStr := SetIdStr + ConChar + IntToStr( k );
        end;
      for i:=1 to NrOfElements do begin
        ResultValue := DbleMtrxColindx.GetValue( SetIndx, KeyAdoSet.Items[ i ],
        NoKeyValue );
        j := DbleMtrxColindx.GetColNr( KeyAdoSet.Items[ i ] );
        if j=1 then
          ResultValue := NoKeyValue; {-Deze kolom bevat tijdstapnummers}
        Setx( i, ResultValue );
        AvRealAdoSet[ i ] := AvRealAdoSet[ i ] + ResultValue;
      end;
    end;
    ResultAdoSet.ExportToOpenedTextFile( f );
  end;
  Result := true;
end;

begin
  if not FileExists( EditKeyFileName.Text ) then begin
    if ( Mode = Interactive ) then
      MessageDlg( 'File: "' + EditKeyFileName.Text + '" does not exist.', mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    Exit;
  end;

  if not FileExists( EditINPUT_TSA.Text ) then begin
    if ( Mode = Interactive ) then
      MessageDlg( 'File: "' + EditINPUT_TSA.Text + '" does not exist.', mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    Exit;
  end;

  With SaveDialog do begin
    if ( Mode = Batch ) or ( ( Mode = Interactive ) and Execute ) then begin
      Try
        //AssignFile( lf, 'TSA.log' ); Rewrite( lf );

        MultipleKeyAdoFiles := RadioButtonIniFile.Checked;
        if MultipleKeyAdoFiles then begin
          WriteToLogFile( 'MultipleKeyAdoFiles' );

          {-Lees de info voor timestep1 uit het ini-bestand }
          Fi:= TiniFile.Create( EditKeyFileName.Text );
          FileAndSetName :=
            Fi.ReadString( 'KeyAdoFilesWithSetNames', 'TimeStep1', 'Error' );
          if  ( FileAndSetName = 'Error' ) then begin
            WriteToLogFile( 'Error reading from ini-file.' );
            if ( Mode = Interactive ) then
              MessageDlg( 'Error reading from ini-file.', mtError, [mbOk], 0)
            else MessageBeep( MB_ICONASTERISK );
            BailOut; Exit;
          end;

          {-Determine the default directory for all file-names in ini-file and
            the KeyFileName }
          KeyFileDir := ExtractFileDir( ExpandFileName( EditKeyFileName.Text ) );
          SplitFileAndSetStr( FileAndSetName, KeyFileName, KeySetName );
          {-Use default directory if directory is not specified}
          if ( ExtractFileDir( KeyFileName ) = '' ) then
            KeyFileName := KeyFileDir + '\' + KeyFileName;
        end else begin
          WriteToLogFile( 'Single KeyAdoFile' );
          KeyFileName := EditKeyFileName.Text;
        end;

        KeyAdoSetCount := 0;
        if not InitiateKeyAdoSet then begin
          BailOut; Exit;
        end;
        NrOfElements := KeyAdoSet.NrOfElements;

      except
        if ( Mode = Interactive ) then
          MessageDlg( 'Unspecified error in TSA.' + #13 + 'Check "TSA.log"', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        BailOut; Exit;
      end;

      try
        MessageDlg( 'Opening' + EditINPUT_TSA.Text, mtInformation, [mbOk], 0);
        AssignFile( f, EditINPUT_TSA.Text ); Reset( f );
        DbleMtrxColindx := TDbleMtrxColindx.InitialiseFromTextFile(
                           f, self );
        CloseFile( f );
      except
        WriteToLogFile( 'Error initiating TSA-matrix from file.' );
        if ( Mode = Interactive ) then
          MessageDlg( 'Error initiating TSA-matrix from file.' + #13 + 'Check "TSA.log"', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        BailOut; Exit;
      end;

      try
        NoKeyValue := StrToFloat( Trim( EditNoKeyValue.Text ) );
      except
        WriteToLogFileFmt( 'Invalid NoKeyValue: "%s".', [EditNoKeyValue.Text] );
        if ( Mode = Interactive ) then
          MessageDlg( 'Invalid NoKeyValue: "' + EditNoKeyValue.Text + '".', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        BailOut; Exit;
      end;

      WriteToLogFileFmt( 'NoKeyValue = %g.', [NoKeyValue] );
      SetStr :=  uppercase( JustName( FileName ) );

      try
        AssignFile( f, FileName ); Rewrite( f ); {-Output file}
        AvSetName  := JustName( FileName ) + 'Average';
        AvFileName := ChangeFileExt( AvSetName, '.ado');
      except
        WriteToLogFileFmt( 'Unable to create file: "%s".', [FileName] );
        if ( Mode = Interactive ) then
          MessageDlg( 'Unable to create file: "' + FileName + '".', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        BailOut; Exit;
      end;

      try
        ResultAdoSet := TRealAdoSet.Create( NrOfElements, 'ResultAdoSet', self );
        AvRealAdoSet := TRealAdoSet.CreateF( NrOfElements, AvSetName, 0, self );
      except
        WriteToLogFile( 'Unable to create "ResultAdoSet".' );
        if ( Mode = Interactive ) then
          MessageDlg( 'Unable to create "ResultAdoSet".', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        BailOut; Exit;
      end;

      nrOfTimeSteps := DbleMtrxColindx.GetNRows;

      if CheckBoxUDSI.Checked then
        ConChar := '~'
      else
        ConChar := '_';

      Save_Cursor   := Screen.Cursor;
      Screen.Cursor := crHourglass;    { Show hourglass cursor }

      try
        for i:=1 to nrOfTimeSteps do
          if not CreateResultAdoSet( i ) then begin
            Screen.Cursor := Save_Cursor;
            BailOut; Exit;
          end;
        with AvRealAdoSet do
          for i:=1 to NrOfElements do
            Setx( i, Getx( i ) / nrOfTimeSteps );
          try
            CloseFile( f );
            AssignFile( f, AvFileName ); Rewrite( f ); {-Output file}
          except
            WriteToLogFileFmt( 'Unable to create file: "%s".', [AvFileName] );
            if ( Mode = Interactive ) then
              MessageDlg( 'Unable to create file: "' + AvFileName + '".', mtError, [mbOk], 0)
            else MessageBeep( MB_ICONASTERISK );
              BailOut; Exit;
          end;
          AvRealAdoSet.ExportToOpenedTextFile( f  );
      finally
        Screen.Cursor := Save_Cursor;  { Always restore to normal }
      end;

      WriteToLogFileFmt( 'Result file: "%s" created.', [ExtractFileName( FileName )] );
      if ( Mode = Interactive ) then
        MessageDlg( 'Result files: "' + ExtractFileName( FileName ) + '" and' + #13 +
        '"' + AvFileName + '" created.', mtInformation, [mbOk], 0)
      else MessageBeep( MB_ICONASTERISK );
      BailOut;
    end; {if Execute}
  end; {With SaveDialog}
end;

procedure tTSAForm.BrowseSelTSA_FileClick(Sender: TObject);
begin
  with OpenTSA_FileDialog do begin
    if Execute then begin
      EditINPUT_TSA.Text := ExpandFileName( FileName );
      SaveDialog.FileName := ChangeFileExt( EditINPUT_TSA.Text, '.ado' );
    end;
  end;
end;
procedure TTSAForm.FormCreate(Sender: TObject);
begin
InitialiseLogFile;
end;

procedure TTSAForm.FormDestroy(Sender: TObject);
begin
FinaliseLogFile;
end;

procedure TTSAForm.RadioButtonIniFileClick(Sender: TObject);
begin
  if RadioButtonIniFile.Checked then
    EditKeyFileName.Text := ChangeFileExt( EditKeyFileName.Text, '.ini' );
end;

procedure TTSAForm.RadioButtonKeyAdoFileClick(Sender: TObject);
begin
  if RadioButtonKeyAdoFile.Checked then
    EditKeyFileName.Text := ChangeFileExt( EditKeyFileName.Text, '.ado' );
end;

initialization
  KeySetName       := 'Key';
finalization
end.
