// ═══════════════════════════════════════════════════════════════════
//  The Quantum One — SaaSLand Interactive Dashboard
//  Live: Open-Meteo · CoinGecko · Reddit · TVMaze · TheMealDB
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const QuantumOneApp());

// ─── Design Tokens ───────────────────────────────────────────────
class K {
  K._();
  static const bg1 = Color(0xFF080B16);
  static const bg2 = Color(0xFF0F1629);

  // Glass
  static const glassBg     = Color(0x0FFFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);

  // Accent palette
  static const purple  = Color(0xFF8B5CF6);
  static const violet  = Color(0xFF7C3AED);
  static const cyan    = Color(0xFF22D3EE);
  static const teal    = Color(0xFF14B8A6);
  static const pink    = Color(0xFFEC4899);
  static const rose    = Color(0xFFF43F5E);
  static const amber   = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const blue    = Color(0xFF3B82F6);
  static const sky     = Color(0xFF38BDF8);
  static const red     = Color(0xFFEF4444);

  // Gradients
  static const gPurple = [Color(0xFF8B5CF6), Color(0xFFEC4899)];
  static const gCyan   = [Color(0xFF06B6D4), Color(0xFF3B82F6)];
  static const gGreen  = [Color(0xFF10B981), Color(0xFF06B6D4)];
  static const gWarm   = [Color(0xFFF59E0B), Color(0xFFF97316)];

  // Text
  static const textW   = Color(0xFFF1F5F9);
  static const textSec = Color(0xFF94A3B8);
  static const textMut = Color(0xFF64748B);

  static const double r = 20;
}

// ─── API Service ─────────────────────────────────────────────────
class Api {
  static final _c = http.Client();

  static Future<Map<String, dynamic>?> weather(double lat, double lng) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m'
        '&hourly=temperature_2m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min,weather_code'
        '&timezone=auto&forecast_days=7',
      ));
      return r.statusCode == 200 ? jsonDecode(r.body) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> crypto() async {
    try {
      final r = await _c.get(Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=bitcoin,ethereum,solana'
        '&vs_currencies=usd&include_24hr_change=true',
      ));
      return r.statusCode == 200 ? jsonDecode(r.body) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<double>> btcChart() async {
    try {
      final r = await _c.get(Uri.parse(
        'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart'
        '?vs_currency=usd&days=7',
      ));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      final prices = data['prices'] as List;
      return prices.map<double>((p) => (p[1] as num).toDouble()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reddit public JSON API — rich news with real thumbnails, no key needed.
  /// Pulls from multiple subreddits for variety.
  static Future<List<Map<String, dynamic>>> news() async {
    const subs = [
      ('worldnews', 'World'),
      ('technology', 'Tech'),
      ('science', 'Science'),
      ('business', 'Business'),
      ('space', 'Space'),
    ];
    try {
      final futs = subs.map((s) => _c.get(
        Uri.parse('https://www.reddit.com/r/${s.$1}/hot.json?limit=6&raw_json=1'),
        headers: {'User-Agent': 'TheQuantumOne/1.0'},
      ));
      final responses = await Future.wait(futs);
      final articles = <Map<String, dynamic>>[];
      for (var i = 0; i < responses.length; i++) {
        if (responses[i].statusCode != 200) continue;
        final body = jsonDecode(responses[i].body);
        final children = body?['data']?['children'] as List? ?? [];
        for (final child in children) {
          final d = child['data'] as Map<String, dynamic>? ?? {};
          // Skip stickied, self-posts without content, and NSFW
          if (d['stickied'] == true || d['over_18'] == true) continue;
          final thumb = d['thumbnail'] as String? ?? '';
          final preview = d['preview']?['images']?[0]?['source']?['url'] as String?;
          final imageUrl = (preview != null && preview.isNotEmpty)
              ? preview
              : (thumb.startsWith('http') ? thumb : null);
          articles.add({
            'title': d['title'] ?? '',
            'url': d['url'] ?? '',
            'thumbnail': imageUrl,
            'score': d['score'] ?? 0,
            'author': d['author'] ?? '',
            'subreddit': d['subreddit'] ?? subs[i].$1,
            'category': subs[i].$2,
            'num_comments': d['num_comments'] ?? 0,
            'created_utc': d['created_utc'] ?? 0,
            'domain': d['domain'] ?? '',
            'selftext': d['selftext'] ?? '',
            'permalink': d['permalink'] ?? '',
          });
        }
      }
      // Deduplicate by URL, sort by score descending, take top 12
      final seen = <String>{};
      articles.removeWhere((a) {
        final url = a['url'] as String;
        if (seen.contains(url)) return true;
        seen.add(url);
        return false;
      });
      articles.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      return articles.take(12).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> shows() async {
    try {
      // Fetch popular/high-rated shows across genres
      final futs = await Future.wait([
        _c.get(Uri.parse('https://api.tvmaze.com/shows?page=0')),
        _c.get(Uri.parse(
          'https://api.tvmaze.com/schedule?date='
          '${DateTime.now().toIso8601String().substring(0, 10)}',
        )),
      ]);
      final popular = <dynamic>[];
      final airing = <dynamic>[];
      if (futs[0].statusCode == 200) {
        final all = jsonDecode(futs[0].body) as List;
        // Sort by rating desc, filter shows with images
        all.sort((a, b) {
          final ra = (a['rating']?['average'] as num?) ?? 0;
          final rb = (b['rating']?['average'] as num?) ?? 0;
          return rb.compareTo(ra);
        });
        for (final s in all) {
          if (s['image'] != null && popular.length < 12) popular.add(s);
        }
      }
      if (futs[1].statusCode == 200) {
        final eps = jsonDecode(futs[1].body) as List;
        final seen = <int>{};
        for (final ep in eps) {
          final show = ep['show'] as Map<String, dynamic>?;
          if (show == null) continue;
          final id = show['id'] as int? ?? 0;
          if (seen.contains(id) || show['image'] == null) continue;
          seen.add(id);
          airing.add({
            'show': show,
            'episode': {
              'name': ep['name'],
              'season': ep['season'],
              'number': ep['number'],
              'airtime': ep['airtime'],
            },
          });
          if (airing.length >= 12) break;
        }
      }
      return [popular, airing];
    } catch (_) {
      return [<dynamic>[], <dynamic>[]];
    }
  }

  static Future<Map<String, dynamic>?> meal() async {
    try {
      final r = await _c.get(
        Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php'),
      );
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body);
      final meals = data['meals'] as List?;
      return meals != null && meals.isNotEmpty ? meals.first : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> quote() async {
    try {
      final r = await _c.get(
        Uri.parse('https://zenquotes.io/api/random'),
      );
      if (r.statusCode != 200) return null;
      final list = jsonDecode(r.body) as List;
      return list.isNotEmpty ? list.first : null;
    } catch (_) {
      return null;
    }
  }

  /// Nominatim geocoding — search for places by name
  static Future<List<Map<String, dynamic>>> geocode(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final r = await _c.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}'
        '&format=json&addressdetails=1&limit=6',
      ), headers: {'User-Agent': 'TheQuantumOne/1.0'});
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// OSRM free routing — returns distance (m), duration (s), route geometry
  static Future<Map<String, dynamic>?> route(
    double fromLat, double fromLng,
    double toLat, double toLng,
  ) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=geojson&steps=true',
      ));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      return routes.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Open Trivia DB — science & nature question
  static Future<Map<String, dynamic>?> scienceQuiz() async {
    try {
      final r = await _c.get(Uri.parse(
        'https://opentdb.com/api.php?amount=1&category=17&type=multiple',
      ));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body);
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return results.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Latest updated shows from TVMaze
  static Future<List<dynamic>> latestShows() async {
    try {
      final r = await _c.get(Uri.parse('https://api.tvmaze.com/schedule'));
      if (r.statusCode != 200) return [];
      final eps = jsonDecode(r.body) as List;
      // Sort by airdate/airtime desc for truly "latest"
      final shows = <dynamic>[];
      final seen = <int>{};
      for (final ep in eps.reversed) {
        final show = ep['show'] as Map<String, dynamic>?;
        if (show == null) continue;
        final id = show['id'] as int? ?? 0;
        if (seen.contains(id) || show['image'] == null) continue;
        seen.add(id);
        shows.add({
          'show': show,
          'episode': {
            'name': ep['name'],
            'season': ep['season'],
            'number': ep['number'],
            'airtime': ep['airtime'],
          },
        });
        if (shows.length >= 12) break;
      }
      return shows;
    } catch (_) {
      return [];
    }
  }

  /// Real-time currency exchange rates (base USD)
  static Future<Map<String, dynamic>?> exchangeRates() async {
    try {
      final r = await _c.get(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (data['result'] != 'success') return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// World Bank economic indicators for a country (ISO3 code)
  static Future<Map<String, dynamic>?> worldBank([String country = 'ZAF']) async {
    const indicators = {
      'gdp': 'NY.GDP.MKTP.CD',
      'population': 'SP.POP.TOTL',
      'unemployment': 'SL.UEM.TOTL.ZS',
      'inflation': 'FP.CPI.TOTL.ZG',
      'co2': 'EN.ATM.CO2E.PC',
      'lifeExpectancy': 'SP.DYN.LE00.IN',
    };
    try {
      final futures = indicators.entries.map((e) => _c.get(Uri.parse(
        'https://api.worldbank.org/v2/country/$country/indicator/${e.value}'
        '?format=json&per_page=10&date=2015:2024',
      )));
      final responses = await Future.wait(futures);
      final result = <String, dynamic>{};
      int i = 0;
      for (final key in indicators.keys) {
        final r = responses.elementAt(i++);
        if (r.statusCode == 200) {
          final body = jsonDecode(r.body);
          if (body is List && body.length == 2) {
            final entries = body[1] as List<dynamic>?;
            if (entries != null) {
              for (final entry in entries) {
                final v = entry['value'];
                if (v != null) {
                  result[key] = (v is num) ? v.toDouble() : v;
                  result['${key}Year'] = entry['date']?.toString() ?? '';
                  break;
                }
              }
            }
          }
        }
      }
      result['countryCode'] = country;
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  /// REST Countries — lightweight list for search/browsing
  static Future<List<Map<String, dynamic>>> restCountriesList() async {
    try {
      final r = await _c.get(Uri.parse(
        'https://restcountries.com/v3.1/all?fields=cca3,name,flags,capital,region,population',
      ));
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List<dynamic>;
      final result = <Map<String, dynamic>>[];
      for (final c in list) {
        if (c is! Map<String, dynamic>) continue;
        result.add({
          'cca3': c['cca3'] ?? '',
          'name': (c['name'] as Map?)?['common'] ?? '',
          'official': (c['name'] as Map?)?['official'] ?? '',
          'flag': (c['flags'] as Map?)?['png'] ?? '',
          'capital': (c['capital'] is List && (c['capital'] as List).isNotEmpty)
              ? (c['capital'] as List).join(', ')
              : '',
          'region': c['region'] ?? '',
          'population': (c['population'] as num?)?.toInt() ?? 0,
        });
      }
      result.sort((a, b) => (b['population'] as int).compareTo(a['population'] as int));
      return result;
    } catch (_) {
      return [];
    }
  }

  /// REST Countries — single country full detail
  static Future<Map<String, dynamic>?> restCountryDetail(String cca3) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://restcountries.com/v3.1/alpha/$cca3'
        '?fields=cca3,name,currencies,languages,flags,borders,capital,'
        'population,region,subregion,area,timezones,continents,car,maps',
      ));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body);
      final c = (body is List ? body.first : body) as Map<String, dynamic>;
      // Flatten key info
      final currencies = <String>[];
      if (c['currencies'] is Map) {
        for (final e in (c['currencies'] as Map).entries) {
          currencies.add('${e.value['name']} (${e.value['symbol'] ?? e.key})');
        }
      }
      final languages = <String>[];
      if (c['languages'] is Map) {
        languages.addAll((c['languages'] as Map).values.cast<String>());
      }
      return {
        'cca3': c['cca3'] ?? cca3,
        'name': (c['name'] as Map?)?['common'] ?? '',
        'official': (c['name'] as Map?)?['official'] ?? '',
        'flag': (c['flags'] as Map?)?['png'] ?? '',
        'flagSvg': (c['flags'] as Map?)?['svg'] ?? '',
        'capital': (c['capital'] is List) ? (c['capital'] as List).join(', ') : '',
        'region': c['region'] ?? '',
        'subregion': c['subregion'] ?? '',
        'population': (c['population'] as num?)?.toInt() ?? 0,
        'area': (c['area'] as num?)?.toDouble() ?? 0,
        'currencies': currencies,
        'languages': languages,
        'borders': (c['borders'] is List) ? List<String>.from(c['borders'] as List) : <String>[],
        'timezones': (c['timezones'] is List) ? List<String>.from(c['timezones'] as List) : <String>[],
        'continents': (c['continents'] is List) ? List<String>.from(c['continents'] as List) : <String>[],
        'drivingSide': (c['car'] as Map?)?['side'] ?? '',
        'googleMaps': (c['maps'] as Map?)?['googleMaps'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Random activity idea (Bored API)
  static Future<Map<String, dynamic>?> boredActivity() async {
    // Try primary mirror, fall back to secondary
    const urls = [
      'https://bored.api.lewagon.com/api/activity',
      'https://www.boredapi.com/api/activity',
    ];
    for (final url in urls) {
      try {
        final r = await _c.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          if (data['activity'] != null) return data;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Sunrise & sunset times for a location
  static Future<Map<String, dynamic>?> sunriseSunset(double lat, double lng) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://api.sunrise-sunset.org/json?lat=$lat&lng=$lng&formatted=0',
      ));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      return data['results'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Random advice (Advice Slip API)
  static Future<String?> adviceSlip() async {
    try {
      final r = await _c.get(
        Uri.parse('https://api.adviceslip.com/advice'),
        headers: {'Accept': 'application/json'},
      );
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return (data['slip'] as Map<String, dynamic>?)?['advice'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Book search (Open Library API)
  static Future<List<Map<String, dynamic>>> openLibrary([String query = 'science']) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://openlibrary.org/search.json?q=$query&limit=8'
        '&fields=title,author_name,first_publish_year,cover_i,'
        'number_of_pages_median,ratings_average,edition_count',
      ));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final docs = data['docs'] as List<dynamic>? ?? [];
      return docs.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Air quality (Open-Meteo Air Quality API — free, no key)
  static Future<Map<String, dynamic>?> airQuality(double lat, double lng) async {
    try {
      final r = await _c.get(Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lng'
        '&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,'
        'sulphur_dioxide,ozone,uv_index,european_aqi,us_aqi'
        '&timezone=auto',
      ));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Draw cards from a fresh shuffled deck (Deck of Cards API)
  static Future<Map<String, dynamic>?> deckOfCards([int count = 5]) async {
    try {
      final s = await _c.get(Uri.parse(
        'https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1',
      ));
      if (s.statusCode != 200) return null;
      final sd = jsonDecode(s.body) as Map<String, dynamic>;
      final deckId = sd['deck_id'] as String?;
      if (deckId == null) return null;
      final d = await _c.get(Uri.parse(
        'https://deckofcardsapi.com/api/deck/$deckId/draw/?count=$count',
      ));
      if (d.statusCode != 200) return null;
      return jsonDecode(d.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Ocean & marine data (Open-Meteo Marine API — free, no key)
  /// Automatically finds nearest coastal point if inland coords return null.
  static Future<Map<String, dynamic>?> oceanMarine(double lat, double lng) async {
    try {
      final result = await _fetchMarine(lat, lng);
      if (result != null) {
        final cur = result['current'] as Map<String, dynamic>?;
        if (cur != null && cur['wave_height'] != null) return result;
      }
      // Inland — try nearby coastal points
      const offsets = [
        [0.0, -0.5], [0.0, 0.5], [-0.5, 0.0], [0.5, 0.0],
        [-0.3, -0.3], [-0.3, 0.3], [0.3, -0.3], [0.3, 0.3],
        [0.0, -1.0], [0.0, 1.0], [-1.0, 0.0], [1.0, 0.0],
      ];
      for (final o in offsets) {
        final r = await _fetchMarine(lat + o[0], lng + o[1]);
        if (r != null) {
          final cur = r['current'] as Map<String, dynamic>?;
          if (cur != null && cur['wave_height'] != null) return r;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchMarine(double lat, double lng) async {
    try {
      // Marine conditions + SST in parallel
      final results = await Future.wait([
        _c.get(Uri.parse(
          'https://marine-api.open-meteo.com/v1/marine'
          '?latitude=$lat&longitude=$lng'
          '&current=wave_height,wave_direction,wave_period,'
          'wind_wave_height,swell_wave_height,swell_wave_direction,'
          'swell_wave_period,ocean_current_velocity,ocean_current_direction'
          '&daily=wave_height_max,wave_period_max'
          '&timezone=auto',
        )),
        _c.get(Uri.parse(
          'https://marine-api.open-meteo.com/v1/marine'
          '?latitude=$lat&longitude=$lng'
          '&hourly=sea_surface_temperature'
          '&forecast_hours=1&timezone=auto',
        )),
      ]);
      if (results[0].statusCode != 200) return null;
      final marine = jsonDecode(results[0].body) as Map<String, dynamic>;
      if (results[1].statusCode == 200) {
        final sst = jsonDecode(results[1].body) as Map<String, dynamic>;
        final temps = (sst['hourly'] as Map<String, dynamic>?)?['sea_surface_temperature'] as List?;
        if (temps != null && temps.isNotEmpty) {
          (marine['current'] as Map<String, dynamic>)['sea_surface_temperature'] = temps[0];
        }
      }
      return marine;
    } catch (_) {
      return null;
    }
  }

  /// ISS real-time position (Where The ISS At API — free, no key)
  static Future<Map<String, dynamic>?> issPosition() async {
    try {
      final r = await _c.get(Uri.parse('https://api.wheretheiss.at/v1/satellites/25544'));
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Near-Earth objects for today (NASA NEO API — DEMO_KEY)
  static Future<Map<String, dynamic>?> nearEarthObjects() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final r = await _c.get(Uri.parse(
        'https://api.nasa.gov/neo/rest/v1/feed'
        '?start_date=$today&end_date=$today&api_key=DEMO_KEY',
      ));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final neos = data['near_earth_objects'] as Map<String, dynamic>? ?? {};
      final todayList = neos[today] as List<dynamic>? ?? [];
      return {'count': data['element_count'] ?? 0, 'objects': todayList};
    } catch (_) {
      return null;
    }
  }

  /// Recently discovered exoplanets (NASA Exoplanet Archive TAP — free)
  static Future<List<Map<String, dynamic>>> exoplanets() async {
    try {
      final r = await _c.get(Uri.parse(
        'https://exoplanetarchive.ipac.caltech.edu/TAP/sync'
        '?query=SELECT+pl_name,hostname,discoverymethod,disc_year,'
        'pl_orbper,pl_rade,pl_bmasse,sy_dist+FROM+ps'
        '+WHERE+default_flag=1+AND+disc_year+IS+NOT+NULL'
        '+ORDER+BY+disc_year+DESC&format=json&maxrec=8',
      ));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Nearby EV charging stations via OpenStreetMap Overpass API.
  static Future<Map<String, dynamic>> evChargers(double lat, double lng) async {
    try {
      // Search in ~30 km radius
      final query = '[out:json][timeout:15];'
          'nwr["amenity"="charging_station"](around:30000,$lat,$lng);'
          'out center 15;';
      final r = await _c.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: 'data=$query',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      if (r.statusCode != 200) return {'stations': <Map<String, dynamic>>[], 'count': 0};
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List<dynamic>?) ?? [];
      final stations = elements.map<Map<String, dynamic>>((e) {
        final el = e as Map<String, dynamic>;
        final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
        // For ways/relations the coordinates come from 'center'
        final cLat = el['lat'] as num? ?? (el['center'] as Map<String, dynamic>?)?['lat'] as num?;
        final cLng = el['lon'] as num? ?? (el['center'] as Map<String, dynamic>?)?['lon'] as num?;
        return {
          'name': tags['name'] ?? tags['operator'] ?? tags['brand'] ?? 'Charging Station',
          'operator': tags['operator'] ?? tags['brand'] ?? '',
          'network': tags['network'] ?? '',
          'capacity': tags['capacity'] ?? '',
          'socket_types': <String>[
            if (tags['socket:type2'] == 'yes') 'Type 2',
            if (tags['socket:type2_combo'] == 'yes') 'CCS',
            if (tags['socket:chademo'] == 'yes') 'CHAdeMO',
            if (tags['socket:type1'] == 'yes') 'Type 1',
            if (tags['socket:schuko'] == 'yes') 'Schuko',
            if (tags['socket:tesla_supercharger'] == 'yes') 'Tesla SC',
          ],
          'fee': tags['fee'] ?? '',
          'opening_hours': tags['opening_hours'] ?? '',
          'lat': cLat?.toDouble(),
          'lng': cLng?.toDouble(),
          'ref_lat': lat,
          'ref_lng': lng,
        };
      }).toList();
      // Sort by distance to search point
      stations.sort((a, b) {
        final dA = _haversine(lat, lng, (a['lat'] as double?) ?? 0, (a['lng'] as double?) ?? 0);
        final dB = _haversine(lat, lng, (b['lat'] as double?) ?? 0, (b['lng'] as double?) ?? 0);
        return dA.compareTo(dB);
      });
      return {'stations': stations, 'count': stations.length};
    } catch (_) {
      return {'stations': <Map<String, dynamic>>[], 'count': 0};
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Trending AI models from Hugging Face Hub (free, no key).
  static Future<Map<String, dynamic>> aiModels() async {
    try {
      // Fetch trending models across key AI categories in parallel
      final categories = ['text-generation', 'text-to-image', 'image-text-to-text', 'object-detection', 'automatic-speech-recognition'];
      final catLabels = {'text-generation': 'Text Gen', 'text-to-image': 'Image Gen', 'image-text-to-text': 'Vision', 'object-detection': 'Detection', 'automatic-speech-recognition': 'Speech'};
      final results = await Future.wait(categories.map((c) =>
        _c.get(Uri.parse('https://huggingface.co/api/models?sort=trendingScore&direction=-1&limit=3&filter=$c')),
      ));
      // Also fetch overall trending
      final trendingResp = await _c.get(Uri.parse('https://huggingface.co/api/models?sort=trendingScore&direction=-1&limit=8'));
      final trending = <Map<String, dynamic>>[];
      if (trendingResp.statusCode == 200) {
        for (final m in jsonDecode(trendingResp.body) as List<dynamic>) {
          final mm = m as Map<String, dynamic>;
          trending.add({
            'id': mm['id'] ?? '',
            'pipeline': mm['pipeline_tag'] ?? '',
            'downloads': mm['downloads'] ?? 0,
            'likes': mm['likes'] ?? 0,
            'trending': mm['trendingScore'] ?? 0,
          });
        }
      }
      final byCategory = <String, List<Map<String, dynamic>>>{};
      for (var i = 0; i < categories.length; i++) {
        if (results[i].statusCode != 200) continue;
        final cat = categories[i];
        final models = <Map<String, dynamic>>[];
        for (final m in jsonDecode(results[i].body) as List<dynamic>) {
          final mm = m as Map<String, dynamic>;
          models.add({
            'id': mm['id'] ?? '',
            'pipeline': mm['pipeline_tag'] ?? '',
            'downloads': mm['downloads'] ?? 0,
            'likes': mm['likes'] ?? 0,
            'trending': mm['trendingScore'] ?? 0,
          });
        }
        byCategory[catLabels[cat] ?? cat] = models;
      }
      return {'trending': trending, 'byCategory': byCategory};
    } catch (_) {
      return {'trending': <Map<String, dynamic>>[], 'byCategory': <String, List<Map<String, dynamic>>>{}};
    }
  }

  /// Trending voice & speech AI models from Hugging Face Hub (free, no key).
  static Future<Map<String, dynamic>> voiceAi() async {
    try {
      final categories = {
        'text-to-speech': '🗣 Text-to-Speech',
        'automatic-speech-recognition': '👂 Speech Recognition',
        'audio-classification': '🔊 Audio Classification',
      };
      final results = await Future.wait(categories.keys.map((c) =>
        _c.get(Uri.parse('https://huggingface.co/api/models?sort=trendingScore&direction=-1&limit=5&filter=$c')),
      ));
      final all = <Map<String, dynamic>>[];
      final byCat = <String, List<Map<String, dynamic>>>{};
      var i = 0;
      for (final cat in categories.keys) {
        final label = categories[cat]!;
        if (results[i].statusCode == 200) {
          final models = <Map<String, dynamic>>[];
          for (final m in jsonDecode(results[i].body) as List<dynamic>) {
            final mm = m as Map<String, dynamic>;
            final entry = {
              'id': mm['id'] ?? '',
              'pipeline': mm['pipeline_tag'] ?? cat,
              'downloads': mm['downloads'] ?? 0,
              'likes': mm['likes'] ?? 0,
              'trending': mm['trendingScore'] ?? 0,
              'created': mm['createdAt'] ?? '',
            };
            models.add(entry);
            all.add(entry);
          }
          byCat[label] = models;
        }
        i++;
      }
      // Sort all by trending score
      all.sort((a, b) => ((b['trending'] as int?) ?? 0).compareTo((a['trending'] as int?) ?? 0));
      return {'all': all, 'byCategory': byCat, 'totalModels': all.length};
    } catch (_) {
      return {'all': <Map<String, dynamic>>[], 'byCategory': <String, List<Map<String, dynamic>>>{}, 'totalModels': 0};
    }
  }
}

// ─── Root App ────────────────────────────────────────────────────
class QuantumOneApp extends StatelessWidget {
  const QuantumOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The Quantum One',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        fontFamilyFallback: const [
          '.AppleSystemUIFont',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ],
        scaffoldBackgroundColor: K.bg1,
        colorScheme: ColorScheme.dark(
          primary: K.purple,
          secondary: K.cyan,
          surface: K.bg2,
          onSurface: K.textW,
        ),
        brightness: Brightness.dark,
      ),
      home: const QuantumDashboardPage(),
    );
  }
}

// ─── Dashboard Page ──────────────────────────────────────────────
class QuantumDashboardPage extends StatefulWidget {
  const QuantumDashboardPage({super.key});
  @override
  State<QuantumDashboardPage> createState() => _DashboardState();
}

class _DashboardState extends State<QuantumDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbCtrl;

  // API data
  Map<String, dynamic>? _weather;
  Map<String, dynamic>? _crypto;
  List<double> _btcChart = [];
  List<Map<String, dynamic>> _news = [];
  List<dynamic> _shows = [];
  List<dynamic> _latestShows = [];
  Map<String, dynamic>? _meal;
  String _quoteText = '';
  String _quoteAuthor = '';
  Map<String, dynamic>? _quiz;
  Map<String, dynamic>? _exchange;
  Map<String, dynamic>? _worldBank;
  List<Map<String, dynamic>> _countriesList = [];
  Map<String, dynamic>? _bored;
  Map<String, dynamic>? _sunriseSunset;
  String? _advice;
  List<Map<String, dynamic>> _books = [];
  Map<String, dynamic>? _airQuality;
  Map<String, dynamic>? _deckCards;
  Map<String, dynamic>? _ocean;
  Map<String, dynamic>? _space;
  Map<String, dynamic>? _ev;
  Map<String, dynamic>? _ai;
  Map<String, dynamic>? _voice;
  bool _loading = true;

  // UI state
  bool _nightMode = false;
  bool _healthDone = false;
  bool _editMode = false;
  bool _doodleBg = false;

  // Widget order — persisted via SharedPreferences
  static const _kWidgetOrder = 'widget_order';
  static const _kDoodleBg = 'doodle_bg';
  static const _defaultOrder = [
    'weather', 'commute', 'stats', 'news', 'shows',
    'crypto', 'exchange', 'worldbank', 'culinary', 'science', 'solar',
    'bored', 'sunrise', 'advice', 'books', 'airquality', 'cards', 'ocean', 'space', 'ev', 'ai', 'voice', 'health', 'quote',
  ];
  List<String> _widgetOrder = List.from(_defaultOrder);

  // Commute state — persisted via SharedPreferences
  double _homeLat = -33.7340, _homeLng = 18.9699;
  double _workLat = -33.9249, _workLng = 18.4241;
  String _homeLabel = 'Paarl';
  String _workLabel = 'Cape Town CBD';
  bool _goingToWork = true;
  Map<String, dynamic>? _commute;
  bool _commuteLoading = false;

  // SharedPreferences keys
  static const _kHomeLat = 'home_lat';
  static const _kHomeLng = 'home_lng';
  static const _kWorkLat = 'work_lat';
  static const _kWorkLng = 'work_lng';
  static const _kHomeLabel = 'home_label';
  static const _kWorkLabel = 'work_label';

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _homeLat = p.getDouble(_kHomeLat) ?? _homeLat;
      _homeLng = p.getDouble(_kHomeLng) ?? _homeLng;
      _workLat = p.getDouble(_kWorkLat) ?? _workLat;
      _workLng = p.getDouble(_kWorkLng) ?? _workLng;
      _homeLabel = p.getString(_kHomeLabel) ?? _homeLabel;
      _workLabel = p.getString(_kWorkLabel) ?? _workLabel;
      final saved = p.getStringList(_kWidgetOrder);
      if (saved != null && saved.length == _defaultOrder.length) {
        _widgetOrder = saved;
      } else if (saved != null) {
        // Migration: add any new widget IDs missing from saved order
        final missing = _defaultOrder.where((id) => !saved.contains(id)).toList();
        _widgetOrder = [...saved, ...missing];
      }
      _doodleBg = p.getBool(_kDoodleBg) ?? false;
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setDouble(_kHomeLat, _homeLat),
      p.setDouble(_kHomeLng, _homeLng),
      p.setDouble(_kWorkLat, _workLat),
      p.setDouble(_kWorkLng, _workLng),
      p.setString(_kHomeLabel, _homeLabel),
      p.setString(_kWorkLabel, _workLabel),
      p.setStringList(_kWidgetOrder, _widgetOrder),
      p.setBool(_kDoodleBg, _doodleBg),
    ]);
  }

  Future<void> _showLocationSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _LocationSettingsDialog(
        homeLat: _homeLat,
        homeLng: _homeLng,
        workLat: _workLat,
        workLng: _workLng,
        homeLabel: _homeLabel,
        workLabel: _workLabel,
        onSave: (hLabel, hLat, hLng, wLabel, wLat, wLng) {
          setState(() {
            _homeLabel = hLabel;
            _homeLat = hLat;
            _homeLng = hLng;
            _workLabel = wLabel;
            _workLat = wLat;
            _workLng = wLng;
          });
        },
      ),
    );

    if (saved == true) {
      await _savePrefs();
      _fetchAll();
    }
  }

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadPrefs().then((_) => _fetchAll());
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      Api.weather(_homeLat, _homeLng),
      Api.crypto(),
      Api.btcChart(),
      Api.news(),
      Api.shows(),
      Api.meal(),
      Api.quote(),
      Api.scienceQuiz(),
      Api.latestShows(),
      Api.exchangeRates(),
      Api.worldBank(),
      Api.restCountriesList(),
      Api.boredActivity(),
      Api.sunriseSunset(_homeLat, _homeLng),
      Api.adviceSlip(),
      Api.openLibrary(),
      Api.airQuality(_homeLat, _homeLng),
      Api.deckOfCards(),
      Api.oceanMarine(_homeLat, _homeLng),
      Api.issPosition(),
      Api.nearEarthObjects(),
      Api.exoplanets(),
      Api.evChargers(_homeLat, _homeLng),
      Api.aiModels(),
      Api.voiceAi(),
    ]);
    if (!mounted) return;
    setState(() {
      _weather = results[0] as Map<String, dynamic>?;
      _crypto = results[1] as Map<String, dynamic>?;
      _btcChart = results[2] as List<double>;
      _news = results[3] as List<Map<String, dynamic>>;
      final showsResult = results[4] as List<dynamic>;
      _shows = showsResult.length == 2 ? showsResult : [<dynamic>[], <dynamic>[]];
      _meal = results[5] as Map<String, dynamic>?;
      final q = results[6] as Map<String, dynamic>?;
      _quoteText = q?['q'] as String? ??
          'The only way to do great work is to love what you do.';
      _quoteAuthor = q?['a'] as String? ?? 'Steve Jobs';
      _quiz = results[7] as Map<String, dynamic>?;
      _latestShows = results[8] as List<dynamic>;
      _exchange = results[9] as Map<String, dynamic>?;
      _worldBank = results[10] as Map<String, dynamic>?;
      _countriesList = results[11] as List<Map<String, dynamic>>;
      _bored = results[12] as Map<String, dynamic>?;
      _sunriseSunset = results[13] as Map<String, dynamic>?;
      _advice = results[14] as String?;
      _books = results[15] as List<Map<String, dynamic>>;
      _airQuality = results[16] as Map<String, dynamic>?;
      _deckCards = results[17] as Map<String, dynamic>?;
      _ocean = results[18] as Map<String, dynamic>?;
      _space = {
        'iss': results[19] as Map<String, dynamic>?,
        'neo': results[20] as Map<String, dynamic>?,
        'exoplanets': results[21] as List<Map<String, dynamic>>,
      };
      _ev = results[22] as Map<String, dynamic>?;
      _ai = results[23] as Map<String, dynamic>?;
      _voice = results[24] as Map<String, dynamic>?;
      _loading = false;
    });
    _fetchCommute();
  }

  // ── Per-widget refresh methods ────────────────────────────────
  Future<void> _refreshWeather() async {
    final r = await Api.weather(_homeLat, _homeLng);
    if (mounted) setState(() => _weather = r);
  }

  Future<void> _refreshNews() async {
    final r = await Api.news();
    if (mounted) setState(() => _news = r);
  }

  Future<void> _refreshShows() async {
    final results = await Future.wait([Api.shows(), Api.latestShows()]);
    if (mounted) {
      setState(() {
        // ignore: unnecessary_cast
        final r = results[0] as List;
        _shows = (r.length == 2) ? r : [<dynamic>[], <dynamic>[]];
        // ignore: unnecessary_cast
        _latestShows = results[1] as List;
      });
    }
  }

  Future<void> _refreshQuiz() async {
    final r = await Api.scienceQuiz();
    if (mounted) setState(() => _quiz = r);
  }

  Future<void> _refreshExchange() async {
    final r = await Api.exchangeRates();
    if (mounted) setState(() => _exchange = r);
  }

  Future<void> _refreshWorldBank() async {
    final country = _worldBank?['countryCode'] as String? ?? 'ZAF';
    final results = await Future.wait([
      Api.worldBank(country),
      if (_countriesList.isEmpty) Api.restCountriesList(),
    ]);
    if (mounted) {
      setState(() {
        _worldBank = results[0] as Map<String, dynamic>?;
        if (results.length > 1) {
          _countriesList = results[1] as List<Map<String, dynamic>>;
        }
      });
    }
  }

  Future<void> _refreshBored() async {
    final r = await Api.boredActivity();
    if (mounted) setState(() => _bored = r);
  }

  Future<void> _refreshSunrise() async {
    final r = await Api.sunriseSunset(_homeLat, _homeLng);
    if (mounted) setState(() => _sunriseSunset = r);
  }

  Future<void> _refreshAdvice() async {
    final r = await Api.adviceSlip();
    if (mounted) setState(() => _advice = r);
  }

  Future<void> _refreshBooks() async {
    final r = await Api.openLibrary();
    if (mounted) setState(() => _books = r);
  }

  Future<void> _refreshAirQuality() async {
    final r = await Api.airQuality(_homeLat, _homeLng);
    if (mounted) setState(() => _airQuality = r);
  }

  Future<void> _refreshCards() async {
    final r = await Api.deckOfCards();
    if (mounted) setState(() => _deckCards = r);
  }

  Future<void> _refreshOcean() async {
    final r = await Api.oceanMarine(_homeLat, _homeLng);
    if (mounted) setState(() => _ocean = r);
  }

  Future<void> _refreshSpace() async {
    final results = await Future.wait([Api.issPosition(), Api.nearEarthObjects(), Api.exoplanets()]);
    if (mounted) {
      setState(() => _space = {
        'iss': results[0] as Map<String, dynamic>?,
        'neo': results[1] as Map<String, dynamic>?,
        'exoplanets': results[2] as List<Map<String, dynamic>>,
      });
    }
  }

  Future<void> _refreshEv() async {
    final r = await Api.evChargers(_homeLat, _homeLng);
    if (mounted) setState(() => _ev = r);
  }

  Future<void> _refreshAi() async {
    final r = await Api.aiModels();
    if (mounted) setState(() => _ai = r);
  }

  Future<void> _refreshVoice() async {
    final r = await Api.voiceAi();
    if (mounted) setState(() => _voice = r);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        doodleBg: _doodleBg,
        onDoodleBgChanged: (v) {
          setState(() => _doodleBg = v);
          _savePrefs();
        },
        nightMode: _nightMode,
        onNightMode: (v) {
          setState(() => _nightMode = v);
          Navigator.pop(context);
        },
        editMode: _editMode,
        onEditMode: () {
          if (_editMode) _savePrefs();
          setState(() => _editMode = !_editMode);
          Navigator.pop(context);
        },
        onRefresh: () {
          Navigator.pop(context);
          _fetchAll();
        },
      ),
    );
  }

  Future<void> _refreshCrypto() async {
    final results = await Future.wait([Api.crypto(), Api.btcChart()]);
    if (mounted) {
      setState(() {
        _crypto = results[0] as Map<String, dynamic>?;
        _btcChart = results[1] as List<double>;
      });
    }
  }

  Future<void> _refreshCulinary() async {
    final r = await Api.meal();
    if (mounted) setState(() => _meal = r);
  }

  Future<void> _refreshQuote() async {
    final q = await Api.quote();
    if (q != null && mounted) {
      setState(() {
        _quoteText = q['q'] ?? _quoteText;
        _quoteAuthor = q['a'] ?? _quoteAuthor;
      });
    }
  }

  Future<void> _fetchCommute() async {
    setState(() => _commuteLoading = true);
    final from = _goingToWork
        ? [_homeLat, _homeLng]
        : [_workLat, _workLng];
    final to = _goingToWork
        ? [_workLat, _workLng]
        : [_homeLat, _homeLng];
    final route = await Api.route(from[0], from[1], to[0], to[1]);
    if (!mounted) return;
    setState(() {
      _commute = route;
      _commuteLoading = false;
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg1,
      body: Stack(
        children: [
          // Animated ambient background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, _) => CustomPaint(
                painter: _OrbPainter(_orbCtrl.value * 2 * math.pi),
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    K.bg1.withValues(alpha: 0.6),
                    K.bg2.withValues(alpha: 0.8),
                    K.bg1,
                  ],
                ),
              ),
            ),
          ),
          // Doodle background
          if (_doodleBg)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.07,
                  child: LayoutBuilder(
                    builder: (_, box) {
                      const tileSize = 90.0;
                      final cols = (box.maxWidth / tileSize).ceil() + 1;
                      final rows = (box.maxHeight / tileSize).ceil() + 1;
                      return Stack(
                        children: List.generate(cols * rows, (i) {
                          final col = i % cols;
                          final row = i ~/ cols;
                          return Positioned(
                            left: col * tileSize + (row.isOdd ? tileSize * 0.5 : 0),
                            top: row * tileSize,
                            child: Transform.rotate(
                              angle: (col + row) * 0.4,
                              child: Image.asset(
                                'assets/icon.png',
                                width: 44,
                                height: 44,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  nightMode: _nightMode,
                  onNightMode: (v) => setState(() => _nightMode = v),
                  onRefresh: _fetchAll,
                  editMode: _editMode,
                  onEditMode: () {
                    if (_editMode) _savePrefs();
                    setState(() => _editMode = !_editMode);
                  },
                  onSettings: _showSettings,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _nightMode
                        ? _NightContent(
                            key: const ValueKey('night'),
                            weather: _weather,
                            quote: _quoteText,
                            quoteAuthor: _quoteAuthor,
                            location: _homeLabel,
                          )
                        : _buildDay(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget-order helpers ──────────────────────────────────────

  static const _widgetLabels = {
    'weather': 'Weather',
    'commute': 'Commute',
    'stats': 'Stats Ribbon',
    'news': 'News',
    'shows': 'Shows',
    'crypto': 'Crypto',
    'exchange': 'Exchange Rates',
    'worldbank': 'Global Data',
    'culinary': 'Culinary',
    'science': 'Science Quiz',
    'solar': 'Solar Fact',
    'bored': 'Activity Idea',
    'sunrise': 'Sun Tracker',
    'advice': 'Advice',
    'books': 'Books',
    'airquality': 'Air Quality',
    'cards': 'Card Draw',
    'ocean': 'Ocean & Marine',
    'space': 'Space & Astronomy',
    'ev': 'EV Chargers',
    'ai': 'AI Models',
    'voice': 'Voice AI',
    'health': 'Health',
    'quote': 'Quote',
  };

  static const _widgetIcons = {
    'weather': Icons.wb_sunny_rounded,
    'commute': Icons.directions_car_rounded,
    'stats': Icons.bar_chart_rounded,
    'news': Icons.newspaper_rounded,
    'shows': Icons.movie_rounded,
    'crypto': Icons.currency_bitcoin_rounded,
    'exchange': Icons.currency_exchange_rounded,
    'worldbank': Icons.public_rounded,
    'culinary': Icons.restaurant_rounded,
    'science': Icons.science_rounded,
    'solar': Icons.public_rounded,
    'bored': Icons.lightbulb_rounded,
    'sunrise': Icons.wb_twilight_rounded,
    'advice': Icons.psychology_rounded,
    'books': Icons.menu_book_rounded,
    'airquality': Icons.air_rounded,
    'cards': Icons.style_rounded,
    'ocean': Icons.waves_rounded,
    'space': Icons.rocket_launch_rounded,
    'ev': Icons.ev_station_rounded,
    'ai': Icons.smart_toy_rounded,
    'voice': Icons.record_voice_over_rounded,
    'health': Icons.favorite_rounded,
    'quote': Icons.format_quote_rounded,
  };

  Widget _buildWidget(String id) {
    switch (id) {
      case 'weather':
        return _WeatherHero(data: _weather, loading: _loading, location: _homeLabel, onRefresh: _refreshWeather);
      case 'commute':
        return _CommuteCard(
          route: _commute,
          loading: _commuteLoading,
          goingToWork: _goingToWork,
          homeLabel: _homeLabel,
          workLabel: _workLabel,
          onToggle: () {
            setState(() => _goingToWork = !_goingToWork);
            _fetchCommute();
          },
          onSettings: _showLocationSettings,
          onRefresh: _fetchCommute,
        );
      case 'stats':
        return _StatsRibbon(crypto: _crypto, newsCount: _news.length, loading: _loading, onRefresh: _refreshCrypto);
      case 'news':
        return _NewsCard(stories: _news, loading: _loading, onRefresh: _refreshNews);
      case 'shows':
        return _ShowsCard(shows: _shows, latestShows: _latestShows, loading: _loading, onRefresh: _refreshShows);
      case 'crypto':
        return _CryptoCard(crypto: _crypto, chart: _btcChart, loading: _loading, onRefresh: _refreshCrypto);
      case 'exchange':
        return _ExchangeCard(data: _exchange, loading: _loading, onRefresh: _refreshExchange);
      case 'worldbank':
        return _GlobalDataCard(
          wbData: _worldBank,
          countries: _countriesList,
          loading: _loading,
          onRefresh: _refreshWorldBank,
          onCountryChanged: (code) async {
            final r = await Api.worldBank(code);
            if (mounted) setState(() => _worldBank = r);
          },
        );
      case 'culinary':
        return _CulinaryCard(meal: _meal, loading: _loading, onRefresh: _refreshCulinary);
      case 'science':
        return _ScienceQuizCard(quiz: _quiz, loading: _loading, onRefresh: _refreshQuiz);
      case 'solar':
        return _SolarFactCard(loading: _loading);
      case 'bored':
        return _BoredCard(data: _bored, loading: _loading, onRefresh: _refreshBored);
      case 'sunrise':
        return _SunriseCard(data: _sunriseSunset, loading: _loading, location: _homeLabel, onRefresh: _refreshSunrise);
      case 'advice':
        return _AdviceCard(advice: _advice, loading: _loading, onRefresh: _refreshAdvice);
      case 'books':
        return _BookCard(books: _books, loading: _loading, onRefresh: _refreshBooks);
      case 'airquality':
        return _AirQualityCard(data: _airQuality, loading: _loading, location: _homeLabel, onRefresh: _refreshAirQuality);
      case 'cards':
        return _DeckOfCardsCard(data: _deckCards, loading: _loading, onRefresh: _refreshCards);
      case 'ocean':
        return _OceanCard(data: _ocean, loading: _loading, location: _homeLabel, onRefresh: _refreshOcean);
      case 'space':
        return _SpaceCard(data: _space, loading: _loading, onRefresh: _refreshSpace);
      case 'ev':
        return _EvChargerCard(data: _ev, loading: _loading, location: _homeLabel, onRefresh: _refreshEv);
      case 'ai':
        return _AiModelsCard(data: _ai, loading: _loading, onRefresh: _refreshAi);
      case 'voice':
        return _VoiceAiCard(data: _voice, loading: _loading, onRefresh: _refreshVoice);
      case 'health':
        return _HealthCard(
          done: _healthDone,
          onToggle: () => setState(() => _healthDone = !_healthDone),
        );
      case 'quote':
        return _FooterQuote(
          text: _quoteText,
          author: _quoteAuthor,
          loading: _loading,
          onRefresh: _refreshQuote,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDay() {
    return LayoutBuilder(
      key: const ValueKey('day'),
      builder: (ctx, box) {
        final wide = box.maxWidth > 900;
        final pad = box.maxWidth < 500 ? 12.0 : 20.0;

        // ── Edit mode — flat single-column ReorderableListView ──
        if (_editMode) {
          return ReorderableListView.builder(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
            buildDefaultDragHandles: false,
            itemCount: _widgetOrder.length,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 0,
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _widgetOrder.removeAt(oldIndex);
                _widgetOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final id = _widgetOrder[index];
              return _EditModeTile(
                key: ValueKey(id),
                index: index,
                label: _widgetLabels[id] ?? id,
                icon: _widgetIcons[id] ?? Icons.widgets_rounded,
              );
            },
          );
        }

        // ── Normal mode — respect _widgetOrder ──────────────────
        // Split IDs into two layout groups for wide mode:
        //   left  = weather, commute, stats, news, shows
        //   right = crypto, culinary, health, quote
        const leftSet  = {'weather', 'commute', 'stats', 'news', 'shows'};
        const rightSet = {'crypto', 'exchange', 'worldbank', 'culinary', 'science', 'solar', 'bored', 'sunrise', 'advice', 'books', 'airquality', 'cards', 'ocean', 'space', 'ev', 'ai', 'voice', 'health', 'quote'};
        final leftIds  = _widgetOrder.where((id) => leftSet.contains(id)).toList();
        final rightIds = _widgetOrder.where((id) => rightSet.contains(id)).toList();

        if (wide) {
          return RefreshIndicator(
            onRefresh: _fetchAll,
            color: K.purple,
            backgroundColor: K.bg2,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
              children: [
                // Full-width widgets first (in order)
                for (final id in _widgetOrder)
                  if (!leftSet.contains(id) && !rightSet.contains(id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _FadeSlide(
                        delay: Duration(milliseconds: _widgetOrder.indexOf(id) * 50),
                        child: _buildWidget(id),
                      ),
                    ),
                // Two-column section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          for (int i = 0; i < leftIds.length; i++) ...[
                            _FadeSlide(
                              delay: Duration(milliseconds: (i + 1) * 100),
                              child: _buildWidget(leftIds[i]),
                            ),
                            if (i < leftIds.length - 1) const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          for (int i = 0; i < rightIds.length; i++) ...[
                            _FadeSlide(
                              delay: Duration(milliseconds: (i + 1) * 100),
                              child: _buildWidget(rightIds[i]),
                            ),
                            if (i < rightIds.length - 1) const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }

        // ── Narrow single-column ────────────────────────────────
        return RefreshIndicator(
          onRefresh: _fetchAll,
          color: K.purple,
          backgroundColor: K.bg2,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
            children: [
              for (int i = 0; i < _widgetOrder.length; i++) ...[
                _FadeSlide(
                  delay: Duration(milliseconds: i * 50),
                  child: _buildWidget(_widgetOrder[i]),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Card Refresh Button ─────────────────────────────────────────
class _CardRefreshBtn extends StatefulWidget {
  const _CardRefreshBtn({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  State<_CardRefreshBtn> createState() => _CardRefreshBtnState();
}

class _CardRefreshBtnState extends State<_CardRefreshBtn> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _tap,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: K.textMut,
                  ),
                )
              : Icon(Icons.refresh_rounded,
                  size: 16, color: K.textMut.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

// ─── Edit-Mode Tile (drag handle + label) ───────────────────────
class _EditModeTile extends StatelessWidget {
  const _EditModeTile({
    super.key,
    required this.index,
    required this.label,
    required this.icon,
  });
  final int index;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(K.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: K.glassBg,
              borderRadius: BorderRadius.circular(K.r),
              border: Border.all(color: K.glassBorder),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    child: Icon(Icons.drag_indicator_rounded,
                        color: K.textMut, size: 20),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(colors: K.gPurple),
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: K.textW,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: K.textMut.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ambient Background Painter ──────────────────────────────────
class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _orb(canvas, Offset(w * 0.15 + math.sin(t * 0.5) * 100, h * 0.2 + math.cos(t * 0.7) * 80), 350, K.violet);
    _orb(canvas, Offset(w * 0.85 + math.cos(t * 0.3) * 120, h * 0.45 + math.sin(t * 0.6) * 60), 280, K.cyan);
    _orb(canvas, Offset(w * 0.5 + math.sin(t * 0.4) * 80, h * 0.85 + math.cos(t * 0.5) * 100), 240, K.pink);
    _orb(canvas, Offset(w * 0.7 + math.cos(t * 0.6) * 60, h * 0.1 + math.sin(t * 0.8) * 50), 200, K.blue);
  }

  void _orb(Canvas c, Offset o, double r, Color col) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [col.withValues(alpha: 0.12), col.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}

// ─── Glass Card ──────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(K.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
            borderRadius: BorderRadius.circular(K.r),
            border: Border.all(color: K.glassBorder),
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }
    return card;
  }
}

// ─── Gradient Text ───────────────────────────────────────────────
class _GradText extends StatelessWidget {
  const _GradText(this.text, {required this.style, required this.colors});
  final String text;
  final TextStyle style;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) =>
          LinearGradient(colors: colors).createShader(b),
      child: Text(text, style: style),
    );
  }
}

// ─── Fade-Slide Entrance ─────────────────────────────────────────
class _FadeSlide extends StatefulWidget {
  const _FadeSlide({required this.delay, required this.child});
  final Duration delay;
  final Widget child;
  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.nightMode,
    required this.onNightMode,
    required this.onRefresh,
    required this.editMode,
    required this.onEditMode,
    required this.onSettings,
  });
  final bool nightMode;
  final ValueChanged<bool> onNightMode;
  final VoidCallback onRefresh;
  final bool editMode;
  final VoidCallback onEditMode;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final compact = box.maxWidth < 520;
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                // App icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                // Title + date
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'The Quantum One',
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: K.textMut.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('9 MARCH 2026',
                            style:
                                TextStyle(fontSize: 10, color: K.textMut)),
                      ],
                    ],
                  ),
                ),
                // Settings
                _miniBtn(Icons.settings_rounded, onSettings),
                const SizedBox(width: 6),
                // Edit layout
                _miniBtn(
                  editMode
                      ? Icons.check_rounded
                      : Icons.dashboard_customize_rounded,
                  onEditMode,
                  highlight: editMode,
                ),
                const SizedBox(width: 6),
                // Refresh
                _miniBtn(Icons.refresh_rounded, onRefresh),
                const SizedBox(width: 6),
                // Night mode toggle
                _miniBtn(
                  nightMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  () => onNightMode(!nightMode),
                ),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    nightMode ? 'Day' : 'Night',
                    style: const TextStyle(fontSize: 10, color: K.textMut),
                  ),
                ],
                const SizedBox(width: 8),
                // Avatar
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        K.purple.withValues(alpha: 0.3),
                        K.cyan.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: K.purple.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text('Q1',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          color: K.purple,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _miniBtn(IconData ic, VoidCallback onTap, {bool highlight = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: highlight
                ? K.purple.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: highlight
                  ? K.purple.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(ic,
              color: highlight ? K.purple : K.textMut, size: 14),
        ),
      ),
    );
  }
}

// ─── Weather Hero ────────────────────────────────────────────────
class _WeatherHero extends StatelessWidget {
  const _WeatherHero({required this.data, required this.loading, required this.location, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final String location;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = data?['current'];
    final temp = current != null
        ? (current['temperature_2m'] as num).round()
        : 22;
    final code = current != null
        ? (current['weather_code'] as num).toInt()
        : 0;
    final wind = current != null
        ? (current['wind_speed_10m'] as num).round()
        : 12;
    final humidity = current != null
        ? (current['relative_humidity_2m'] as num).round()
        : 38;

    return GlassCard(
      onTap: () => _showWeatherSheet(context),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          K.blue.withValues(alpha: 0.2),
          K.purple.withValues(alpha: 0.1),
          K.cyan.withValues(alpha: 0.05),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_wIcon(code), color: K.amber, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: K.textSec, size: 14),
                        const SizedBox(width: 4),
                        Text(location,
                            style: TextStyle(
                                color: K.textSec, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w200,
                        color: K.textW,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _CardRefreshBtn(onRefresh: onRefresh),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: K.purple,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Condition row
          Wrap(
            spacing: 16,
            children: [
              _chip(Icons.cloud_outlined, _wDesc(code)),
              _chip(Icons.air_rounded, '$wind km/h'),
              _chip(Icons.water_drop_outlined, '$humidity%'),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          // Hourly forecast
          SizedBox(
            height: 80,
            child: _buildHourly(),
          ),
        ],
      ),
    );
  }

  Widget _buildHourly() {
    final hourly = data?['hourly'];
    if (hourly == null) {
      // Fallback hourly
      return ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(8, (i) {
          final h = 14 + i;
          return _hourlyItem('${h > 12 ? h - 12 : h} ${h >= 12 ? "PM" : "AM"}',
              Icons.wb_sunny_rounded, '${22 + (i % 3) - 1}°');
        }),
      );
    }
    final times = hourly['time'] as List;
    final temps = hourly['temperature_2m'] as List;
    final codes = hourly['weather_code'] as List;
    // Find current hour index
    final currentTime = data!['current']['time'] as String;
    int startIdx = 0;
    for (int i = 0; i < times.length; i++) {
      if (times[i] == currentTime) {
        startIdx = i;
        break;
      }
    }
    final count = math.min(12, times.length - startIdx);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: count,
      itemBuilder: (_, i) {
        final idx = startIdx + i;
        final t = times[idx] as String;
        final hour = int.tryParse(t.substring(11, 13)) ?? 0;
        final label = i == 0
            ? 'Now'
            : '${hour > 12 ? hour - 12 : hour} ${hour >= 12 ? "PM" : "AM"}';
        final temp = (temps[idx] as num).round();
        final c = (codes[idx] as num).toInt();
        return _hourlyItem(label, _wIcon(c), '$temp°');
      },
    );
  }

  Widget _hourlyItem(String label, IconData icon, String temp) {
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(label,
              style: const TextStyle(color: K.textMut, fontSize: 10)),
          Icon(icon, color: K.amber, size: 18),
          Text(temp,
              style: const TextStyle(
                  color: K.textW, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: K.textMut, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: K.textSec, fontSize: 13)),
      ],
    );
  }

  void _showWeatherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WeatherSheet(data: data, location: location),
    );
  }
}

// ─── Location Settings Dialog (search-based) ────────────────────
class _LocationSettingsDialog extends StatefulWidget {
  const _LocationSettingsDialog({
    required this.homeLat,
    required this.homeLng,
    required this.workLat,
    required this.workLng,
    required this.homeLabel,
    required this.workLabel,
    required this.onSave,
  });
  final double homeLat, homeLng, workLat, workLng;
  final String homeLabel, workLabel;
  final void Function(String hLabel, double hLat, double hLng,
      String wLabel, double wLat, double wLng) onSave;

  @override
  State<_LocationSettingsDialog> createState() =>
      _LocationSettingsDialogState();
}

class _LocationSettingsDialogState extends State<_LocationSettingsDialog> {
  late String _hLabel, _wLabel;
  late double _hLat, _hLng, _wLat, _wLng;
  String? _editingField; // 'home' or 'work'
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _hLabel = widget.homeLabel;
    _hLat = widget.homeLat;
    _hLng = widget.homeLng;
    _wLabel = widget.workLabel;
    _wLat = widget.workLat;
    _wLng = widget.workLng;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.trim().length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await Api.geocode(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    });
  }

  void _selectResult(Map<String, dynamic> place) {
    final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0;
    final lng = double.tryParse(place['lon']?.toString() ?? '') ?? 0;
    final display = place['display_name'] as String? ?? '';
    // Use the city/town/village or first part of display name as short label
    final addr = place['address'] as Map<String, dynamic>? ?? {};
    final short = addr['city'] as String? ??
        addr['town'] as String? ??
        addr['village'] as String? ??
        addr['suburb'] as String? ??
        addr['county'] as String? ??
        display.split(',').first;

    setState(() {
      if (_editingField == 'home') {
        _hLabel = short;
        _hLat = lat;
        _hLng = lng;
      } else {
        _wLabel = short;
        _wLat = lat;
        _wLng = lng;
      }
      _editingField = null;
      _searchCtrl.clear();
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _editingField != null;

    return AlertDialog(
      backgroundColor: K.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          if (isSearching)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _editingField = null;
                  _searchCtrl.clear();
                  _results = [];
                }),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_back_rounded,
                      color: K.textSec, size: 20),
                ),
              ),
            ),
          Icon(
            isSearching
                ? Icons.search_rounded
                : Icons.edit_location_alt_rounded,
            color: K.cyan,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSearching
                  ? 'Search ${_editingField == "home" ? "Home" : "Work"} Address'
                  : 'Edit Locations',
              style: const TextStyle(
                  color: K.textW,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: isSearching ? _buildSearch() : _buildOverview(),
      ),
      actions: isSearching
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('Cancel', style: TextStyle(color: K.textMut)),
              ),
              FilledButton.icon(
                onPressed: () {
                  widget.onSave(
                      _hLabel, _hLat, _hLng, _wLabel, _wLat, _wLng);
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save'),
                style: FilledButton.styleFrom(backgroundColor: K.teal),
              ),
            ],
    );
  }

  Widget _buildOverview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _locationTile(
          'HOME',
          _hLabel,
          '${_hLat.toStringAsFixed(4)}, ${_hLng.toStringAsFixed(4)}',
          Icons.home_rounded,
          K.teal,
          () => setState(() {
            _editingField = 'home';
            _searchCtrl.clear();
            _results = [];
          }),
        ),
        const SizedBox(height: 12),
        _locationTile(
          'WORK',
          _wLabel,
          '${_wLat.toStringAsFixed(4)}, ${_wLng.toStringAsFixed(4)}',
          Icons.business_rounded,
          K.purple,
          () => setState(() {
            _editingField = 'work';
            _searchCtrl.clear();
            _results = [];
          }),
        ),
      ],
    );
  }

  Widget _locationTile(String tag, String label, String coords,
      IconData icon, Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tag,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: const TextStyle(
                            color: K.textW,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(coords,
                        style: const TextStyle(
                            color: K.textMut, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.search_rounded, color: K.textMut, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: K.textW, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Type an address or place name\u2026',
            hintStyle: const TextStyle(color: K.textMut, fontSize: 13),
            prefixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: K.cyan)),
                  )
                : const Icon(Icons.location_searching_rounded,
                    size: 18, color: K.textSec),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: K.cyan),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: _results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _searchCtrl.text.length < 2
                        ? 'Start typing to search\u2026'
                        : _searching
                            ? 'Searching\u2026'
                            : 'No results found',
                    style:
                        const TextStyle(color: K.textMut, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                  itemBuilder: (_, i) {
                    final place = _results[i];
                    final display =
                        place['display_name'] as String? ?? '';
                    final type = place['type'] as String? ?? '';
                    final addr =
                        place['address'] as Map<String, dynamic>? ?? {};
                    final country =
                        addr['country'] as String? ?? '';

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: K.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.place_rounded,
                              color: K.cyan, size: 16),
                        ),
                        title: Text(
                          display.split(',').first,
                          style: const TextStyle(
                              color: K.textW,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$type${country.isNotEmpty ? " \u00b7 $country" : ""}',
                          style: const TextStyle(
                              color: K.textMut, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: K.textMut),
                        onTap: () => _selectResult(place),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Stats Ribbon ────────────────────────────────────────────────
class _StatsRibbon extends StatelessWidget {
  const _StatsRibbon({
    required this.crypto,
    required this.newsCount,
    required this.loading,
    required this.onRefresh,
  });
  final Map<String, dynamic>? crypto;
  final int newsCount;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final btc = crypto?['bitcoin'];
    final eth = crypto?['ethereum'];
    final sol = crypto?['solana'];

    String fmtPrice(dynamic data, String fallback) {
      if (data == null) return fallback;
      final p = (data['usd'] as num).toDouble();
      if (p >= 1000) return '\$${(p / 1000).toStringAsFixed(1)}k';
      return '\$${p.toStringAsFixed(2)}';
    }

    String fmtChange(dynamic data) {
      if (data == null) return '0%';
      final c = (data['usd_24h_change'] as num).toDouble();
      final sign = c >= 0 ? '+' : '';
      return '$sign${c.toStringAsFixed(1)}%';
    }

    Color changeColor(dynamic data) {
      if (data == null) return K.textMut;
      return (data['usd_24h_change'] as num) >= 0 ? K.emerald : K.rose;
    }

    final tiles = [
      _StatTileData(Icons.currency_bitcoin, K.gWarm, 'Bitcoin',
          fmtPrice(btc, '\$68.1k'), fmtChange(btc), changeColor(btc)),
      _StatTileData(Icons.diamond_outlined, K.gCyan, 'Ethereum',
          fmtPrice(eth, '\$3.8k'), fmtChange(eth), changeColor(eth)),
      _StatTileData(Icons.bolt_rounded, K.gPurple, 'Solana',
          fmtPrice(sol, '\$142'), fmtChange(sol), changeColor(sol)),
      _StatTileData(Icons.newspaper_rounded, K.gGreen, 'Live Feed',
          '$newsCount stories', 'Reddit', K.emerald),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Market Overview',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: K.textMut)),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, box) {
      if (box.maxWidth < 500) {
        return Column(
          children: tiles
              .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildTile(t),
                  ))
              .toList(),
        );
      }
      if (box.maxWidth < 900) {
        return Column(
          children: [
            Row(children: [
              Expanded(child: _buildTile(tiles[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildTile(tiles[1])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildTile(tiles[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildTile(tiles[3])),
            ]),
          ],
        );
      }
      return Row(
        children: tiles
            .asMap()
            .entries
            .map((e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: e.key > 0 ? 14 : 0),
                    child: _buildTile(e.value),
                  ),
                ))
            .toList(),
      );
    }),
      ],
    );
  }

  Widget _buildTile(_StatTileData d) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: d.gradColors),
            ),
            child: Icon(d.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style:
                        const TextStyle(fontSize: 11, color: K.textMut)),
                const SizedBox(height: 2),
                Text(d.value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: K.textW,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: d.badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(d.badge,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: d.badgeColor)),
          ),
        ],
      ),
    );
  }
}

class _StatTileData {
  const _StatTileData(
      this.icon, this.gradColors, this.label, this.value, this.badge, this.badgeColor);
  final IconData icon;
  final List<Color> gradColors;
  final String label, value, badge;
  final Color badgeColor;
}

// ─── News Card (Hacker News) ─────────────────────────────────────
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.stories, required this.loading, required this.onRefresh});
  final List<Map<String, dynamic>> stories;
  final bool loading;
  final Future<void> Function() onRefresh;

  static const _categoryColors = <String, Color>{
    'World': K.rose,
    'Tech': K.cyan,
    'Science': K.emerald,
    'Business': K.amber,
    'Space': K.purple,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: K.gWarm),
                ),
                child: const Icon(Icons.newspaper_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global News Feed',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('World · Tech · Science · Business · Space',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: onRefresh),
              const SizedBox(width: 4),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: K.amber,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: K.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: K.emerald,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Live',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: K.emerald)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Hero story (first article, large thumbnail) ──
          if (stories.isNotEmpty) _heroStory(context, stories.first),

          if (stories.isEmpty && !loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Could not load news',
                    style: TextStyle(color: K.textMut)),
              ),
            )
          else ...[
            if (stories.length > 1) const SizedBox(height: 12),
            // ── Remaining stories ──
            ...stories.skip(1).take(7).map((s) => _storyRow(context, s)),
          ],
        ],
      ),
    );
  }

  /// Large featured card for the top story
  Widget _heroStory(BuildContext ctx, Map<String, dynamic> s) {
    final title = s['title'] as String? ?? 'Untitled';
    final thumb = s['thumbnail'] as String?;
    final category = s['category'] as String? ?? '';
    final domain = s['domain'] as String? ?? '';
    final score = s['score'] as int? ?? 0;
    final comments = s['num_comments'] as int? ?? 0;
    final catColor = _categoryColors[category] ?? K.blue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showNewsDetail(ctx, s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: thumb != null
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholderImage(catColor),
                      )
                    : _placeholderImage(catColor),
              ),
            ),
            const SizedBox(height: 10),
            // Category + domain
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(category,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(domain,
                      style: const TextStyle(fontSize: 11, color: K.textMut),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Title
            Text(title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: K.textW,
                    height: 1.4)),
            const SizedBox(height: 6),
            // Score + comments
            Row(
              children: [
                Icon(Icons.arrow_upward_rounded, size: 13, color: K.amber),
                const SizedBox(width: 3),
                Text(_formatScore(score),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: K.amber)),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline_rounded, size: 12, color: K.textMut),
                const SizedBox(width: 3),
                Text('$comments',
                    style: const TextStyle(fontSize: 11, color: K.textMut)),
                const Spacer(),
                Text(_timeAgo(((s['created_utc'] as num?) ?? 0).toInt()),
                    style: const TextStyle(fontSize: 11, color: K.textMut)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(color: K.glassBorder, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _storyRow(BuildContext ctx, Map<String, dynamic> s) {
    final title = s['title'] as String? ?? 'Untitled';
    final score = s['score'] as int? ?? 0;
    final thumb = s['thumbnail'] as String?;
    final domain = s['domain'] as String? ?? '';
    final category = s['category'] as String? ?? '';
    final comments = s['num_comments'] as int? ?? 0;
    final catColor = _categoryColors[category] ?? K.blue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showNewsDetail(ctx, s),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: thumb != null
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderThumb(catColor),
                        )
                      : _placeholderThumb(catColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(category,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: catColor)),
                    ),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: K.textW,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(domain,
                            style: const TextStyle(
                                fontSize: 10, color: K.textMut)),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_upward_rounded,
                            size: 11, color: K.amber),
                        Text(_formatScore(score),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: K.amber)),
                        const SizedBox(width: 6),
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 10, color: K.textMut),
                        Text(' $comments',
                            style: const TextStyle(
                                fontSize: 10, color: K.textMut)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage(Color color) {
    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(Icons.public_rounded, size: 40, color: color.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _placeholderThumb(Color color) {
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(Icons.public_rounded, size: 22, color: color.withValues(alpha: 0.5)),
      ),
    );
  }

  static String _formatScore(int score) {
    if (score >= 10000) return '${(score / 1000).toStringAsFixed(1)}k';
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
    return '$score';
  }

  void _showNewsDetail(BuildContext ctx, Map<String, dynamic> s) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NewsDetailSheet(story: s),
    );
  }
}

// ─── Shows Card (TVMaze) ─────────────────────────────────────────
class _ShowsCard extends StatefulWidget {
  const _ShowsCard({required this.shows, required this.latestShows, required this.loading, required this.onRefresh});
  final List<dynamic> shows;
  final List<dynamic> latestShows;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_ShowsCard> createState() => _ShowsCardState();
}

class _ShowsCardState extends State<_ShowsCard> {
  int _tab = 0; // 0 = Top Rated, 1 = Latest, 2 = Airing Today

  List<dynamic> get _popular =>
      widget.shows.isNotEmpty ? widget.shows[0] as List<dynamic> : [];
  List<dynamic> get _airing =>
      widget.shows.length > 1 ? widget.shows[1] as List<dynamic> : [];
  List<dynamic> get _latest => widget.latestShows;
  List<dynamic> get _activeList {
    switch (_tab) {
      case 1: return _latest;
      case 2: return _airing;
      default: return _popular;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: K.gPurple),
                ),
                child: const Icon(Icons.live_tv_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Movies & Series',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('Powered by TVMaze',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: widget.onRefresh),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: K.pink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Tabs
          Row(
            children: [
              _tabChip(0, 'Top Rated', Icons.star_rounded),
              const SizedBox(width: 8),
              _tabChip(1, 'Latest', Icons.new_releases_rounded),
              const SizedBox(width: 8),
              _tabChip(2, 'Airing Today', Icons.schedule_rounded),
            ],
          ),
          const SizedBox(height: 14),
          // Show grid
          SizedBox(
            height: 240,
            child: _activeList.isEmpty && !widget.loading
                ? const Center(
                    child: Text('Could not load shows',
                        style: TextStyle(color: K.textMut)))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: ListView.builder(
                      key: ValueKey(_tab),
                      scrollDirection: Axis.horizontal,
                      itemCount: _activeList.length,
                      itemBuilder: (_, i) {
                        final item = _activeList[i];
                        Map<String, dynamic> show;
                        Map<String, dynamic>? episode;
                        if ((_tab == 1 || _tab == 2) && item is Map<String, dynamic> && item.containsKey('show')) {
                          show = item['show'] as Map<String, dynamic>;
                          episode = item['episode'] as Map<String, dynamic>?;
                        } else {
                          show = item as Map<String, dynamic>;
                        }
                        return _showPoster(context, show, episode: (_tab == 1 || _tab == 2) ? episode : null);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label, IconData icon) {
    final active = _tab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? K.purple.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? K.purple.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? K.purple : K.textMut),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? K.textW : K.textMut)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showPoster(BuildContext ctx, Map<String, dynamic> show,
      {Map<String, dynamic>? episode}) {
    final name = show['name'] as String? ?? 'Unknown';
    final img = show['image'] as Map<String, dynamic>?;
    final imageUrl = img?['medium'] as String?;
    final rating = show['rating'] as Map<String, dynamic>?;
    final avg = rating?['average'];
    final genres = (show['genres'] as List?)?.take(2).join(' · ') ?? '';
    final status = show['status'] as String? ?? '';
    final network = show['network'] as Map<String, dynamic>?;
    final netName = network?['name'] as String? ?? '';
    final premiered = show['premiered'] as String? ?? '';
    final year = premiered.length >= 4 ? premiered.substring(0, 4) : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showShowDetail(ctx, show),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: K.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _posterFallback(),
                )
              else
                _posterFallback(),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Top badges
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    if (avg != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: K.amber, size: 12),
                            const SizedBox(width: 3),
                            Text('$avg',
                                style: const TextStyle(
                                    color: K.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (status == 'Running')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: K.emerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: K.emerald.withValues(alpha: 0.4)),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(
                                color: K.emerald,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                  ],
                ),
              ),
              // Episode airing badge
              if (episode != null)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: K.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: K.cyan.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'S${episode['season']}E${episode['number']}',
                        style: const TextStyle(
                            color: K.cyan,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              // Bottom info
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (year.isNotEmpty) ...[
                          Text(year,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500)),
                          if (genres.isNotEmpty || netName.isNotEmpty)
                            Text(' · ',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 10)),
                        ],
                        Expanded(
                          child: Text(
                            netName.isNotEmpty ? netName : genres,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    if (genres.isNotEmpty && netName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(genres,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 9)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            K.purple.withValues(alpha: 0.3),
            K.pink.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: const Icon(Icons.movie_rounded,
          color: Colors.white24, size: 40),
    );
  }

  void _showShowDetail(BuildContext ctx, Map<String, dynamic> show) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShowDetailSheet(show: show),
    );
  }
}

// ─── Crypto Card ─────────────────────────────────────────────────
class _CryptoCard extends StatelessWidget {
  const _CryptoCard({
    required this.crypto,
    required this.chart,
    required this.loading,
    required this.onRefresh,
  });
  final Map<String, dynamic>? crypto;
  final List<double> chart;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: K.gWarm),
                ),
                child: const Icon(Icons.candlestick_chart_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Crypto Markets',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('CoinGecko live data',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: onRefresh),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.amber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // BTC Sparkline
          if (chart.isNotEmpty) ...[
            SizedBox(
              height: 60,
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _SparklinePainter(
                  values: chart,
                  color: chart.last >= chart.first ? K.emerald : K.rose,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _cryptoRow('BTC', Icons.currency_bitcoin, 'bitcoin', K.amber),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
          _cryptoRow('ETH', Icons.diamond_outlined, 'ethereum', K.cyan),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
          _cryptoRow('SOL', Icons.bolt_rounded, 'solana', K.purple),
        ],
      ),
    );
  }

  Widget _cryptoRow(String label, IconData icon, String key, Color color) {
    final data = crypto?[key];
    final price = data != null
        ? (data['usd'] as num).toDouble()
        : 0.0;
    final change = data != null
        ? (data['usd_24h_change'] as num).toDouble()
        : 0.0;
    final priceStr = price >= 1000
        ? '\$${(price / 1000).toStringAsFixed(1)}k'
        : '\$${price.toStringAsFixed(2)}';
    final sign = change >= 0 ? '+' : '';
    final changeColor = change >= 0 ? K.emerald : K.rose;

    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: K.textW, fontWeight: FontWeight.w600, fontSize: 14)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(priceStr,
                style: const TextStyle(
                    color: K.textW,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Text('$sign${change.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: changeColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ─── Exchange Rates Card ─────────────────────────────────────────
class _ExchangeCard extends StatefulWidget {
  const _ExchangeCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends State<_ExchangeCard> {
  // Track which base currency to display from
  int _baseIndex = 0;
  bool _reversed = false; // false = 1 BASE = X foreign, true = X foreign = 1 BASE
  static const _bases = ['USD', 'EUR', 'GBP', 'JPY', 'ZAR'];
  static const _baseFlags = ['🇺🇸', '🇪🇺', '🇬🇧', '🇯🇵', '🇿🇦'];

  // Top currencies to display per base
  static const _displayCurrencies = [
    'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'ZAR', 'BRL',
    'KRW', 'MXN', 'SGD', 'NZD', 'SEK', 'HKD', 'NOK', 'TRY', 'PLN', 'THB',
  ];

  static const _currencyFlags = {
    'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧', 'JPY': '🇯🇵', 'CAD': '🇨🇦',
    'AUD': '🇦🇺', 'CHF': '🇨🇭', 'CNY': '🇨🇳', 'INR': '🇮🇳', 'ZAR': '🇿🇦',
    'BRL': '🇧🇷', 'KRW': '🇰🇷', 'MXN': '🇲🇽', 'SGD': '🇸🇬', 'NZD': '🇳🇿',
    'SEK': '🇸🇪', 'HKD': '🇭🇰', 'NOK': '🇳🇴', 'TRY': '🇹🇷', 'PLN': '🇵🇱',
    'THB': '🇹🇭',
  };

  static const _currencyNames = {
    'USD': 'US Dollar', 'EUR': 'Euro', 'GBP': 'British Pound',
    'JPY': 'Japanese Yen', 'CAD': 'Canadian Dollar', 'AUD': 'Australian Dollar',
    'CHF': 'Swiss Franc', 'CNY': 'Chinese Yuan', 'INR': 'Indian Rupee',
    'ZAR': 'South African Rand', 'BRL': 'Brazilian Real', 'KRW': 'South Korean Won',
    'MXN': 'Mexican Peso', 'SGD': 'Singapore Dollar', 'NZD': 'New Zealand Dollar',
    'SEK': 'Swedish Krona', 'HKD': 'Hong Kong Dollar', 'NOK': 'Norwegian Krone',
    'TRY': 'Turkish Lira', 'PLN': 'Polish Zloty', 'THB': 'Thai Baht',
  };

  Map<String, double> _getRatesForBase() {
    final rates = widget.data?['rates'] as Map<String, dynamic>?;
    if (rates == null) return {};
    final base = _bases[_baseIndex];
    final baseRate = (rates[base] as num?)?.toDouble() ?? 1.0;
    final result = <String, double>{};
    for (final c in _displayCurrencies) {
      if (c == base) continue;
      final r = (rates[c] as num?)?.toDouble();
      if (r != null) result[c] = r / baseRate;
    }
    return result;
  }

  String _formatRate(double rate) {
    if (rate >= 1000) return rate.toStringAsFixed(0);
    if (rate >= 100) return rate.toStringAsFixed(1);
    if (rate >= 1) return rate.toStringAsFixed(3);
    return rate.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final converted = _getRatesForBase();
    final base = _bases[_baseIndex];
    final baseFlag = _baseFlags[_baseIndex];

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: K.gWarm),
                ),
                child: const Icon(Icons.currency_exchange_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exchange Rates',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('Real-time currency data',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: widget.onRefresh),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.amber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Base selector
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _bases.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == _baseIndex;
                return GestureDetector(
                  onTap: () => setState(() => _baseIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: selected
                          ? K.amber.withAlpha(30)
                          : Colors.white.withAlpha(8),
                      border: Border.all(
                        color: selected
                            ? K.amber.withAlpha(80)
                            : Colors.white.withAlpha(15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_baseFlags[i], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          _bases[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? K.amber : K.textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Base display with swap toggle
          GestureDetector(
            onTap: () => setState(() => _reversed = !_reversed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [K.amber.withAlpha(15), K.amber.withAlpha(6)],
                ),
                border: Border.all(color: K.amber.withAlpha(25)),
              ),
              child: Row(
                children: [
                  Text(baseFlag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _reversed ? 'How much for 1 $base' : '1 $base equals',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: K.amber,
                          ),
                        ),
                        Text(
                          _reversed
                              ? 'Showing foreign → $base'
                              : 'Showing $base → foreign',
                          style: const TextStyle(fontSize: 10, color: K.textMut),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _reversed ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: K.amber.withAlpha(25),
                        border: Border.all(color: K.amber.withAlpha(50)),
                      ),
                      child: const Icon(Icons.swap_vert_rounded,
                          size: 16, color: K.amber),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Rate list
          if (converted.isEmpty && !widget.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Could not load rates',
                    style: TextStyle(color: K.textMut)),
              ),
            )
          else
            ...converted.entries.take(10).map((e) {
              final flag = _currencyFlags[e.key] ?? '💱';
              final name = _currencyNames[e.key] ?? e.key;
              final rate = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: K.textW)),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 10, color: K.textMut)),
                        ],
                      ),
                    ),
                    if (_reversed)
                      // e.g. "R16.49 = $1"
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: K.textW,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          children: [
                            TextSpan(text: _formatRate(rate)),
                            TextSpan(
                              text: ' = 1 $base',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: K.textMut,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // e.g. "16.49"
                      Text(
                        _formatRate(rate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: K.textW,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Global Data Card (World Bank + REST Countries) ──────────────
class _GlobalDataCard extends StatefulWidget {
  const _GlobalDataCard({
    required this.wbData,
    required this.countries,
    required this.loading,
    required this.onRefresh,
    required this.onCountryChanged,
  });
  final Map<String, dynamic>? wbData;
  final List<Map<String, dynamic>> countries;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String code) onCountryChanged;

  @override
  State<_GlobalDataCard> createState() => _GlobalDataCardState();
}

class _GlobalDataCardState extends State<_GlobalDataCard> {
  String _selectedCode = 'ZAF';
  bool _switching = false;

  // Top 5 pinned countries (always shown)
  static const _pinnedCodes = ['ZAF', 'USA', 'GBR', 'CHN', 'IND'];

  List<Map<String, dynamic>> get _pinnedCountries {
    if (widget.countries.isEmpty) return [];
    return _pinnedCodes
        .map((c) => widget.countries.firstWhere(
              (e) => e['cca3'] == c,
              orElse: () => <String, dynamic>{},
            ))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _selectCountry(String code) async {
    if (code == _selectedCode || _switching) return;
    setState(() {
      _selectedCode = code;
      _switching = true;
    });
    await widget.onCountryChanged(code);
    if (mounted) setState(() => _switching = false);
  }

  void _showCountrySearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountrySearchSheet(
        countries: widget.countries,
        selectedCode: _selectedCode,
        onSelect: (code) {
          Navigator.pop(context);
          _selectCountry(code);
        },
      ),
    );
  }

  void _showCountryDetail() {
    final wb = widget.wbData;
    if (wb == null) return;
    // Find the country from list for flag image
    final country = widget.countries.firstWhere(
      (e) => e['cca3'] == _selectedCode,
      orElse: () => <String, dynamic>{},
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountryDetailSheet(
        code: _selectedCode,
        wbData: wb,
        countrySummary: country,
      ),
    );
  }

  String _fmtBig(double v) {
    if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _fmtPop(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.wbData;
    final pinned = _pinnedCountries;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                ),
                child: const Icon(Icons.public_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Data',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('World Bank · REST Countries',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: widget.onRefresh),
              if (widget.loading || _switching)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.blue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Top 5 pinned countries + search ──
          SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pinned.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = pinned[i];
                      final code = c['cca3'] as String;
                      final flag = c['flag'] as String? ?? '';
                      final sel = code == _selectedCode;
                      return GestureDetector(
                        onTap: () => _selectCountry(code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                            color: sel
                                ? K.blue.withAlpha(30)
                                : Colors.white.withAlpha(8),
                            border: Border.all(
                              color: sel
                                  ? K.blue.withAlpha(80)
                                  : Colors.white.withAlpha(15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (flag.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.network(flag,
                                      width: 22, height: 15, fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(width: 22, height: 15)),
                                )
                              else
                                const SizedBox(width: 22, height: 15),
                              const SizedBox(width: 6),
                              Text(code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? K.blue : K.textSec,
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Search button
                GestureDetector(
                  onTap: _showCountrySearch,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      color: Colors.white.withAlpha(8),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: K.textSec, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Data area ──
          if (d != null) ...[
            // ── Country banner — tap to see full info ──
            GestureDetector(
              onTap: _showCountryDetail,
              child: _countryBanner(d),
            ),
            const SizedBox(height: 14),

            // ── Key indicators ──
            _indicatorTile(
              icon: Icons.account_balance_rounded,
              label: 'GDP',
              value: d['gdp'] != null ? _fmtBig(d['gdp'] as double) : '—',
              year: d['gdpYear'] as String? ?? '',
              gradient: const [Color(0xFF10B981), Color(0xFF059669)],
            ),
            const SizedBox(height: 8),
            _indicatorTile(
              icon: Icons.groups_rounded,
              label: 'Population',
              value: d['population'] != null
                  ? _fmtPop(d['population'] as double)
                  : '—',
              year: d['populationYear'] as String? ?? '',
              gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _indicatorMini(
                    icon: Icons.work_off_rounded,
                    label: 'Unemployment',
                    value: d['unemployment'] != null
                        ? '${(d['unemployment'] as double).toStringAsFixed(1)}%'
                        : '—',
                    year: d['unemploymentYear'] as String? ?? '',
                    color: K.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _indicatorMini(
                    icon: Icons.trending_up_rounded,
                    label: 'Inflation',
                    value: d['inflation'] != null
                        ? '${(d['inflation'] as double).toStringAsFixed(1)}%'
                        : '—',
                    year: d['inflationYear'] as String? ?? '',
                    color: K.rose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _indicatorMini(
                    icon: Icons.cloud_rounded,
                    label: 'CO\u2082/capita',
                    value: d['co2'] != null
                        ? '${(d['co2'] as double).toStringAsFixed(1)}t'
                        : '—',
                    year: d['co2Year'] as String? ?? '',
                    color: K.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _indicatorMini(
                    icon: Icons.health_and_safety_rounded,
                    label: 'Life Expectancy',
                    value: d['lifeExpectancy'] != null
                        ? '${(d['lifeExpectancy'] as double).toStringAsFixed(1)}y'
                        : '—',
                    year: d['lifeExpectancyYear'] as String? ?? '',
                    color: K.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tap-to-detail hint
            Center(
              child: GestureDetector(
                onTap: _showCountryDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: K.blue.withAlpha(15),
                    border: Border.all(color: K.blue.withAlpha(30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: K.blue),
                      SizedBox(width: 6),
                      Text('Tap for full country profile',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: K.blue)),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 40),
            const Center(
              child: Text('No data available',
                  style: TextStyle(color: K.textMut, fontSize: 13)),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _countryBanner(Map<String, dynamic> d) {
    final country = widget.countries.firstWhere(
      (e) => e['cca3'] == _selectedCode,
      orElse: () => <String, dynamic>{},
    );
    final flagUrl = country['flag'] as String? ?? '';
    final name = country['name'] as String? ??
        d['countryCode'] as String? ??
        _selectedCode;
    final region = country['region'] as String? ?? '';
    final capital = country['capital'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withAlpha(20),
            const Color(0xFF8B5CF6).withAlpha(15),
          ],
        ),
        border: Border.all(color: K.blue.withAlpha(30)),
      ),
      child: Row(
        children: [
          if (flagUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(flagUrl,
                  width: 44, height: 30, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.flag_rounded, size: 30, color: K.textMut)),
            )
          else
            const Icon(Icons.flag_rounded, size: 30, color: K.textMut),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: K.textW)),
                if (region.isNotEmpty || capital.isNotEmpty)
                  Text(
                    [if (region.isNotEmpty) region, if (capital.isNotEmpty) 'Capital: $capital']
                        .join('  •  '),
                    style: const TextStyle(fontSize: 11, color: K.textMut),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: K.textMut, size: 20),
        ],
      ),
    );
  }

  Widget _indicatorTile({
    required IconData icon,
    required String label,
    required String value,
    required String year,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [gradient[0].withAlpha(18), gradient[1].withAlpha(10)],
        ),
        border: Border.all(color: gradient[0].withAlpha(35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: gradient),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: K.textMut)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: gradient[0])),
              ],
            ),
          ),
          if (year.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withAlpha(8),
              ),
              child: Text(year,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: K.textMut)),
            ),
        ],
      ),
    );
  }

  Widget _indicatorMini({
    required IconData icon,
    required String label,
    required String value,
    required String year,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withAlpha(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: K.textMut),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color)),
          if (year.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(year,
                  style: const TextStyle(fontSize: 9, color: K.textMut)),
            ),
        ],
      ),
    );
  }
}

// ─── Country Search Sheet ────────────────────────────────────────
class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({
    required this.countries,
    required this.selectedCode,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> countries;
  final String selectedCode;
  final void Function(String code) onSelect;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  String _query = '';

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.countries.take(30).toList();
    final q = _query.toLowerCase();
    return widget.countries
        .where((c) =>
            (c['name'] as String).toLowerCase().contains(q) ||
            (c['cca3'] as String).toLowerCase().contains(q) ||
            (c['capital'] as String).toLowerCase().contains(q) ||
            (c['region'] as String).toLowerCase().contains(q))
        .take(40)
        .toList();
  }

  String _fmtPop(int v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: K.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Search Countries',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: K.textW)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: K.textW, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by name, code, capital, region...',
                hintStyle: const TextStyle(color: K.textMut, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: K.textMut),
                filled: true,
                fillColor: Colors.white.withAlpha(8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withAlpha(15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: K.blue.withAlpha(80)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${widget.countries.length} countries available',
              style: const TextStyle(fontSize: 11, color: K.textMut),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final code = c['cca3'] as String;
                final sel = code == widget.selectedCode;
                return GestureDetector(
                  onTap: () => widget.onSelect(code),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: sel
                          ? K.blue.withAlpha(20)
                          : Colors.white.withAlpha(5),
                      border: sel
                          ? Border.all(color: K.blue.withAlpha(60))
                          : null,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            c['flag'] as String? ?? '',
                            width: 32,
                            height: 22,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 32, height: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['name'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel ? K.blue : K.textW,
                                  )),
                              Text(
                                '$code  •  ${c['region']}  •  Pop: ${_fmtPop(c['population'] as int)}',
                                style: const TextStyle(
                                    fontSize: 11, color: K.textMut),
                              ),
                            ],
                          ),
                        ),
                        if (sel)
                          const Icon(Icons.check_circle_rounded,
                              color: K.blue, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Country Detail Sheet ────────────────────────────────────────
class _CountryDetailSheet extends StatefulWidget {
  const _CountryDetailSheet({
    required this.code,
    required this.wbData,
    required this.countrySummary,
  });
  final String code;
  final Map<String, dynamic> wbData;
  final Map<String, dynamic> countrySummary;

  @override
  State<_CountryDetailSheet> createState() => _CountryDetailSheetState();
}

class _CountryDetailSheetState extends State<_CountryDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final d = await Api.restCountryDetail(widget.code);
    if (mounted) setState(() { _detail = d; _loading = false; });
  }

  String _fmtBig(double v) {
    if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _fmtPop(num v) {
    final d = v.toDouble();
    if (d >= 1e9) return '${(d / 1e9).toStringAsFixed(2)}B';
    if (d >= 1e6) return '${(d / 1e6).toStringAsFixed(1)}M';
    if (d >= 1e3) return '${(d / 1e3).toStringAsFixed(0)}K';
    return v.toString();
  }

  String _fmtArea(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M km\u00B2';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K km\u00B2';
    return '${v.toStringAsFixed(0)} km\u00B2';
  }

  @override
  Widget build(BuildContext context) {
    final wb = widget.wbData;
    final cs = widget.countrySummary;
    final flagUrl = cs['flag'] as String? ?? '';
    final name = cs['name'] as String? ?? widget.code;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: K.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // ── Flag + Name header ──
          if (flagUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(flagUrl,
                  width: 80, height: 54, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: K.textW)),
          if (_detail != null && (_detail!['official'] as String).isNotEmpty)
            Text(_detail!['official'] as String,
                style: const TextStyle(fontSize: 12, color: K.textMut),
                textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.blue))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // ── Economic Indicators (World Bank) ──
                      _sectionTitle('Economic Indicators', Icons.analytics_rounded),
                      const SizedBox(height: 8),
                      _detailRow('GDP', wb['gdp'] != null
                          ? '${_fmtBig(wb['gdp'] as double)}  (${wb['gdpYear']})'
                          : '—'),
                      _detailRow('Population (WB)', wb['population'] != null
                          ? '${_fmtPop(wb['population'] as double)}  (${wb['populationYear']})'
                          : '—'),
                      _detailRow('Unemployment', wb['unemployment'] != null
                          ? '${(wb['unemployment'] as double).toStringAsFixed(1)}%  (${wb['unemploymentYear']})'
                          : '—'),
                      _detailRow('Inflation', wb['inflation'] != null
                          ? '${(wb['inflation'] as double).toStringAsFixed(1)}%  (${wb['inflationYear']})'
                          : '—'),
                      _detailRow('CO\u2082 per capita', wb['co2'] != null
                          ? '${(wb['co2'] as double).toStringAsFixed(1)} tonnes  (${wb['co2Year']})'
                          : '—'),
                      _detailRow('Life Expectancy', wb['lifeExpectancy'] != null
                          ? '${(wb['lifeExpectancy'] as double).toStringAsFixed(1)} years  (${wb['lifeExpectancyYear']})'
                          : '—'),

                      if (_detail != null) ...[
                        const SizedBox(height: 20),
                        // ── Country Info (REST Countries) ──
                        _sectionTitle('Country Information', Icons.info_outline_rounded),
                        const SizedBox(height: 8),
                        _detailRow('Region', '${_detail!['region']}  •  ${_detail!['subregion']}'),
                        _detailRow('Capital', _detail!['capital'] as String),
                        _detailRow('Population', _fmtPop(_detail!['population'] as int)),
                        _detailRow('Area', _fmtArea(_detail!['area'] as double)),
                        _detailRow('Continent(s)',
                            (_detail!['continents'] as List).join(', ')),
                        _detailRow('Timezone(s)',
                            (_detail!['timezones'] as List).join(', ')),
                        _detailRow('Driving Side',
                            (_detail!['drivingSide'] as String).isNotEmpty
                                ? '${(_detail!['drivingSide'] as String)[0].toUpperCase()}${(_detail!['drivingSide'] as String).substring(1)}'
                                : '—'),

                        const SizedBox(height: 20),
                        _sectionTitle('Currencies', Icons.attach_money_rounded),
                        const SizedBox(height: 8),
                        ...(_detail!['currencies'] as List).map((c) =>
                            _detailRow('', c as String)),

                        const SizedBox(height: 20),
                        _sectionTitle('Languages', Icons.translate_rounded),
                        const SizedBox(height: 8),
                        _detailRow('', (_detail!['languages'] as List).join(', ')),

                        if ((_detail!['borders'] as List).isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _sectionTitle('Borders', Icons.map_rounded),
                          const SizedBox(height: 8),
                          _detailRow('', (_detail!['borders'] as List).join(', ')),
                        ],
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: K.blue, size: 16),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: K.blue)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: K.textMut)),
            ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: K.textW)),
          ),
        ],
      ),
    );
  }
}

// ─── Culinary Card (TheMealDB) ───────────────────────────────────
class _CulinaryCard extends StatelessWidget {
  const _CulinaryCard({required this.meal, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? meal;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = meal?['strMeal'] as String? ?? 'Today\'s Recipe';
    final category = meal?['strCategory'] as String? ?? 'Loading...';
    final area = meal?['strArea'] as String? ?? '';
    final thumb = meal?['strMealThumb'] as String?;

    return GlassCard(
      onTap: meal != null ? () => _showMealDetail(context) : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          if (thumb != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(K.r)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                              color: K.amber.withValues(alpha: 0.1),
                              child: const Icon(Icons.restaurant,
                                  color: K.amber, size: 40),
                            )),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              K.bg1.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: K.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category,
                                style: const TextStyle(
                                    color: K.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (area.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: K.cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(area,
                                  style: const TextStyle(
                                      color: K.cyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_outlined,
                        color: K.amber, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Culinary Blueprint',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: K.textW)),
                    ),
                    _CardRefreshBtn(onRefresh: onRefresh),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: K.amber),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: K.textSec, fontSize: 13, height: 1.4)),
                if (meal != null) ...[
                  const SizedBox(height: 8),
                  Text('Tap for full recipe →',
                      style: TextStyle(
                          color: K.purple.withValues(alpha: 0.8),
                          fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMealDetail(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MealDetailSheet(meal: meal!),
    );
  }
}

// ─── Commute Card (Waze-style) ───────────────────────────────────
class _CommuteCard extends StatelessWidget {
  const _CommuteCard({
    required this.route,
    required this.loading,
    required this.goingToWork,
    required this.onToggle,
    required this.homeLabel,
    required this.workLabel,
    required this.onSettings,
    required this.onRefresh,
  });
  final Map<String, dynamic>? route;
  final bool loading;
  final bool goingToWork;
  final VoidCallback onToggle;
  final String homeLabel;
  final String workLabel;
  final VoidCallback onSettings;
  final Future<void> Function() onRefresh;

  static const _wazeTeal = Color(0xFF33CCFF);
  static const _wazeBlue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    // Parse route data
    final duration = route?['duration'] as num? ?? 0;
    final distance = route?['distance'] as num? ?? 0;
    final mins = (duration / 60).round();
    final km = (distance / 1000).toStringAsFixed(1);

    // Steps summary
    final legs = route?['legs'] as List?;
    final steps = <Map<String, dynamic>>[];
    if (legs != null && legs.isNotEmpty) {
      final legSteps = legs.first['steps'] as List? ?? [];
      for (final s in legSteps.take(5)) {
        steps.add(s as Map<String, dynamic>);
      }
    }

    final dest = goingToWork ? 'Work' : 'Home';
    final destIcon = goingToWork
        ? Icons.business_rounded
        : Icons.home_rounded;

    return GlassCard(
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _wazeBlue.withValues(alpha: 0.12),
          _wazeTeal.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [_wazeBlue, _wazeTeal],
                    ),
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commute',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: K.textW)),
                      Text(
                        '$homeLabel → ${goingToWork ? workLabel : homeLabel}',
                        style: const TextStyle(
                            fontSize: 10, color: K.textMut),
                      ),
                    ],
                  ),
                ),
                // Toggle Home / Work
                _toggleButton(destIcon, dest),
                _CardRefreshBtn(onRefresh: onRefresh),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onSettings,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.settings_rounded,
                          size: 16, color: K.textMut),
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _wazeTeal),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Big ETA section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ETA
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            mins > 0 ? '$mins' : '--',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w200,
                              color: K.textW,
                              height: 1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6, left: 4),
                            child: Text('min',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: K.textSec,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _etaArrival(mins),
                        style: const TextStyle(
                            fontSize: 11, color: K.textMut),
                      ),
                    ],
                  ),
                ),
                // Traffic badge + distance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _trafficBadge(mins),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten_rounded,
                            size: 12, color: K.textMut),
                        const SizedBox(width: 4),
                        Text('$km km',
                            style: const TextStyle(
                                fontSize: 12,
                                color: K.textSec,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Route visual bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _routeBar(steps, mins),
          ),
          const SizedBox(height: 10),
          // Turn-by-turn steps
          if (steps.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: steps.length,
                itemBuilder: (_, i) => _stepChip(steps[i], i),
              ),
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _toggleButton(IconData icon, String label) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _wazeTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _wazeTeal.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: _wazeTeal),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _wazeTeal)),
              const SizedBox(width: 3),
              Icon(Icons.swap_horiz_rounded,
                  size: 12, color: _wazeTeal.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trafficBadge(int mins) {
    Color color;
    String label;
    if (mins < 35) {
      color = K.emerald;
      label = 'Light traffic';
    } else if (mins < 55) {
      color = K.amber;
      label = 'Moderate';
    } else {
      color = K.rose;
      label = 'Heavy traffic';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _routeBar(List<Map<String, dynamic>> steps, int totalMins) {
    if (steps.isEmpty) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: Colors.white.withValues(alpha: 0.06),
        ),
      );
    }
    // Segment the bar by step durations
    final total = steps.fold<double>(
        0, (sum, s) => sum + ((s['duration'] as num?) ?? 1).toDouble());
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: steps.asMap().entries.map((e) {
            final dur = ((e.value['duration'] as num?) ?? 1).toDouble();
            final frac = dur / (total == 0 ? 1 : total);
            // Color by segment speed
            final dist = ((e.value['distance'] as num?) ?? 0).toDouble();
            final speed = dur > 0 ? (dist / dur) * 3.6 : 0; // km/h
            Color c;
            if (speed > 80) {
              c = K.emerald;
            } else if (speed > 40) {
              c = const Color(0xFF33CCFF);
            } else if (speed > 20) {
              c = K.amber;
            } else {
              c = K.rose;
            }
            return Expanded(
              flex: (frac * 100).round().clamp(1, 100),
              child: Container(
                margin: EdgeInsets.only(left: e.key > 0 ? 1 : 0),
                color: c,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _stepChip(Map<String, dynamic> step, int index) {
    final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
    final modifier = maneuver['modifier'] as String? ?? '';
    final type = maneuver['type'] as String? ?? 'depart';
    final name = step['name'] as String? ?? '';
    final dist = ((step['distance'] as num?) ?? 0).toDouble();
    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} km'
        : '${dist.round()} m';

    IconData icon;
    if (type == 'depart') {
      icon = Icons.trip_origin_rounded;
    } else if (type == 'arrive') {
      icon = Icons.flag_rounded;
    } else if (modifier.contains('left')) {
      icon = Icons.turn_left_rounded;
    } else if (modifier.contains('right')) {
      icon = Icons.turn_right_rounded;
    } else if (type == 'roundabout' || type == 'rotary') {
      icon = Icons.roundabout_left_rounded;
    } else if (type == 'merge' || type == 'on ramp') {
      icon = Icons.merge_rounded;
    } else {
      icon = Icons.arrow_upward_rounded;
    }

    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: _wazeTeal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(distLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        color: K.textSec,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            name.isNotEmpty ? name : type.replaceAll(' ', '\n'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: K.textMut),
          ),
        ],
      ),
    );
  }

  String _etaArrival(int mins) {
    if (mins <= 0) return 'Calculating...';
    final now = DateTime.now().add(Duration(minutes: mins));
    final h = now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return 'Arrive by $h12:$m $period';
  }
}

// ─── Science Quiz Card ───────────────────────────────────────────
class _ScienceQuizCard extends StatefulWidget {
  const _ScienceQuizCard({
    required this.quiz,
    required this.loading,
    required this.onRefresh,
  });
  final Map<String, dynamic>? quiz;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_ScienceQuizCard> createState() => _ScienceQuizCardState();
}

class _ScienceQuizCardState extends State<_ScienceQuizCard> {
  int? _selected;
  bool _revealed = false;
  List<String> _shuffled = [];
  String _correctAnswer = '';

  @override
  void didUpdateWidget(covariant _ScienceQuizCard old) {
    super.didUpdateWidget(old);
    if (widget.quiz != old.quiz) {
      _selected = null;
      _revealed = false;
      _prepareAnswers();
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareAnswers();
  }

  static String _decodeHtml(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»');
  }

  void _prepareAnswers() {
    final q = widget.quiz;
    if (q == null) {
      _shuffled = [];
      _correctAnswer = '';
      return;
    }
    _correctAnswer = _decodeHtml(q['correct_answer'] as String? ?? '');
    final incorrect = (q['incorrect_answers'] as List?)
            ?.map((e) => _decodeHtml(e as String))
            .toList() ??
        [];
    _shuffled = [...incorrect, _correctAnswer]..shuffle();
  }

  void _onTap(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final question = q != null
        ? _decodeHtml(q['question'] as String? ?? 'Loading…')
        : 'Loading…';
    final difficulty = q != null ? (q['difficulty'] as String? ?? '') : '';

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: K.gCyan),
                ),
                child: const Icon(Icons.science_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Science Quiz',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('Open Trivia DB',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: () async {
                setState(() {
                  _selected = null;
                  _revealed = false;
                });
                await widget.onRefresh();
              }),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: K.cyan,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Difficulty badge
          if (difficulty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: difficulty == 'easy'
                      ? K.emerald.withAlpha(40)
                      : difficulty == 'medium'
                          ? K.amber.withAlpha(40)
                          : K.rose.withAlpha(40),
                ),
                child: Text(
                  difficulty[0].toUpperCase() + difficulty.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: difficulty == 'easy'
                        ? K.emerald
                        : difficulty == 'medium'
                            ? K.amber
                            : K.rose,
                  ),
                ),
              ),
            ),
          // Question
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: K.textW,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Answers
          ...List.generate(_shuffled.length, (i) {
            final answer = _shuffled[i];
            final isCorrect = answer == _correctAnswer;
            final isSelected = _selected == i;
            Color bg = Colors.white.withAlpha(8);
            Color border = Colors.white.withAlpha(20);
            Color textColor = K.textW;
            if (_revealed) {
              if (isCorrect) {
                bg = K.emerald.withAlpha(30);
                border = K.emerald.withAlpha(80);
                textColor = K.emerald;
              } else if (isSelected && !isCorrect) {
                bg = K.rose.withAlpha(30);
                border = K.rose.withAlpha(80);
                textColor = K.rose;
              }
            } else if (isSelected) {
              bg = K.cyan.withAlpha(20);
              border = K.cyan.withAlpha(60);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _revealed && isCorrect
                              ? K.emerald.withAlpha(50)
                              : _revealed && isSelected
                                  ? K.rose.withAlpha(50)
                                  : Colors.white.withAlpha(12),
                        ),
                        child: Center(
                          child: _revealed && isCorrect
                              ? const Icon(Icons.check_rounded,
                                  size: 15, color: K.emerald)
                              : _revealed && isSelected && !isCorrect
                                  ? const Icon(Icons.close_rounded,
                                      size: 15, color: K.rose)
                                  : Text(
                                      String.fromCharCode(65 + i), // A, B, C, D
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: K.textSec),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(answer,
                            style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                                fontWeight: _revealed && isCorrect
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Result message
          if (_revealed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _selected != null && _shuffled[_selected!] == _correctAnswer
                    ? '🎉 Correct! Well done.'
                    : '❌ Wrong — the answer is: $_correctAnswer',
                style: TextStyle(
                  fontSize: 13,
                  color: _selected != null &&
                          _shuffled[_selected!] == _correctAnswer
                      ? K.emerald
                      : K.rose,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Voice AI Card ───────────────────────────────────────────────
class _VoiceAiCard extends StatefulWidget {
  const _VoiceAiCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_VoiceAiCard> createState() => _VoiceAiCardState();
}

class _VoiceAiCardState extends State<_VoiceAiCard> {
  int _tabIdx = 0;

  @override
  Widget build(BuildContext context) {
    final byCat = (widget.data?['byCategory'] as Map<String, dynamic>?) ?? {};
    final catKeys = byCat.keys.toList();
    final tabNames = ['🔥 Top', ...catKeys];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [K.pink, K.rose]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice AI',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Trending voice & speech models',
                      style: TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: widget.onRefresh),
          ]),
          const SizedBox(height: 12),

          // Tabs
          if (tabNames.length > 1)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(tabNames.length, (i) {
                    final sel = _tabIdx == i;
                    return GestureDetector(
                      onTap: () => setState(() => _tabIdx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? LinearGradient(colors: [K.pink.withValues(alpha: 0.3), K.rose.withValues(alpha: 0.15)])
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tabNames[i],
                            style: TextStyle(
                              color: sel ? K.textW : K.textSec,
                              fontSize: 11,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                            )),
                      ),
                    );
                  }),
                ),
              ),
            ),
          const SizedBox(height: 14),

          // Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _buildContent(catKeys),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<String> catKeys) {
    if (widget.loading && widget.data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(strokeWidth: 2, color: K.pink),
        ),
      );
    }

    List<dynamic> models;
    if (_tabIdx == 0) {
      models = (widget.data?['all'] as List<dynamic>?) ?? [];
    } else {
      final catKey = catKeys[_tabIdx - 1];
      models = (widget.data?['byCategory'] as Map<String, dynamic>?)?[catKey] as List<dynamic>? ?? [];
    }

    if (models.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.record_voice_over_rounded, color: K.textSec.withValues(alpha: 0.4), size: 36),
              const SizedBox(height: 8),
              const Text('No voice models available', style: TextStyle(color: K.textSec, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: models.take(6).map<Widget>((m) => _modelTile(m as Map<String, dynamic>)).toList(),
    );
  }

  Widget _modelTile(Map<String, dynamic> m) {
    final id = m['id'] as String? ?? '';
    final pipeline = m['pipeline'] as String? ?? '';
    final downloads = m['downloads'] as int? ?? 0;
    final likes = m['likes'] as int? ?? 0;
    final trending = m['trending'] as int? ?? 0;

    final parts = id.split('/');
    final author = parts.length > 1 ? parts[0] : '';
    final modelName = parts.length > 1 ? parts[1] : id;

    // Pipeline color + icon
    Color pipeColor;
    IconData pipeIcon;
    String pipeLabel;
    switch (pipeline) {
      case 'text-to-speech':
        pipeColor = K.pink;
        pipeIcon = Icons.campaign_rounded;
        pipeLabel = 'TTS';
        break;
      case 'automatic-speech-recognition':
        pipeColor = K.cyan;
        pipeIcon = Icons.hearing_rounded;
        pipeLabel = 'ASR';
        break;
      case 'audio-classification':
        pipeColor = K.amber;
        pipeIcon = Icons.graphic_eq_rounded;
        pipeLabel = 'Audio Class';
        break;
      case 'voice-activity-detection':
        pipeColor = K.emerald;
        pipeIcon = Icons.mic_rounded;
        pipeLabel = 'VAD';
        break;
      case 'audio-to-audio':
        pipeColor = K.violet;
        pipeIcon = Icons.transform_rounded;
        pipeLabel = 'Audio→Audio';
        break;
      default:
        pipeColor = K.sky;
        pipeIcon = Icons.music_note_rounded;
        pipeLabel = pipeline.replaceAll('-', ' ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: K.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: pipeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(pipeIcon, color: pipeColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(modelName,
                          style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (author.isNotEmpty)
                        Text(author,
                            style: const TextStyle(color: K.textSec, fontSize: 11)),
                    ],
                  ),
                ),
                if (trending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: K.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('🔥 $trending',
                        style: const TextStyle(color: K.rose, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                _chip(pipeLabel, pipeColor),
                _chip('⬇ ${_fmtNum(downloads)}', K.sky),
                _chip('❤️ ${_fmtNum(likes)}', K.rose),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── AI Models Card (Hugging Face Trending) ──────────────────────
class _AiModelsCard extends StatefulWidget {
  const _AiModelsCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_AiModelsCard> createState() => _AiModelsCardState();
}

class _AiModelsCardState extends State<_AiModelsCard> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _catNames = <String>[];

  @override
  void initState() {
    super.initState();
    final cats = (widget.data?['byCategory'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    _catNames.addAll(cats);
    _tab = TabController(length: 1 + _catNames.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _AiModelsCard old) {
    super.didUpdateWidget(old);
    if (widget.data != old.data) _rebuildTabs();
  }

  void _rebuildTabs() {
    final cats = (widget.data?['byCategory'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    final newLen = 1 + cats.length;
    if (cats.length != _catNames.length || cats.join() != _catNames.join()) {
      _catNames
        ..clear()
        ..addAll(cats);
      final oldIndex = _tab.index.clamp(0, newLen - 1);
      _tab.dispose();
      _tab = TabController(length: newLen, vsync: this, initialIndex: oldIndex);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure tab controller length is correct
    final tabLen = 1 + _catNames.length;
    if (_tab.length != tabLen) {
      _tab.dispose();
      _tab = TabController(length: tabLen.clamp(1, 99), vsync: this);
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [K.violet, K.pink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Models',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Trending on Hugging Face',
                      style: TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: widget.onRefresh),
          ]),
          const SizedBox(height: 12),

          // Tabs
          if (tabLen > 1)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                onTap: (_) => setState(() {}),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: [K.violet.withValues(alpha: 0.3), K.pink.withValues(alpha: 0.2)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                labelColor: K.textW,
                unselectedLabelColor: K.textSec,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: '🔥 Trending', height: 34),
                  ..._catNames.map((c) => Tab(text: c, height: 34)),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.loading && widget.data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(strokeWidth: 2, color: K.violet),
        ),
      );
    }

    if (_tab.index == 0) {
      return _buildTrending();
    } else {
      final idx = _tab.index - 1;
      if (idx >= _catNames.length) return const SizedBox.shrink();
      final catModels = (widget.data?['byCategory'] as Map<String, dynamic>?)?[_catNames[idx]];
      return _buildModelList(catModels as List<dynamic>? ?? []);
    }
  }

  Widget _buildTrending() {
    final trending = (widget.data?['trending'] as List<dynamic>?) ?? [];
    if (trending.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.smart_toy_rounded, color: K.textSec.withValues(alpha: 0.5), size: 36),
              const SizedBox(height: 8),
              const Text('No model data available', style: TextStyle(color: K.textSec, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: trending.take(6).map<Widget>((m) => _modelTile(m as Map<String, dynamic>)).toList(),
    );
  }

  Widget _buildModelList(List<dynamic> models) {
    if (models.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No models found', style: TextStyle(color: K.textSec, fontSize: 13))),
      );
    }
    return Column(
      children: models.take(5).map<Widget>((m) => _modelTile(m as Map<String, dynamic>)).toList(),
    );
  }

  Widget _modelTile(Map<String, dynamic> m) {
    final id = m['id'] as String? ?? '';
    final pipeline = m['pipeline'] as String? ?? '';
    final downloads = m['downloads'] as int? ?? 0;
    final likes = m['likes'] as int? ?? 0;
    final trending = m['trending'] as int? ?? 0;

    // Parse author/model name
    final parts = id.split('/');
    final author = parts.length > 1 ? parts[0] : '';
    final modelName = parts.length > 1 ? parts[1] : id;

    // Pipeline color coding
    Color pipeColor;
    IconData pipeIcon;
    switch (pipeline) {
      case 'text-generation':
        pipeColor = K.violet;
        pipeIcon = Icons.text_fields_rounded;
        break;
      case 'text-to-image':
        pipeColor = K.pink;
        pipeIcon = Icons.image_rounded;
        break;
      case 'image-text-to-text':
        pipeColor = K.cyan;
        pipeIcon = Icons.visibility_rounded;
        break;
      case 'object-detection':
        pipeColor = K.amber;
        pipeIcon = Icons.crop_free_rounded;
        break;
      case 'automatic-speech-recognition':
        pipeColor = K.emerald;
        pipeIcon = Icons.mic_rounded;
        break;
      case 'image-to-video':
        pipeColor = K.rose;
        pipeIcon = Icons.videocam_rounded;
        break;
      default:
        pipeColor = K.sky;
        pipeIcon = Icons.memory_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: K.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: pipeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(pipeIcon, color: pipeColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(modelName,
                          style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (author.isNotEmpty)
                        Text(author,
                            style: const TextStyle(color: K.textSec, fontSize: 11)),
                    ],
                  ),
                ),
                if (trending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: K.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('🔥 $trending',
                        style: const TextStyle(color: K.rose, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                _chip(pipeline.replaceAll('-', ' '), pipeColor),
                _chip('⬇ ${_fmtNum(downloads)}', K.sky),
                _chip('❤️ ${_fmtNum(likes)}', K.rose),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── EV Charger Card ─────────────────────────────────────────────
class _EvChargerCard extends StatelessWidget {
  const _EvChargerCard({required this.data, required this.loading, required this.location, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final String location;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final stations = (data?['stations'] as List<dynamic>?) ?? [];
    final count = data?['count'] as int? ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [K.emerald, K.teal]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.ev_station_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EV Chargers',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Near $location',
                      style: const TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ]),
          const SizedBox(height: 14),

          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [K.emerald.withValues(alpha: 0.15), K.teal.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: K.emerald.withValues(alpha: 0.2)),
            ),
            child: loading && data == null
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(strokeWidth: 2, color: K.emerald)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, color: K.emerald, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$count', style: const TextStyle(
                              color: K.emerald, fontSize: 32, fontWeight: FontWeight.w800)),
                          const Text('Charging stations within 30 km',
                              style: TextStyle(color: K.textSec, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
          ),
          if (stations.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...stations.take(6).map((s) => _stationTile(s as Map<String, dynamic>)),
          ] else if (!loading) ...[
            const SizedBox(height: 14),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(Icons.ev_station_rounded, color: K.textSec.withValues(alpha: 0.4), size: 32),
                    const SizedBox(height: 6),
                    const Text('No stations found in this area',
                        style: TextStyle(color: K.textSec, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stationTile(Map<String, dynamic> s) {
    final name = s['name'] as String? ?? 'Charging Station';
    final operator = s['operator'] as String? ?? '';
    final network = s['network'] as String? ?? '';
    final capacity = s['capacity'] as String? ?? '';
    final sockets = (s['socket_types'] as List<dynamic>?) ?? [];
    final fee = s['fee'] as String? ?? '';
    final hours = s['opening_hours'] as String? ?? '';
    final lat = s['lat'] as double?;
    final lng = s['lng'] as double?;
    final refLat = s['ref_lat'] as double? ?? 0;
    final refLng = s['ref_lng'] as double? ?? 0;

    String distLabel = '';
    if (lat != null && lng != null) {
      final km = Api._haversine(refLat, refLng, lat, lng);
      distLabel = km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(1)} km';
    }

    final displayOp = operator.isNotEmpty ? operator
        : network.isNotEmpty ? network : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: K.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: K.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: K.emerald, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (displayOp.isNotEmpty)
                        Text(displayOp,
                            style: const TextStyle(color: K.textSec, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (distLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: K.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(distLabel,
                        style: const TextStyle(color: K.cyan, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                if (sockets.isNotEmpty)
                  ...sockets.map<Widget>((t) => _chip('🔌 $t', K.sky)),
                if (capacity.isNotEmpty) _chip('⚡ $capacity ports', K.amber),
                if (fee == 'yes') _chip('💰 Paid', K.rose)
                else if (fee == 'no') _chip('🆓 Free', K.emerald),
                if (hours.isNotEmpty && hours != '24/7')
                  _chip('🕐 $hours', K.violet)
                else if (hours == '24/7')
                  _chip('🕐 24/7', K.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Space & Astronomy Card (ISS + NEO + Exoplanets) ────────────
class _SpaceCard extends StatefulWidget {
  const _SpaceCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_SpaceCard> createState() => _SpaceCardState();
}

class _SpaceCardState extends State<_SpaceCard> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [K.violet, K.purple]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Space & Astronomy',
                  style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _CardRefreshBtn(onRefresh: widget.onRefresh),
          ]),
          const SizedBox(height: 12),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tab,
              onTap: (_) => setState(() {}),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: [K.violet.withValues(alpha: 0.3), K.purple.withValues(alpha: 0.2)]),
                borderRadius: BorderRadius.circular(10),
              ),
              dividerColor: Colors.transparent,
              labelColor: K.textW,
              unselectedLabelColor: K.textSec,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: const [
                Tab(text: '🛰 ISS', height: 34),
                Tab(text: '☄️ Asteroids', height: 34),
                Tab(text: '🪐 Exoplanets', height: 34),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (widget.loading && widget.data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(strokeWidth: 2, color: K.violet),
        ),
      );
    }

    switch (_tab.index) {
      case 0:
        return _buildISS();
      case 1:
        return _buildNEO();
      case 2:
        return _buildExoplanets();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── ISS Tab ───────────────────────────────────────────────────
  Widget _buildISS() {
    final iss = widget.data?['iss'] as Map<String, dynamic>?;
    if (iss == null) {
      return _emptyState('ISS data unavailable', Icons.satellite_alt_rounded);
    }

    final lat = (iss['latitude'] as num?)?.toDouble();
    final lng = (iss['longitude'] as num?)?.toDouble();
    final alt = (iss['altitude'] as num?)?.toDouble();
    final vel = (iss['velocity'] as num?)?.toDouble();
    final vis = iss['visibility'] as String? ?? 'unknown';

    return Column(
      children: [
        // ISS hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [K.violet.withValues(alpha: 0.15), K.purple.withValues(alpha: 0.08)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: K.violet.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.satellite_alt_rounded, color: K.violet, size: 36),
              const SizedBox(height: 8),
              const Text('International Space Station',
                  style: TextStyle(color: K.textW, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: vis == 'daylight'
                      ? K.amber.withValues(alpha: 0.2)
                      : K.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vis == 'daylight' ? '☀️ Daylight' : '🌙 Eclipse',
                  style: TextStyle(
                    color: vis == 'daylight' ? K.amber : K.sky,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stats grid
        Row(
          children: [
            _statTile('Latitude', lat != null ? '${lat.toStringAsFixed(2)}°' : '--', K.cyan),
            const SizedBox(width: 8),
            _statTile('Longitude', lng != null ? '${lng.toStringAsFixed(2)}°' : '--', K.blue),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statTile('Altitude', alt != null ? '${alt.toStringAsFixed(0)} km' : '--', K.emerald),
            const SizedBox(width: 8),
            _statTile('Velocity', vel != null ? '${(vel / 1000).toStringAsFixed(1)}k km/h' : '--', K.rose),
          ],
        ),
      ],
    );
  }

  // ── NEO / Asteroids Tab ───────────────────────────────────────
  Widget _buildNEO() {
    final neo = widget.data?['neo'] as Map<String, dynamic>?;
    if (neo == null) {
      return _emptyState('Asteroid data unavailable', Icons.blur_circular_rounded);
    }

    final count = neo['count'] as int? ?? 0;
    final objects = neo['objects'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Count hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [K.amber.withValues(alpha: 0.15), K.rose.withValues(alpha: 0.08)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: K.amber.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.blur_circular_rounded, color: K.amber, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count', style: const TextStyle(
                      color: K.amber, fontSize: 32, fontWeight: FontWeight.w800)),
                  const Text('Near-Earth objects today',
                      style: TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Object list
        ...objects.take(5).map((obj) {
          final o = obj as Map<String, dynamic>;
          final name = (o['name'] as String? ?? '').replaceAll(RegExp(r'[()]'), '').trim();
          final hazardous = o['is_potentially_hazardous_asteroid'] as bool? ?? false;
          final mag = o['absolute_magnitude_h'] as num?;
          final dia = o['estimated_diameter'] as Map<String, dynamic>?;
          final meters = dia?['meters'] as Map<String, dynamic>?;
          final minD = (meters?['estimated_diameter_min'] as num?)?.toDouble();
          final maxD = (meters?['estimated_diameter_max'] as num?)?.toDouble();
          final approach = (o['close_approach_data'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
          final missKm = double.tryParse(approach?['miss_distance']?['kilometers'] ?? '');
          final velKph = double.tryParse(approach?['relative_velocity']?['kilometers_per_hour'] ?? '');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hazardous
                    ? K.rose.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hazardous ? K.rose.withValues(alpha: 0.2) : K.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (hazardous)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: K.rose.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('⚠️ Hazardous',
                              style: TextStyle(color: K.rose, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      if (minD != null && maxD != null)
                        _neoChip('⌀ ${minD.toStringAsFixed(0)}-${maxD.toStringAsFixed(0)}m'),
                      if (missKm != null)
                        _neoChip('📏 ${(missKm / 1e6).toStringAsFixed(2)}M km'),
                      if (velKph != null)
                        _neoChip('🚀 ${(velKph / 1000).toStringAsFixed(1)}k km/h'),
                      if (mag != null)
                        _neoChip('✨ mag ${mag.toStringAsFixed(1)}'),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Exoplanets Tab ────────────────────────────────────────────
  Widget _buildExoplanets() {
    final planets = widget.data?['exoplanets'] as List<Map<String, dynamic>>? ?? [];
    if (planets.isEmpty) {
      return _emptyState('Exoplanet data unavailable', Icons.public_rounded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [K.cyan.withValues(alpha: 0.12), K.teal.withValues(alpha: 0.06)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: K.cyan.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.public_rounded, color: K.cyan, size: 28),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest Discoveries',
                      style: TextStyle(color: K.cyan, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('NASA Exoplanet Archive',
                      style: TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Planet list
        ...planets.take(6).map((p) {
          final name = p['pl_name'] as String? ?? 'Unknown';
          final host = p['hostname'] as String? ?? '';
          final method = p['discoverymethod'] as String? ?? '';
          final year = p['disc_year'] as int?;
          final radius = p['pl_rade'] as num?; // Earth radii
          final mass = p['pl_bmasse'] as num?;  // Earth masses
          final dist = p['sy_dist'] as num?;     // parsecs
          final period = p['pl_orbper'] as num?;  // days

          // Size classification
          String sizeClass;
          Color sizeColor;
          if (radius == null) {
            sizeClass = '?';
            sizeColor = K.textSec;
          } else if (radius < 1.5) {
            sizeClass = 'Rocky';
            sizeColor = K.emerald;
          } else if (radius < 4) {
            sizeClass = 'Super-Earth';
            sizeColor = K.cyan;
          } else if (radius < 10) {
            sizeClass = 'Neptune-like';
            sizeColor = K.blue;
          } else {
            sizeClass = 'Gas Giant';
            sizeColor = K.amber;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: K.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Planet size dot
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: sizeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      if (year != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: K.violet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$year',
                              style: const TextStyle(color: K.violet, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$host  \u2022  $method',
                      style: const TextStyle(color: K.textSec, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      _exoChip(sizeClass, sizeColor),
                      if (radius != null) _exoChip('${radius.toStringAsFixed(1)}x R⊕', K.cyan),
                      if (mass != null) _exoChip('${mass.toStringAsFixed(1)}x M⊕', K.amber),
                      if (dist != null) _exoChip('${dist.toStringAsFixed(1)} pc', K.emerald),
                      if (period != null) _exoChip('${period.toStringAsFixed(1)}d orbit', K.sky),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, color: K.textSec.withValues(alpha: 0.5), size: 36),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(color: K.textSec, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: K.textW, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _neoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: K.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: K.amber, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _exoChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Ocean & Marine Card ─────────────────────────────────────────
class _OceanCard extends StatelessWidget {
  const _OceanCard({required this.data, required this.loading, required this.location, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final String location;
  final Future<void> Function() onRefresh;

  String _compassDir(num? deg) {
    if (deg == null) return '--';
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                   'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    return dirs[((deg.toDouble() % 360) / 22.5).round() % 16];
  }

  @override
  Widget build(BuildContext context) {
    final current = data?['current'] as Map<String, dynamic>?;
    final daily = data?['daily'] as Map<String, dynamic>?;

    final waveH = current?['wave_height'] as num?;
    // If wave_height is null, the point is inland — treat as no data
    final hasData = waveH != null;
    final waveDir = current?['wave_direction'] as num?;
    final wavePer = current?['wave_period'] as num?;
    final swellH = current?['swell_wave_height'] as num?;
    final swellDir = current?['swell_wave_direction'] as num?;
    final swellPer = current?['swell_wave_period'] as num?;
    final windWaveH = current?['wind_wave_height'] as num?;
    final currentVel = current?['ocean_current_velocity'] as num?;
    final currentDir = current?['ocean_current_direction'] as num?;
    final sst = current?['sea_surface_temperature'] as num?;

    // 7-day forecast
    final dailyMax = daily?['wave_height_max'] as List<dynamic>?;
    final dailyTimes = daily?['time'] as List<dynamic>?;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: K.gCyan),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.waves_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ocean & Marine',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Near $location',
                      style: const TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ]),
          const SizedBox(height: 16),

          if (loading && !hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2, color: K.cyan),
              ),
            )
          else if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: K.textSec.withValues(alpha: 0.5), size: 36),
                    const SizedBox(height: 8),
                    const Text('No ocean data available', style: TextStyle(color: K.textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            // Hero: wave height + SST
            Row(
              children: [
                // Wave height hero
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [K.cyan.withValues(alpha: 0.15), K.blue.withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: K.cyan.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.waves_rounded, color: K.cyan, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          '${waveH.toStringAsFixed(1)}m',
                          style: const TextStyle(color: K.textW, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Wave Height',
                          style: TextStyle(color: K.cyan.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        if (waveDir != null)
                          Text('from ${_compassDir(waveDir)}',
                              style: const TextStyle(color: K.textSec, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Sea Surface Temp
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [K.teal.withValues(alpha: 0.15), K.emerald.withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: K.teal.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.thermostat_rounded, color: K.teal, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          sst != null ? '${sst.toStringAsFixed(1)}°C' : '--',
                          style: const TextStyle(color: K.textW, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Sea Temp',
                          style: TextStyle(color: K.teal.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const Text('surface', style: TextStyle(color: K.textSec, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Detail grid
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _oceanTile('Swell', swellH != null ? '${swellH.toStringAsFixed(1)}m' : '--',
                    swellDir != null ? _compassDir(swellDir) : null, K.blue),
                _oceanTile('Swell Period', swellPer != null ? '${swellPer.toStringAsFixed(1)}s' : '--',
                    null, K.blue),
                _oceanTile('Wave Period', wavePer != null ? '${wavePer.toStringAsFixed(1)}s' : '--',
                    null, K.cyan),
                _oceanTile('Wind Wave', windWaveH != null ? '${windWaveH.toStringAsFixed(1)}m' : '--',
                    null, K.sky),
                _oceanTile('Current', currentVel != null ? '${currentVel.toStringAsFixed(1)} km/h' : '--',
                    currentDir != null ? _compassDir(currentDir) : null, K.emerald),
              ],
            ),

            // 7-day wave forecast mini chart
            if (dailyMax != null && dailyMax.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('7-Day Wave Forecast',
                  style: TextStyle(color: K.textSec, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < dailyMax.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              (dailyMax[i] as num).toStringAsFixed(1),
                              style: const TextStyle(color: K.textSec, fontSize: 9),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: ((dailyMax[i] as num).toDouble() / 4.0).clamp(0.1, 1.0) * 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  colors: [K.cyan.withValues(alpha: 0.3), K.cyan.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dailyTimes != null && i < dailyTimes.length
                                  ? (dailyTimes[i] as String).substring(5)
                                  : '',
                              style: const TextStyle(color: K.textMut, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _oceanTile(String label, String value, String? subtitle, Color c) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: K.textW, fontSize: 15, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: K.textSec, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Deck of Cards Card ──────────────────────────────────────────
class _DeckOfCardsCard extends StatelessWidget {
  const _DeckOfCardsCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  static const _suitColors = {
    'SPADES': Color(0xFF94A3B8),
    'CLUBS': Color(0xFF94A3B8),
    'HEARTS': Color(0xFFF43F5E),
    'DIAMONDS': Color(0xFFF43F5E),
  };

  static const _suitSymbols = {
    'SPADES': '♠',
    'CLUBS': '♣',
    'HEARTS': '♥',
    'DIAMONDS': '♦',
  };

  @override
  Widget build(BuildContext context) {
    final cards = (data?['cards'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final remaining = data?['remaining'] as int?;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [K.rose, K.pink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.style_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Card Draw',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  if (remaining != null)
                    Text('$remaining cards remaining',
                        style: const TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ]),
          const SizedBox(height: 16),

          if (loading && cards.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2, color: K.rose),
              ),
            )
          else if (cards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.casino_rounded, color: K.textSec.withValues(alpha: 0.5), size: 36),
                    const SizedBox(height: 8),
                    const Text('No cards drawn', style: TextStyle(color: K.textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            // Fan of cards with overlap
            SizedBox(
              height: 160,
              child: Center(
                child: SizedBox(
                  width: cards.length * 64.0 + 36,
                  height: 160,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int i = 0; i < cards.length; i++)
                        Positioned(
                          left: i * 64.0,
                          child: Transform.rotate(
                            angle: (i - (cards.length - 1) / 2) * 0.06,
                            child: Container(
                              width: 100,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8, offset: const Offset(2, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  cards[i]['image'] as String? ?? '',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, e, s) => _fallbackCard(cards[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card labels row
            Wrap(
              spacing: 6, runSpacing: 6,
              alignment: WrapAlignment.center,
              children: cards.map((c) {
                final value = c['value'] as String? ?? '?';
                final suit = c['suit'] as String? ?? '';
                final color = _suitColors[suit] ?? K.textSec;
                final symbol = _suitSymbols[suit] ?? '';
                final label = value == 'ACE' ? 'A'
                    : value == 'KING' ? 'K'
                    : value == 'QUEEN' ? 'Q'
                    : value == 'JACK' ? 'J'
                    : value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$label$symbol',
                    style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Draw again button
            Center(
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.casino_rounded, size: 16),
                label: const Text('Shuffle & Draw', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: K.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackCard(Map<String, dynamic> card) {
    final value = card['value'] as String? ?? '?';
    final suit = card['suit'] as String? ?? '';
    final color = _suitColors[suit] ?? K.textSec;
    final symbol = _suitSymbols[suit] ?? '';
    final label = value == 'ACE' ? 'A'
        : value == 'KING' ? 'K'
        : value == 'QUEEN' ? 'Q'
        : value == 'JACK' ? 'J'
        : value;
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          '$label\n$symbol',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
        ),
      ),
    );
  }
}

// ─── Book Card (Open Library) ────────────────────────────────────
class _BookCard extends StatefulWidget {
  const _BookCard({required this.books, required this.loading, required this.onRefresh});
  final List<Map<String, dynamic>> books;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  final _ctrl = TextEditingController(text: 'science');
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.books;
  }

  @override
  void didUpdateWidget(covariant _BookCard old) {
    super.didUpdateWidget(old);
    if (widget.books != old.books && !_searching) _results = widget.books;
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final r = await Api.openLibrary(q);
    if (mounted) setState(() { _results = r; _searching = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: K.gWarm),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Book Explorer',
                  style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _CardRefreshBtn(onRefresh: widget.onRefresh),
          ]),
          const SizedBox(height: 14),

          // Search bar
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: K.textW, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search books\u2026',
                    hintStyle: TextStyle(color: K.textSec.withValues(alpha: 0.6), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: K.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: K.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: K.amber),
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: _searching ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: K.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _searching
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Results
          if (widget.loading && _results.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2, color: K.amber),
              ),
            )
          else if (_results.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, color: K.textSec.withValues(alpha: 0.5), size: 36),
                    const SizedBox(height: 8),
                    const Text('No books found', style: TextStyle(color: K.textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._results.take(6).map((book) {
              final title = book['title'] as String? ?? 'Untitled';
              final authors = (book['author_name'] as List<dynamic>?)?.join(', ') ?? 'Unknown';
              final year = book['first_publish_year'] as int?;
              final coverId = book['cover_i'] as int?;
              final pages = book['number_of_pages_median'] as int?;
              final rating = (book['ratings_average'] as num?)?.toDouble();
              final editions = book['edition_count'] as int? ?? 0;
              final coverUrl = coverId != null
                  ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: K.glassBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: coverUrl != null
                            ? Image.network(coverUrl, width: 48, height: 68,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => Container(
                                  width: 48, height: 68,
                                  color: K.amber.withValues(alpha: 0.15),
                                  child: const Icon(Icons.book_rounded, color: K.amber, size: 24),
                                ))
                            : Container(
                                width: 48, height: 68,
                                color: K.amber.withValues(alpha: 0.15),
                                child: const Icon(Icons.book_rounded, color: K.amber, size: 24),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: K.textW, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(authors,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: K.textSec, fontSize: 11)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6, runSpacing: 4,
                              children: [
                                if (year != null)
                                  _bookChip(Icons.calendar_today_rounded, '$year'),
                                if (pages != null)
                                  _bookChip(Icons.auto_stories_rounded, '${pages}p'),
                                if (rating != null)
                                  _bookChip(Icons.star_rounded, rating.toStringAsFixed(1)),
                                if (editions > 1)
                                  _bookChip(Icons.layers_rounded, '$editions ed.'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _bookChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: K.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: K.amber),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: K.amber, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Air Quality Card (Open-Meteo) ──────────────────────────────
class _AirQualityCard extends StatelessWidget {
  const _AirQualityCard({required this.data, required this.loading, required this.location, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final String location;
  final Future<void> Function() onRefresh;

  static const _aqiLevels = [
    (max: 25, label: 'Excellent', color: Color(0xFF10B981), icon: Icons.sentiment_very_satisfied_rounded),
    (max: 50, label: 'Good', color: Color(0xFF22D3EE), icon: Icons.sentiment_satisfied_rounded),
    (max: 75, label: 'Moderate', color: Color(0xFFF59E0B), icon: Icons.sentiment_neutral_rounded),
    (max: 100, label: 'Poor', color: Color(0xFFF97316), icon: Icons.sentiment_dissatisfied_rounded),
    (max: 999, label: 'Very Poor', color: Color(0xFFEF4444), icon: Icons.sentiment_very_dissatisfied_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final current = data?['current'] as Map<String, dynamic>?;
    final units = data?['current_units'] as Map<String, dynamic>?;
    final eaqi = (current?['european_aqi'] as num?)?.toInt();
    final usaqi = (current?['us_aqi'] as num?)?.toInt();

    // Determine level from European AQI
    final level = eaqi != null
        ? _aqiLevels.firstWhere((l) => eaqi <= l.max)
        : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: K.gGreen),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.air_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Air Quality',
                      style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(location,
                      style: const TextStyle(color: K.textSec, fontSize: 11)),
                ],
              ),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ]),
          const SizedBox(height: 16),

          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2, color: K.emerald),
              ),
            )
          else if (current == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: K.textSec.withValues(alpha: 0.5), size: 36),
                    const SizedBox(height: 8),
                    const Text('No data available', style: TextStyle(color: K.textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            // AQI hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (level?.color ?? K.emerald).withValues(alpha: 0.15),
                    (level?.color ?? K.emerald).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (level?.color ?? K.emerald).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(level?.icon ?? Icons.air_rounded,
                      color: level?.color ?? K.emerald, size: 40),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (eaqi != null) ...[
                        Text('$eaqi', style: TextStyle(
                            color: level?.color ?? K.emerald,
                            fontSize: 36, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level?.label ?? '',
                                style: TextStyle(color: level?.color ?? K.emerald,
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const Text('EU AQI',
                                style: TextStyle(color: K.textSec, fontSize: 10)),
                          ],
                        ),
                      ],
                      if (usaqi != null) ...[
                        const SizedBox(width: 20),
                        Container(width: 1, height: 30,
                            color: K.glassBorder),
                        const SizedBox(width: 20),
                        Column(
                          children: [
                            Text('$usaqi', style: const TextStyle(
                                color: K.textW, fontSize: 22, fontWeight: FontWeight.w700)),
                            const Text('US AQI',
                                style: TextStyle(color: K.textSec, fontSize: 10)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Pollutant grid
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _pollutantTile('PM2.5', current['pm2_5'], units?['pm2_5'], K.cyan),
                _pollutantTile('PM10', current['pm10'], units?['pm10'], K.blue),
                _pollutantTile('O\u2083', current['ozone'], units?['ozone'], K.emerald),
                _pollutantTile('NO\u2082', current['nitrogen_dioxide'], units?['nitrogen_dioxide'], K.amber),
                _pollutantTile('SO\u2082', current['sulphur_dioxide'], units?['sulphur_dioxide'], K.rose),
                _pollutantTile('CO', current['carbon_monoxide'], units?['carbon_monoxide'], K.purple),
                if (current['uv_index'] != null)
                  _pollutantTile('UV', current['uv_index'], 'index', K.pink),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pollutantTile(String label, dynamic value, dynamic unit, Color c) {
    final v = value is num ? value.toStringAsFixed(1) : '--';
    final u = (unit is String) ? unit : '';
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(color: K.textW, fontSize: 16, fontWeight: FontWeight.w800)),
          if (u.isNotEmpty)
            Text(u, style: const TextStyle(color: K.textSec, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Advice Slip Card ────────────────────────────────────────────
class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.loading, required this.onRefresh});
  final String? advice;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: K.gPurple),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Advice of the Moment',
                  style: TextStyle(color: K.textW, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _CardRefreshBtn(onRefresh: onRefresh),
          ]),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2, color: K.purple),
              ),
            )
          else if (advice == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: K.textSec.withValues(alpha: 0.5), size: 40),
                    const SizedBox(height: 8),
                    Text('No advice available', style: TextStyle(color: K.textSec, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    K.purple.withValues(alpha: 0.12),
                    K.violet.withValues(alpha: 0.08),
                    K.cyan.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: K.purple.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: K.purple.withValues(alpha: 0.6), size: 32),
                  const SizedBox(height: 12),
                  Text(
                    '"$advice"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: K.textW,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: K.gPurple),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Advice Slip',
                        style: TextStyle(
                          color: K.purple.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: K.gPurple),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('New Advice', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: K.purple,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bored / Activity Idea Card ──────────────────────────────────
class _BoredCard extends StatelessWidget {
  const _BoredCard({required this.data, required this.loading, required this.onRefresh});
  final Map<String, dynamic>? data;
  final bool loading;
  final Future<void> Function() onRefresh;

  static const _typeColors = {
    'education': Color(0xFF3B82F6),
    'recreational': Color(0xFF10B981),
    'social': Color(0xFFF59E0B),
    'diy': Color(0xFFF97316),
    'charity': Color(0xFFEC4899),
    'cooking': Color(0xFFEF4444),
    'relaxation': Color(0xFF8B5CF6),
    'music': Color(0xFF06B6D4),
    'busywork': Color(0xFF64748B),
  };

  static const _typeIcons = {
    'education': Icons.school_rounded,
    'recreational': Icons.park_rounded,
    'social': Icons.groups_rounded,
    'diy': Icons.build_rounded,
    'charity': Icons.volunteer_activism_rounded,
    'cooking': Icons.restaurant_rounded,
    'relaxation': Icons.spa_rounded,
    'music': Icons.music_note_rounded,
    'busywork': Icons.checklist_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final activity = data?['activity'] as String? ?? 'Finding something fun...';
    final type = (data?['type'] as String? ?? 'recreational').toLowerCase();
    final participants = data?['participants'] as num? ?? 1;
    final price = data?['price'] as num? ?? 0;
    final accessibility = data?['accessibility'] as num? ?? 0.5;

    final color = _typeColors[type] ?? K.purple;
    final icon = _typeIcons[type] ?? Icons.lightbulb_rounded;

    // Difficulty label from accessibility (0 = easy, 1 = hard)
    final diffLabel = accessibility <= 0.25
        ? 'Easy'
        : accessibility <= 0.6
            ? 'Moderate'
            : 'Challenging';
    final diffColor = accessibility <= 0.25
        ? K.emerald
        : accessibility <= 0.6
            ? K.amber
            : K.rose;

    // Price label
    final priceLabel = price == 0
        ? 'Free'
        : price <= 0.3
            ? 'Low cost'
            : price <= 0.6
                ? 'Moderate'
                : 'Pricey';

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [color, color.withAlpha(180)],
                  ),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Activity Idea',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text('Bored? Try this!',
                        style: TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: onRefresh),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.purple),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Activity card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withAlpha(20),
                  color.withAlpha(8),
                ],
              ),
              border: Border.all(color: color.withAlpha(35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: color.withAlpha(30),
                        border: Border.all(color: color.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 13, color: color),
                          const SizedBox(width: 5),
                          Text(type[0].toUpperCase() + type.substring(1),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Activity text
                Text(activity,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: K.textW,
                        height: 1.3)),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  children: [
                    _activityChip(
                        Icons.person_rounded,
                        '${participants.toInt()} ${participants == 1 ? 'person' : 'people'}',
                        K.blue),
                    const SizedBox(width: 8),
                    _activityChip(Icons.speed_rounded, diffLabel, diffColor),
                    const SizedBox(width: 8),
                    _activityChip(Icons.attach_money_rounded, priceLabel,
                        price == 0 ? K.emerald : K.amber),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withAlpha(12),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Sunrise / Sunset Card ───────────────────────────────────────
class _SunriseCard extends StatelessWidget {
  const _SunriseCard({
    required this.data,
    required this.loading,
    required this.location,
    required this.onRefresh,
  });
  final Map<String, dynamic>? data;
  final bool loading;
  final String location;
  final Future<void> Function() onRefresh;

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final amPm = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $amPm';
    } catch (_) {
      return '--:--';
    }
  }

  String _fmtDuration(num? seconds) {
    if (seconds == null) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  double _sunProgress() {
    if (data == null) return 0.5;
    try {
      final sunrise = DateTime.parse(data!['sunrise'] as String).toLocal();
      final sunset = DateTime.parse(data!['sunset'] as String).toLocal();
      final now = DateTime.now();
      if (now.isBefore(sunrise)) return 0.0;
      if (now.isAfter(sunset)) return 1.0;
      return (now.difference(sunrise).inMinutes) /
          (sunset.difference(sunrise).inMinutes);
    } catch (_) {
      return 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sunrise = data?['sunrise'] as String?;
    final sunset = data?['sunset'] as String?;
    final solarNoon = data?['solar_noon'] as String?;
    final dayLength = data?['day_length'] as num?;
    final civilBegin = data?['civil_twilight_begin'] as String?;
    final civilEnd = data?['civil_twilight_end'] as String?;
    final progress = _sunProgress();
    final isDay = progress > 0.0 && progress < 1.0;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                  ),
                ),
                child: const Icon(Icons.wb_twilight_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sun Tracker',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    Text(location,
                        style: const TextStyle(
                            fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              _CardRefreshBtn(onRefresh: onRefresh),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: K.amber),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Sun arc visualization
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: _SunArcPainter(progress: progress, isDay: isDay),
              size: const Size(double.infinity, 80),
            ),
          ),
          const SizedBox(height: 14),

          // Sunrise / Sunset row
          Row(
            children: [
              Expanded(
                child: _sunTimeBlock(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Sunrise',
                  time: _fmtTime(sunrise),
                  color: const Color(0xFFFBBF24),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha(10),
              ),
              Expanded(
                child: _sunTimeBlock(
                  icon: Icons.nightlight_rounded,
                  label: 'Sunset',
                  time: _fmtTime(sunset),
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sunChip(Icons.wb_sunny_outlined, 'Solar Noon',
                  _fmtTime(solarNoon), K.amber),
              _sunChip(Icons.timelapse_rounded, 'Daylight',
                  _fmtDuration(dayLength), K.emerald),
              _sunChip(Icons.blur_on_rounded, 'Dawn',
                  _fmtTime(civilBegin), K.sky),
              _sunChip(Icons.blur_on_rounded, 'Dusk',
                  _fmtTime(civilEnd), K.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sunTimeBlock({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: K.textMut)),
      ],
    );
  }

  Widget _sunChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withAlpha(12),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text('$label  ', style: const TextStyle(fontSize: 10, color: K.textMut)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Sun Arc Painter ─────────────────────────────────────────────
class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.progress, required this.isDay});
  final double progress;
  final bool isDay;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final arcRect = Rect.fromLTRB(0, 0, w, h * 2);

    // Horizon line
    final horizonPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h), Offset(w, h), horizonPaint);

    // Arc path
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(20);
    canvas.drawArc(arcRect, math.pi, math.pi, false, arcPaint);

    // Filled arc up to progress
    if (isDay) {
      final filledPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawArc(
          arcRect, math.pi, math.pi * progress, false, filledPaint);
    }

    // Sun dot
    final angle = math.pi + math.pi * progress;
    final cx = w / 2 + (w / 2) * math.cos(angle);
    final cy = h + h * math.sin(angle);

    // Glow
    final glowPaint = Paint()
      ..color = (isDay ? const Color(0xFFFBBF24) : const Color(0xFF64748B))
          .withAlpha(40);
    canvas.drawCircle(Offset(cx, cy), 12, glowPaint);

    // Dot
    final dotPaint = Paint()
      ..color = isDay ? const Color(0xFFFBBF24) : const Color(0xFF64748B);
    canvas.drawCircle(Offset(cx, cy), 5, dotPaint);

    // Labels
    final sunriseTP = TextPainter(
      text: const TextSpan(
          text: '☀️',
          style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    sunriseTP.paint(canvas, Offset(4, h - 22));

    final sunsetTP = TextPainter(
      text: const TextSpan(
          text: '🌙',
          style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    sunsetTP.paint(canvas, Offset(w - 22, h - 22));
  }

  @override
  bool shouldRepaint(_SunArcPainter old) =>
      old.progress != progress || old.isDay != isDay;
}

// ─── Solar Fact Card ─────────────────────────────────────────────
class _SolarFactCard extends StatefulWidget {
  const _SolarFactCard({required this.loading});
  final bool loading;

  @override
  State<_SolarFactCard> createState() => _SolarFactCardState();
}

class _SolarFactCardState extends State<_SolarFactCard> {
  int _factIndex = 0;

  static const List<_SolarFact> _facts = [
    _SolarFact(
      title: 'The Sun',
      body:
          'The Sun accounts for 99.86% of all mass in our solar system. It could fit roughly 1.3 million Earths inside it.',
      icon: Icons.wb_sunny_rounded,
      colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
      orbitColor: Color(0x30FFA726),
    ),
    _SolarFact(
      title: "Jupiter's Great Red Spot",
      body:
          "Jupiter's iconic storm is larger than Earth and has been raging for at least 350 years.",
      icon: Icons.blur_circular_rounded,
      colors: [Color(0xFFFF8A65), Color(0xFFD84315)],
      orbitColor: Color(0x30FF8A65),
    ),
    _SolarFact(
      title: "Saturn's Rings",
      body:
          "Saturn's rings are made of ice and rock, stretching 282,000 km wide but only about 10 metres thick.",
      icon: Icons.trip_origin_rounded,
      colors: [Color(0xFFFFCC02), Color(0xFFD4A017)],
      orbitColor: Color(0x30FFCC02),
    ),
    _SolarFact(
      title: 'Speed of Light',
      body:
          'Sunlight takes about 8 minutes and 20 seconds to travel the 150 million km from the Sun to Earth.',
      icon: Icons.bolt_rounded,
      colors: [Color(0xFF64FFDA), Color(0xFF00BFA5)],
      orbitColor: Color(0x3064FFDA),
    ),
    _SolarFact(
      title: 'Neutron Stars',
      body:
          'A teaspoon of neutron star material would weigh about 6 billion tons — roughly the weight of Mount Everest.',
      icon: Icons.stars_rounded,
      colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
      orbitColor: Color(0x30B388FF),
    ),
    _SolarFact(
      title: "Mars' Olympus Mons",
      body:
          'The tallest volcano in the solar system is on Mars, standing 21.9 km high — nearly 3× the height of Everest.',
      icon: Icons.terrain_rounded,
      colors: [Color(0xFFEF9A9A), Color(0xFFE53935)],
      orbitColor: Color(0x30EF9A9A),
    ),
    _SolarFact(
      title: 'Venus Spins Backwards',
      body:
          'Venus rotates in the opposite direction to most planets. A day on Venus is longer than its year.',
      icon: Icons.autorenew_rounded,
      colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
      orbitColor: Color(0x30CE93D8),
    ),
    _SolarFact(
      title: 'The Milky Way',
      body:
          'Our galaxy contains between 100–400 billion stars and is about 100,000 light-years in diameter.',
      icon: Icons.all_inclusive_rounded,
      colors: [Color(0xFF90CAF9), Color(0xFF1565C0)],
      orbitColor: Color(0x3090CAF9),
    ),
    _SolarFact(
      title: "Europa's Ocean",
      body:
          "Jupiter's moon Europa likely has a subsurface ocean with more water than all of Earth's oceans combined.",
      icon: Icons.water_rounded,
      colors: [Color(0xFF80DEEA), Color(0xFF00838F)],
      orbitColor: Color(0x3080DEEA),
    ),
    _SolarFact(
      title: 'Asteroid Belt',
      body:
          'Despite Hollywood depictions, the asteroid belt is mostly empty space — objects are millions of km apart on average.',
      icon: Icons.scatter_plot_rounded,
      colors: [Color(0xFFBCAAA4), Color(0xFF6D4C41)],
      orbitColor: Color(0x30BCAAA4),
    ),
  ];

  void _nextFact() => setState(() => _factIndex = (_factIndex + 1) % _facts.length);

  @override
  Widget build(BuildContext context) {
    final fact = _facts[_factIndex];
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Orbit ring decorations
          Positioned(
            top: -40,
            right: -40,
            child: CustomPaint(
              size: const Size(160, 160),
              painter: _OrbitRingPainter(color: fact.orbitColor),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _OrbitRingPainter(color: fact.orbitColor.withAlpha(20)),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(colors: fact.colors),
                      ),
                      child: Icon(Icons.rocket_launch_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Solar & Space',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: K.textW)),
                          Text('Curated facts',
                              style:
                                  TextStyle(fontSize: 11, color: K.textMut)),
                        ],
                      ),
                    ),
                    if (widget.loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: K.cyan,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Planet icon + title
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: fact.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: fact.colors.first.withAlpha(80),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(fact.icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        fact.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          foreground: Paint()
                            ..shader = LinearGradient(colors: fact.colors)
                                .createShader(
                                    const Rect.fromLTWH(0, 0, 200, 30)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Fact body
                Text(
                  fact.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: K.textSec,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                // Next fact button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _nextFact,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: fact.colors
                              .map((c) => c.withAlpha(40))
                              .toList(),
                        ),
                        border: Border.all(
                            color: fact.colors.first.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 15, color: fact.colors.first),
                          const SizedBox(width: 6),
                          Text(
                            'Next Fact',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: fact.colors.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolarFact {
  const _SolarFact({
    required this.title,
    required this.body,
    required this.icon,
    required this.colors,
    required this.orbitColor,
  });
  final String title;
  final String body;
  final IconData icon;
  final List<Color> colors;
  final Color orbitColor;
}

class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.width, height: size.height * 0.5),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: size.width * 0.65, height: size.height * 0.35),
      paint..color = color.withAlpha(((color.a * 255.0).round() * 0.6).round()),
    );
    // Small planet dot
    final dotPaint = Paint()..color = color.withAlpha(150);
    canvas.drawCircle(
        Offset(center.dx + size.width * 0.35, center.dy - 4), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter old) => old.color != color;
}

// ─── Health Card ─────────────────────────────────────────────────
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.done, required this.onToggle});
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: K.gGreen),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Health Prescription',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: K.textW)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Recovery metric
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: 0.88,
                        strokeWidth: 4,
                        color: K.emerald,
                        backgroundColor: K.emerald.withValues(alpha: 0.15),
                      ),
                    ),
                    const Text('88%',
                        style: TextStyle(
                            color: K.emerald,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Score',
                      style: TextStyle(fontSize: 12, color: K.textMut)),
                  SizedBox(height: 2),
                  Text('Optimal',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: K.emerald)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 12),
          // Task
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: done
                            ? K.emerald
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: done
                              ? K.emerald
                              : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complete 5-min Grounding Exercise',
                        style: TextStyle(
                          fontSize: 13,
                          color: K.textSec,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: K.gGreen),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Start Exercise',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: K.textMut),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Do one 5-min physical activity as your "anchor" to regulate your system.',
                  style: TextStyle(
                      fontSize: 11,
                      color: K.textMut,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Footer Quote ────────────────────────────────────────────────
class _FooterQuote extends StatelessWidget {
  const _FooterQuote({
    required this.text,
    required this.author,
    required this.loading,
    required this.onRefresh,
  });
  final String text, author;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onRefresh,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          K.purple.withValues(alpha: 0.12),
          K.pink.withValues(alpha: 0.08),
          K.cyan.withValues(alpha: 0.06),
        ],
      ),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Gradient accent stripe
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: K.gPurple,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(K.r),
                bottomLeft: Radius.circular(K.r),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$text"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: K.textSec,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('— $author',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: K.textMut)),
                      const Spacer(),
                      const Icon(Icons.refresh_rounded,
                          color: K.textMut, size: 14),
                      const SizedBox(width: 4),
                      const Text('Tap for new quote',
                          style: TextStyle(
                              fontSize: 10, color: K.textMut)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Night Mode ──────────────────────────────────────────────────
class _NightContent extends StatelessWidget {
  const _NightContent({
    super.key,
    required this.weather,
    required this.quote,
    required this.quoteAuthor,
    required this.location,
  });
  final Map<String, dynamic>? weather;
  final String quote, quoteAuthor;
  final String location;

  @override
  Widget build(BuildContext context) {
    final temp = weather?['current'] != null
        ? (weather!['current']['temperature_2m'] as num).round()
        : 22;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 20),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (b) =>
                  const LinearGradient(colors: K.gWarm).createShader(b),
              child: const Icon(Icons.nightlight_round, size: 56),
            ),
            const SizedBox(height: 14),
            _GradText(
              'Night Mode · Essentials',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              colors: K.gPurple,
            ),
            const SizedBox(height: 6),
            const Text('Wind down. Rest. Recover.',
                textAlign: TextAlign.center,
                style: TextStyle(color: K.textMut, fontSize: 13)),
            const SizedBox(height: 28),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded,
                          color: K.amber, size: 28),
                      const SizedBox(width: 12),
                      Text('$temp°C · $location',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: K.textW)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('HEALTH & RECOVERY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: K.textMut,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                value: 0.88,
                                strokeWidth: 3,
                                color: K.emerald,
                                backgroundColor:
                                    K.emerald.withValues(alpha: 0.15),
                              ),
                            ),
                            const Text('88%',
                                style: TextStyle(
                                    color: K.emerald,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recovery Score',
                              style:
                                  TextStyle(fontSize: 11, color: K.textMut)),
                          Text('Optimal',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: K.emerald)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              gradient: LinearGradient(
                colors: [
                  K.purple.withValues(alpha: 0.1),
                  K.pink.withValues(alpha: 0.06),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$quote"',
                      style: const TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: K.textSec,
                          height: 1.5)),
                  const SizedBox(height: 8),
                  Text('— $quoteAuthor',
                      style:
                          const TextStyle(fontSize: 13, color: K.textMut)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weather Detail Sheet ────────────────────────────────────────
class _WeatherSheet extends StatelessWidget {
  const _WeatherSheet({required this.data, required this.location});
  final Map<String, dynamic>? data;
  final String location;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final daily = data?['daily'];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 100, 12, 0),
      decoration: BoxDecoration(
        color: K.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: K.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradText(
                      '7-Day Forecast',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                      colors: K.gCyan,
                    ),
                    const SizedBox(height: 4),
                    Text(location,
                        style: const TextStyle(color: K.textMut, fontSize: 13)),
                    const SizedBox(height: 20),
                    if (daily != null)
                      ...List.generate(
                        math.min(7, (daily['time'] as List).length),
                        (i) {
                          final time = daily['time'][i] as String;
                          final max =
                              (daily['temperature_2m_max'][i] as num).round();
                          final min =
                              (daily['temperature_2m_min'][i] as num).round();
                          final code =
                              (daily['weather_code'][i] as num).toInt();
                          return _dayRow(time, max, min, code);
                        },
                      )
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No forecast data',
                              style: TextStyle(color: K.textMut)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(String date, int max, int min, int code) {
    // Parse date string to get day name
    final parts = date.split('-');
    final dt = DateTime.tryParse(date);
    final dayName = dt != null
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1]
        : parts.last;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text('$dayName ${parts.last}',
                style: const TextStyle(color: K.textSec, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Icon(_wIcon(code), color: K.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_wDesc(code),
                style: const TextStyle(color: K.textMut, fontSize: 12)),
          ),
          Text('$max°',
              style: const TextStyle(
                  color: K.textW, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 8),
          Text('$min°',
              style: const TextStyle(color: K.textMut, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── News Detail Sheet ───────────────────────────────────────────
class _NewsDetailSheet extends StatelessWidget {
  const _NewsDetailSheet({required this.story});
  final Map<String, dynamic> story;

  static const _categoryColors = <String, Color>{
    'World': K.rose,
    'Tech': K.cyan,
    'Science': K.emerald,
    'Business': K.amber,
    'Space': K.purple,
  };

  @override
  Widget build(BuildContext context) {
    final title = story['title'] as String? ?? 'Untitled';
    final score = story['score'] as int? ?? 0;
    final author = story['author'] as String? ?? 'unknown';
    final createdUtc = ((story['created_utc'] as num?) ?? 0).toInt();
    final url = story['url'] as String?;
    final thumb = story['thumbnail'] as String?;
    final comments = story['num_comments'] as int? ?? 0;
    final domain = story['domain'] as String? ?? '';
    final category = story['category'] as String? ?? '';
    final subreddit = story['subreddit'] as String? ?? '';
    final selftext = story['selftext'] as String? ?? '';
    final catColor = _categoryColors[category] ?? K.blue;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 80, 12, 0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: K.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: K.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dragHandle(),
            // ── Hero thumbnail ──
            if (thumb != null)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: catColor.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(Icons.public_rounded,
                          size: 48, color: catColor.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, 24 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + subreddit
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(category,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor)),
                      ),
                      const SizedBox(width: 8),
                      Text('r/$subreddit',
                          style: const TextStyle(
                              fontSize: 12, color: K.textMut)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: K.textW,
                          height: 1.4)),
                  const SizedBox(height: 12),
                  // Stats badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _badge(Icons.arrow_upward_rounded,
                          _formatScore(score), K.amber),
                      _badge(Icons.chat_bubble_outline,
                          '$comments comments', K.cyan),
                      _badge(Icons.person_outline, 'u/$author', K.purple),
                      _badge(Icons.schedule, _timeAgo(createdUtc), K.textMut),
                    ],
                  ),
                  // Self-text preview
                  if (selftext.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: K.glassBorder),
                      ),
                      child: Text(
                        selftext.length > 300
                            ? '${selftext.substring(0, 300)}…'
                            : selftext,
                        style: const TextStyle(
                            color: K.textSec, fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                  // Source link
                  if (url != null && url.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: K.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded,
                              color: K.textMut, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(domain,
                                style: const TextStyle(
                                    color: K.cyan, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('via r/$subreddit on Reddit',
                      style: const TextStyle(color: K.textMut, fontSize: 11)),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  static String _formatScore(int score) {
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
    return '$score';
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Show Detail Sheet ───────────────────────────────────────────
class _ShowDetailSheet extends StatelessWidget {
  const _ShowDetailSheet({required this.show});
  final Map<String, dynamic> show;

  @override
  Widget build(BuildContext context) {
    final name = show['name'] as String? ?? 'Unknown';
    final img = show['image'] as Map<String, dynamic>?;
    final imageUrl = img?['original'] as String? ?? img?['medium'] as String?;
    final rating = show['rating'] as Map<String, dynamic>?;
    final avg = rating?['average'];
    final genres = (show['genres'] as List?)?.join(', ') ?? '';
    final summary = _stripHtml(show['summary'] as String? ?? '');
    final status = show['status'] as String? ?? '';
    final network = show['network'] as Map<String, dynamic>?;
    final netName = network?['name'] as String? ?? '';
    final premiered = show['premiered'] as String? ?? '';
    final ended = show['ended'] as String? ?? '';
    final runtime = show['runtime'] as int?;
    final lang = show['language'] as String? ?? '';
    final type = show['type'] as String? ?? '';
    final schedule = show['schedule'] as Map<String, dynamic>?;
    final days = (schedule?['days'] as List?)?.join(', ') ?? '';
    final schedTime = schedule?['time'] as String? ?? '';

    Color statusColor;
    if (status == 'Running') {
      statusColor = K.emerald;
    } else if (status == 'To Be Determined') {
      statusColor = K.amber;
    } else {
      statusColor = K.textMut;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      decoration: BoxDecoration(
        color: K.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: K.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    24, 8, 24, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image
                    if (imageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Image.network(imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                        color: K.purple.withValues(alpha: 0.1),
                                        child: const Icon(Icons.movie_rounded,
                                            color: K.purple, size: 40),
                                      )),
                            ),
                          ),
                          // Status overlay badge
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(status,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Title
                    Text(name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    const SizedBox(height: 10),
                    // Tags row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (avg != null) _tag('★ $avg', K.amber),
                        if (type.isNotEmpty) _tag(type, K.cyan),
                        if (genres.isNotEmpty) _tag(genres, K.purple),
                        if (lang.isNotEmpty) _tag(lang, K.textSec),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Metadata grid
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: K.glassBorder),
                      ),
                      child: Column(
                        children: [
                          if (netName.isNotEmpty)
                            _metaRow(Icons.tv_rounded, 'Network', netName),
                          if (premiered.isNotEmpty)
                            _metaRow(Icons.calendar_today_rounded, 'Premiered',
                                '$premiered${ended.isNotEmpty ? " — $ended" : ""}'),
                          if (runtime != null)
                            _metaRow(Icons.timer_outlined, 'Runtime',
                                '$runtime min'),
                          if (days.isNotEmpty)
                            _metaRow(Icons.date_range_rounded, 'Schedule',
                                '$days${schedTime.isNotEmpty ? " at $schedTime" : ""}'),
                        ],
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('SYNOPSIS',
                          style: TextStyle(
                              color: K.textMut,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(summary,
                          style: const TextStyle(
                              color: K.textSec,
                              fontSize: 13,
                              height: 1.6)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: K.textMut),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: K.textMut,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: K.textW, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Meal Detail Sheet ───────────────────────────────────────────
class _MealDetailSheet extends StatelessWidget {
  const _MealDetailSheet({required this.meal});
  final Map<String, dynamic> meal;

  @override
  Widget build(BuildContext context) {
    final name = meal['strMeal'] as String? ?? 'Recipe';
    final thumb = meal['strMealThumb'] as String?;
    final instructions = meal['strInstructions'] as String? ?? '';
    final ingredients = <String>[];
    for (int i = 1; i <= 20; i++) {
      final ing = meal['strIngredient$i'] as String?;
      final measure = meal['strMeasure$i'] as String?;
      if (ing != null && ing.trim().isNotEmpty) {
        ingredients.add('${measure?.trim() ?? ''} $ing'.trim());
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      decoration: BoxDecoration(
        color: K.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: K.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    24, 8, 24, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumb != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(thumb,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink()),
                      ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: K.textW)),
                    if (ingredients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _GradText('Ingredients',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          colors: K.gWarm),
                      const SizedBox(height: 10),
                      ...ingredients.map(
                        (ing) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: K.amber),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(ing,
                                    style: const TextStyle(
                                        color: K.textSec, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (instructions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _GradText('Instructions',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          colors: K.gGreen),
                      const SizedBox(height: 10),
                      Text(instructions,
                          style: const TextStyle(
                              color: K.textSec, fontSize: 13, height: 1.6)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sparkline Painter ───────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ─── Settings Sheet ──────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.doodleBg,
    required this.onDoodleBgChanged,
    required this.nightMode,
    required this.onNightMode,
    required this.editMode,
    required this.onEditMode,
    required this.onRefresh,
  });
  final bool doodleBg;
  final ValueChanged<bool> onDoodleBgChanged;
  final bool nightMode;
  final ValueChanged<bool> onNightMode;
  final bool editMode;
  final VoidCallback onEditMode;
  final VoidCallback onRefresh;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _doodle;
  late bool _night;

  @override
  void initState() {
    super.initState();
    _doodle = widget.doodleBg;
    _night = widget.nightMode;
  }

  Widget _settingsToggle({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(colors: gradient),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: K.textW)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: K.textMut)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: value
                      ? K.purple.withAlpha(180)
                      : Colors.white.withAlpha(20),
                  border: Border.all(
                    color: value
                        ? K.purple.withAlpha(120)
                        : Colors.white.withAlpha(15),
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? Colors.white : K.textMut,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsAction({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(10)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: gradient),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: K.textW)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 11, color: K.textMut)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withAlpha(8),
                  border: Border.all(color: Colors.white.withAlpha(12)),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    color: K.textMut, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: K.bg2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(),
          const SizedBox(height: 8),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: K.gPurple),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: K.textW)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Night Mode
          _settingsToggle(
            icon: _night ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            gradient: _night ? K.gWarm : [const Color(0xFF1A237E), const Color(0xFF283593)],
            title: 'Night Mode',
            subtitle: _night ? 'Zen mode with minimal content' : 'Full dashboard with all widgets',
            value: _night,
            onChanged: (v) {
              setState(() => _night = v);
              widget.onNightMode(v);
            },
          ),
          const SizedBox(height: 10),
          // Edit Layout
          _settingsAction(
            icon: Icons.dashboard_customize_rounded,
            gradient: K.gCyan,
            title: 'Edit Layout',
            subtitle: 'Drag and reorder dashboard widgets',
            onTap: widget.onEditMode,
          ),
          const SizedBox(height: 10),
          // Refresh Data
          _settingsAction(
            icon: Icons.refresh_rounded,
            gradient: K.gGreen,
            title: 'Refresh Data',
            subtitle: 'Reload all live data from APIs',
            onTap: widget.onRefresh,
          ),
          const SizedBox(height: 10),
          // Doodle Background
          _settingsToggle(
            icon: Icons.auto_awesome_rounded,
            gradient: K.gPurple,
            title: 'Icon Doodle Background',
            subtitle: 'Scatter faint logo icons behind content',
            value: _doodle,
            onChanged: (v) {
              setState(() => _doodle = v);
              widget.onDoodleBgChanged(v);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────
Widget _dragHandle() {
  return Container(
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────
IconData _wIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code <= 2) return Icons.cloud_queue_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code <= 48) return Icons.foggy;
  if (code <= 55) return Icons.grain_rounded;
  if (code <= 65) return Icons.water_drop_rounded;
  if (code <= 75) return Icons.ac_unit_rounded;
  if (code <= 82) return Icons.beach_access_rounded;
  return Icons.thunderstorm_rounded;
}

String _wDesc(int code) {
  if (code == 0) return 'Clear Sky';
  if (code <= 2) return 'Partly Cloudy';
  if (code == 3) return 'Overcast';
  if (code <= 48) return 'Foggy';
  if (code <= 55) return 'Drizzle';
  if (code <= 65) return 'Rainy';
  if (code <= 75) return 'Snow';
  if (code <= 82) return 'Showers';
  return 'Thunderstorm';
}

String _timeAgo(int unix) {
  if (unix == 0) return '';
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final diff = now - unix;
  if (diff < 60) return 'just now';
  if (diff < 3600) return '${diff ~/ 60}m ago';
  if (diff < 86400) return '${diff ~/ 3600}h ago';
  return '${diff ~/ 86400}d ago';
}

String _stripHtml(String html) {
  return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
