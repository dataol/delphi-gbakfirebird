program BackupFirebird;

uses
  Vcl.Forms,
  UBackupFirebird in 'UBackupFirebird.pas' {frmBackupFirebird},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Backup Firebird';
  Application.CreateForm(TfrmBackupFirebird, frmBackupFirebird);
  Application.Run;
end.
