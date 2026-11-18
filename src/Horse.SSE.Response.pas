unit Horse.SSE.Response;

{$IF DEFINED(FPC)}{$MODE DELPHI}{$H+}{$ENDIF}

// =============================================================================
//  horse-sse -- Horse glue
//  -----------------------------------------------------------------------------
//  THorseSSE.Prepare sets the headers required for SSE before SendStream.
//  THorseSSE.Stream is the one-call entry point: sets headers, then drives
//  the callback pattern cross-compiler.
//
//  THorseSSESession is the portable (Delphi + FPC) session carrier: subclass
//  it, capture handler state in fields, implement Execute. Delphi handlers
//  may also use the anonymous-method overload of Stream.
//
//  Lifetime of the session object: owned by the caller. THorseSSE.Stream
//  runs Execute synchronously (SendStream is synchronous) and returns when
//  Execute returns; the caller frees the session in its own finally block.
// =============================================================================

interface

uses
{$IF DEFINED(FPC)}
  SysUtils,
  Classes,
{$ELSE}
  System.SysUtils,
  System.Classes,
{$IFEND}
  Horse.Request,
  Horse.Response,
  Horse.SSE.Writer;

type
  // Cross-compiler streaming session. Subclass, store state in fields,
  // implement Execute. Example:
  //
  //   type TMySession = class(THorseSSESession)
  //   public
  //     procedure Execute(const ASSE: THorseSSEWriter); override;
  //   end;
  //
  //   procedure TMySession.Execute(const ASSE: THorseSSEWriter);
  //   begin
  //     while ASSE.IsConnected do
  //     begin
  //       ASSE.Send('ping');
  //       Sleep(1000);
  //     end;
  //   end;
  THorseSSESession = class abstract
  public
    procedure Execute(const ASSE: THorseSSEWriter); virtual; abstract;
  end;

{$IF NOT DEFINED(FPC)}
  // Named alias required — Delphi rejects inline 'reference to procedure'
  // expressions in method parameter positions (E2003).
  TSSEStreamProc = reference to procedure(const ASSE: THorseSSEWriter);
{$IFEND}

  THorseSSE = class
  public
    // Set Content-Type, Cache-Control and X-Accel-Buffering headers.
    // Must be called before Res.SendStream (the stream base writer reads
    // Content-Type in its constructor to decide chunked framing).
    class procedure Prepare(const ARes: THorseResponse); static;

    // Return the Last-Event-ID header sent by the client on reconnect.
    // Returns '' if no such header is present.
    class function LastEventId(const AReq: THorseRequest): string; static;

    // Prepare headers and stream using a session object (Delphi + FPC).
    // ASession is NOT owned or freed by Stream.
    class procedure Stream(const ARes: THorseResponse;
                           const ASession: THorseSSESession); overload; static;

{$IF NOT DEFINED(FPC)}
    // Prepare headers and stream using an anonymous callback (Delphi only).
    // The closure captures whatever state the caller needs.
    class procedure Stream(const ARes: THorseResponse;
      const AProc: TSSEStreamProc); overload; static;
{$IFEND}
  end;

implementation

// ---------------------------------------------------------------------------
// Internal adapter: bridges THorseSSESession to THorseStreamProc.
// Lifetime: created and freed within the same Stream call.
// ---------------------------------------------------------------------------
type
  TSSEStreamAdapter = class
  strict private
    FSession: THorseSSESession;
  public
    constructor Create(const ASession: THorseSSESession);
    procedure Run(const AWriter: IHorseStreamWriter);
  end;

constructor TSSEStreamAdapter.Create(const ASession: THorseSSESession);
begin
  inherited Create;
  FSession := ASession;
end;

procedure TSSEStreamAdapter.Run(const AWriter: IHorseStreamWriter);
var
  LSSE: THorseSSEWriter;
begin
  LSSE := THorseSSEWriter.Create(AWriter);
  try
    FSession.Execute(LSSE);
  finally
    LSSE.Free;
  end;
end;

// ---------------------------------------------------------------------------
// THorseSSE
// ---------------------------------------------------------------------------

class procedure THorseSSE.Prepare(const ARes: THorseResponse);
begin
  ARes.ContentType('text/event-stream');
  ARes.AddHeader('Cache-Control', 'no-cache');
  ARes.AddHeader('X-Accel-Buffering', 'no');
end;

class function THorseSSE.LastEventId(const AReq: THorseRequest): string;
begin
  Result := AReq.Headers['Last-Event-ID'];
end;

class procedure THorseSSE.Stream(const ARes: THorseResponse;
                                  const ASession: THorseSSESession);
var
  LAdapter: TSSEStreamAdapter;
begin
  Prepare(ARes);
  LAdapter := TSSEStreamAdapter.Create(ASession);
  try
    ARes.SendStream(LAdapter.Run);
  finally
    LAdapter.Free;
  end;
end;

{$IF NOT DEFINED(FPC)}
class procedure THorseSSE.Stream(const ARes: THorseResponse;
  const AProc: TSSEStreamProc);
begin
  Prepare(ARes);
  ARes.SendStream(
    procedure(const AWriter: IHorseStreamWriter)
    var
      LSSE: THorseSSEWriter;
    begin
      LSSE := THorseSSEWriter.Create(AWriter);
      try
        AProc(LSSE);
      finally
        LSSE.Free;
      end;
    end);
end;
{$IFEND}

end.
