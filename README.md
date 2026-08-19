# trgou

**The Royal Game of Ur** - a Flutter based implementation of the the Royal Game of Ur with; local hotseat, an adaptive and explainable AI, optional deterministic RNG, and saved games.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK **^3.11.0** as in `pubspec.yaml`)

## How to Run

```bash
flutter pub get
flutter run
```

## Play

From the home screen you can:

- **Against AI** - There are five AI settings to pick from, with default, Bayesian, or a fixed style (debug mode shows extra details).
- **Hotseat** - Two players can play against each other on a shared device.
- **Continue Match** - Continue the last in-progress game from local storage (`SharedPreferences`).
- **Settings** - Optional **fixed RNG seed** (reproducible dice + AI randomness) and a **debug layer** (diagnostics, details, etc. on the game screen).

Tap the dice area to roll when it is your turn, then tap a piece or tile to move when the rules allow.

## AI System

The game includes several AI configurations:

- **Default AI** - Balanced, uses only value-based reasoning. For each legal move, the AI will compute three heuristic cores and then combine them for a total score, the move with the heighest total score is what the AI will play.
- **Bayesian AI** - Adapts dynamically to player behaviour using Bayesian learning.
- **Aggressive AI** - Prioritises captures and pressure. 
- **Defensive AI** - Prioritises safety and risk minimisation.
- **Progressive AI** - Prioritises advancing pieces toward completion. 

The Bayesian AI observes player actions and adjusts its strategic priorities accordingly, allowing it to respond differently to aggressive, defensive, or progress-focused playstyles.

### Rules (Brief Rundown)

This implementation follows the standard rule set of the Royal Game of Ur.

- Four binary dice are rolled each turn, their values are summed for the total roll (values 0–4).
- Pieces enter from the start, move along a shared central track, and exit at the finish.
- Rosettes are safe and give the respective player an extra turn.
- Landing on an opponent’s piece captures it, sending it back to the respective player's starting area.

For a more full explanation, see the following:
- [British Museum / Irving Finkel materials](https://www.britishmuseum.org/blog/royal-game-ur)
- [Wikipedia](https://en.wikipedia.org/wiki/Royal_Game_of_Ur)

## Project Context

This project was developed as a part of a Computer Science dissertation. The following features were the main focus:

- Value-Based Reasoning for decision-making.
- Bayesian Learning for adaptive AI behaviour.
- Explainable AI in game environments.

The goal is to demonstrate how AI systems can be both **adaptive** and **interpretable** in a constrained mobile environment.

## Tech

- **Flutter** UI
- **Riverpod** for app and game state
- **shared_preferences** for save games and logs
