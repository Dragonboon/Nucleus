# Optional EventBus Module

## Status

`addons/nucleus/modules/event_bus` is optional and is not loaded by default.

Prefer local Godot signals when producer and consumer have a natural ownership
relationship.

## Purpose

`NucleusEventBus` is a priority-aware mediator for genuinely decoupled events,
non-SceneTree collaborators, or projects that explicitly choose a global bus.

It supports:

- subscription and one-shot subscription;
- priority ordering with stable insertion order;
- synchronous or deferred callbacks;
- deferred publication;
- optional bounded publication history;
- invalid-Callable pruning.

## Ownership and lifetime

The module is a Node. The game decides where it lives.

Only configure it as an Autoload when events truly need process-wide,
cross-scene lifetime. A scene-local EventBus is valid when the decoupling scope
is scene-local.

## Threading

The current implementation is main-thread infrastructure. Do not publish from
worker threads.

## Diagnostics/history

`max_history_length` defaults to zero. History is opt-in and bounded.

History is for diagnostics; it is not an event replay/persistence mechanism.

## When not to use it

Do not use EventBus to avoid passing a reference, connecting a local signal, or
defining a small explicit interface.

It must not evolve into a Service Locator.
