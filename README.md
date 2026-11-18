# Brainrot Bazaar — roblox-brainrot-01

A 3D brainrot game for make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01), built as a
Rojo project. You walk a 3D world, buy absurd meme brainrots off a central conveyor, park them on your base to earn
$/sec, and climb a ladder of rarities, mutations and rebirths — while other players, the Sneaky Snatcher thief and
the Grinder Pit sweeper all try to take what you caught.

## The loop

1. Brainrots walk down the central conveyor, each wearing a label with its name, rarity and $/sec.
2. Press **E** near one to buy it (if you can afford it). It waddles to a slot on your base and starts earning.
3. Money ticks up every second, server-side. Spend it on rarer brainrots, Golden Conveyor upgrades (+25% income
   per level, max 5) or a **Rebirth** ($25,000 × (rebirths + 1), +50% income forever, resets money and base).
4. Defend: hold **E** on another player's base brainrot to steal it (5 s hold). Owners press **F** to slap thieves
   away — a slapped thief cannot steal again for 10 s — or **L** to lock their base for 20 s (60 s cooldown).
   Alone in the server, the Sneaky Snatcher raids a random base every 60 s, and the Grinder Pit's spinning sweeper
   knocks wanderers back to spawn. **U** buys an upgrade and **R** rebirths, so every action has a key.

## The cast (12, $50–$50,000, $1–$500/sec)

Common: Soggy Crouton Kevin ($1/s), Sandal Lord Zorp ($3/s). Rare: Sprinkler Goblin Nubbs ($8/s), Grandma Gazebo
($15/s). Epic: Cinderblock Cherub ($30/s), The Lawnmower Whisperer ($55/s). Legendary: Sir Soggybottom III ($95/s),
Cosmic Grandma Brenda ($160/s). Mythic: Baron Von Washing Machine ($220/s), DJ Traffic Cone ($320/s). Secret:
Grandpa Internet ($420/s), The Last Slice of Pizza ($500/s). Mutations: Normal ×1, Golden ×3, Rainbow ×5,
Diamond ×10 — Rainbow and Diamond brainrots wear a visible glow shell, so a rare pull reads across the map.

## The map

A grass plaza with a 300-stud conveyor down the middle, 8 shop-like bases on a ring around it (striped awnings,
owner signs, six display slots each), a golden statue, a thief ring-walkway with lamps, a lava Grinder Pit with a
spinning sweeper bar in the north-west corner, trees, bushes, clouds, and a pink "BRAINROT BAZAAR" arch over the
conveyor's north end. Bright cartoon lighting, up to 8 players.

## Layout

- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and
  `PLAY.json` to `/output`, leaving out every name that starts with a dot, and writes `/output/dossier.json` with
  `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is the place Rojo builds from `src/` and `default.project.json` (`rojo build default.project.json
  --output game.rbxl`). Never run Rojo over a Studio-saved place.
- `src/shared/Cast.luau` — the cast, rarity ladder and every economy number, in one place.
- `src/server/World.luau` — builds the 3D world in code: spawn plaza, conveyor, 8 bases, thief ring-walkway,
  Grinder Pit, scenery.
- `src/server/BrainrotFactory.luau` — builds each brainrot from parts, with its label and buy/steal prompts.
- `src/server/State.luau` — all player state (money, income, bases, locks, rebirths, upgrades, slot tracking).
- `src/server/init.server.luau` — the server loop: spawning, walking, income, stealing, slapping, the thief,
  the sweeper.
- `src/client/Game.client.luau` — keyboard: F slap, L lock, U upgrade, R rebirth. `src/client/Hud.client.luau` —
  the HUD (money, income, objective, feed, rebirths/upgrade level, Lock/Upgrade/Rebirth buttons). The server owns
  all money; the client only displays it.
- `screenshots/` holds three captures of the game running in Studio; the first by name is the cover and must also
  be the game's first thumbnail on Roblox. `PLAY.json` names the published place.
  `https://www.roblox.com/games/89535437916456/Brainrot-Bazaar`. `TOUR.json` is the optional reviewer tour
  (E to buy, L to lock).

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt,
which gives every command in order (Before you submit, then Enter).

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Takoyaki061/make-fun-roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Takoyaki061/make-fun-roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)
