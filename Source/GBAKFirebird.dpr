program GBAKFirebird;

uses
  Vcl.Forms,
  UBackupFirebird in 'UBackupFirebird.pas' {frmBackupFirebird},
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10');
  Application.Title := 'GBAKFirebird';
  Application.CreateForm(TfrmBackupFirebird, frmBackupFirebird);
  Application.Run;
end.
