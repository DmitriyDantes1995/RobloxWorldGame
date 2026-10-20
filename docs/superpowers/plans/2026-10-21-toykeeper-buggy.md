# ToyKeeper Buggy Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The owner has approved the design and explicitly requested implementation and publication in this session.

**Goal:** Two players can ride one buggy in the published ToyKeeper.
**Architecture:** An Edit-authored physical model, one server vehicle controller and one input LocalScript. Existing game loop starts the controller; capture ejects only its victim before applying an impulse.
**Tech Stack:** Luau, Roblox constraints, VehicleSeat/Seat, ProximityPrompt, RemoteEvent, StudioTestService, existing XML place.
**Spec:** ../specs/2026-10-21-toykeeper-buggy-design.md

## Global Constraints

- ToyKeeper only; preserve existing dirty work and Studio model. No Git push.
- Forward limit 45, reverse 18 studs/s. Two seats. E entry, jump exit.
- No profile changes, external assets or runtime map generation.
- Publish existing place 78424799936316 after checks; no purchases or account changes.

## Review Focus

- Passenger/malformed/stale input cannot drive the vehicle.
- Leaving or dying does not retain throttle or remove the other passenger.
- Capture detaches one SeatWeld before applying impulse.
- Empty recovery never teleports an occupied vehicle or overwrites players.
- Saved/published place contains authoring model and product scripts, no QA state.

## Task 1 — Vehicle

Files: toy-keeper/authoring/Buggy.luau; src/ServerScriptService/ToyVehicle.luau; src/StarterPlayer/StarterPlayerScripts/ToyVehicleClient.luau (all under toy-keeper).
Interfaces: Vehicle.new(scene), Vehicle:Input(player,throttle,steer,now), Vehicle:Step(now,dt), Vehicle:Eject(humanoid). Live model scene.Buggy, ReplicatedStorage.ToyDrive.

- [x] Run a failing Edit assertion that scene.Buggy and two independently usable seats exist.
- [x] Author model at (0,2.3,12), install controller/client and manifest entries.
- [x] Test physical movement, reverse, steering and braking with two clients; assert passenger and invalid input rejection and input timeout.

## Task 2 — Game integration and recovery

Files: ToyServer.luau; ToyGame.luau; ToyVehicle.luau.

- [x] Test Catch on a seated capture target; verify only target detaches and machine does not receive the throw.
- [x] Implement safe Eject; retain gift dropping, grace period and ordinary recovery.
- [x] Test exit/driver swap and empty out-of-bounds reset. Death/disconnect paths reviewed; no dedicated live disconnect/death assertion was run.

## Task 3 — Save and publish

Files: place/ToyKeeper.rbxlx; toy-keeper/scripts-manifest.json; toy-keeper/README.md; toy-keeper/AGENTS.md.

- [x] Remove QA instances in Edit, compile all product sources, check 24 gift points / 3 guards / 12 toys.
- [x] Save model and all source copies to XML; compare Studio/model and local source hashes and ensure TreasureLair unchanged.
- [x] Publish through Studio; verify new cloud place version. Provide play link and controls.

## Execution ledger

Ruling: use the current shared Studio checkout, preserving all existing work. A second checkout would not isolate the active Studio scene and would omit uncommitted work. Do not commit unrelated prior changes.
Ruling: the owner's explicit “Да, делай … и обнови опубликованную игру … сразу” supplies design, execution and deployment authorization; continue through implementation and publication without asking to approve the same scope again.

Task 1 and 2: complete. Physical two-client test passed: forward 131.419 studs, top speed 44.9275, reverse 28.2938, turn heading dot -0.71486. Passenger/malformed input rejected; timeout brakes; both seats replicated; driver swap; victim-only Catch (throw distance 54.9933) and empty recovery pass. Exit ownership auto=true and correct owner. One unrelated Roblox Core ChatScript SetCore error appeared in the virtual client; no ToyKeeper product error was recorded.

Steering RED: actual throttle=.5 and steer=1 reached server, but heading dot after 2s was .98765. Each frame rebuilt the goal from the lagging body. GREEN: accumulated heading produced -.71486. QA initially looked at non-replicated Occupant rather than actual SeatWelds; switched observation to physical joints and waited for client response. Capture QA initially retained the actuator velocity from its preceding timeout test; zeroed it before measuring the isolated throw.

Native single-player controls verified with the product LocalScript and enabled PlayerModule: W drove 116.293 studs; W+D turned; Space exited; ordinary W walked 24.0778 studs after exit. No QA autopilot or persistence requests in that run. The added model was visually inspected in Play.

Task 3 local verification: work/qa/verify-buggy.py passes (8 Studio/source/XML hashes equal, 24 gifts, 3 guards, 12 toys, original geometry preserved except parking, no QA or dangling refs). All eight sources compile in Studio; git diff --check passes. Review by review_buggy found no publication blockers.

Publication complete: native capture and key input failed; after the clean Edit state was restored, the owner performed File → Publish and replied “Опубликовано”. Creator Dashboard, Version History with Show published only enabled, confirms version 9 published on 21.10.2026 at 00:22 Moscow time. Public access was already enabled and was not changed. Proof: task visualization artifact toykeeper-buggy-published-v9.jpg. No Git push.
