# horse-sse

Server-Sent Events for the [Horse](https://github.com/HashLoad/horse) web framework.

Implements the [SSE wire protocol](https://html.spec.whatwg.org/multipage/server-sent-events.html)
on top of `Res.SendStream` / `IHorseStreamWriter`: correct UTF-8 framing, multi-line data,
event types, last-event-ID, reconnect hints, heartbeats, and field validation.
The streaming transport (socket, TLS, keep-alive) stays in Horse core and its providers;
this package owns only the `event:` / `data:` / `id:` / `retry:` protocol layer.

Dual-compiles: **Delphi 10.4+** and **FPC 3.2.2+**.

## Install

```
boss install freitasjca/horse-sse
```

Requires Horse ≥ 3.3.13.

## Quick start

### Delphi — anonymous method

```pascal
uses Horse, Horse.SSE.Response;

THorse.Get('/events',
  procedure(Req: THorseRequest; Res: THorseResponse)
  begin
    THorseSSE.Stream(Res,
      procedure(const SSE: THorseSSEWriter)
      var I: Integer;
      begin
        for I := 1 to 5 do
        begin
          if not SSE.Send('update', IntToStr(I)) then Break;
          Sleep(1000);
        end;
      end);
  end);
```

### FPC / cross-compiler — session class

```pascal
uses Horse, Horse.SSE.Response;

type
  TCountSession = class(THorseSSESession)
  public
    procedure Execute(const SSE: THorseSSEWriter); override;
  end;

procedure TCountSession.Execute(const SSE: THorseSSEWriter);
var I: Integer;
begin
  for I := 1 to 5 do
  begin
    if not SSE.Send('update', IntToStr(I)) then Break;
    Sleep(1000);
  end;
end;

THorse.Get('/events',
  procedure(Req: THorseRequest; Res: THorseResponse)
  var LSession: TCountSession;
  begin
    LSession := TCountSession.Create;
    try
      THorseSSE.Stream(Res, LSession);
    finally
      LSession.Free;
    end;
  end);
```

Consume with:

```
curl -N http://localhost:9000/events
```

## API

### `THorseSSE`

| Method | Description |
|--------|-------------|
| `Prepare(Res)` | Set `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`. Call before `Res.SendStream` when managing the stream manually. |
| `Stream(Res, Session)` | Prepare headers and run `Session.Execute`. Delphi + FPC. |
| `Stream(Res, Proc)` | Prepare headers and run an anonymous procedure. **Delphi only.** |
| `LastEventId(Req)` | Return the `Last-Event-ID` header sent by the client on reconnect; `''` if absent. |

### `THorseSSEWriter`

Passed to `Execute` or the anonymous procedure. Single-threaded — do not share across threads.

| Method | Returns | Description |
|--------|---------|-------------|
| `Send(Data)` | `Boolean` | Send a data-only event (`data: …\n\n`). Returns `False` after disconnect. |
| `Send(Event, Data [, Id])` | `Boolean` | Send a typed event with optional `id:` field. |
| `SendEvent(TSSEEvent)` | `Boolean` | Send a pre-built event record. |
| `Comment(Text)` | `Boolean` | Send a comment line (`: …\n`). Not dispatched as an event on the client. |
| `Heartbeat` | `Boolean` | Send `: \n\n` to keep the connection alive. |
| `HeartbeatIfDue(IntervalMs)` | `Boolean` | Send a heartbeat only if `IntervalMs` have elapsed. Returns `False` on disconnect, `True` otherwise. |
| `Retry(Ms)` | `Boolean` | Send `retry: N\n\n` — updates the client's reconnect delay without dispatching a data event. |
| `IsConnected` | `Boolean` | `False` after the first failed write. |
| `LastEventId` | `string` | The `id:` from the last successfully delivered event that carried a non-empty `Id`. |

### `TSSEEvent`

```pascal
type
  TSSEEvent = record
    Event: string;   // event type; '' = omit the event: field
    Data:  string;   // may contain CR, LF, CRLF — each newline becomes a new data: line
    Id:    string;   // last-event-ID; '' = omit; must not contain CR, LF or NUL
    Retry: Integer;  // reconnect hint (ms); < 0 = omit the retry: field
    class function Default: TSSEEvent; static;
  end;
```

### `THorseSSESession`

Abstract base for cross-compiler session classes:

```pascal
type
  THorseSSESession = class abstract
  public
    procedure Execute(const SSE: THorseSSEWriter); virtual; abstract;
  end;
```

### `EHorseSSEInvalidField`

Raised by the formatter when `Event` contains CR or LF, or when `Id` contains CR, LF, or NUL.

### Low-level framing (advanced)

`Horse.SSE.Format` exposes the pure framing functions used internally — no Horse dependency:

```pascal
function SSEFormatEvent(const AEvent: TSSEEvent): TBytes;
function SSEFormatComment(const AText: string): TBytes;
function SSEFormatRetry(const AMs: Integer): TBytes;
```

Pass the returned `TBytes` directly to `IHorseStreamWriter.Write` when building a custom
streaming loop without `THorseSSEWriter`.

## Requirements

| Requirement | Version |
|-------------|---------|
| Horse | ≥ 3.3.13 |
| Delphi | 10.4 Sydney or later |
| FPC | 3.2.2 or later |

Any Horse provider that supports `Res.SendStream` works: CrossSocket, nghttp2, mORMot,
Indy (original Horse default), and fphttpserver (FPC).

## License

MIT — see [LICENSE](LICENSE).
