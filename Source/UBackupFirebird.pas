unit UBackupFirebird;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.ImgList, System.ImageList, System.Math, Win.Registry,
  System.IOUtils;

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
    cbxPageSize: TComboBox;
    lbl5: TLabel;
    btnDBInfo: TButton;
    procedure btnBackupClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure edtArquivoBancoDadosRightButtonClick(Sender: TObject);
    procedure edtArquivoBackupRightButtonClick(Sender: TObject);
    procedure lstVerboseDblClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnDBInfoClick(Sender: TObject);
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

  if not FileExists(CaminhoBanco)then
  begin
    Exit;
  end;

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
          if (OdsMinor = 1) then
          begin
            Result := 'Versão do banco: Firebird 5.0 (ODS 13.1)';
          end
          else
          begin
            Result := 'Versão do banco: Firebird 4.0 (ODS 13.0)';
          end;
        end;
      else
        Result := 'Não foi possível identificar a versão do banco Firebird (ODS ' + IntToStr(OdsMajor) + '.' + IntToStr(OdsMinor) + ')';
      end;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      Result := 'Erro leitura: ' + E.Message;
    end;
  end;
end;

procedure ExecutarComandoDOS(const Comando: string);
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.wShowWindow := SW_HIDE;
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;

  // MUDANÇA SÊNIOR: Removemos o 'cmd.exe /c'.
  // Agora o Windows executa o ISQL direto, ignorando a crise das aspas múltiplas.
  if CreateProcess(nil, PChar(Comando), nil, nil, False,
    CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
  begin
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
  end;
end;

procedure TfrmBackupFirebird.btnRestoreClick(Sender: TObject);
var
  ComandoPageSize: string;
begin
  ComandoPageSize := '-page_size 8192';

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
                edtParametroExtra.Text + ' ' + ComandoPageSize + ' ' + edtArquivoBackup.Text + ' ' +
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
  OpenDialog: TOpenDialog;
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
  OpenDialog: TOpenDialog;
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
  BUFFER_SIZE = 4096;
var
  StartUpInfo: TStartUpInfo;
  ProcessInfo: TProcessInformation;
  SecurityAttributes: TSecurityAttributes;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  Buffer: array[0..BUFFER_SIZE] of AnsiChar;
  BytesAvail, BytesRead: DWORD;
  WaitRes, ExitCode: DWORD;
  Linha, Dir, FullCmd: string;
begin
  Result := False;
  Application.ProcessMessages;

  with SecurityAttributes do
  begin
    nLength := SizeOf(SecurityAttributes);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;

  // Cria o Pipe de comunicação (Canal invisível entre o DOS e o Delphi)
  if not CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecurityAttributes, 0) then
  begin
    Exit;
  end;

  try
    FillChar(StartUpInfo, SizeOf(StartUpInfo), 0);
    StartUpInfo.cb          := SizeOf(StartUpInfo);
    StartUpInfo.dwFlags     := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    StartUpInfo.wShowWindow := SW_HIDE;
    StartUpInfo.hStdInput   := GetStdHandle(STD_INPUT_HANDLE);
    StartUpInfo.hStdOutput  := StdOutPipeWrite;
    StartUpInfo.hStdError   := StdOutPipeWrite;

    //caminho do firebird
    Dir := ExtractFilePath(ParamStr(0));
    if rbFB30.Checked then
    begin
      Dir := Dir + '30\';
    end
    else
    if rbFB50.Checked then
    begin
      Dir := Dir + '50\';
    end
    else
    begin
      Dir := Dir + '25\';
    end;

    //comando original para não quebrar caminhos
    FullCmd := Dir + Comando + ' ' + Parametros;
    UniqueString(FullCmd);

    //executa o gbak
    if not CreateProcess(nil, PChar(FullCmd), nil, nil, True,
                         CREATE_NO_WINDOW or NORMAL_PRIORITY_CLASS,
                         nil, nil, StartUpInfo, ProcessInfo) then
    begin
      CloseHandle(StdOutPipeWrite);
      Exit;
    end;

    CloseHandle(StdOutPipeWrite);

    try
      Linha := '';
      lstVerbose.Items.Add('Inicializando ' + BackupRestore + '...');
      lstVerbose.Items.Add('');
      repeat
        Application.ProcessMessages;
        WaitRes := WaitForSingleObject(ProcessInfo.hProcess, 10);
        while True do
        begin
          if not PeekNamedPipe(StdOutPipeRead, nil, 0, nil, @BytesAvail, nil) then
          begin
            BytesAvail := 0;
          end;

          if (BytesAvail = 0) then
          begin
            Break;
          end;

          if ReadFile(StdOutPipeRead, Buffer, Min(BytesAvail, BUFFER_SIZE), BytesRead, nil) and (BytesRead > 0) then
          begin
            Buffer[BytesRead] := #0; // Finaliza o buffer C-String
            Linha := Linha + string(PAnsiChar(@Buffer));

            while Pos(#13#10, Linha) > 0 do
            begin
              lstVerbose.Items.Add(Trim(Copy(Linha, 1, Pos(#13#10, Linha) - 1)));
              Delete(Linha, 1, Pos(#13#10, Linha) + 1);
            end;
            lstVerbose.ItemIndex := lstVerbose.Items.Count - 1;
          end;
        end;
      until (WaitRes = WAIT_OBJECT_0);

      if (Trim(Linha) <> '') then
      begin
        lstVerbose.Items.Add(Trim(Linha));
        lstVerbose.ItemIndex := lstVerbose.Items.Count - 1;
      end;

      GetExitCodeProcess(ProcessInfo.hProcess, ExitCode);
      Result := (ExitCode = 0); // 0 = Sucesso

      lstVerbose.Items.Add('');
      if Result then
      begin
        lstVerbose.Items.Add(BackupRestore + ' realizado com sucesso!');
        if (BackupRestore = 'Backup') then
        begin
          edtArquivoBackup.Text := ChangeFileExt(edtArquivoBancoDados.Text, '.FBK');
          btnRestore.Enabled := True;
        end;
      end
      else
      begin
        lstVerbose.Items.Add('ATENÇÃO! Falha ao realizar ' + BackupRestore);
        Application.MessageBox(PChar('ATENÇÃO! Falha ao realizar ' + BackupRestore + '.' + #13#10 +
                                     'Verifique o log de mensagens para mais detalhes.'),
                               PChar(Application.Title), MB_OK + MB_ICONERROR);
        if (BackupRestore = 'Backup') then
        begin
          btnRestore.Enabled := False;
        end;
      end;

      lstVerbose.ItemIndex := lstVerbose.Items.Count - 1;

    finally
      CloseHandle(ProcessInfo.hThread);
      CloseHandle(ProcessInfo.hProcess);
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

procedure ObterInformacoesCompletas(const CaminhoBanco, CaminhoISQL: string;
  out VersaoFB: string; out TamanhoMB: Double; out PageSize: Integer);
var
  ScriptSQL, SaidaTXT: TStringList;
  CmdISQL, RespostaLimpa, PastaApp, ArqSQL, ArqTXT: string;
  PosicaoSeparador: Integer;
begin
  VersaoFB  := 'Desconhecida';
  TamanhoMB := 0.0;
  PageSize  := 0;

  PastaApp := ExtractFilePath(ParamStr(0));
  ArqSQL   := PastaApp + 'script_info.sql';
  ArqTXT   := PastaApp + 'saida_info.txt';

  if TFile.Exists(CaminhoBanco) then
  begin
    TamanhoMB := TFile.GetSize(CaminhoBanco) / 1048576;
  end;

  ScriptSQL := TStringList.Create;
  SaidaTXT  := TStringList.Create;
  try
    ScriptSQL.Add('SET HEADING OFF;');
    ScriptSQL.Add('SELECT TRIM(MON$PAGE_SIZE) || '';'' || TRIM(RDB$GET_CONTEXT(''SYSTEM'', ''ENGINE_VERSION'')) FROM MON$DATABASE;');
    ScriptSQL.SaveToFile(ArqSQL);

    CmdISQL := Format('"%s" -q -user SYSDBA -password masterkey "%s" -i "%s" -o "%s"',
                      [CaminhoISQL, CaminhoBanco, ArqSQL, ArqTXT]);

    ExecutarComandoDOS(CmdISQL);

    if FileExists(ArqTXT) then
    begin
      SaidaTXT.LoadFromFile(ArqTXT);

      if (SaidaTXT.Count > 0) then
      begin
        RespostaLimpa    := Trim(SaidaTXT.Text);
        PosicaoSeparador := Pos(';', RespostaLimpa);

        if (PosicaoSeparador > 0) then
        begin
          PageSize := StrToIntDef(Copy(RespostaLimpa, 1, PosicaoSeparador - 1), 0);
          VersaoFB := Copy(RespostaLimpa, PosicaoSeparador + 1, Length(RespostaLimpa));
        end;
      end;
    end;
  finally
    ScriptSQL.Free;
    SaidaTXT.Free;

    if FileExists(ArqSQL) then
    begin
      DeleteFile(ArqSQL);
    end;

    if FileExists(ArqTXT) then
    begin
      DeleteFile(ArqTXT);
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

procedure TfrmBackupFirebird.btnDBInfoClick(Sender: TObject);
var
  Versao: string;
  Tamanho: Double;
  Pagina: Integer;
begin
  ObterInformacoesCompletas(
    edtArquivoBancoDados.Text,
    ExtractFilePath(ParamStr(0)) + '50\isql.exe',
    Versao,
    Tamanho,
    Pagina
  );

  ShowMessage(
    'Versão do Firebird: ' + Versao + sLineBreak +
    'Page Size: ' + IntToStr(Pagina div 1024) + ' KB (' + IntToStr(Pagina) + ' bytes)' + sLineBreak +
    'Tamanho Físico: ' + FormatFloat(',0.00', Tamanho) + ' MB'
  );
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
