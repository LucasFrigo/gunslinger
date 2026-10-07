# Feature planning (ask first)

When planning a feature — roadmap entry, design note, or an implementation that is not a straight bugfix — stop and ask the user every design question that would change the result. Do this before writing the plan into `Roadmap.md`, `docs/FEATURES.md`, or code.

Keep this file in step with `.cursor/rules/feature-planning.mdc` when the workflow changes.

## How to ask

- Maximize the list. Cover feel, who it applies to (VR / flat / AI / MP), defaults, settings, persistence, failure cases, and what stays unchanged.
- One question per decision. Give the real options, and mark a recommendation only after the options are stated.
- Skip a question only when the user already answered it in this conversation.
- Wait for the answers before locking the plan. A partial answer locks only what they decided; ask again for the rest.

## Example

Planning "slow-hand aim steady" should ask, before the roadmap bullet exists: Does the visible gun lag with the filtered bore, or only the bullet? Is strength a slider, a toggle, or always on? Does the trigger-click spike get dropped? Does flat mode change? Is the default on for Quest?
