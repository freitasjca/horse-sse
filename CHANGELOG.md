# Changelog

All notable changes are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0-alpha.1] - 2026-11-18

### Added

- **`Horse.SSE.Format`** — pure framing functions; no Horse dependency; UTF-8 safe on
  Delphi (`TEncoding.UTF8`) and FPC (`AnsiString` raw bytes):
  - `SSEFormatEvent(TSSEEvent): TBytes` — full event block with optional `event:`, `id:`,
    `retry:`, and one or more `data:` lines.
  - `SSEFormatComment(string): TBytes` — comment line(s) (`': …\n'`).
  - `SSEFormatRetry(Integer): TBytes` — `retry: N\n\n` without a data event.
  - `EHorseSSEInvalidField` — raised when `Event` contains CR/LF, or `Id` contains
    CR, LF, or NUL.

- **`Horse.SSE.Writer`** — `THorseSSEWriter` wraps `IHorseStreamWriter`:
  - `Send(Data)`, `Send(Event, Data [, Id])`, `SendEvent(TSSEEvent)`.
  - `Comment(Text)`, `Heartbeat`, `HeartbeatIfDue(IntervalMs)`, `Retry(Ms)`.
  - `IsConnected`, `LastEventId` properties.
  - Write failures (network disconnect) are caught and set `IsConnected := False`;
    subsequent calls return `False` immediately.

- **`Horse.SSE.Response`** — Horse glue:
  - `THorseSSE.Prepare(Res)` — sets `Content-Type: text/event-stream`,
    `Cache-Control: no-cache`, `X-Accel-Buffering: no`.
  - `THorseSSE.Stream(Res, Session)` — session-object overload (Delphi + FPC).
  - `THorseSSE.Stream(Res, Proc)` — anonymous-method overload (Delphi only).
  - `THorseSSE.LastEventId(Req)` — returns the `Last-Event-ID` reconnect header.
  - `THorseSSESession` abstract base for cross-compiler session classes.

- In-process conformance suite (`tests/HorseSSETests.dpr`): 47 assertions across
  Format (F01–F19), Writer (W01–W15), and Response (R01–R04) groups.
  Verified green on FPC 3.2.2, FPC 3.3.1 trunk, and Delphi 64-bit (Win64).
