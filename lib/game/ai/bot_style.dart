import 'package:shared_preferences/shared_preferences.dart';

import 'package:trgou/game/ai/aggressive_strategy.dart';
import 'package:trgou/game/ai/ai_strategy.dart';
import 'package:trgou/game/ai/defensive_strategy.dart';

enum BotStyle {
  aggressive,
  defensive;

  static BotStyle fromString(String value) {
    return BotStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BotStyle.aggressive,
    );
  }
}

const String _key = 'trgou_bot_style';

Future<BotStyle> loadBotStyle() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_key);
  return value != null ? BotStyle.fromString(value) : BotStyle.aggressive;
}

Future<void> saveBotStyle(BotStyle style) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, style.name);
}

AiStrategy strategyFor(BotStyle style) {
  switch (style) {
    case BotStyle.aggressive:
      return aggressiveStrategy;
    case BotStyle.defensive:
      return defensiveStrategy;
  }
}
