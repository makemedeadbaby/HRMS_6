import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuoteService — fetches a daily motivational quote from ZenQuotes API.
//
// Strategy:
//   1. Check shared_preferences for a cached quote from today.
//   2. If today's quote exists → return it (no network call).
//   3. Otherwise fetch a new quote from zenquotes.io/api/quotes
//      (returns 50 quotes per request — we pick one based on employee ID
//       so each employee sees a different quote on the same day).
//   4. Cache the fetched quotes list for the day.
//   5. Fall back to a built-in list if network fails.
// ─────────────────────────────────────────────────────────────────────────────

class DailyQuote {
  final String text;
  final String author;

  const DailyQuote({required this.text, required this.author});
}

class QuoteService {
  static const _prefKey   = 'daily_quotes_cache';
  static const _prefDate  = 'daily_quotes_date';

  // ── Get today's quote for a specific employee ─────────────────────────────
  static Future<DailyQuote> getTodaysQuote(String employeeId) async {
    final today = _todayString();
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_prefDate);

    List<Map<String, dynamic>> quotes;

    if (cachedDate == today) {
      // Use cached quotes
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          quotes = decoded.map((e) => e as Map<String, dynamic>).toList();
        } catch (_) {
          quotes = await _fetchFromNetwork(prefs, today);
        }
      } else {
        quotes = await _fetchFromNetwork(prefs, today);
      }
    } else {
      // New day — fetch fresh batch
      quotes = await _fetchFromNetwork(prefs, today);
    }

    if (quotes.isEmpty) return _fallback(employeeId);

    // Deterministically pick a quote based on employee ID + today's date
    // so the same employee always gets the same quote for the day,
    // but different employees see different quotes.
    final seed = employeeId.hashCode ^ today.hashCode;
    final rng = Random(seed);
    final idx = rng.nextInt(quotes.length);
    final q = quotes[idx];

    return DailyQuote(
      text: (q['q'] as String?)?.trim() ?? (q['text'] as String?)?.trim() ?? '',
      author: (q['a'] as String?)?.trim() ?? (q['author'] as String?)?.trim() ?? 'Unknown',
    );
  }

  // ── Fetch from network ────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _fetchFromNetwork(
    SharedPreferences prefs,
    String today,
  ) async {
    try {
      // ZenQuotes returns 50 random quotes per call
      const url = 'https://zenquotes.io/api/quotes';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final filtered = decoded
              .where((e) =>
                  e is Map &&
                  (e['q'] as String?)?.isNotEmpty == true &&
                  (e['q'] as String?) != 'Too Many Requests - Wait before requesting again')
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          if (filtered.isNotEmpty) {
            // Cache for today
            await prefs.setString(_prefKey, jsonEncode(filtered));
            await prefs.setString(_prefDate, today);
            return filtered;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[QuoteService] Network error: $e');
    }

    // Try quotable.io as fallback API
    try {
      final quotes = <Map<String, dynamic>>[];
      for (int i = 0; i < 10; i++) {
        final response = await http
            .get(Uri.parse('https://api.quotable.io/random'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          quotes.add({
            'q': data['content'],
            'a': data['author'],
          });
        }
        if (quotes.length >= 3) break;
      }
      if (quotes.isNotEmpty) {
        await prefs.setString(_prefKey, jsonEncode(quotes));
        await prefs.setString(_prefDate, today);
        return quotes;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[QuoteService] Fallback API error: $e');
    }

    return [];
  }

  // ── Fallback built-in quotes (offline mode) ───────────────────────────────
  static DailyQuote _fallback(String employeeId) {
    final today = _todayString();
    final seed = employeeId.hashCode ^ today.hashCode;
    final rng = Random(seed);
    final q = _builtInQuotes[rng.nextInt(_builtInQuotes.length)];
    return q;
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  // ── Built-in motivational quotes (used when offline) ─────────────────────
  static const _builtInQuotes = [
    DailyQuote(text: 'The only way to do great work is to love what you do.', author: 'Steve Jobs'),
    DailyQuote(text: 'Success is not final, failure is not fatal: it is the courage to continue that counts.', author: 'Winston Churchill'),
    DailyQuote(text: 'Believe you can and you\'re halfway there.', author: 'Theodore Roosevelt'),
    DailyQuote(text: 'The future belongs to those who believe in the beauty of their dreams.', author: 'Eleanor Roosevelt'),
    DailyQuote(text: 'It does not matter how slowly you go as long as you do not stop.', author: 'Confucius'),
    DailyQuote(text: 'Your time is limited, so don\'t waste it living someone else\'s life.', author: 'Steve Jobs'),
    DailyQuote(text: 'Strive not to be a success, but rather to be of value.', author: 'Albert Einstein'),
    DailyQuote(text: 'Life is what happens to you while you\'re busy making other plans.', author: 'John Lennon'),
    DailyQuote(text: 'The secret of getting ahead is getting started.', author: 'Mark Twain'),
    DailyQuote(text: 'In the middle of difficulty lies opportunity.', author: 'Albert Einstein'),
    DailyQuote(text: 'Whether you think you can or think you can\'t, you\'re right.', author: 'Henry Ford'),
    DailyQuote(text: 'An investment in knowledge pays the best interest.', author: 'Benjamin Franklin'),
    DailyQuote(text: 'Life is 10% what happens to you and 90% how you react to it.', author: 'Charles R. Swindoll'),
    DailyQuote(text: 'The mind is everything. What you think you become.', author: 'Buddha'),
    DailyQuote(text: 'You miss 100% of the shots you don\'t take.', author: 'Wayne Gretzky'),
    DailyQuote(text: 'Twenty years from now you will be more disappointed by the things you didn\'t do than by the ones you did.', author: 'Mark Twain'),
    DailyQuote(text: 'Do what you can, with what you have, where you are.', author: 'Theodore Roosevelt'),
    DailyQuote(text: 'Hard work beats talent when talent doesn\'t work hard.', author: 'Tim Notke'),
    DailyQuote(text: 'Push yourself, because no one else is going to do it for you.', author: 'Anonymous'),
    DailyQuote(text: 'Great things never come from comfort zones.', author: 'Anonymous'),
    DailyQuote(text: 'Dream it. Wish it. Do it.', author: 'Anonymous'),
    DailyQuote(text: 'Success doesn\'t just find you. You have to go out and get it.', author: 'Anonymous'),
    DailyQuote(text: 'The harder you work for something, the greater you\'ll feel when you achieve it.', author: 'Anonymous'),
    DailyQuote(text: 'Don\'t stop when you\'re tired. Stop when you\'re done.', author: 'Anonymous'),
    DailyQuote(text: 'Wake up with determination. Go to bed with satisfaction.', author: 'Anonymous'),
    DailyQuote(text: 'Do something today that your future self will thank you for.', author: 'Sean Patrick Flanery'),
    DailyQuote(text: 'Little things make big days.', author: 'Anonymous'),
    DailyQuote(text: 'It\'s going to be hard, but hard does not mean impossible.', author: 'Anonymous'),
    DailyQuote(text: 'Don\'t wait for opportunity. Create it.', author: 'Anonymous'),
    DailyQuote(text: 'Sometimes we\'re tested not to show our weaknesses, but to discover our strengths.', author: 'Anonymous'),
  ];
}
