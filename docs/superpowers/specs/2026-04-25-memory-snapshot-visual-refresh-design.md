# Memory Snapshot Visual Refresh Design

## Goal

Refresh `memory snapshot` so it keeps the current information architecture while borrowing the brighter visual language, colored icons, status treatment, and update motion from `battery snapshot`.

## Current Context

- `MemorySnapshotView` already has a strong layout with `headerSection`, `pressureCard`, `detailsCard`, and `usageBreakdown`.
- `BatterySnapshotView` already demonstrates the target visual vocabulary: brighter cards, colored status accents, small motion on changing values, and clearer state badges.
- The requested change is visual polish, not a structural rewrite.

## Approved Direction

- Base direction: option `A` from the visual companion.
- Keep the current `memory snapshot` layout intact.
- Make the screen brighter overall.
- Increase motion slightly, especially around pressure/chart/value updates.
- Do not turn the screen into a new dashboard or reduce information density.

## Design

### Layout

Keep the current section order and responsive behavior:

- header
- pressure overview card
- details card
- usage breakdown card

No new top-level sections. No major resizing that changes scan order.

### Visual Language

Apply battery-inspired styling to `memory snapshot`:

- Brighter card surfaces and clearer border/highlight treatment.
- Colored icon chips for key memory groups and pressure status.
- Stronger status badge treatment in header.
- Slightly richer gradients in the pressure chart background and quick stat cards.

### Motion

Use restrained motion only when values update:

- Pulse key values when related metrics change.
- Fade/scale state badges when pressure state changes.
- Keep chart animation smooth but short.
- Avoid infinite animations or decorative motion that adds noise.

### Pressure Emphasis

Make the pressure card feel more like the primary hero:

- Give pressure state stronger color presence.
- Brighten chart treatment.
- Make latest pressure point and pressure badge feel more alive.
- Keep the chart secondary to readability; chart should support scanability, not dominate it.

### Details And Breakdown

Keep existing data density, but increase readability:

- Mini cards should be brighter and use clearer accent colors.
- Detail groups should feel lighter and more intentional.
- Usage breakdown should inherit the brighter visual treatment without changing the actual metric content.

## Architecture

Introduce a small presentation helper for `memory snapshot` visual state so styling and change-detection logic can be tested separately from SwiftUI layout code.

This helper should own:

- change detection for animated value groups
- pressure/status presentation decisions
- icon and accent selection for refreshed visual treatment

`MemorySnapshotView` should remain the composition layer that applies those decisions to existing sections.

## Testing

- Add focused unit tests for the new presentation helper.
- Verify change detection for animated groups.
- Verify status/pressure presentation decisions that drive the visual refresh.
- Run targeted Swift tests for the new helper and related memory tests.

## Scope Guardrails

In scope:

- visual refresh
- colored icon treatment
- brighter cards
- restrained update motion
- helper extraction needed to support testability

Out of scope:

- changing memory collection logic
- changing metric semantics
- adding new sections or controls
- rewriting the dashboard layout system
