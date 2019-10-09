unit UBackupFirebird;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.ImgList, cxPropertiesStore, dxGDIPlusClasses;

type
  TfrmBackupFirebird = class(TForm)
    btnBackup: TButton;
    lstVerbose: TListBox;
    edtBackup: TButtonedEdit;
    lbl1: TLabel;
    lbl2: TLabel;
    edtRestore: TButtonedEdit;
    btnRestore: TButton;
    imlBackupFirebird: TImageList;
    ppsBackupFirebird: TcxPropertiesStore;
    img1: TImage;
    lbl3: TLabel;
    edtParametroExtra: TEdit;
    lbl4: TLabel;
    procedure btnBackupClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure edtBackupRightButtonClick(Sender: TObject);
    procedure edtRestoreRightButtonClick(Sender: TObject);
    procedure lstVerboseDblClick(Sender: TObject);
  private
    function ExecutaGBak(Comando, Parametros, BackupRestore: string): Boolean;
  public
    { Public declarations }
  end;

var
  frmBackupFirebird: TfrmBackupFirebird;

implementation

{$R *.dfm}

procedure TfrmBackupFirebird.btnRestoreClick(Sender: TObject);
begin
  if (Trim(edtRestore.Text) = EmptyStr) or (not FileExists(Trim(edtRestore.Text))) then
  begin
    Application.MessageBox(PChar('Arquivo não encontrado. Selecione o arquivo de backup a ser restaurado.'),
                           PChar(Application.Title), MB_OK + MB_ICONINFORMATION);
    edtRestore.SetFocus;
    edtRestore.SelectAll;
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    btnBackup.Enabled  := False;
    btnRestore.Enabled := False;
    lstVerbose.Enabled := False;
    lstVerbose.Items.Clear;
    ExecutaGBak('GBAK -CREATE -VERBOSE -REPLACE_DATABASE ' +
                edtParametroExtra.Text + ' ' + edtRestore.Text + ' ' +
                StringReplace(AnsiUpperCase(edtRestore.Text),'.FBK', '.FDB', [rfReplaceAll]) + ' ' +
                '-USER SYSDBA -PASSWORD masterkey', '', 'Restore');
  finally
    btnBackup.Enabled  := True;
    btnRestore.Enabled := True;
    lstVerbose.Enabled := True;
    Screen.Cursor      := crDefault;
  end;
end;

procedure TfrmBackupFirebird.edtBackupRightButtonClick(Sender: TObject);
var
  OpenDialog : TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    if (edtBackup.Text <> '') and DirectoryExists(ExtractFilePath(edtBackup.Text)) then
    begin
      OpenDialog.InitialDir := ExtractFilePath(edtBackup.Text);
    end
    else
    begin
      OpenDialog.InitialDir := GetCurrentDir;
    end;
    OpenDialog.Title  := 'Selecione o banco de dados.';
    OpenDialog.Filter := 'Banco de Dados Firebird|*.fdb';
    if OpenDialog.Execute then
    begin
      edtBackup.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TfrmBackupFirebird.edtRestoreRightButtonClick(Sender: TObject);
var
  OpenDialog : TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    if (edtRestore.Text <> '') and DirectoryExists(ExtractFilePath(edtRestore.Text)) then
    begin
      OpenDialog.InitialDir := ExtractFilePath(edtRestore.Text);
    end
    else
    begin
      OpenDialog.InitialDir := GetCurrentDir;
    end;
    OpenDialog.Title  := 'Selecione o arquivo de backup.';
    OpenDialog.Filter := 'Backup Firebird|*.fbk';
    if OpenDialog.Execute then
    begin
      edtRestore.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

function TfrmBackupFirebird.ExecutaGBak(Comando, Parametros, BackupRestore: string): Boolean;
const
  BUFFER_SIZE = 2400;
var
  StartUpInfo: TStartUpInfo;
  ProcessInformation: TProcessInformation;
  ProcessOk: Boolean;
  SecurityAttributes: TSecurityAttributes;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  Buffer: array[0..BUFFER_SIZE] of AnsiChar;
  TotalBytesAvail,
  BytesLeftThisMessage, BytesRead: Cardinal;
  Linha: string;
begin
  Result := False;
  Application.ProcessMessages;
  with SecurityAttributes do
  begin
    nLength := SizeOf(SecurityAttributes);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;

  //create pipe for standard output redirection
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecurityAttributes, 0);
  try
    //Make child process use StdOutPipeWrite as standard out,
    //and make sure it does not show on screen.
    with StartUpInfo do
    begin
      FillChar(StartUpInfo,SizeOf(StartUpInfo),0);
      cb := SizeOf(StartUpInfo);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;

      if (Win32Platform = VER_PLATFORM_WIN32_WINDOWS) then
        wShowWindow := SW_HIDE
      else
        wShowWindow := SW_SHOWMINNOACTIVE;

      hStdInput := GetStdHandle(STD_INPUT_HANDLE);
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;
    //launch the command line compiler
    ProcessOK := CreateProcess(nil, PChar(Comando + ' ' + Parametros), nil, nil, True, IDLE_PRIORITY_CLASS or
                               CREATE_NO_WINDOW, nil, nil, StartUpInfo, ProcessInformation);
    //Now that the handle has been inherited, close write to be safe.
    //We don't want to read or write to it accidentally.
    CloseHandle(StdOutPipeWrite);
    if (not ProcessOK) then
    begin
      Exit;
    end;

    try
      //get all output until dos app finishes
      Linha := '';
      lstVerbose.Items.Add('Inicializando ' + BackupRestore + '...');
      lstVerbose.Items.Add('');
      repeat
        ProcessOK := (WaitForSingleObject(ProcessInformation.hProcess,8) <> WAIT_OBJECT_0);
        Application.ProcessMessages;
        PeekNamedPipe(StdOutPipeRead, @Buffer, BUFFER_SIZE, @BytesRead, @TotalBytesAvail, @BytesLeftThisMessage);
        if (BytesRead > 0) then
        begin
          if (BytesRead > BUFFER_SIZE) then
          begin
            BytesRead := BUFFER_SIZE;
          end;
          ProcessOK := ReadFile(StdOutPipeRead, Buffer, BytesRead, BytesRead, nil);
        end;
        //has anything been read?
        if (BytesRead > 0) then
        begin
          //finish buffer to PChar
          Buffer[BytesRead] := #0;
          //combine the buffer with the rest of the last run
          Linha := (Linha + string(Buffer));
          while (Pos(#13#10, Linha) > 0) do
          begin
            lstVerbose.Items.Add(Trim(Copy(Linha, 1, Pos(#13#10, Linha) - 1)));
            Linha := Copy(Linha,Pos(#13#10, Linha) + 2, 5000);
          end;
          lstVerbose.ItemIndex := (lstVerbose.Items.Count - 1);
        end;
      until (not ProcessOK) {or (BytesRead=0)};

      if (BackupRestore = 'Backup') then
      begin
        Result := (Copy(lstVerbose.Items.Strings[lstVerbose.Items.Count - 1], 1, 45) = 'gbak:closing file, committing, and finishing.');
      end
      else
      if (BackupRestore = 'Restore') then
      begin
        Result := ((Copy(lstVerbose.Items.Strings[lstVerbose.Items.Count - 1], 1, 40) = 'gbak:finishing, closing, and going home') or
                   (Copy(lstVerbose.Items.Strings[lstVerbose.Items.Count - 2], 1, 40) = 'gbak:finishing, closing, and going home'));
      end
      else
      begin
        Result := False;
      end;

      lstVerbose.Items.Add('');
      if Result then
      begin
        lstVerbose.Items.Add(BackupRestore + ' realizado com sucesso!');
        if (BackupRestore = 'Backup') then
        begin
          edtRestore.Text := Copy(edtBackup.Text, 1, (Length(edtBackup.Text) - 3)) + 'FBK';
          btnRestore.Enabled := True;
        end;
      end
      else
      begin
        lstVerbose.Items.Add('ATENÇÃO! Falha ao realizar ' + BackupRestore);
        Application.MessageBox(PChar('ATENÇÃO! Falha ao realizar ' + BackupRestore + #13 +
                                     'Provavelmente o arquivo foi danificado no processo.'),
                               PChar(Application.Title), MB_OK + MB_ICONERROR);
        if (BackupRestore = 'Backup') then
        begin
          btnRestore.Enabled := False;
        end;
      end;
      lstVerbose.ItemIndex := (lstVerbose.Items.Count - 1);
    finally
      CloseHandle(ProcessInformation.hThread);
      CloseHandle(ProcessInformation.hProcess);
    end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

procedure TfrmBackupFirebird.lstVerboseDblClick(Sender: TObject);
begin
  ShowMessage(lstVerbose.Items[lstVerbose.ItemIndex]);
end;

procedure TfrmBackupFirebird.btnBackupClick(Sender: TObject);
begin
  if (Trim(edtBackup.Text) = EmptyStr) or (not FileExists(Trim(edtBackup.Text))) then
  begin
    Application.MessageBox(PChar('Arquivo não encontrado. Selecione o banco de dados do qual será realizado o backup.'),
                           PChar(Application.Title), MB_OK + MB_ICONINFORMATION);
    edtBackup.SetFocus;
    edtBackup.SelectAll;
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    btnBackup.Enabled  := False;
    btnRestore.Enabled := False;
    lstVerbose.Enabled := False;
    lstVerbose.Items.Clear;
    ExecutaGBak('GBAK -BACKUP -VERBOSE -TRANSPORTABLE -IGNORE -GARBAGE -LIMBO ' +
                edtParametroExtra.Text + ' ' + edtBackup.Text + ' ' +
                StringReplace(AnsiUpperCase(edtBackup.Text), '.FDB', '.FBK', [rfReplaceAll]) + ' ' +
                '-USER SYSDBA -PASSWORD masterkey', '', 'Backup');
  finally
    btnBackup.Enabled  := True;
    btnRestore.Enabled := True;
    lstVerbose.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

end.
