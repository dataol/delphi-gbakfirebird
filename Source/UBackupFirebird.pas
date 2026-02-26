unit UBackupFirebird;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.ImgList, System.ImageList, Registry;

type
  TfrmBackupFirebird = class(TForm)
    btnBackup: TButton;
    lstVerbose: TListBox;
    edtArquivoBancoDados: TButtonedEdit;
    lbl1: TLabel;
    lbl2: TLabel;
    edtArquivoBackup: TButtonedEdit;
    btnRestore: TButton;
    imlBackupFirebird: TImageList;
    edtParametroExtra: TEdit;
    lbl4: TLabel;
    rbFB25: TRadioButton;
    rbFB30: TRadioButton;
    rbFB50: TRadioButton;
    procedure btnBackupClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure edtArquivoBancoDadosRightButtonClick(Sender: TObject);
    procedure edtArquivoBackupRightButtonClick(Sender: TObject);
    procedure lstVerboseDblClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    function ExecutaGBAK(Comando, Parametros, BackupRestore: string): Boolean;
    function ValidarCaminhoArquivo(Caminho: string): Boolean;
    procedure SalvarPropriedadesRegistro;
    procedure CarregarPropriedadesRegistro;
  public
    { Public declarations }
  end;

var
  frmBackupFirebird: TfrmBackupFirebird;

implementation

{$R *.dfm}

function ObterVersaoODS(const CaminhoBanco: string): string;
var
  FS: TFileStream;
  Buffer: array[0..4] of Byte; // Aumentamos o buffer para capturar o Minor Version
  OdsMajor, OdsMinor: Byte;
begin
  Result := 'Desconhecido';

  if not FileExists(CaminhoBanco) then Exit;

  try
    FS := TFileStream.Create(CaminhoBanco, fmOpenRead or fmShareDenyNone);
    try
      // Offset 18 = Major Version
      // Offset 20 = Minor Version
      FS.Position := 18;

      // Lemos 4 bytes de uma vez (Bytes 18, 19, 20 e 21)
      FS.Read(Buffer, 4);

      OdsMajor := Buffer[0]; // Byte 18 (Major)
      OdsMinor := Buffer[2]; // Byte 20 (Minor) - Pulamos o byte 19 que é padding

      case OdsMajor of
        10: Result := 'Versão do banco: Firebird 2.0 / 2.1 (ODS 10)';
        11: Result := 'Versão do banco: Firebird 2.5 (ODS 11)';
        12: Result := 'Versão do banco: Firebird 3.0 (ODS 12)';
        13:
          begin
             if OdsMinor = 1 then
               Result := 'Versão do banco: Firebird 5.0 (ODS 13.1)'
             else
               Result := 'Versão do banco: Firebird 4.0 (ODS 13.0)';
          end;
      else
        // Útil para debugging de versões futuras (ex: ODS 14)
        Result := 'Não foi possível identificar a versão do banco Firebird (ODS ' + IntToStr(OdsMajor) + '.' + IntToStr(OdsMinor) + ')';
      end;

    finally
      FS.Free;
    end;
  except
    on E: Exception do
      Result := 'Erro leitura: ' + E.Message;
  end;
end;

procedure TfrmBackupFirebird.btnRestoreClick(Sender: TObject);
begin
  lstVerbose.Items.Clear;

  if not ValidarCaminhoArquivo(edtArquivoBackup.Text) then
  begin
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    btnBackup.Enabled  := False;
    btnRestore.Enabled := False;
    lstVerbose.Enabled := False;
    ExecutaGBak('GBAK -CREATE -VERBOSE -REPLACE_DATABASE ' +
                edtParametroExtra.Text + ' ' + edtArquivoBackup.Text + ' ' +
                StringReplace(AnsiUpperCase(edtArquivoBackup.Text),'.FBK', '.FDB', [rfReplaceAll]) + ' ' +
                '-USER SYSDBA -PASSWORD masterkey', '', 'Restore');
  finally
    btnBackup.Enabled  := True;
    btnRestore.Enabled := True;
    lstVerbose.Enabled := True;
    Screen.Cursor      := crDefault;
  end;
end;

procedure TfrmBackupFirebird.CarregarPropriedadesRegistro;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    Reg.CreateKey('\Software\' + Application.Title);
    Reg.OpenKey('\Software\' + Application.Title, True);
    edtArquivoBancoDados.Text := Reg.ReadString('ArquivoBancoDados');
    edtArquivoBackup.Text     := Reg.ReadString('ArquivoBackup');
    edtParametroExtra.Text    := Reg.ReadString('ParametroExtra');
  finally
    Reg.CloseKey;
    Reg.Free;
  end;
end;

procedure TfrmBackupFirebird.edtArquivoBancoDadosRightButtonClick(Sender: TObject);
var
  OpenDialog : TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    if (edtArquivoBancoDados.Text <> '') and DirectoryExists(ExtractFilePath(edtArquivoBancoDados.Text)) then
    begin
      OpenDialog.InitialDir := ExtractFilePath(edtArquivoBancoDados.Text);
    end
    else
    begin
      OpenDialog.InitialDir := GetCurrentDir;
    end;
    OpenDialog.Title  := 'Selecione o banco de dados.';
    OpenDialog.Filter := 'Banco de Dados Firebird|*.fdb';
    if OpenDialog.Execute then
    begin
      edtArquivoBancoDados.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TfrmBackupFirebird.edtArquivoBackupRightButtonClick(Sender: TObject);
var
  OpenDialog : TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    if (edtArquivoBackup.Text <> '') and DirectoryExists(ExtractFilePath(edtArquivoBackup.Text)) then
    begin
      OpenDialog.InitialDir := ExtractFilePath(edtArquivoBackup.Text);
    end
    else
    begin
      OpenDialog.InitialDir := GetCurrentDir;
    end;
    OpenDialog.Title  := 'Selecione o arquivo de backup.';
    OpenDialog.Filter := 'Backup Firebird|*.fbk';
    if OpenDialog.Execute then
    begin
      edtArquivoBackup.Text := OpenDialog.FileName;
    end;
  finally
    OpenDialog.Free;
  end;
end;

function TfrmBackupFirebird.ExecutaGBAK(Comando, Parametros, BackupRestore: string): Boolean;
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
  Dir: string;
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
      begin
        wShowWindow := SW_HIDE;
      end
      else
      begin
        wShowWindow := SW_SHOWMINNOACTIVE;
      end;

      hStdInput := GetStdHandle(STD_INPUT_HANDLE);
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;

    Dir := ExtractFilePath(ParamStr(0)) + '25/';
    if rbFB30.Checked then
    begin
      Dir := ExtractFilePath(ParamStr(0)) + '30/';
    end
    else
    if rbFB50.Checked then
    begin
      Dir := ExtractFilePath(ParamStr(0)) + '50/';
    end;

    //launch the command line compiler
    ProcessOK := CreateProcess(nil, PChar(Dir + Comando + ' ' + Parametros), nil, nil, True, IDLE_PRIORITY_CLASS or
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
          edtArquivoBackup.Text := Copy(edtArquivoBancoDados.Text, 1, (Length(edtArquivoBancoDados.Text) - 3)) + 'FBK';
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

procedure TfrmBackupFirebird.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  SalvarPropriedadesRegistro;
end;

function GetVersion(FileName: WideString): string;
var
  VersionInfoSize, VerInfoSize, GetInfoSizeJunk: LongWord;
  VersionInfo, Translation, InfoPointer: Pointer;
  VersionValue: WideString;
begin
  VerInfoSize := GetFileVersionInfoSizeW(PWideChar(FileName), GetInfoSizeJunk);
  if (VerInfoSize > 0) then
  begin
    GetMem(VersionInfo, VerInfoSize);
    try
      GetFileVersionInfoW(PWideChar(FileName), 0, VerInfoSize, VersionInfo);
      VerQueryValue(VersionInfo, '\\VarFileInfo\\Translation', Translation, VerInfoSize);
      VersionValue := '\\StringFileInfo\\' + IntToHex((PLongInt(Translation)^ shl 16) or (PLongInt(Translation)^ shr 16), 8) + '\\';
      VersionInfoSize := 0;
      VerQueryValueW(VersionInfo, PWideChar(VersionValue + 'FileVersion'), InfoPointer, VersionInfoSize);
      Result := Trim(PWideChar(InfoPointer));
    finally
      FreeMem(VersionInfo);
    end;
  end;
end;

procedure TfrmBackupFirebird.FormShow(Sender: TObject);
begin
  Caption := 'GBAK Firebird v.' + GetVersion(Application.ExeName);
  CarregarPropriedadesRegistro;
end;

procedure TfrmBackupFirebird.lstVerboseDblClick(Sender: TObject);
begin
  ShowMessage(lstVerbose.Items[lstVerbose.ItemIndex]);
end;

procedure TfrmBackupFirebird.SalvarPropriedadesRegistro;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    Reg.CreateKey('\Software\' + Application.Title);
    Reg.OpenKey('\Software\' + Application.Title, True);
    Reg.WriteString('ArquivoBancoDados', edtArquivoBancoDados.Text);
    Reg.WriteString('ArquivoBackup', edtArquivoBackup.Text);
    Reg.WriteString('ParametroExtra', edtParametroExtra.Text);
  finally
    Reg.CloseKey;
    Reg.Free;
  end;
end;

function TfrmBackupFirebird.ValidarCaminhoArquivo(Caminho: string): Boolean;
begin
  Result := False;

  if (Trim(Caminho) = EmptyStr) or (not FileExists(Trim(Caminho))) then
  begin
    lstVerbose.Items.Add('Arquivo não encontrado. Selecione o FBD para backup ou FBK para restauração.');
    edtArquivoBancoDados.SetFocus;
    edtArquivoBancoDados.SelectAll;
    Exit;
  end;

  if (Pos(' ', Caminho) > 0) then
  begin
    lstVerbose.Items.Add('O caminho do arquivo NÃO pode conter espaços.');
    lstVerbose.Items.Add('Caminho inválido: ' + Caminho);
    edtArquivoBancoDados.SetFocus;
    edtArquivoBancoDados.SelectAll;
    Exit;
  end;

  Result := True;
end;

procedure TfrmBackupFirebird.btnBackupClick(Sender: TObject);
begin
  lstVerbose.Items.Clear;

  if not ValidarCaminhoArquivo(edtArquivoBancoDados.Text) then
  begin
    Exit;
  end;

  lstVerbose.Items.Add(ObterVersaoODS(edtArquivoBancoDados.Text));
  lstVerbose.Items.Add('');

  Screen.Cursor := crHourGlass;
  try
    btnBackup.Enabled  := False;
    btnRestore.Enabled := False;
    lstVerbose.Enabled := False;
    ExecutaGBak('GBAK -BACKUP -VERBOSE -TRANSPORTABLE -IGNORE -GARBAGE -LIMBO ' +
                edtParametroExtra.Text + ' ' + edtArquivoBancoDados.Text + ' ' +
                StringReplace(AnsiUpperCase(edtArquivoBancoDados.Text), '.FDB', '.FBK', [rfReplaceAll]) + ' ' +
                '-USER SYSDBA -PASSWORD masterkey', '', 'Backup');
  finally
    btnBackup.Enabled  := True;
    btnRestore.Enabled := True;
    lstVerbose.Enabled := True;
    Screen.Cursor := crDefault;
  end;
end;

end.
