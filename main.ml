(* Copyright (C) 2015, Thomas Leonard
 * See the README file for details. *)

open React    (* Provides [S] for signals (and [E] for events) *)

(* Each module provides a [sig] block describing its public interface and a [struct]
   with its implementation. The [sig] blocks are optional, but make it easier to see
   a module's API quickly. In a larger program, you would put each module in a separate
   file.
   e.g. the contents of [Time]'s sig block would go in `time.mli` and the contents of
   its struct block in `time.ml`. *)

module Time : sig
  (** A helper module to provide the current time as a reactive signal. *)

  val current : float S.t   (** The current time, updated each second *)
end = struct
  open Lwt.Infix            (* Provides >>=, the "bind" / "and_then" operator *)

  let current, set_current = S.create (Unix.gettimeofday ())

  let () =
    (* Update [current] every second *)
    let rec loop () =
      Lwt_js.sleep 1.0 >>= fun () ->
      set_current (Unix.gettimeofday ());
      loop () in
    Lwt.async loop
end

module Model : sig
  (** The core application logic. *)

  val display : string S.t  (** The output value to display on the screen *)

  val start : unit -> unit
  val stop : unit -> unit
end = struct
  let state, set_state = S.create `Clear

  let start () =
    set_state (`Running_since (S.value Time.current))

  let stop () =
    set_state (
      match S.value state with
      | `Running_since start -> `Stopped_showing (S.value Time.current -. start)
      | `Stopped_showing _ | `Clear -> `Clear
    )

  (* [calc time state] returns the string to display for a given time and state.
     Note: it works on regular values, not signals. *)
  let calc time = function
    | `Running_since start -> Printf.sprintf "%.0f s" (time -. start)
    | `Stopped_showing x -> Printf.sprintf "%.0f s (stopped)" x
    | `Clear -> "Ready"

  let display =
    (* [S.l2 calc] lifts the 2-argument function [calc] to work on 2 signals.
       [calc] will be called when either input changes. *)
    S.l2 calc Time.current state
end

module Templates : sig
  (** Render the model using HTML elements. *)

  val main :  Html_types.div Tyxml_js.Html.elt
  (** The <div> element for the app. *)
end = struct
  module R = Tyxml_js.R.Html   (* Reactive elements, using signals *)
  open Tyxml_js.Html           (* Ordinary, non-reactive HTML elements *)

  (* An "onclick" attribute that calls [fn] and returns [true],
   * ignoring the event object. *)
  let onclick fn =
    a_onclick (fun _ev -> fn (); true)

  let main = div [
    div ~a:[a_class ["display"]] [R.pcdata Model.display];
    button ~a:[onclick Model.start] [pcdata "Start"];
    button ~a:[onclick Model.stop] [pcdata "Stop"];
  ]
end

(* Initialisation code, called at start-up. *)
let () =
  (* Add [Templates.main] to the <body>. *)
  Tyxml_js.Register.body [Templates.main]
