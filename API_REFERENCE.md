
# The Quantum One — API Reference

All endpoints used by the app, their methods, and return value shapes.
Every API is **free / no-key** unless noted. HTTP timeout: **8 seconds**.

---

## 1. Weather — Open-Meteo

| Method | `Api.weather(lat, lng)` |
|--------|------------------------|
| **URL** | `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,uv_index,apparent_temperature&hourly=temperature_2m,weather_code,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset,uv_index_max,precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=7` |
| **Returns** | `Map<String, dynamic>?` |

```json
{
  "current": {
    "temperature_2m": 22.5,
    "weather_code": 3,
    "wind_speed_10m": 12.0,
    "wind_direction_10m": 180,
    "relative_humidity_2m": 65,
    "uv_index": 4.2,
    "apparent_temperature": 21.0
  },
  "hourly": {
    "temperature_2m": [21, 22, "..."],
    "weather_code": [3, 2, "..."],
    "precipitation_probability": [10, 20, "..."]
  },
  "daily": {
    "temperature_2m_max": [25, 26, "..."],
    "temperature_2m_min": [15, 14, "..."],
    "weather_code": [3, 1, "..."],
    "sunrise": ["2026-03-25T06:12", "..."],
    "sunset": ["2026-03-25T18:05", "..."],
    "uv_index_max": [6, 5, "..."],
    "precipitation_probability_max": [30, 10, "..."],
    "wind_speed_10m_max": [20, 15, "..."]
  }
}
```

---

## 2. Crypto Prices — CoinGecko

| Method | `Api.crypto()` |
|--------|----------------|
| **URL** | `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd&include_24hr_change=true` |
| **Returns** | `Map<String, dynamic>?` |

```json
{
  "bitcoin":  { "usd": 67234.0, "usd_24h_change": 2.45 },
  "ethereum": { "usd": 3456.0,  "usd_24h_change": -1.2 },
  "solana":   { "usd": 145.0,   "usd_24h_change": 5.1 }
}
```

### Crypto Charts

| Method | URL | Returns |
|--------|-----|---------|
| `Api.btcChart()` | `.../coins/bitcoin/market_chart?vs_currency=usd&days=7` | `List<double>` — 7-day price points |
| `Api.ethChart()` | `.../coins/ethereum/market_chart?vs_currency=usd&days=7` | `List<double>` |
| `Api.solChart()` | `.../coins/solana/market_chart?vs_currency=usd&days=7` | `List<double>` |

---

## 3. News — Reddit JSON API

| Method | `Api.news()` |
|--------|--------------|
| **URLs** | `https://www.reddit.com/r/{sub}/hot.json?limit=20&raw_json=1` × 5 subs: `worldnews`, `technology`, `science`, `business`, `space` |
| **Returns** | `List<Map<String, dynamic>>` — up to 50 articles |

```json
[
  {
    "title": "...",
    "url": "https://...",
    "thumbnail": "https://...",
    "score": 12345,
    "author": "user123",
    "subreddit": "worldnews",
    "category": "World",
    "num_comments": 456,
    "created_utc": 1711324800,
    "domain": "reuters.com",
    "selftext": "...",
    "permalink": "/r/worldnews/comments/..."
  }
]
```

---

## 4. TV Shows — TVMaze

### Popular + Airing Today

| Method | `Api.shows(countryCode)` |
|--------|--------------------------|
| **URLs** | `https://api.tvmaze.com/shows?page=0` + `https://api.tvmaze.com/schedule?country={code}&date={today}` + `https://api.tvmaze.com/schedule/web?date={today}` |
| **Returns** | `List<dynamic>` — `[popular[], airing[]]` |

### Latest Shows

| Method | `Api.latestShows(countryCode)` |
|--------|-------------------------------|
| **URLs** | `https://api.tvmaze.com/schedule?country={code}` + `https://api.tvmaze.com/schedule/web` |
| **Returns** | `List<dynamic>` — up to 20 airing entries |

Each airing entry:
```json
{
  "show": { "id": 1, "name": "...", "image": {}, "rating": {"average": 8.5}, "genres": [], "type": "Scripted" },
  "episode": { "name": "Pilot", "season": 1, "number": 1, "airtime": "20:00" }
}
```

---

## 5. Culinary — TheMealDB

| Method | `Api.meal()` |
|--------|--------------|
| **URL** | `https://www.themealdb.com/api/json/v1/1/random.php` |
| **Returns** | `Map<String, dynamic>?` |

```json
{
  "strMeal": "Pasta Carbonara",
  "strMealThumb": "https://...",
  "strCategory": "Pasta",
  "strArea": "Italian",
  "strInstructions": "...",
  "strIngredient1": "Spaghetti",
  "strMeasure1": "200g"
}
```

---

## 6. Quotes — ZenQuotes

| Method | `Api.quote()` |
|--------|---------------|
| **URL** | `https://zenquotes.io/api/random` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "q": "The only way to do great work...", "a": "Steve Jobs", "h": "<blockquote>..." }
```

---

## 7. Geocoding — Nominatim (OpenStreetMap)

| Method | URL | Returns |
|--------|-----|---------|
| `Api.geocode(query)` | `https://nominatim.openstreetmap.org/search?q={query}&format=json&addressdetails=1&limit=6` | `List<Map>` — `{display_name, lat, lon, address}` |
| `Api.reverseGeocode(lat, lng)` | `https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lng}&format=json&addressdetails=1&zoom=3` | `String?` — country name |

---

## 8. Google Places (New API v1) 🔑

> Requires `_googleKey`. Falls back to Nominatim if unconfigured.

| Method | URL | Returns |
|--------|-----|---------|
| `Api.googleAutocomplete(query)` | `POST https://places.googleapis.com/v1/places:autocomplete` | `List<Map>` — `{place_id, description, structured_formatting}` |
| `Api.googlePlaceDetails(placeId)` | `https://places.googleapis.com/v1/places/{placeId}` | `Map?` — `{geometry: {location: {lat, lng}}, formatted_address, address_components[]}` |

---

## 9. Routing — OSRM

| Method | `Api.route(fromLat, fromLng, toLat, toLng)` |
|--------|---------------------------------------------|
| **URL** | `https://router.project-osrm.org/route/v1/driving/{lng},{lat};{lng},{lat}?overview=full&geometries=geojson&steps=true` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "routes": [{ "distance": 12345, "duration": 600, "geometry": { "coordinates": [] }, "legs": [{ "steps": [] }] }] }
```

---

## 10. Trivia — Open Trivia DB

| Method | URL | Returns |
|--------|-----|---------|
| `Api.scienceQuiz()` | `https://opentdb.com/api.php?amount=1&category=17&type=multiple` | `Map?` — science & nature |
| `Api.dailyTrivia()` | `https://opentdb.com/api.php?amount=1&type=multiple` | `Map?` — general knowledge |

```json
{ "question": "...", "correct_answer": "...", "incorrect_answers": ["...", "...", "..."], "category": "...", "difficulty": "medium" }
```

---

## 11. Exchange Rates — ExchangeRate-API

| Method | `Api.exchangeRates()` |
|--------|----------------------|
| **URL** | `https://open.er-api.com/v6/latest/USD` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "result": "success", "base_code": "USD", "rates": { "EUR": 0.92, "GBP": 0.79, "ZAR": 18.5 } }
```

---

## 12. World Bank Indicators

| Method | `Api.worldBank(countryIso3)` |
|--------|------------------------------|
| **URLs** | `https://api.worldbank.org/v2/country/{iso3}/indicator/{id}?format=json&per_page=10&date=2015:2024` × 6 indicators |
| **Returns** | `Map<String, dynamic>?` |

Indicators: GDP, population, unemployment, inflation, CO2, life expectancy.

```json
{
  "gdp": 4.19e11, "gdpYear": "2022",
  "population": 60000000, "populationYear": "2023",
  "unemployment": 32.9, "inflation": 6.9,
  "co2": 7.5, "lifeExpectancy": 64.9,
  "countryCode": "ZAF"
}
```

---

## 13. REST Countries

| Method | URL | Returns |
|--------|-----|---------|
| `Api.restCountriesList()` | `https://restcountries.com/v3.1/all?fields=cca3,name,flags,capital,region,population` | `List<Map>` — `{cca3, name, official, flag, capital, region, population}` |
| `Api.restCountryDetail(cca3)` | `https://restcountries.com/v3.1/alpha/{cca3}?fields=...` (2 calls) | `Map?` — full detail incl. currencies, languages, borders, timezones |
| `Api.countrySpotlight()` | `https://restcountries.com/v3.1/all?fields=name,flags,capital,region,subregion,population,area,languages,currencies,timezones` | `Map` — deterministic daily pick |

---

## 14. Bored / Activity — Bored API

| Method | `Api.boredActivity()` |
|--------|----------------------|
| **URLs** | `https://bored.api.lewagon.com/api/activity` (fallback: `https://www.boredapi.com/api/activity`) |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "activity": "Learn a new recipe", "type": "cooking", "participants": 1, "price": 0.0 }
```

---

## 15. Sunrise / Sunset

| Method | `Api.sunriseSunset(lat, lng)` |
|--------|------------------------------|
| **URL** | `https://api.sunrise-sunset.org/json?lat={lat}&lng={lng}&formatted=0` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "sunrise": "2026-03-25T04:12:00+00:00", "sunset": "2026-03-25T16:05:00+00:00", "solar_noon": "...", "day_length": 42780 }
```

---

## 16. Advice Slip

| Method | `Api.adviceSlip()` |
|--------|-------------------|
| **URL** | `https://api.adviceslip.com/advice` |
| **Returns** | `String?` — the advice text |

---

## 17. Books — Open Library

| Method | `Api.openLibrary(query)` |
|--------|--------------------------|
| **URL** | `https://openlibrary.org/search.json?q={query}&limit=8&fields=title,author_name,first_publish_year,cover_i,number_of_pages_median,ratings_average,edition_count` |
| **Returns** | `List<Map<String, dynamic>>` |

```json
[{ "title": "...", "author_name": ["..."], "first_publish_year": 2020, "cover_i": 12345, "ratings_average": 4.2 }]
```

---

## 18. Air Quality — Open-Meteo

| Method | `Api.airQuality(lat, lng)` |
|--------|---------------------------|
| **URL** | `https://air-quality-api.open-meteo.com/v1/air-quality?latitude={lat}&longitude={lng}&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,uv_index,european_aqi,us_aqi&timezone=auto` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "current": { "pm10": 15.2, "pm2_5": 8.1, "carbon_monoxide": 200, "nitrogen_dioxide": 12, "ozone": 45, "european_aqi": 25, "us_aqi": 42 } }
```

---

## 19. Deck of Cards

| Method | `Api.deckOfCards(count)` |
|--------|-------------------------|
| **URLs** | `https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1` then `https://deckofcardsapi.com/api/deck/{id}/draw/?count={n}` |
| **Returns** | `Map<String, dynamic>?` |

```json
{ "success": true, "deck_id": "abc123", "cards": [{ "code": "AS", "image": "https://...", "value": "ACE", "suit": "SPADES" }], "remaining": 47 }
```

---

## 20. Ocean / Marine — Open-Meteo Marine

| Method | `Api.oceanMarine(lat, lng)` |
|--------|----------------------------|
| **URLs** | `https://marine-api.open-meteo.com/v1/marine?...&current=wave_height,wave_direction,wave_period,...&daily=wave_height_max,wave_period_max` + SST hourly call |
| **Returns** | `Map<String, dynamic>?` |

```json
{
  "current": {
    "wave_height": 1.5, "wave_direction": 220, "wave_period": 8.2,
    "wind_wave_height": 0.8, "swell_wave_height": 1.2,
    "ocean_current_velocity": 0.3, "ocean_current_direction": 180,
    "sea_surface_temperature": 18.5
  },
  "daily": { "wave_height_max": [2.0], "wave_period_max": [9.0] }
}
```

> Auto-retries nearby coastal offsets if inland coordinates return null.

---

## 21. Space & Astronomy

| Method | URL | Returns |
|--------|-----|---------|
| `Api.issPosition()` | `https://api.wheretheiss.at/v1/satellites/25544` | `Map?` — `{latitude, longitude, altitude, velocity, visibility}` |
| `Api.nearEarthObjects()` | `https://api.nasa.gov/neo/rest/v1/feed?start_date={today}&end_date={today}&api_key=DEMO_KEY` | `Map?` — `{count, objects[]}` |
| `Api.exoplanets()` | `https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=...&format=json&maxrec=8` | `List<Map>` — `{pl_name, hostname, discoverymethod, disc_year, pl_orbper, pl_rade, pl_bmasse, sy_dist}` |

---

## 22. EV Chargers — OpenStreetMap Overpass

| Method | `Api.evChargers(lat, lng)` |
|--------|---------------------------|
| **URL** | `POST https://overpass-api.de/api/interpreter` (amenity=charging_station, 30 km radius) |
| **Returns** | `Map<String, dynamic>` |

```json
{
  "count": 5,
  "stations": [{
    "name": "Charging Hub",
    "operator": "...", "network": "...",
    "capacity": "4", "socket_types": ["Type 2", "CCS"],
    "fee": "yes", "opening_hours": "24/7",
    "lat": -33.92, "lng": 18.42
  }]
}
```

---

## 23. AI Models — Hugging Face

| Method | `Api.aiModels()` |
|--------|------------------|
| **URL** | `https://huggingface.co/api/models?sort=trendingScore&direction=-1&limit=5` |
| **Returns** | `Map<String, dynamic>` |

```json
{ "models": [{ "name": "llama-3", "author": "meta-llama", "pipeline": "text-generation", "likes": 12345, "downloads": 9999999 }] }
```

---

## 24. Fun Facts — Multiple APIs

| Method | `Api.voiceAi()` |
|--------|-----------------|
| **URLs** | `https://uselessfacts.jsph.pl/api/v2/facts/random` (x2), `https://catfact.ninja/fact`, `https://meowfacts.herokuapp.com/` |
| **Returns** | `Map<String, dynamic>` |

```json
{ "facts": [{ "emoji": "brain-emoji", "text": "A random fact..." }, { "emoji": "cat-emoji", "text": "Cats sleep 70%..." }] }
```

---

## 25. On This Day — Wikimedia

| Method | URL | Returns |
|--------|-----|---------|
| `Api.onThisDay()` | `https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/all/{MM}/{DD}` | `Map` — `{events: [{year, text, type}], date}` |
| `Api.dayInScience()` | `https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/events/{MM}/{DD}` | `Map` — `{events: [{year, text}], date}` (filtered to science keywords) |

---

## 26. Word of the Day — Free Dictionary API

| Method | `Api.wordOfDay()` |
|--------|-------------------|
| **URL** | `https://api.dictionaryapi.dev/api/v2/entries/en/{word}` |
| **Returns** | `Map<String, dynamic>` |

```json
{ "word": "serendipity", "phonetic": "/ser.en.dip.e.ti/", "partOfSpeech": "noun", "definition": "...", "example": "..." }
```

---

## 27. Language Phrase

| Method | `Api.languagePhrase()` |
|--------|------------------------|
| **URL** | *(local curated list — no API call)* |
| **Returns** | `Map<String, dynamic>` — `{phrase, meaning, language, flag}` |

---

## 28. SA Fuel Prices

| Method | `Api.saFuelPrices()` |
|--------|----------------------|
| **URL** | `https://api.allorigins.win/raw?url=...globalpetrolprices.com/...` (fallback: curated data) |
| **Returns** | `Map<String, dynamic>` |

```json
{ "petrol95": "R25.35", "petrol93": "R25.01", "diesel50": "R23.12", "effective": "March 2026", "source": "Dept. of Mineral Resources & Energy" }
```

---

## 29. Load Shedding — Eskom

| Method | `Api.loadShedding()` |
|--------|----------------------|
| **URLs** | `https://developer.sepush.co.za/business/2.0/status` then fallback: `https://loadshedding.eskom.co.za/LoadShedding/GetStatus` |
| **Returns** | `Map<String, dynamic>` — `{stage, source, note}` |

---

## 30. Riddle of the Day

| Method | `Api.riddleOfDay()` |
|--------|---------------------|
| **URL** | `https://riddles-api.vercel.app/random` (fallback: curated list) |
| **Returns** | `Map<String, dynamic>` — `{riddle, answer}` |

---

## 31. Random Animal

| Method | `Api.randomAnimal()` |
|--------|----------------------|
| **URLs** | `https://dog.ceo/api/breeds/image/random`, `https://catfact.ninja/fact`, `https://dogapi.dog/api/v2/facts?limit=1`, `https://api.thecatapi.com/v1/images/search` |
| **Returns** | `Map<String, dynamic>` — `{image, fact, animal}` |

---

## 32. Tech Products — Hacker News (Firebase)

| Method | `Api.techProducts()` |
|--------|----------------------|
| **URLs** | `https://hacker-news.firebaseio.com/v0/topstories.json` then `.../item/{id}.json` (x6) |
| **Returns** | `List<Map<String, dynamic>>` |

```json
[{ "title": "Show HN: ...", "url": "https://...", "score": 500, "by": "user", "comments": 120, "time": 1711324800 }]
```

---

## 33. Sports — TheSportsDB

| Method | `Api.sportsEvents(countryName)` |
|--------|--------------------------------|
| **URLs** | `https://www.thesportsdb.com/api/v1/json/3/search_all_leagues.php?c={country}` then `.../eventspastleague.php?id={id}` + `.../eventsnextleague.php?id={id}` per league |
| **Returns** | `Map<String, dynamic>` |

```json
{
  "country": "South Africa",
  "leagues": ["Premier Soccer League"],
  "results": [{ "event": "...", "sport": "Soccer", "home": "...", "away": "...", "homeScore": "2", "awayScore": "1", "date": "2026-03-20" }],
  "upcoming": [{ "event": "...", "sport": "Soccer", "home": "...", "away": "...", "date": "2026-03-28", "time": "15:00" }]
}
```

---

## Summary

| # | Service | Key | Methods |
|---|---------|:---:|---------|
| 1 | Open-Meteo Weather | - | `weather` |
| 2 | CoinGecko | - | `crypto`, `btcChart`, `ethChart`, `solChart` |
| 3 | Reddit | - | `news` |
| 4 | TVMaze | - | `shows`, `latestShows` |
| 5 | TheMealDB | - | `meal` |
| 6 | ZenQuotes | - | `quote` |
| 7 | Nominatim | - | `geocode`, `reverseGeocode` |
| 8 | Google Places | Yes | `googleAutocomplete`, `googlePlaceDetails` |
| 9 | OSRM | - | `route` |
| 10 | Open Trivia DB | - | `scienceQuiz`, `dailyTrivia` |
| 11 | ExchangeRate-API | - | `exchangeRates` |
| 12 | World Bank | - | `worldBank` |
| 13 | REST Countries | - | `restCountriesList`, `restCountryDetail`, `countrySpotlight` |
| 14 | Bored API | - | `boredActivity` |
| 15 | Sunrise-Sunset | - | `sunriseSunset` |
| 16 | Advice Slip | - | `adviceSlip` |
| 17 | Open Library | - | `openLibrary` |
| 18 | Open-Meteo Air Quality | - | `airQuality` |
| 19 | Deck of Cards | - | `deckOfCards` |
| 20 | Open-Meteo Marine | - | `oceanMarine` |
| 21 | Where The ISS At | - | `issPosition` |
| 22 | NASA NEO | - | `nearEarthObjects` |
| 23 | NASA Exoplanet Archive | - | `exoplanets` |
| 24 | Overpass (OSM) | - | `evChargers` |
| 25 | Hugging Face | - | `aiModels` |
| 26 | Useless Facts / Cat Facts / Meow Facts | - | `voiceAi` |
| 27 | Wikimedia | - | `onThisDay`, `dayInScience` |
| 28 | Free Dictionary | - | `wordOfDay` |
| 29 | *(local)* | - | `languagePhrase` |
| 30 | Global Petrol Prices | - | `saFuelPrices` |
| 31 | Eskom / EskomSePush | - | `loadShedding` |
| 32 | Riddles API | - | `riddleOfDay` |
| 33 | Dog CEO / Cat API / Dog API | - | `randomAnimal` |
| 34 | Hacker News (Firebase) | - | `techProducts` |
| 35 | TheSportsDB | - | `sportsEvents` |

**Total: 33 API methods · ~25 distinct services · ~45+ HTTP endpoints**