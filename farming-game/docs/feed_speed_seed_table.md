# Seeds from feed speed

When you successfully feed a customer, seeds use **how much of their order timer was left** when you pressed **E**.

## Definitions

- **Order time** = that customer’s `time_limit` (seconds), after any wave/random variation.
- **Time left** = seconds remaining on their timer at the moment you feed them.
- **Speed ratio** = `time_left / order_time`, clamped to `0 … 1`.
  - **1.0** = you fed them right away (almost full timer left).
  - **0.0** = you fed them at the last moment (timer nearly empty).

## Speed multiplier (feed timing only)

```text
speed_mult = lerp(0.50, 1.35, speed_ratio)
           = 0.50 + 0.85 × speed_ratio
```

| Time left (as % of order) | speed_ratio | speed_mult |
|---------------------------|-------------|------------|
| 0% (last moment)          | 0.00        | 0.50       |
| 25%                       | 0.25        | 0.71       |
| 50%                       | 0.50        | 0.93       |
| 75%                       | 0.75        | 1.14       |
| 100% (instant)            | 1.00        | 1.35       |

## Full seed formula (in code)

1. **base_seeds** from wave + combo streak (see `game_manager.gd`).
2. **mutator_seed_tint** from endless mutators (usually ~1.0 in normal mode).
3. **speed_mult** from the table above.

```text
seeds_earned = round(base_seeds × mutator_seed_tint × speed_mult)
seeds_earned = max(1, seeds_earned)
```

## Example (same wave, no combo, mutator 1.0)

If **base_seeds = 3** (typical mid-wave):

| speed_ratio | speed_mult | seeds |
|-------------|------------|-------|
| 0.00        | 0.50       | 2     |
| 0.25        | 0.71       | 2     |
| 0.50        | 0.93       | 3     |
| 0.75        | 1.14       | 3     |
| 1.00        | 1.35       | 4     |

If **base_seeds = 2** (early wave):

| speed_ratio | seeds (rounded) |
|-------------|-----------------|
| 0.00        | 1               |
| 1.00        | 3               |

Constants: `FEED_SPEED_MULT_MIN = 0.5`, `FEED_SPEED_MULT_MAX = 1.35` in `game_manager.gd`.
