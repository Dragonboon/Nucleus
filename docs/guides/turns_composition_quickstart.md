# Turn-based gameplay: a first scene

You can use Nucleus turns for tactics, cards, board games, RPG combat or a
multiplayer lobby. A turn does **not** require damage, a character or a global
manager. This guide links the pieces in the simplest useful order.

## 1. Place the scene-owned nodes

```text
GameBoard (Node)
├── TurnSession (NucleusTurnSession)
├── PlayerA (Node)
│   ├── TurnParticipant (NucleusTurnParticipant)
│   └── Action (NucleusGameplayAction)
│       ├── TurnRequirement (NucleusTurnRequirement)
│       └── FinishTurn (NucleusFinishTurnEffect)
└── PlayerB (Node)
    └── TurnParticipant (NucleusTurnParticipant)
```

Give participants distinct `participant_id` values. Point the requirement
and effect to PlayerA's participant and point the requirement to the session.
Use `SERIAL`, `INITIATIVE` or `SIMULTANEOUS` in the session Inspector.

Start a round with:

```gdscript
@onready var turns: NucleusTurnSession = $TurnSession
@onready var a: NucleusTurnParticipant = $PlayerA/TurnParticipant
@onready var b: NucleusTurnParticipant = $PlayerB/TurnParticipant

func _ready() -> void:
    turns.start_session([a, b])
```

Only the active participant's turn-gated actions may commit. The
`NucleusFinishTurnEffect` completes the opportunity *after* earlier effects.
For a game in which players perform several actions per turn, omit that effect
and explicitly call `participant.end_turn()` when the player chooses "End turn".

## 2. Pick a clock for temporary effects

A status definition defaults to duration in **seconds**. Set
`duration_unit = TURNS` for a status lasting discrete opportunities or rounds.
The status container does not guess which actor should advance its clock.

Add one `NucleusTurnStatusBinding` for the container, assign its session and
the participant, and choose:

| Clock | Advances when |
| --- | --- |
| Participant opportunity | The selected participant's turn ends or is blocked |
| Every opportunity | Any participant's turn ends or is blocked |
| Completed round | The entire roster has completed its round |

Do not attach multiple clock bindings to one status container. Numeric lifetime
values/tick intervals for turn statuses are whole numbers. Real-time statuses in
the same container continue to use seconds independently.

## 3. Compose additional rules only as needed

| Feature | Contract |
| --- | --- |
| Mana, stamina or arbitrary cost | [ValuePool / GameplayAction](../components/gameplay_actions_attributes_status.md) |
| Dynamic attacks and layered shields | [Combat composition](../components/rpg_composition.md) |
| Learned and slotted abilities | [Progression / loadout](../components/rpg_composition.md) |
| Enemy waves and encounter completion | [Encounter director](../components/rpg_composition.md) |
| Reactions during a turn | [Reaction coordinator](../components/gameplay_actions_attributes_status.md) |

Network input authorization, simultaneous-action resolution order, legal moves,
rewards and victory conditions belong to the game. A reaction does not
automatically end the reacting actor's opportunity.

## 4. Confirm locally

Open `tests/headless/test_runner.tscn` and press **F6**, or run:

```bash
godot --headless --path . res://tests/headless/test_runner.tscn
```

Use `tests/smoke/rpg_battle_smoke.tscn` for the combat-focused acceptance.
The generic turn/action/status integration is covered in
`tests/headless/turn_composition_test.gd`.

**Further reference:** [Full turn-session contract](../components/turn_sessions.md).
