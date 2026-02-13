import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as quill_delta;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initDemoDataIfNeeded();
  runApp(const EthosNoteApp());
}

Future<void> _initDemoDataIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('demo_data_loaded') == true) return;

  // ── Demo Profile ──
  // Generate a small 64x64 avatar PNG in memory
  final avatarBase64 = _generateDemoAvatarBase64();
  final profile = UserProfile(
    nome: 'Marco',
    cognome: 'Rossi',
    email: 'marco.rossi@email.it',
    dataNascita: DateTime(1992, 7, 15),
    isPro: true,
    photoBase64: avatarBase64,
    religione: 'Cattolica',
  );
  await prefs.setString('user_profile', json.encode(profile.toJson()));

  // ── Demo Calendar Events ──
  final now = DateTime.now();
  final events = <String, List<Map<String, dynamic>>>{};

  void addEvent(DateTime date, String title, int startH, int startM, int endH, int endM, {String calendar = 'Personale'}) {
    final key = '${date.year}-${date.month}-${date.day}';
    final event = CalendarEventFull(
      title: title,
      startTime: DateTime(date.year, date.month, date.day, startH, startM),
      endTime: DateTime(date.year, date.month, date.day, endH, endM),
      calendar: calendar,
    ).toJson();
    events.putIfAbsent(key, () => []).add(event);
  }

  // Today
  addEvent(now, 'Riunione di lavoro', 9, 30, 11, 0, calendar: 'Lavoro');
  addEvent(now, 'Palestra', 18, 0, 19, 30);
  // Tomorrow
  final tomorrow = now.add(const Duration(days: 1));
  addEvent(tomorrow, 'Pranzo con Anna', 12, 30, 14, 0);
  addEvent(tomorrow, 'Dentista', 16, 0, 17, 0);
  // Day after tomorrow
  final dopodomani = now.add(const Duration(days: 2));
  addEvent(dopodomani, 'Call cliente Milano', 10, 0, 10, 45, calendar: 'Lavoro');
  // 3 days from now
  final fra3 = now.add(const Duration(days: 3));
  addEvent(fra3, 'Corso di inglese', 17, 0, 18, 30);
  addEvent(fra3, 'Cena con amici', 20, 30, 23, 0);
  // 5 days
  final fra5 = now.add(const Duration(days: 5));
  addEvent(fra5, 'Spesa settimanale', 10, 0, 11, 30);
  addEvent(fra5, 'Cinema: nuovo film', 21, 0, 23, 15);
  // Past event yesterday
  final ieri = now.subtract(const Duration(days: 1));
  addEvent(ieri, 'Consegna progetto', 14, 0, 16, 0, calendar: 'Lavoro');
  // Next week
  final settProx = now.add(const Duration(days: 7));
  addEvent(settProx, 'Visita medica', 8, 30, 9, 30);
  addEvent(settProx, 'Aperitivo colleghi', 18, 30, 20, 0, calendar: 'Lavoro');

  await prefs.setString('calendar_events_full', json.encode(events));

  // ── Demo Pro Notes ──
  final proNotes = <ProNote>[
    ProNote(
      title: 'Lista della spesa',
      content: 'Pane integrale\nLatte fresco\nPomodori San Marzano\nMozzarella di bufala\nBasilico fresco\nPasta De Cecco\nOlio EVO\nParmigiano 24 mesi',
      folder: 'Personale',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    ProNote(
      title: 'Idee progetto app',
      content: 'Feature da implementare:\n- Sincronizzazione cloud\n- Notifiche push per eventi\n- Widget per la home screen\n- Tema personalizzabile con colori\n- Export PDF delle note\n- Integrazione con Google Calendar',
      folder: 'Lavoro',
      createdAt: now.subtract(const Duration(days: 5)),
    ),
    ProNote(
      title: 'Ricetta Carbonara',
      content: 'Ingredienti (4 persone):\n- 400g spaghetti\n- 200g guanciale\n- 6 tuorli d\'uovo\n- 100g pecorino romano\n- Pepe nero q.b.\n\nPreparazione:\n1. Tagliare il guanciale a listarelle\n2. Rosolare in padella senza olio\n3. Mescolare tuorli, pecorino e pepe\n4. Cuocere la pasta al dente\n5. Mantecare fuori dal fuoco con la crema di uova',
      folder: 'Personale',
      createdAt: now.subtract(const Duration(days: 10)),
    ),
    ProNote(
      title: 'Meeting notes - Q1 Review',
      content: 'Partecipanti: Marco, Giulia, Alessandro, Sara\n\nPunti discussi:\n- Obiettivi Q1 raggiunti al 87%\n- Budget marketing da rivedere\n- Nuova campagna social media\n- Assunzione developer senior\n\nAction items:\n- Marco: preparare report vendite\n- Giulia: contattare agenzia PR\n- Alessandro: colloqui candidati entro venerdì',
      folder: 'Lavoro',
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    ProNote(
      title: 'Libri da leggere 2026',
      content: '1. "Il nome della rosa" - Umberto Eco\n2. "Sapiens" - Yuval Noah Harari\n3. "Atomic Habits" - James Clear\n4. "L\'arte della guerra" - Sun Tzu\n5. "Clean Code" - Robert C. Martin\n6. "Il Piccolo Principe" - Saint-Exupéry',
      folder: 'Generale',
      createdAt: now.subtract(const Duration(days: 15)),
    ),
    ProNote(
      title: 'Workout settimanale',
      content: 'Lunedì - Petto e tricipiti\nMartedì - Schiena e bicipiti\nMercoledì - Riposo / Cardio leggero\nGiovedì - Spalle e addominali\nVenerdì - Gambe e glutei\nSabato - HIIT 30 min\nDomenica - Riposo completo\n\nNote: aumentare peso squat di 5kg la prossima settimana',
      folder: 'Personale',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];
  await prefs.setStringList(
    'pro_notes',
    proNotes.map((n) => json.encode(n.toJson())).toList(),
  );

  // ── Demo Flash Notes ──
  final flashNotes = <FlashNote>[
    FlashNote(content: 'Comprare regalo compleanno Laura - 20 febbraio', createdAt: now.subtract(const Duration(hours: 2))),
    FlashNote(content: 'Chiamare idraulico per rubinetto cucina', createdAt: now.subtract(const Duration(hours: 5))),
    FlashNote(content: 'Password WiFi ufficio: EthosNet2026!', createdAt: now.subtract(const Duration(days: 1))),
    FlashNote(content: 'Palestra domani ore 18:30 - non dimenticare asciugamano', createdAt: now.subtract(const Duration(days: 1))),
    FlashNote(content: 'Prenotare ristorante sabato sera per 6 persone', createdAt: now.subtract(const Duration(days: 2))),
    FlashNote(content: 'IBAN Giulia: IT60X054281101000000123456', createdAt: now.subtract(const Duration(days: 3))),
    FlashNote(content: 'Volo Roma-Milano 14 marzo - Alitalia AZ1020 ore 7:45', createdAt: now.subtract(const Duration(days: 3))),
    FlashNote(content: 'Idea: app per tracciare consumi energia in casa', createdAt: now.subtract(const Duration(days: 4))),
    FlashNote(content: 'Controllare scadenza assicurazione auto - fine marzo', createdAt: now.subtract(const Duration(days: 5))),
    FlashNote(content: 'Film consigliato da Luca: "Perfect Days" di Wim Wenders', createdAt: now.subtract(const Duration(days: 7))),
    FlashNote(content: 'Codice sconto Amazon: SPRING2026 - 15% elettronica', createdAt: now.subtract(const Duration(days: 8))),
    FlashNote(content: 'Riunione condominiale giovedì 20:00 - portare preventivo', createdAt: now.subtract(const Duration(days: 10))),
  ];
  await prefs.setStringList(
    'flash_notes_v2',
    flashNotes.map((n) => json.encode(n.toJson())).toList(),
  );

  // ── Calendar Settings: enable weather for demo ──
  final calSettings = const CalendarSettings(
    showWeather: true,
    weatherCity: 'Roma',
    showHoroscope: true,
  );
  await calSettings.save();

  await prefs.setBool('demo_data_loaded', true);
}

/// Generate a small 48x48 PNG avatar with initials "MR" as base64
String _generateDemoAvatarBase64() {
  // Minimal valid 1x1 indigo PNG - the app will show initials over it
  // Using a pre-built tiny PNG (8x8 solid indigo color)
  // For a real avatar we generate raw PNG bytes
  final width = 8;
  final height = 8;

  // PNG file structure
  final bytes = <int>[];

  // PNG signature
  bytes.addAll([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  final ihdr = <int>[
    0, 0, 0, width, // width
    0, 0, 0, height, // height
    8, // bit depth
    2, // color type (RGB)
    0, 0, 0, // compression, filter, interlace
  ];
  bytes.addAll(_pngChunk('IHDR', ihdr));

  // IDAT chunk - raw image data
  // Each row: filter byte (0) + RGB pixels
  final rawData = <int>[];
  for (int y = 0; y < height; y++) {
    rawData.add(0); // no filter
    for (int x = 0; x < width; x++) {
      // Indigo gradient
      rawData.addAll([99, 102, 241]); // #6366F1
    }
  }

  // Compress with zlib (deflate)
  // Simple: store block (no compression)
  final deflated = <int>[
    0x78, 0x01, // zlib header
  ];
  // Split into blocks of max 65535
  int offset = 0;
  while (offset < rawData.length) {
    final remaining = rawData.length - offset;
    final blockSize = remaining > 65535 ? 65535 : remaining;
    final isLast = (offset + blockSize) >= rawData.length;
    deflated.add(isLast ? 0x01 : 0x00); // BFINAL + BTYPE=00 (stored)
    deflated.add(blockSize & 0xFF);
    deflated.add((blockSize >> 8) & 0xFF);
    deflated.add((~blockSize) & 0xFF);
    deflated.add(((~blockSize) >> 8) & 0xFF);
    deflated.addAll(rawData.sublist(offset, offset + blockSize));
    offset += blockSize;
  }
  // Adler32
  int a = 1, b = 0;
  for (final byte in rawData) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  final adler = (b << 16) | a;
  deflated.add((adler >> 24) & 0xFF);
  deflated.add((adler >> 16) & 0xFF);
  deflated.add((adler >> 8) & 0xFF);
  deflated.add(adler & 0xFF);

  bytes.addAll(_pngChunk('IDAT', deflated));

  // IEND chunk
  bytes.addAll(_pngChunk('IEND', []));

  return base64Encode(Uint8List.fromList(bytes));
}

List<int> _pngChunk(String type, List<int> data) {
  final chunk = <int>[];
  // Length (4 bytes big-endian)
  final len = data.length;
  chunk.addAll([(len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
  // Type
  final typeBytes = type.codeUnits;
  chunk.addAll(typeBytes);
  // Data
  chunk.addAll(data);
  // CRC32
  final crcData = [...typeBytes, ...data];
  final crc = _crc32(crcData);
  chunk.addAll([(crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF]);
  return chunk;
}

int _crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}

class EthosNoteApp extends StatefulWidget {
  const EthosNoteApp({super.key});

  @override
  State<EthosNoteApp> createState() => _EthosNoteAppState();
}

class _EthosNoteAppState extends State<EthosNoteApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('dark_mode', isDark);
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: colorScheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 65,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ethos Note',
      localizationsDelegates: const [
        quill.FlutterQuillLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onThemeChanged: toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

class UserProfile {
  String? nome;
  String? cognome;
  String? email;
  DateTime? dataNascita;
  bool isPro;
  String? photoPath;
  String? photoBase64;
  bool googleCalendarConnected;
  bool googleDriveConnected;
  bool geminiConnected;
  String backupMode;
  String religione;

  UserProfile({
    this.nome,
    this.cognome,
    this.email,
    this.dataNascita,
    this.isPro = false,
    this.photoPath,
    this.photoBase64,
    this.googleCalendarConnected = false,
    this.googleDriveConnected = false,
    this.geminiConnected = false,
    this.backupMode = 'local',
    this.religione = 'Cattolica',
  });

  int? get eta {
    if (dataNascita == null) return null;
    final now = DateTime.now();
    int age = now.year - dataNascita!.year;
    if (now.month < dataNascita!.month ||
        (now.month == dataNascita!.month && now.day < dataNascita!.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'dataNascita': dataNascita?.toIso8601String(),
      'isPro': isPro,
      'photoPath': photoPath,
      'photoBase64': photoBase64,
      'googleCalendarConnected': googleCalendarConnected,
      'googleDriveConnected': googleDriveConnected,
      'geminiConnected': geminiConnected,
      'backupMode': backupMode,
      'religione': religione,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nome: json['nome'],
      cognome: json['cognome'],
      email: json['email'],
      dataNascita: json['dataNascita'] != null
          ? DateTime.parse(json['dataNascita'])
          : null,
      isPro: json['isPro'] ?? false,
      photoPath: json['photoPath'],
      photoBase64: json['photoBase64'],
      googleCalendarConnected: json['googleCalendarConnected'] ?? false,
      googleDriveConnected: json['googleDriveConnected'] ?? false,
      geminiConnected: json['geminiConnected'] ?? false,
      backupMode: json['backupMode'] ?? 'local',
      religione: json['religione'] ?? 'Cattolica',
    );
  }

  String get initials {
    if (nome == null && cognome == null) return '?';
    final n = nome?.isNotEmpty == true ? nome![0] : '';
    final c = cognome?.isNotEmpty == true ? cognome![0] : '';
    return '$n$c'.toUpperCase();
  }

  String get fullName {
    if (nome == null && cognome == null) return 'Ospite';
    return '${nome ?? ''} ${cognome ?? ''}'.trim();
  }

  bool get hasAccount => email != null && email!.isNotEmpty;

  Uint8List? get photoBytes {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      return base64Decode(photoBase64!);
    }
    return null;
  }
}

class CalendarEventFull {
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String calendar;
  final String? reminder;
  final String? preset;
  final String? attachmentPath;
  final String? notes;

  CalendarEventFull({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.calendar = 'Personale',
    this.reminder,
    this.preset,
    this.attachmentPath,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'calendar': calendar,
      'reminder': reminder,
      'preset': preset,
      'attachmentPath': attachmentPath,
      'notes': notes,
    };
  }

  factory CalendarEventFull.fromJson(Map<String, dynamic> json) {
    return CalendarEventFull(
      title: json['title'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      calendar: json['calendar'] ?? 'Personale',
      reminder: json['reminder'],
      preset: json['preset'],
      attachmentPath: json['attachmentPath'],
      notes: json['notes'],
    );
  }
}

class Holidays {
  static Map<String, List<Holiday>> getHolidays(String religione) {
    final base = <Holiday>[
      Holiday(1, 1, '🎉', 'Capodanno'),
      Holiday(1, 6, '⭐', 'Epifania'),
      Holiday(4, 25, '🇮🇹', 'Liberazione'),
      Holiday(5, 1, '🛠️', 'Festa Lavoro'),
      Holiday(6, 2, '🇮🇹', 'Repubblica'),
      Holiday(8, 15, '⛱️', 'Ferragosto'),
      Holiday(11, 1, '🕯️', 'Ognissanti'),
      Holiday(12, 8, '🎄', 'Immacolata'),
      Holiday(12, 25, '🎄', 'Natale'),
      Holiday(12, 26, '🎁', 'S. Stefano'),
    ];

    if (religione == 'Cattolica') {
      base.add(Holiday(4, 20, '🐣', 'Pasqua'));
      base.add(Holiday(4, 21, '🐣', 'Pasquetta'));
    } else if (religione == 'Ebraica') {
      base.add(Holiday(9, 25, '🕎', 'Rosh Hashanah'));
      base.add(Holiday(12, 25, '🕎', 'Hanukkah'));
    } else if (religione == 'Islamica') {
      base.add(Holiday(4, 10, '🌙', 'Eid al-Fitr'));
      base.add(Holiday(6, 16, '🌙', 'Eid al-Adha'));
    }

    Map<String, List<Holiday>> result = {};
    for (var h in base) {
      final key = '${h.month}-${h.day}';
      result[key] = result[key] ?? [];
      result[key]!.add(h);
    }
    return result;
  }
}

class Holiday {
  final int month;
  final int day;
  final String emoji;
  final String name;

  Holiday(this.month, this.day, this.emoji, this.name);
}

String getZodiacSignFromDate(int month, int day, {String mode = 'icon_and_text'}) {
  // Accurate zodiac based on actual date ranges
  String segno;
  String icon;
  if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) { segno = 'Ariete'; icon = '♈'; }
  else if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) { segno = 'Toro'; icon = '♉'; }
  else if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) { segno = 'Gemelli'; icon = '♊'; }
  else if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) { segno = 'Cancro'; icon = '♋'; }
  else if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) { segno = 'Leone'; icon = '♌'; }
  else if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) { segno = 'Vergine'; icon = '♍'; }
  else if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) { segno = 'Bilancia'; icon = '♎'; }
  else if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) { segno = 'Scorpione'; icon = '♏'; }
  else if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) { segno = 'Sagittario'; icon = '♐'; }
  else if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) { segno = 'Capricorno'; icon = '♑'; }
  else if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) { segno = 'Acquario'; icon = '♒'; }
  else { segno = 'Pesci'; icon = '♓'; }

  switch (mode) {
    case 'icon_only': return icon;
    case 'text_only': return segno;
    case 'icon_and_text':
    default: return '$icon $segno';
  }
}

// ─── Horoscope Data ─────────────────────────────────────────────────────────

class HoroscopeData {
  final String segno;
  final String testo;
  final DateTime fetchedAt;

  HoroscopeData({required this.segno, required this.testo, required this.fetchedAt});

  bool get isStale => DateTime.now().difference(fetchedAt).inHours > 12;

  Map<String, dynamic> toJson() => {
    'segno': segno,
    'testo': testo,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory HoroscopeData.fromJson(Map<String, dynamic> json) => HoroscopeData(
    segno: json['segno'],
    testo: json['testo'],
    fetchedAt: DateTime.parse(json['fetchedAt']),
  );

  static Future<HoroscopeData?> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('horoscope_cache');
    if (jsonStr != null) {
      final data = HoroscopeData.fromJson(json.decode(jsonStr));
      if (!data.isStale) return data;
    }
    return null;
  }

  Future<void> saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('horoscope_cache', json.encode(toJson()));
  }
}

Future<HoroscopeData?> fetchOroscopo(String segno) async {
  // Check cache first
  final cached = await HoroscopeData.loadCached();
  if (cached != null && cached.segno.toLowerCase() == segno.toLowerCase()) {
    return cached;
  }

  try {
    final now = DateTime.now();
    const giorniSettimana = ['', 'lunedi', 'martedi', 'mercoledi', 'giovedi', 'venerdi', 'sabato', 'domenica'];
    const mesiIt = ['', 'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
      'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];

    final giorno = giorniSettimana[now.weekday];
    final giornoNumero = now.day;
    final mese = mesiIt[now.month];
    final anno = now.year;

    final url = 'https://www.superguidatv.it/oroscopo-paolo-fox-del-giorno-$giorno-$giornoNumero-$mese-$anno/';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = response.body;
      // Search for the zodiac sign section
      final segnoLower = segno.toLowerCase();
      final patterns = [
        RegExp('oroscopo\\s+paolo\\s+fox\\s+$segnoLower[^<]*</h[23]>\\s*<p>([^<]+)', caseSensitive: false),
        RegExp('$segnoLower[^<]*</h[23]>\\s*<p>([^<]+)', caseSensitive: false),
        RegExp('$segnoLower[^<]*</strong>\\s*[.:–-]?\\s*([^<]+)', caseSensitive: false),
      ];

      String? testo;
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) {
          testo = match.group(1)?.trim();
          if (testo != null && testo.length > 20) break;
          testo = null;
        }
      }

      if (testo != null) {
        // Clean HTML entities
        testo = testo.replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&rsquo;', "'")
            .replaceAll('&lsquo;', "'")
            .replaceAll('&ldquo;', '"')
            .replaceAll('&rdquo;', '"')
            .replaceAll(RegExp(r'&#\d+;'), '')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();

        final data = HoroscopeData(segno: segno, testo: testo, fetchedAt: DateTime.now());
        await data.saveCache();
        return data;
      }
    }
  } catch (_) {
    // fallback
  }

  return null;
}

// ─── Weather Data ───────────────────────────────────────────────────────────

class DailyWeather {
  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;

  DailyWeather({required this.date, required this.weatherCode, required this.tempMax, required this.tempMin});

  String get icon {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '🌤️';
    if (weatherCode <= 48) return '☁️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '❄️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 86) return '❄️';
    if (weatherCode <= 99) return '⛈️';
    return '🌤️';
  }

  String get description {
    if (weatherCode == 0) return 'Sereno';
    if (weatherCode <= 3) return 'Parz. nuvoloso';
    if (weatherCode <= 48) return 'Nuvoloso';
    if (weatherCode <= 57) return 'Pioggerella';
    if (weatherCode <= 67) return 'Pioggia';
    if (weatherCode <= 77) return 'Neve';
    if (weatherCode <= 82) return 'Acquazzone';
    if (weatherCode <= 86) return 'Neve forte';
    if (weatherCode <= 99) return 'Temporale';
    return 'Variabile';
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weatherCode': weatherCode,
    'tempMax': tempMax,
    'tempMin': tempMin,
  };

  factory DailyWeather.fromJson(Map<String, dynamic> json) => DailyWeather(
    date: DateTime.parse(json['date']),
    weatherCode: json['weatherCode'],
    tempMax: (json['tempMax'] as num).toDouble(),
    tempMin: (json['tempMin'] as num).toDouble(),
  );
}

class WeatherData {
  final String city;
  final double lat;
  final double lon;
  final List<DailyWeather> forecast;
  final DateTime fetchedAt;

  WeatherData({required this.city, required this.lat, required this.lon, required this.forecast, required this.fetchedAt});

  bool get isStale => DateTime.now().difference(fetchedAt).inHours > 6;

  DailyWeather? forDay(DateTime day) {
    for (final f in forecast) {
      if (f.date.year == day.year && f.date.month == day.month && f.date.day == day.day) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'city': city,
    'lat': lat,
    'lon': lon,
    'forecast': forecast.map((f) => f.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    city: json['city'],
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    forecast: (json['forecast'] as List).map((f) => DailyWeather.fromJson(f)).toList(),
    fetchedAt: DateTime.parse(json['fetchedAt']),
  );

  static Future<WeatherData?> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('weather_cache');
    if (jsonStr != null) {
      final data = WeatherData.fromJson(json.decode(jsonStr));
      if (!data.isStale) return data;
    }
    return null;
  }

  Future<void> saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_cache', json.encode(toJson()));
  }
}

class WeatherService {
  static Future<({double lat, double lon})?> geocodeCity(String name) async {
    try {
      final url = 'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(name)}&count=1&language=it';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return (lat: (results[0]['latitude'] as num).toDouble(), lon: (results[0]['longitude'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<WeatherData?> fetchWeather(String city, double lat, double lon) async {
    // Check cache first
    final cached = await WeatherData.loadCached();
    if (cached != null && cached.city == city) return cached;

    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
          '&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=Europe/Rome';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daily = data['daily'];
        final dates = (daily['time'] as List).cast<String>();
        final codes = (daily['weathercode'] as List);
        final maxTemps = (daily['temperature_2m_max'] as List);
        final minTemps = (daily['temperature_2m_min'] as List);

        final forecast = <DailyWeather>[];
        for (int i = 0; i < dates.length && i < 7; i++) {
          forecast.add(DailyWeather(
            date: DateTime.parse(dates[i]),
            weatherCode: (codes[i] as num).toInt(),
            tempMax: (maxTemps[i] as num).toDouble(),
            tempMin: (minTemps[i] as num).toDouble(),
          ));
        }

        final weatherData = WeatherData(
          city: city, lat: lat, lon: lon, forecast: forecast, fetchedAt: DateTime.now(),
        );
        await weatherData.saveCache();
        return weatherData;
      }
    } catch (_) {}
    return null;
  }
}

String getZodiacSign(int month, {String mode = 'icon_and_text'}) {
  const icons = {
    1: '♑', 2: '♒', 3: '♓', 4: '♈', 5: '♉', 6: '♊',
    7: '♋', 8: '♌', 9: '♍', 10: '♎', 11: '♏', 12: '♐',
  };
  const names = {
    1: 'Capricorno', 2: 'Acquario', 3: 'Pesci', 4: 'Ariete',
    5: 'Toro', 6: 'Gemelli', 7: 'Cancro', 8: 'Leone',
    9: 'Vergine', 10: 'Bilancia', 11: 'Scorpione', 12: 'Sagittario',
  };
  final icon = icons[month] ?? '';
  final name = names[month] ?? '';
  switch (mode) {
    case 'icon_only':
      return icon;
    case 'text_only':
      return name;
    case 'icon_and_text':
    default:
      return '$icon $name';
  }
}

class _SlideInItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _SlideInItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 50 * index.clamp(0, 8));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  int _refreshKey = 0;
  UserProfile _userProfile = UserProfile();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      setState(() {
        _userProfile = UserProfile.fromJson(json.decode(profileJson));
      });
    }
  }

  Future<void> _saveUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(_userProfile.toJson()));
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          userProfile: _userProfile,
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          onSave: (profile) {
            setState(() {
              _userProfile = profile;
            });
            _saveUserProfile();
          },
        ),
      ),
    ).then((_) {
      // Refresh pages when returning from settings
      setState(() => _refreshKey++);
    });
  }

  // Section accent colors
  static const _sectionColors = [
    Color(0xFFE53935), // Deep Note - red
    Color(0xFF1E88E5), // Calendar - blue
    Color(0xFFFFA726), // Flash Notes - amber
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = _sectionColors[_selectedIndex];

    final pages = [
      const NotesProPage(),
      CalendarPage(religione: _userProfile.religione),
      const FlashNotesPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _openSettings,
            child: CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.12),
              backgroundImage: _userProfile.photoBytes != null
                  ? MemoryImage(_userProfile.photoBytes!)
                  : null,
              child: _userProfile.photoBytes == null
                  ? Text(
                      _userProfile.initials,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        title: const Text('Ethos Note'),
        scrolledUnderElevation: 2,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<String>('${_selectedIndex}_$_refreshKey'),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.note_outlined, color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.note, color: _sectionColors[0]),
            label: 'Deep Note',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined, color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.calendar_today, color: _sectionColors[1]),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined, color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.flash_on, color: _sectionColors[2]),
            label: 'Flash Notes',
          ),
        ],
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  final String religione;

  const CalendarPage({super.key, required this.religione});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<CalendarEventFull>> _events = {};
  late Map<String, List<Holiday>> _holidays;
  CalendarSettings _calSettings = const CalendarSettings();

  // Horoscope
  HoroscopeData? _horoscopeData;
  bool _isLoadingHoroscope = false;

  // Weather
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _holidays = Holidays.getHolidays(widget.religione);
    _loadEvents();
    _loadCalendarSettings();
  }

  Future<void> _loadCalendarSettings() async {
    final settings = await CalendarSettings.load();
    setState(() => _calSettings = settings);
    if (settings.showHoroscope) _loadHoroscope();
    if (settings.showWeather && settings.weatherCity != null && settings.weatherCity!.isNotEmpty) {
      _loadWeather();
    }
  }

  Future<void> _loadHoroscope() async {
    if (_isLoadingHoroscope) return;
    setState(() => _isLoadingHoroscope = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        final profile = UserProfile.fromJson(json.decode(profileJson));
        if (profile.dataNascita != null) {
          final segno = getZodiacSignFromDate(
            profile.dataNascita!.month, profile.dataNascita!.day, mode: 'text_only',
          );
          final data = await fetchOroscopo(segno);
          if (mounted) setState(() => _horoscopeData = data);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHoroscope = false);
  }

  Future<void> _loadWeather() async {
    if (_isLoadingWeather) return;
    setState(() => _isLoadingWeather = true);
    try {
      final city = _calSettings.weatherCity;
      if (city != null && city.isNotEmpty) {
        // Try cache first
        final cached = await WeatherData.loadCached();
        if (cached != null && cached.city == city) {
          if (mounted) setState(() => _weatherData = cached);
        } else {
          final geo = await WeatherService.geocodeCity(city);
          if (geo != null) {
            final data = await WeatherService.fetchWeather(city, geo.lat, geo.lon);
            if (mounted) setState(() => _weatherData = data);
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingWeather = false);
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString('calendar_events_full') ?? '{}';
    final Map<String, dynamic> decoded = json.decode(eventsJson);
    setState(() {
      _events = decoded.map(
        (key, value) => MapEntry(
          key,
          (value as List).map((e) => CalendarEventFull.fromJson(e)).toList(),
        ),
      );
    });
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = _events.map(
      (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('calendar_events_full', json.encode(eventsJson));
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  List<CalendarEventFull> _getEventsForDay(DateTime day) =>
      _events[_dateKey(day)] ?? [];

  void _createEvent() {
    if (_selectedDay == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventEditorPage(
          selectedDate: _selectedDay!,
          onSave: (event) {
            setState(() {
              final key = _dateKey(_selectedDay!);
              _events[key] = [..._getEventsForDay(_selectedDay!), event];
            });
            _saveEvents();
          },
        ),
      ),
    );
  }

  void _deleteEvent(int index) {
    if (_selectedDay == null) return;
    setState(() {
      final key = _dateKey(_selectedDay!);
      _events[key]?.removeAt(index);
      if (_events[key]?.isEmpty ?? false) _events.remove(key);
    });
    _saveEvents();
  }

  Widget _buildCalendarCell(DateTime day, DateTime focusedDay, {bool isOutsideMonth = false}) {
    final isToday = isSameDay(day, DateTime.now());
    final hasEvents = _getEventsForDay(day).isNotEmpty;
    final holidayKey = '${day.month}-${day.day}';
    final holiday = _holidays[holidayKey]?.first;
    final todayColor = _calSettings.todayBorderColor;
    final fontFamily = _calSettings.fontFamily == 'Default' ? null : _calSettings.fontFamily.toLowerCase();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dayStart = DateTime(day.year, day.month, day.day);
    final daysFromToday = dayStart.difference(todayStart).inDays;
    final weather = (_calSettings.showWeather && daysFromToday >= 0 && daysFromToday <= 7)
        ? _weatherData?.forDay(day) : null;

    return Stack(
      children: [
        Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: todayColor, width: 2) : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isOutsideMonth
                      ? _calSettings.calendarColor.withValues(alpha: 0.35)
                      : null,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: _calSettings.dayFontSize,
                  fontFamily: fontFamily,
                ),
              ),
            ),
          ),
        ),
        if (weather != null && !isOutsideMonth)
          Positioned(
            top: 2,
            left: 4,
            child: Text(weather.icon, style: const TextStyle(fontSize: 10)),
          ),
        if (hasEvents)
          const Positioned(
            top: 2,
            right: 8,
            child: Icon(Icons.lightbulb, size: 12, color: Colors.amber),
          ),
        if (holiday != null)
          Positioned(
            bottom: 2,
            right: 8,
            child: Text(holiday.emoji, style: const TextStyle(fontSize: 10)),
          ),
      ],
    );
  }

  TableCalendar _buildTableCalendar(ColorScheme colorScheme, {CalendarFormat format = CalendarFormat.month, double? rowHeight}) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: format,
      rowHeight: rowHeight ?? 52,
      sixWeekMonthsEnforced: _calSettings.showNextMonthPreview,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        if (_calSettings.calendarLayout == 'fullScreen') {
          _showDayEventsBottomSheet(selectedDay);
        }
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _calSettings.calendarLayout == 'fullScreen'
                ? _buildFullScreenCell(day, focusedDay)
                : _buildCalendarCell(day, focusedDay),
        outsideBuilder: _calSettings.showNextMonthPreview
            ? (context, day, focusedDay) =>
                _buildCalendarCell(day, focusedDay, isOutsideMonth: true)
            : null,
        selectedBuilder: (context, day, focusedDay) => Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _calSettings.selectedDayColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _calSettings.calendarLayout == 'fullScreen'
              ? _buildFullScreenCell(day, focusedDay)
              : _buildCalendarCell(day, focusedDay),
        ),
        todayBuilder: (context, day, focusedDay) =>
            _calSettings.calendarLayout == 'fullScreen'
                ? _buildFullScreenCell(day, focusedDay)
                : _buildCalendarCell(day, focusedDay),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          final months = [
            '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
            'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
          ];
          final zodiacSuffix = _calSettings.showZodiac
              ? ' (${getZodiacSign(date.month, mode: _calSettings.zodiacDisplayMode)})'
              : '';
          return '${months[date.month]} ${date.year}$zodiacSuffix';
        },
        titleTextStyle: TextStyle(
          fontSize: _calSettings.headerFontSize,
          fontWeight: FontWeight.bold,
          color: _calSettings.headerColor,
          fontFamily: _calSettings.fontFamily == 'Default' ? null : _calSettings.fontFamily.toLowerCase(),
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: _calSettings.calendarColor, size: 28),
        rightChevronIcon: Icon(Icons.chevron_right, color: _calSettings.calendarColor, size: 28),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: _calSettings.showNextMonthPreview,
        markersMaxCount: 0,
        markerDecoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
        selectedTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: _calSettings.dayFontSize,
        ),
      ),
    );
  }

  Widget _buildFullScreenCell(DateTime day, DateTime focusedDay) {
    final isToday = isSameDay(day, DateTime.now());
    final events = _getEventsForDay(day);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dayStart = DateTime(day.year, day.month, day.day);
    final daysFromNow = dayStart.difference(todayStart).inDays;
    final weather = (_calSettings.showWeather && daysFromNow >= 0 && daysFromNow <= 7)
        ? _weatherData?.forDay(day) : null;
    final todayColor = _calSettings.todayBorderColor;
    final holidayKey = '${day.month}-${day.day}';
    final holiday = _holidays[holidayKey]?.first;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (weather != null) Text(weather.icon, style: const TextStyle(fontSize: 8)),
              const SizedBox(width: 1),
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: todayColor, width: 1.5) : null,
                ),
                child: Center(
                  child: Text('${day.day}', style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? todayColor : null,
                  )),
                ),
              ),
              if (holiday != null) Text(holiday.emoji, style: const TextStyle(fontSize: 8)),
            ],
          ),
          if (events.isNotEmpty) ...[
            ...events.take(2).map((e) => Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: _calSettings.calendarColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                e.title,
                style: const TextStyle(fontSize: 7),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            if (events.length > 2)
              Text('+${events.length - 2}', style: TextStyle(fontSize: 7, color: _calSettings.calendarColor)),
          ],
        ],
      ),
    );
  }

  void _showDayEventsBottomSheet(DateTime day) {
    final events = _getEventsForDay(day);
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (ctx, scrollController) {
            return StatefulBuilder(builder: (ctx, setSheetState) {
              final currentEvents = _getEventsForDay(day);
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${day.day}/${day.month}/${day.year}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${currentEvents.length} event${currentEvents.length == 1 ? 'o' : 'i'}',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedDay = day);
                            _createEvent();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Evento'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: currentEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_note_outlined, size: 48, color: colorScheme.outlineVariant),
                                const SizedBox(height: 8),
                                Text('Nessun evento', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: currentEvents.length,
                            itemBuilder: (ctx, index) {
                              final event = currentEvents[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _calSettings.calendarColor.withValues(alpha: 0.12),
                                  child: Icon(Icons.event, color: _calSettings.calendarColor, size: 20),
                                ),
                                title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${event.startTime.hour}:${event.startTime.minute.toString().padLeft(2, '0')} - ${event.endTime.hour}:${event.endTime.minute.toString().padLeft(2, '0')}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: colorScheme.error,
                                  onPressed: () {
                                    _deleteEvent(index);
                                    setSheetState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            });
          },
        );
      },
    );
  }

  Widget _buildHoroscopeCard() {
    if (!_calSettings.showHoroscope) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: _isLoadingHoroscope
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          : _horoscopeData != null
              ? ExpansionTile(
                  leading: const Text('⭐', style: TextStyle(fontSize: 22)),
                  title: Text(
                    'Oroscopo ${_horoscopeData!.segno}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text('Paolo Fox', style: TextStyle(fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        _horoscopeData!.testo,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  ],
                )
              : ListTile(
                  leading: const Text('⭐', style: TextStyle(fontSize: 22)),
                  title: const Text('Oroscopo non disponibile'),
                  subtitle: const Text('Imposta la data di nascita nel profilo'),
                ),
    );
  }

  Widget _buildWeatherCard() {
    if (!_calSettings.showWeather || _weatherData == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Meteo ${_weatherData!.city}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _weatherData!.forecast.length,
                itemBuilder: (context, index) {
                  final day = _weatherData!.forecast[index];
                  final weekDays = ['', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
                  final isToday = isSameDay(day.date, DateTime.now());
                  return Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? _calSettings.calendarColor.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday ? Border.all(color: _calSettings.calendarColor, width: 1.5) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekDays[day.date.weekday],
                          style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                        ),
                        Text(day.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          '${day.tempMax.round()}° / ${day.tempMin.round()}°',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'split', icon: Icon(Icons.view_agenda, size: 18), label: Text('Split')),
                ButtonSegment(value: 'fullScreen', icon: Icon(Icons.calendar_month, size: 18), label: Text('Full')),
              ],
              selected: {_calSettings.calendarLayout},
              onSelectionChanged: (v) {
                setState(() {
                  _calSettings = _calSettings.copyWith(calendarLayout: v.first);
                });
                _calSettings.save();
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          if (_calSettings.calendarLayout == 'fullScreen') ...[
            const SizedBox(width: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'month', label: Text('Mese')),
                ButtonSegment(value: 'week', label: Text('Sett.')),
              ],
              selected: {_calSettings.calendarViewMode},
              onSelectionChanged: (v) {
                setState(() {
                  _calSettings = _calSettings.copyWith(calendarViewMode: v.first);
                });
                _calSettings.save();
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitLayout(ColorScheme colorScheme) {
    final eventsForSelectedDay = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <CalendarEventFull>[];

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildTableCalendar(colorScheme),
          ),
        ),
        _buildHoroscopeCard(),
        const SizedBox(height: 12),
        if (_selectedDay != null) ...[
          Expanded(
            child: eventsForSelectedDay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_outlined, size: 64, color: colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Nessun evento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Tocca il pulsante Evento per aggiungerne uno', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: eventsForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final event = eventsForSelectedDay[index];
                      return _SlideInItem(index: index, child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _calSettings.calendarColor.withValues(alpha: 0.12),
                            child: Icon(Icons.event, color: _calSettings.calendarColor, size: 22),
                          ),
                          title: Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${event.startTime.hour}:${event.startTime.minute.toString().padLeft(2, '0')} - ${event.endTime.hour}:${event.endTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${event.calendar}${event.reminder != null ? ' · ${event.reminder}' : ''}',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: colorScheme.error,
                            iconSize: 22,
                            onPressed: () => _deleteEvent(index),
                          ),
                        ),
                      ));
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event, color: _calSettings.calendarColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _createEvent,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Evento'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Custom week view: 3 rows of 3 cells (7 days + 2 preview from next week)
  Widget _buildCustomWeekView(ColorScheme colorScheme) {
    // Get start of current week (Monday)
    final now = _focusedDay;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    // 7 days of this week + 2 preview days of next week
    final days = List.generate(9, (i) => monday.add(Duration(days: i)));

    const weekDaysShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom', 'Lun', 'Mar'];
    const monthsShort = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];

    Widget buildWeekDayCell(DateTime day, String label, {bool isPreview = false}) {
      final isToday = isSameDay(day, DateTime.now());
      final isSelected = isSameDay(day, _selectedDay);
      final events = _getEventsForDay(day);
      final todayNow = DateTime.now();
      final todayS = DateTime(todayNow.year, todayNow.month, todayNow.day);
      final dayS = DateTime(day.year, day.month, day.day);
      final daysAhead = dayS.difference(todayS).inDays;
      final weather = (_calSettings.showWeather && daysAhead >= 0 && daysAhead <= 7)
          ? _weatherData?.forDay(day) : null;
      final holidayKey = '${day.month}-${day.day}';
      final holiday = _holidays[holidayKey]?.first;
      final todayColor = _calSettings.todayBorderColor;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
            });
            _showDayEventsBottomSheet(day);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? _calSettings.selectedDayColor.withValues(alpha: 0.15)
                  : isPreview
                      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: isToday
                  ? Border.all(color: todayColor, width: 2)
                  : Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: weekday + day number + weather
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isPreview
                                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                color: isPreview
                                    ? colorScheme.onSurface.withValues(alpha: 0.4)
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          if (weather != null) Text(weather.icon, style: const TextStyle(fontSize: 16)),
                          if (holiday != null) Text(holiday.emoji, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  if (weather != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${weather.tempMax.round()}°/${weather.tempMin.round()}°',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  const Spacer(),
                  // Events
                  if (events.isNotEmpty && !isPreview) ...[
                    ...events.take(3).map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _calSettings.calendarColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.title,
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    if (events.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+${events.length - 3} altri',
                          style: TextStyle(fontSize: 9, color: _calSettings.calendarColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                  if (events.isNotEmpty && isPreview)
                    Text(
                      '${events.length} event${events.length == 1 ? 'o' : 'i'}',
                      style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Week navigation header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: _calSettings.calendarColor, size: 28),
                onPressed: () => setState(() => _focusedDay = _focusedDay.subtract(const Duration(days: 7))),
              ),
              GestureDetector(
                onTap: () => setState(() => _focusedDay = DateTime.now()),
                child: Text(
                  '${days[0].day} ${monthsShort[days[0].month]} - ${days[6].day} ${monthsShort[days[6].month]} ${days[6].year}',
                  style: TextStyle(
                    fontSize: _calSettings.headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: _calSettings.headerColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: _calSettings.calendarColor, size: 28),
                onPressed: () => setState(() => _focusedDay = _focusedDay.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
        // Row 1: days 0-2 (Lun, Mar, Mer)
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < 3; i++)
                buildWeekDayCell(days[i], weekDaysShort[i]),
            ],
          ),
        ),
        // Row 2: days 3-5 (Gio, Ven, Sab)
        Expanded(
          child: Row(
            children: [
              for (int i = 3; i < 6; i++)
                buildWeekDayCell(days[i], weekDaysShort[i]),
            ],
          ),
        ),
        // Row 3: day 6 (Dom) + preview days 7-8 (Lun, Mar next week)
        Expanded(
          child: Row(
            children: [
              buildWeekDayCell(days[6], weekDaysShort[6]),
              buildWeekDayCell(days[7], weekDaysShort[7], isPreview: true),
              buildWeekDayCell(days[8], weekDaysShort[8], isPreview: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullScreenLayout(ColorScheme colorScheme) {
    final isWeek = _calSettings.calendarViewMode == 'week';

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: isWeek
                  ? _buildCustomWeekView(colorScheme)
                  : _buildTableCalendar(colorScheme, format: CalendarFormat.month, rowHeight: 90),
            ),
            _buildHoroscopeCard(),
            const SizedBox(height: 60),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () {
              if (_selectedDay == null) setState(() => _selectedDay = DateTime.now());
              _createEvent();
            },
            icon: const Icon(Icons.add),
            label: const Text('Evento'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildLayoutToggle(),
          Expanded(
            child: _calSettings.calendarLayout == 'fullScreen'
                ? _buildFullScreenLayout(colorScheme)
                : _buildSplitLayout(colorScheme),
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Settings Model ─────────────────────────────────────────────────

class CalendarAlertConfig {
  final String alertType; // 'sound', 'vibration', 'sound_vibration'
  final String? soundName;
  final int durationSeconds;

  const CalendarAlertConfig({
    this.alertType = 'sound_vibration',
    this.soundName,
    this.durationSeconds = 3,
  });

  Map<String, dynamic> toJson() => {
    'alertType': alertType,
    'soundName': soundName,
    'durationSeconds': durationSeconds,
  };

  factory CalendarAlertConfig.fromJson(Map<String, dynamic> json) =>
      CalendarAlertConfig(
        alertType: json['alertType'] ?? 'sound_vibration',
        soundName: json['soundName'],
        durationSeconds: json['durationSeconds'] ?? 3,
      );
}

class CalendarSettings {
  // Alert settings
  final CalendarAlertConfig alertConfig;
  final List<int> alertMinutesBefore; // e.g. [10, 60] = 10 min + 1 hour before

  // Appearance
  final int calendarColorValue;        // Color stored as int
  final int headerColorValue;
  final int selectedDayColorValue;
  final int todayBorderColorValue;
  final String fontFamily;
  final double dayFontSize;
  final double headerFontSize;

  // Zodiac
  final bool showZodiac;
  final String zodiacDisplayMode; // 'icon_only', 'icon_and_text', 'text_only'

  // Next month preview
  final bool showNextMonthPreview;

  // Horoscope
  final bool showHoroscope;

  // Weather
  final bool showWeather;
  final String? weatherCity;

  // Layout
  final String calendarLayout; // 'split' or 'fullScreen'
  final String calendarViewMode; // 'month' or 'week'

  const CalendarSettings({
    this.alertConfig = const CalendarAlertConfig(),
    this.alertMinutesBefore = const [10],
    this.calendarColorValue = 0xFF2196F3,   // Colors.blue
    this.headerColorValue = 0xFF2196F3,
    this.selectedDayColorValue = 0xFF2196F3,
    this.todayBorderColorValue = 0xFFF44336, // Colors.red
    this.fontFamily = 'Default',
    this.dayFontSize = 14.0,
    this.headerFontSize = 18.0,
    this.showZodiac = true,
    this.zodiacDisplayMode = 'icon_and_text',
    this.showNextMonthPreview = false,
    this.showHoroscope = false,
    this.showWeather = false,
    this.weatherCity,
    this.calendarLayout = 'split',
    this.calendarViewMode = 'month',
  });

  Color get calendarColor => Color(calendarColorValue);
  Color get headerColor => Color(headerColorValue);
  Color get selectedDayColor => Color(selectedDayColorValue);
  Color get todayBorderColor => Color(todayBorderColorValue);

  CalendarSettings copyWith({
    CalendarAlertConfig? alertConfig,
    List<int>? alertMinutesBefore,
    int? calendarColorValue,
    int? headerColorValue,
    int? selectedDayColorValue,
    int? todayBorderColorValue,
    String? fontFamily,
    double? dayFontSize,
    double? headerFontSize,
    bool? showZodiac,
    String? zodiacDisplayMode,
    bool? showNextMonthPreview,
    bool? showHoroscope,
    bool? showWeather,
    String? weatherCity,
    String? calendarLayout,
    String? calendarViewMode,
  }) {
    return CalendarSettings(
      alertConfig: alertConfig ?? this.alertConfig,
      alertMinutesBefore: alertMinutesBefore ?? this.alertMinutesBefore,
      calendarColorValue: calendarColorValue ?? this.calendarColorValue,
      headerColorValue: headerColorValue ?? this.headerColorValue,
      selectedDayColorValue: selectedDayColorValue ?? this.selectedDayColorValue,
      todayBorderColorValue: todayBorderColorValue ?? this.todayBorderColorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      dayFontSize: dayFontSize ?? this.dayFontSize,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      showZodiac: showZodiac ?? this.showZodiac,
      zodiacDisplayMode: zodiacDisplayMode ?? this.zodiacDisplayMode,
      showNextMonthPreview: showNextMonthPreview ?? this.showNextMonthPreview,
      showHoroscope: showHoroscope ?? this.showHoroscope,
      showWeather: showWeather ?? this.showWeather,
      weatherCity: weatherCity ?? this.weatherCity,
      calendarLayout: calendarLayout ?? this.calendarLayout,
      calendarViewMode: calendarViewMode ?? this.calendarViewMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'alertConfig': alertConfig.toJson(),
    'alertMinutesBefore': alertMinutesBefore,
    'calendarColorValue': calendarColorValue,
    'headerColorValue': headerColorValue,
    'selectedDayColorValue': selectedDayColorValue,
    'todayBorderColorValue': todayBorderColorValue,
    'fontFamily': fontFamily,
    'dayFontSize': dayFontSize,
    'headerFontSize': headerFontSize,
    'showZodiac': showZodiac,
    'zodiacDisplayMode': zodiacDisplayMode,
    'showNextMonthPreview': showNextMonthPreview,
    'showHoroscope': showHoroscope,
    'showWeather': showWeather,
    'weatherCity': weatherCity,
    'calendarLayout': calendarLayout,
    'calendarViewMode': calendarViewMode,
  };

  factory CalendarSettings.fromJson(Map<String, dynamic> json) =>
      CalendarSettings(
        alertConfig: json['alertConfig'] != null
            ? CalendarAlertConfig.fromJson(json['alertConfig'])
            : const CalendarAlertConfig(),
        alertMinutesBefore: (json['alertMinutesBefore'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            [10],
        calendarColorValue: json['calendarColorValue'] ?? 0xFF2196F3,
        headerColorValue: json['headerColorValue'] ?? 0xFF2196F3,
        selectedDayColorValue: json['selectedDayColorValue'] ?? 0xFF2196F3,
        todayBorderColorValue: json['todayBorderColorValue'] ?? 0xFFF44336,
        fontFamily: json['fontFamily'] ?? 'Default',
        dayFontSize: (json['dayFontSize'] ?? 14.0).toDouble(),
        headerFontSize: (json['headerFontSize'] ?? 18.0).toDouble(),
        showZodiac: json['showZodiac'] ?? true,
        zodiacDisplayMode: json['zodiacDisplayMode'] ?? 'icon_and_text',
        showNextMonthPreview: json['showNextMonthPreview'] ?? false,
        showHoroscope: json['showHoroscope'] ?? false,
        showWeather: json['showWeather'] ?? false,
        weatherCity: json['weatherCity'],
        calendarLayout: json['calendarLayout'] ?? 'split',
        calendarViewMode: json['calendarViewMode'] ?? 'month',
      );

  static Future<CalendarSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('calendar_settings');
    if (jsonStr != null) {
      return CalendarSettings.fromJson(json.decode(jsonStr));
    }
    return const CalendarSettings();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calendar_settings', json.encode(toJson()));
  }
}

// ─── Calendar Settings Page ──────────────────────────────────────────────────

class CalendarSettingsPage extends StatefulWidget {
  final CalendarSettings settings;
  final Function(CalendarSettings) onSave;

  const CalendarSettingsPage({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  late CalendarSettings _settings;

  static const _availableAlertMinutes = <int, String>{
    5: '5 minuti prima',
    10: '10 minuti prima',
    15: '15 minuti prima',
    30: '30 minuti prima',
    60: '1 ora prima',
    120: '2 ore prima',
    1440: '1 giorno prima',
    10080: '1 settimana prima',
  };

  static const _alertTypes = {
    'vibration': 'Solo Vibrazione',
    'sound': 'Solo Suono',
    'sound_vibration': 'Suono + Vibrazione',
  };

  static const _alertSounds = [
    'Default',
    'Campanella',
    'Gong',
    'Chime',
    'Ding',
    'Melodia',
  ];

  static const _alertDurations = {
    3: '3 secondi',
    5: '5 secondi',
    10: '10 secondi',
  };

  static const _colorPresets = <String, int>{
    'Blu': 0xFF2196F3,
    'Rosso': 0xFFF44336,
    'Verde': 0xFF4CAF50,
    'Viola': 0xFF9C27B0,
    'Arancione': 0xFFFF9800,
    'Teal': 0xFF009688,
    'Indigo': 0xFF3F51B5,
    'Rosa': 0xFFE91E63,
    'Grigio': 0xFF607D8B,
  };

  static const _fontFamilies = [
    'Default',
    'Roboto',
    'Serif',
    'Monospace',
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _updateSettings(CalendarSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  void _saveAndPop() {
    widget.onSave(_settings);
    _settings.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Calendario'),
        actions: [
          FilledButton.icon(
            onPressed: _saveAndPop,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Salva'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── SECTION: Avvisi ──
            _buildSectionHeader('Avvisi Personalizzati', Icons.notifications_active),
            const SizedBox(height: 8),
            _buildAlertTypeCard(),
            const SizedBox(height: 8),
            _buildAlertSoundCard(),
            const SizedBox(height: 8),
            _buildAlertDurationCard(),
            const SizedBox(height: 8),
            _buildAlertTimingCard(),
            const SizedBox(height: 24),

            // ── SECTION: Aspetto ──
            _buildSectionHeader('Colori e Font', Icons.palette),
            const SizedBox(height: 8),
            _buildColorPickerCard('Colore Calendario', _settings.calendarColorValue, (v) {
              _updateSettings(_settings.copyWith(calendarColorValue: v, headerColorValue: v, selectedDayColorValue: v));
            }),
            const SizedBox(height: 8),
            _buildColorPickerCard('Colore Oggi (bordo)', _settings.todayBorderColorValue, (v) {
              _updateSettings(_settings.copyWith(todayBorderColorValue: v));
            }),
            const SizedBox(height: 8),
            _buildFontCard(),
            const SizedBox(height: 8),
            _buildFontSizeCard(),
            const SizedBox(height: 24),

            // ── SECTION: Segni Zodiacali ──
            _buildSectionHeader('Segni Zodiacali', Icons.auto_awesome),
            const SizedBox(height: 8),
            _buildZodiacCard(),
            const SizedBox(height: 24),

            // ── SECTION: Anteprima Mese Successivo ──
            _buildSectionHeader('Anteprima Mese Successivo', Icons.calendar_view_week),
            const SizedBox(height: 8),
            _buildNextMonthPreviewCard(),
            const SizedBox(height: 24),

            // ── SECTION: Oroscopo ──
            _buildSectionHeader('Oroscopo', Icons.auto_awesome),
            const SizedBox(height: 8),
            _buildHoroscopeSettingsCard(),
            const SizedBox(height: 24),

            // ── SECTION: Meteo ──
            _buildSectionHeader('Meteo', Icons.cloud),
            const SizedBox(height: 8),
            _buildWeatherSettingsCard(),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveAndPop,
                icon: const Icon(Icons.save),
                label: const Text('Salva Impostazioni'),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(_settings.calendarColorValue), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(_settings.calendarColorValue),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertTypeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo di Avviso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...(_alertTypes.entries.map((entry) {
              return RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: _settings.alertConfig.alertType,
                activeColor: Color(_settings.calendarColorValue),
                onChanged: (value) {
                  _updateSettings(_settings.copyWith(
                    alertConfig: CalendarAlertConfig(
                      alertType: value!,
                      soundName: _settings.alertConfig.soundName,
                      durationSeconds: _settings.alertConfig.durationSeconds,
                    ),
                  ));
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertSoundCard() {
    final showSound = _settings.alertConfig.alertType != 'vibration';
    if (!showSound) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suono Avviso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settings.alertConfig.soundName ?? 'Default',
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                prefixIcon: Icon(Icons.music_note, color: Color(_settings.calendarColorValue)),
              ),
              items: _alertSounds.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) {
                _updateSettings(_settings.copyWith(
                  alertConfig: CalendarAlertConfig(
                    alertType: _settings.alertConfig.alertType,
                    soundName: value,
                    durationSeconds: _settings.alertConfig.durationSeconds,
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCustomDuration =>
      !_alertDurations.containsKey(_settings.alertConfig.durationSeconds);

  Widget _buildAlertDurationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Durata Avviso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ..._alertDurations.entries.map((entry) {
                  final isSelected = _settings.alertConfig.durationSeconds == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: Color(_settings.calendarColorValue).withValues(alpha: 0.2),
                    onSelected: (selected) {
                      if (selected) {
                        _updateSettings(_settings.copyWith(
                          alertConfig: CalendarAlertConfig(
                            alertType: _settings.alertConfig.alertType,
                            soundName: _settings.alertConfig.soundName,
                            durationSeconds: entry.key,
                          ),
                        ));
                      }
                    },
                  );
                }),
                ChoiceChip(
                  label: Text(_isCustomDuration
                      ? 'Personalizzato (${_settings.alertConfig.durationSeconds}s)'
                      : 'Personalizzato'),
                  selected: _isCustomDuration,
                  selectedColor: Color(_settings.calendarColorValue).withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) _showCustomDurationDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDurationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Durata Personalizzata'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Inserisci i secondi',
            suffixText: 'secondi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1) {
                _updateSettings(_settings.copyWith(
                  alertConfig: CalendarAlertConfig(
                    alertType: _settings.alertConfig.alertType,
                    soundName: _settings.alertConfig.soundName,
                    durationSeconds: value,
                  ),
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  List<int> get _customAlertMinutes =>
      _settings.alertMinutesBefore
          .where((m) => !_availableAlertMinutes.containsKey(m))
          .toList();

  String _formatCustomMinutes(int m) {
    if (m < 60) return '$m min prima';
    if (m < 1440) {
      final h = m ~/ 60;
      final rm = m % 60;
      return rm == 0 ? '$h ore prima' : '$h ore $rm min prima';
    }
    final d = m ~/ 1440;
    return d == 1 ? '1 giorno prima' : '$d giorni prima';
  }

  Widget _buildAlertTimingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempi di Avviso',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Puoi selezionare più avvisi contemporaneamente',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ..._availableAlertMinutes.entries.map((entry) {
                  final isSelected = _settings.alertMinutesBefore.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: Color(_settings.calendarColorValue).withValues(alpha: 0.2),
                    checkmarkColor: Color(_settings.calendarColorValue),
                    onSelected: (selected) {
                      final newList = List<int>.from(_settings.alertMinutesBefore);
                      if (selected) {
                        newList.add(entry.key);
                        newList.sort();
                      } else {
                        newList.remove(entry.key);
                      }
                      if (newList.isNotEmpty) {
                        _updateSettings(_settings.copyWith(alertMinutesBefore: newList));
                      }
                    },
                  );
                }),
                FilterChip(
                  label: Text(_customAlertMinutes.isNotEmpty
                      ? 'Personalizzato (${_customAlertMinutes.map(_formatCustomMinutes).join(', ')})'
                      : 'Personalizzato'),
                  selected: _customAlertMinutes.isNotEmpty,
                  selectedColor: Color(_settings.calendarColorValue).withValues(alpha: 0.2),
                  checkmarkColor: Color(_settings.calendarColorValue),
                  onSelected: (_) => _showCustomAlertTimeDialog(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attivi: ${_settings.alertMinutesBefore.map((m) => _availableAlertMinutes[m] ?? _formatCustomMinutes(m)).join(', ')}',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(_settings.calendarColorValue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomAlertTimeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tempo di Avviso Personalizzato'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Inserisci i minuti',
            suffixText: 'minuti prima',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1) {
                final newList = List<int>.from(_settings.alertMinutesBefore);
                if (!newList.contains(value)) {
                  newList.add(value);
                  newList.sort();
                }
                _updateSettings(_settings.copyWith(alertMinutesBefore: newList));
                Navigator.pop(context);
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerCard(String label, int currentValue, Function(int) onChanged) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPresets.entries.map((entry) {
                final isSelected = currentValue == entry.value;
                return GestureDetector(
                  onTap: () => onChanged(entry.value),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(entry.value),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Color(entry.value).withValues(alpha: 0.4), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.onInverseSurface, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(entry.key, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Font Calendario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settings.fontFamily,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                prefixIcon: Icon(Icons.font_download, color: Color(_settings.calendarColorValue)),
              ),
              items: _fontFamilies.map((f) {
                return DropdownMenuItem(
                  value: f,
                  child: Text(f, style: TextStyle(fontFamily: f == 'Default' ? null : f.toLowerCase())),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateSettings(_settings.copyWith(fontFamily: value));
                }
              },
            ),
            const SizedBox(height: 12),
            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Anteprima: 1 2 3 4 5 Gennaio 2026',
                  style: TextStyle(
                    fontFamily: _settings.fontFamily == 'Default' ? null : _settings.fontFamily.toLowerCase(),
                    fontSize: _settings.dayFontSize,
                    color: Color(_settings.calendarColorValue),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dimensione Font', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Numeri giorni:', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: _settings.dayFontSize,
                    min: 10,
                    max: 22,
                    divisions: 12,
                    activeColor: Color(_settings.calendarColorValue),
                    label: '${_settings.dayFontSize.round()}',
                    onChanged: (v) {
                      _updateSettings(_settings.copyWith(dayFontSize: v));
                    },
                  ),
                ),
                Text('${_settings.dayFontSize.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              children: [
                const Text('Intestazione:', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: _settings.headerFontSize,
                    min: 14,
                    max: 28,
                    divisions: 14,
                    activeColor: Color(_settings.calendarColorValue),
                    label: '${_settings.headerFontSize.round()}',
                    onChanged: (v) {
                      _updateSettings(_settings.copyWith(headerFontSize: v));
                    },
                  ),
                ),
                Text('${_settings.headerFontSize.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZodiacCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Mostra Segni Zodiacali', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Nell\'intestazione del calendario'),
              value: _settings.showZodiac,
              activeColor: Color(_settings.calendarColorValue),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                _updateSettings(_settings.copyWith(showZodiac: v));
              },
            ),
            if (_settings.showZodiac) ...[
              const Divider(),
              const Text('Formato visualizzazione:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: const Text('Solo icona (es: ♒)'),
                value: 'icon_only',
                groupValue: _settings.zodiacDisplayMode,
                activeColor: Color(_settings.calendarColorValue),
                onChanged: (v) => _updateSettings(_settings.copyWith(zodiacDisplayMode: v)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Icona + Testo (es: ♒ Acquario)'),
                value: 'icon_and_text',
                groupValue: _settings.zodiacDisplayMode,
                activeColor: Color(_settings.calendarColorValue),
                onChanged: (v) => _updateSettings(_settings.copyWith(zodiacDisplayMode: v)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Solo testo (es: Acquario)'),
                value: 'text_only',
                groupValue: _settings.zodiacDisplayMode,
                activeColor: Color(_settings.calendarColorValue),
                onChanged: (v) => _updateSettings(_settings.copyWith(zodiacDisplayMode: v)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextMonthPreviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Mostra Anteprima Mese Successivo', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('La prima settimana del mese successivo verrà mostrata in colore più chiaro'),
              value: _settings.showNextMonthPreview,
              activeColor: Color(_settings.calendarColorValue),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                _updateSettings(_settings.copyWith(showNextMonthPreview: v));
              },
            ),
            if (_settings.showNextMonthPreview) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPreviewDay('28', false),
                    _buildPreviewDay('29', false),
                    _buildPreviewDay('30', false),
                    Container(width: 1, height: 30, color: Theme.of(context).colorScheme.outlineVariant),
                    _buildPreviewDay('1', true),
                    _buildPreviewDay('2', true),
                    _buildPreviewDay('3', true),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'I giorni del mese successivo appaiono più chiari',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHoroscopeSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Mostra Oroscopo Giornaliero', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Paolo Fox — richiede data di nascita nel profilo'),
              value: _settings.showHoroscope,
              activeColor: Color(_settings.calendarColorValue),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                _updateSettings(_settings.copyWith(showHoroscope: v));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Mostra Meteo', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Previsioni 7 giorni nel calendario'),
              value: _settings.showWeather,
              activeColor: Color(_settings.calendarColorValue),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                _updateSettings(_settings.copyWith(showWeather: v));
              },
            ),
            if (_settings.showWeather) ...[
              const Divider(),
              TextField(
                controller: TextEditingController(text: _settings.weatherCity ?? ''),
                decoration: InputDecoration(
                  labelText: 'Città',
                  hintText: 'es: Roma, Milano, Napoli',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                  prefixIcon: Icon(Icons.location_city, color: Color(_settings.calendarColorValue)),
                ),
                onChanged: (v) {
                  _updateSettings(_settings.copyWith(weatherCity: v.isEmpty ? '' : v));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewDay(String day, bool isNextMonth) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isNextMonth
            ? Color(_settings.calendarColorValue).withValues(alpha: 0.1)
            : null,
      ),
      child: Center(
        child: Text(
          day,
          style: TextStyle(
            fontSize: 14,
            color: isNextMonth
                ? Color(_settings.calendarColorValue).withValues(alpha: 0.4)
                : colorScheme.onSurface,
            fontWeight: isNextMonth ? FontWeight.normal : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class EventEditorPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(CalendarEventFull) onSave;

  const EventEditorPage({
    super.key,
    required this.selectedDate,
    required this.onSave,
  });

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime _startTime;
  late DateTime _endTime;
  String _selectedCalendar = 'Personale';
  String? _selectedReminder;

  final List<String> _calendars = [
    'Personale',
    'Lavoro',
    'Famiglia',
    'Compleanno',
  ];
  final List<String> _reminders = [
    '10 minuti prima',
    '30 minuti prima',
    '1 ora prima',
    '1 giorno prima',
    '1 settimana prima',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      9,
      0,
    );
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  void _saveEvent() {
    if (_titleController.text.isNotEmpty) {
      widget.onSave(
        CalendarEventFull(
          title: _titleController.text,
          startTime: _startTime,
          endTime: _endTime,
          calendar: _selectedCalendar,
          reminder: _selectedReminder,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = DateTime(
            _startTime.year,
            _startTime.month,
            _startTime.day,
            time.hour,
            time.minute,
          );
        } else {
          _endTime = DateTime(
            _endTime.year,
            _endTime.month,
            _endTime.day,
            time.hour,
            time.minute,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo Evento'),
        actions: [
          FilledButton.icon(
            onPressed: _saveEvent,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Salva'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titolo evento',
                hintText: 'es. Riunione, Compleanno, Appuntamento...',
                prefixIcon: Icon(Icons.event, color: colorScheme.primary),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              'Durata',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Inizio',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        '${_startTime.hour}:${_startTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fine',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        '${_endTime.hour}:${_endTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCalendar,
              decoration: const InputDecoration(
                labelText: 'Calendario',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: _calendars
                  .map((cal) => DropdownMenuItem(value: cal, child: Text(cal)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCalendar = value!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Avviso',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reminders.map((reminder) {
                final isSelected = _selectedReminder == reminder;
                return FilterChip(
                  label: Text(reminder),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(
                      () => _selectedReminder = selected ? reminder : null,
                    );
                  },
                  selectedColor: colorScheme.primaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funzione allegati in arrivo!'),
                  ),
                );
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Aggiungi File o Foto'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveEvent,
                icon: const Icon(Icons.save),
                label: const Text('Salva Evento'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
} // SETTINGS PAGE

class SettingsPage extends StatefulWidget {
  final UserProfile userProfile;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Function(UserProfile) onSave;

  const SettingsPage({
    super.key,
    required this.userProfile,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onSave,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = UserProfile(
      nome: widget.userProfile.nome,
      cognome: widget.userProfile.cognome,
      email: widget.userProfile.email,
      dataNascita: widget.userProfile.dataNascita,
      isPro: widget.userProfile.isPro,
      photoPath: widget.userProfile.photoPath,
      googleCalendarConnected: widget.userProfile.googleCalendarConnected,
      googleDriveConnected: widget.userProfile.googleDriveConnected,
      geminiConnected: widget.userProfile.geminiConnected,
      backupMode: widget.userProfile.backupMode,
      religione: widget.userProfile.religione,
    );
  }

  void _saveProfile() {
    widget.onSave(_profile);
    Navigator.pop(context);
  }

  Future<void> _addPhoto() async {
    final hasPhoto = _profile.photoBase64 != null && _profile.photoBase64!.isNotEmpty;

    if (hasPhoto) {
      // Show options: change or remove
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Foto Profilo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                title: const Text('Cambia Foto'),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: const Text('Rimuovi Foto'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      );

      if (action == 'remove') {
        setState(() {
          _profile.photoBase64 = null;
          _profile.photoPath = null;
        });
        _saveProfile();
        return;
      }
      if (action != 'change') return;
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          _profile.photoBase64 = base64String;
        });
        _saveProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento della foto: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showProfileEditor() {
    final nomeController = TextEditingController(text: _profile.nome);
    final cognomeController = TextEditingController(text: _profile.cognome);
    DateTime selectedDate = _profile.dataNascita ?? DateTime(2000, 1, 1);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Modifica Profilo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cognomeController,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data di Nascita',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.cake),
                    ),
                    child: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _profile.nome = nomeController.text;
                  _profile.cognome = cognomeController.text;
                  _profile.dataNascita = selectedDate;
                });
                Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeToPro() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Passa a PRO'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade100, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      '0,99€',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      '/mese',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Vantaggi PRO:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildProFeature(Icons.business, 'Profilo Business'),
              _buildProFeature(
                Icons.group,
                'Condivisione con gruppi di lavoro',
              ),
              _buildProFeature(Icons.people, 'Condivisione calendario e note'),
              _buildProFeature(Icons.edit_note, 'Editor avanzato stile Word'),
              _buildProFeature(
                Icons.format_bold,
                'Formattazione testo completa',
              ),
              _buildProFeature(
                Icons.table_chart,
                'Tabelle e inserimento media',
              ),
              _buildProFeature(Icons.cloud_upload, 'Backup cloud illimitato'),
              _buildProFeature(
                Icons.sync,
                'Sincronizzazione multi-dispositivo',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Forse dopo'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _profile.isPro = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Benvenuto in Ethos Note PRO!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Attiva PRO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.green.shade700, size: 16),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        actions: [
          FilledButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Salva'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage: _profile.photoBytes != null
                            ? MemoryImage(_profile.photoBytes!)
                            : null,
                        child: _profile.photoBytes == null
                            ? Text(
                                _profile.initials,
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _addPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _profile.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_profile.eta != null)
                    Text(
                      '${_profile.eta} anni',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showProfileEditor,
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.email,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Account Ethos Note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_profile.hasAccount) ...[
                    Text(
                      'Registrati per sincronizzare le tue note',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final emailController = TextEditingController();
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text('Registrati con Email'),
                                content: TextField(
                                  controller: emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'tuaemail@esempio.com',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.email),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annulla'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (emailController.text.contains('@')) {
                                        setState(() {
                                          _profile.email = emailController.text;
                                        });
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('✓ Account creato!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Registrati'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.email),
                        label: const Text(
                          'Registrati con Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _profile.email = 'utente@gmail.com';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Registrato con Google!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text(
                          'Registrati con Google',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email: ${_profile.email}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Integrazioni',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildIntegrationTile(
                    'Google Drive',
                    Icons.cloud,
                    Colors.blue.shade700,
                    _profile.googleDriveConnected,
                    (value) =>
                        setState(() => _profile.googleDriveConnected = value),
                  ),
                  const SizedBox(height: 12),
                  _buildIntegrationTile(
                    'Gemini AI',
                    Icons.auto_awesome,
                    Colors.purple.shade700,
                    _profile.geminiConnected,
                    (value) => setState(() => _profile.geminiConnected = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text(
                    'Impostazioni Generali',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('Tema Scuro'),
                  value: widget.isDarkMode,
                  onChanged: widget.onThemeChanged,
                ),
                ListTile(
                  leading: const Icon(Icons.church),
                  title: const Text('Religione'),
                  subtitle: Text(_profile.religione),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Seleziona Religione'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile(
                              title: const Text('Cattolica'),
                              value: 'Cattolica',
                              groupValue: _profile.religione,
                              onChanged: (value) {
                                setState(() => _profile.religione = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Ebraica'),
                              value: 'Ebraica',
                              groupValue: _profile.religione,
                              onChanged: (value) {
                                setState(() => _profile.religione = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Islamica'),
                              value: 'Islamica',
                              groupValue: _profile.religione,
                              onChanged: (value) {
                                setState(() => _profile.religione = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Altra/Nessuna'),
                              value: 'Nessuna',
                              groupValue: _profile.religione,
                              onChanged: (value) {
                                setState(() => _profile.religione = value!);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text(
                    'Impostazioni Deep Note',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final currentSettings = await NoteProSettings.load();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteProSettingsPage(
                          settings: currentSettings,
                          onSave: (newSettings) {
                            newSettings.save();
                          },
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text(
                    'Impostazioni Calendario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final currentSettings = await CalendarSettings.load();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CalendarSettingsPage(
                          settings: currentSettings,
                          onSave: (newSettings) {
                            newSettings.save();
                          },
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: const Text(
                    'Impostazioni Flash Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final currentSettings = await FlashNotesSettings.load();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashNotesSettingsPage(
                          settings: currentSettings,
                          onSave: (newSettings) {
                            newSettings.save();
                          },
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text(
                    'Cestino',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrashPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup'),
                  subtitle: Text(
                    _profile.backupMode == 'local' ? 'Locale' : 'Google Drive',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Modalità Backup'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile(
                              title: const Text('Locale'),
                              subtitle: const Text('Salva sul dispositivo'),
                              value: 'local',
                              groupValue: _profile.backupMode,
                              onChanged: (value) {
                                setState(() => _profile.backupMode = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile(
                              title: const Text('Google Drive'),
                              subtitle: const Text('Sincronizza su cloud'),
                              value: 'drive',
                              groupValue: _profile.backupMode,
                              onChanged: (value) {
                                setState(() => _profile.backupMode = value!);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Informazioni'),
                  subtitle: const Text('Versione 1.0.0'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Ethos Note'),
                        content: const Text(
                          'Versione 1.0.0\n\n© 2025 Ethos Note',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIntegrationTile(
    String title,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value ? 'Connesso' : 'Non connesso',
          style: TextStyle(
            color: value ? Colors.green : colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: (val) {
            onChanged(val);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val ? '$title connesso' : '$title disconnesso'),
              ),
            );
          },
        ),
      ),
    );
  }
}

// FLASH NOTES
// ─── NLP Event Extraction ─────────────────────────────────────────

class ParsedEvent {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAllDay;

  ParsedEvent({
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isAllDay = false,
  });

  CalendarEventFull toCalendarEvent() => CalendarEventFull(
    title: title,
    startTime: startDate,
    endTime: endDate,
    calendar: 'Personale',
  );
}

ParsedEvent parseFlashNote(String text) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String remaining = text;
  DateTime? parsedDate;
  int? startHour;
  int? startMinute;
  int? endHour;
  int? endMinute;

  // a) Explicit @date syntax
  final dateFullRe = RegExp(r'@(\d{1,2})/(\d{1,2})/(\d{4})');
  final dateShortRe = RegExp(r'@(\d{1,2})/(\d{1,2})(?!/\d)');
  final atTimeRe = RegExp(r'@(\d{1,2}):(\d{2})');

  final fullMatch = dateFullRe.firstMatch(remaining);
  if (fullMatch != null) {
    parsedDate = DateTime(
      int.parse(fullMatch.group(3)!),
      int.parse(fullMatch.group(2)!),
      int.parse(fullMatch.group(1)!),
    );
    remaining = remaining.replaceFirst(fullMatch.group(0)!, '');
  } else {
    final shortMatch = dateShortRe.firstMatch(remaining);
    if (shortMatch != null) {
      parsedDate = DateTime(
        now.year,
        int.parse(shortMatch.group(2)!),
        int.parse(shortMatch.group(1)!),
      );
      remaining = remaining.replaceFirst(shortMatch.group(0)!, '');
    }
  }

  final atTimeMatch = atTimeRe.firstMatch(remaining);
  if (atTimeMatch != null) {
    startHour = int.parse(atTimeMatch.group(1)!);
    startMinute = int.parse(atTimeMatch.group(2)!);
    remaining = remaining.replaceFirst(atTimeMatch.group(0)!, '');
  }

  // b) Natural language relative dates (IT)
  if (parsedDate == null) {
    final relativeDays = {
      'dopodomani': 2,
      'domani': 1,
      'oggi': 0,
    };
    for (final entry in relativeDays.entries) {
      final re = RegExp('\\b${entry.key}\\b', caseSensitive: false);
      if (re.hasMatch(remaining)) {
        parsedDate = today.add(Duration(days: entry.value));
        remaining = remaining.replaceFirst(re, '');
        break;
      }
    }
  }

  if (parsedDate == null) {
    final weekdays = {
      'lunedì': DateTime.monday,
      'lunedi': DateTime.monday,
      'martedì': DateTime.tuesday,
      'martedi': DateTime.tuesday,
      'mercoledì': DateTime.wednesday,
      'mercoledi': DateTime.wednesday,
      'giovedì': DateTime.thursday,
      'giovedi': DateTime.thursday,
      'venerdì': DateTime.friday,
      'venerdi': DateTime.friday,
      'sabato': DateTime.saturday,
      'domenica': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      final re = RegExp('\\bprossimo\\s+${entry.key}\\b|\\b${entry.key}\\b', caseSensitive: false);
      final m = re.firstMatch(remaining);
      if (m != null) {
        var daysAhead = entry.value - now.weekday;
        if (daysAhead <= 0) daysAhead += 7;
        parsedDate = today.add(Duration(days: daysAhead));
        remaining = remaining.replaceFirst(m.group(0)!, '');
        break;
      }
    }
  }

  // c) Time ranges and single times
  final rangeRe = RegExp(r'dalle\s+(\d{1,2})([:.]\d{2})?\s+alle\s+(\d{1,2})([:.]\d{2})?', caseSensitive: false);
  final rangeMatch = rangeRe.firstMatch(remaining);
  if (rangeMatch != null) {
    startHour ??= int.parse(rangeMatch.group(1)!);
    startMinute ??= rangeMatch.group(2) != null ? int.parse(rangeMatch.group(2)!.substring(1)) : 0;
    endHour = int.parse(rangeMatch.group(3)!);
    endMinute = rangeMatch.group(4) != null ? int.parse(rangeMatch.group(4)!.substring(1)) : 0;
    remaining = remaining.replaceFirst(rangeMatch.group(0)!, '');
  }

  if (startHour == null) {
    final singleTimeRe = RegExp(r'(?:ore|alle)\s+(\d{1,2})([:.]\d{2})?', caseSensitive: false);
    final singleMatch = singleTimeRe.firstMatch(remaining);
    if (singleMatch != null) {
      startHour = int.parse(singleMatch.group(1)!);
      startMinute = singleMatch.group(2) != null ? int.parse(singleMatch.group(2)!.substring(1)) : 0;
      remaining = remaining.replaceFirst(singleMatch.group(0)!, '');
    }
  }

  // d) Clean title
  String title = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) title = text.trim();

  // e) Defaults
  final date = parsedDate ?? today;
  final bool isAllDay = (startHour == null);

  DateTime startDate;
  DateTime endDate;

  if (isAllDay) {
    startDate = DateTime(date.year, date.month, date.day, 0, 0);
    endDate = DateTime(date.year, date.month, date.day, 23, 59);
  } else {
    startDate = DateTime(date.year, date.month, date.day, startHour!, startMinute ?? 0);
    if (endHour != null) {
      endDate = DateTime(date.year, date.month, date.day, endHour, endMinute ?? 0);
    } else {
      endDate = startDate.add(const Duration(hours: 1));
    }
  }

  return ParsedEvent(
    title: title,
    startDate: startDate,
    endDate: endDate,
    isAllDay: isAllDay,
  );
}

// ──────────────────────────────────────────────────────────────────

class FlashNote {
  final String content;
  final DateTime createdAt;

  FlashNote({required this.content, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FlashNote.fromJson(Map<String, dynamic> json) => FlashNote(
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class FlashNotesSettings {
  final bool geminiEnabled;
  final String geminiApiKey;
  final String autoSaveMode; // 'never', 'daily', 'weekly', 'monthly', 'custom'
  final int customAutoSaveDays;
  final String formattingPreset; // 'simple', 'ai', 'custom'
  final String customFormatInstructions;
  final double aiCorrectionLevel; // 0.0 (solo ortografia) - 1.0 (riscrittura completa)
  final String groupingMode; // 'daily', 'weekly', 'monthly', 'yearly'

  const FlashNotesSettings({
    this.geminiEnabled = false,
    this.geminiApiKey = '',
    this.autoSaveMode = 'never',
    this.customAutoSaveDays = 7,
    this.formattingPreset = 'simple',
    this.customFormatInstructions = '',
    this.aiCorrectionLevel = 0.0,
    this.groupingMode = 'monthly',
  });

  FlashNotesSettings copyWith({
    bool? geminiEnabled,
    String? geminiApiKey,
    String? autoSaveMode,
    int? customAutoSaveDays,
    String? formattingPreset,
    String? customFormatInstructions,
    double? aiCorrectionLevel,
    String? groupingMode,
  }) {
    return FlashNotesSettings(
      geminiEnabled: geminiEnabled ?? this.geminiEnabled,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      autoSaveMode: autoSaveMode ?? this.autoSaveMode,
      customAutoSaveDays: customAutoSaveDays ?? this.customAutoSaveDays,
      formattingPreset: formattingPreset ?? this.formattingPreset,
      customFormatInstructions: customFormatInstructions ?? this.customFormatInstructions,
      aiCorrectionLevel: aiCorrectionLevel ?? this.aiCorrectionLevel,
      groupingMode: groupingMode ?? this.groupingMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'geminiEnabled': geminiEnabled,
    'geminiApiKey': geminiApiKey,
    'autoSaveMode': autoSaveMode,
    'customAutoSaveDays': customAutoSaveDays,
    'formattingPreset': formattingPreset,
    'customFormatInstructions': customFormatInstructions,
    'aiCorrectionLevel': aiCorrectionLevel,
    'groupingMode': groupingMode,
  };

  factory FlashNotesSettings.fromJson(Map<String, dynamic> json) =>
      FlashNotesSettings(
        geminiEnabled: json['geminiEnabled'] ?? false,
        geminiApiKey: json['geminiApiKey'] ?? '',
        autoSaveMode: json['autoSaveMode'] ?? 'never',
        customAutoSaveDays: json['customAutoSaveDays'] ?? 7,
        formattingPreset: json['formattingPreset'] ?? 'simple',
        customFormatInstructions: json['customFormatInstructions'] ?? '',
        aiCorrectionLevel: (json['aiCorrectionLevel'] ?? 0.0).toDouble(),
        groupingMode: json['groupingMode'] ?? 'monthly',
      );

  static Future<FlashNotesSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('flash_notes_settings');
    if (jsonStr != null) {
      return FlashNotesSettings.fromJson(json.decode(jsonStr));
    }
    return const FlashNotesSettings();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flash_notes_settings', json.encode(toJson()));
  }
}

class FlashNotesSettingsPage extends StatefulWidget {
  final FlashNotesSettings settings;
  final Function(FlashNotesSettings) onSave;

  const FlashNotesSettingsPage({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<FlashNotesSettingsPage> createState() => _FlashNotesSettingsPageState();
}

class _FlashNotesSettingsPageState extends State<FlashNotesSettingsPage> {
  late FlashNotesSettings _settings;
  late TextEditingController _apiKeyController;
  late TextEditingController _customDaysController;
  late TextEditingController _customInstructionsController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _apiKeyController = TextEditingController(text: _settings.geminiApiKey);
    _customDaysController = TextEditingController(text: _settings.customAutoSaveDays.toString());
    _customInstructionsController = TextEditingController(text: _settings.customFormatInstructions);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customDaysController.dispose();
    _customInstructionsController.dispose();
    super.dispose();
  }

  void _updateSettings(FlashNotesSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  void _saveAndPop() {
    widget.onSave(_settings);
    _settings.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = Color(0xFFFFA726);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Flash Notes'),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saveAndPop,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Salva'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SEZIONE A: Integrazione Gemini AI
          _buildSectionHeader('Integrazione Gemini AI', Icons.auto_awesome, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abilita Gemini AI',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Usa l\'intelligenza artificiale per formattare le note'),
                    value: _settings.geminiEnabled,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(geminiEnabled: value));
                    },
                  ),
                  if (_settings.geminiEnabled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Key Gemini',
                        hintText: 'Inserisci la tua chiave API...',
                        prefixIcon: Icon(Icons.key),
                      ),
                      onChanged: (value) {
                        _updateSettings(_settings.copyWith(geminiApiKey: value));
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _settings.geminiApiKey.isNotEmpty
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _settings.geminiApiKey.isNotEmpty
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _settings.geminiApiKey.isNotEmpty
                              ? 'Connesso'
                              : 'Non connesso',
                          style: TextStyle(
                            color: _settings.geminiApiKey.isNotEmpty
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La chiave API viene salvata localmente sul dispositivo',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE B: Salvataggio Automatico
          _buildSectionHeader('Salvataggio Automatico in Deep Note', Icons.save_alt, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Sempre li'),
                    subtitle: const Text('Nessun salvataggio automatico'),
                    value: 'never',
                    groupValue: _settings.autoSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(autoSaveMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Ogni giorno'),
                    value: 'daily',
                    groupValue: _settings.autoSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(autoSaveMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('1 volta a settimana'),
                    value: 'weekly',
                    groupValue: _settings.autoSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(autoSaveMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('1 volta al mese'),
                    value: 'monthly',
                    groupValue: _settings.autoSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(autoSaveMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Personalizzato'),
                    value: 'custom',
                    groupValue: _settings.autoSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(autoSaveMode: value));
                    },
                  ),
                  if (_settings.autoSaveMode == 'custom')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _customDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ogni quanti giorni',
                          suffixText: 'giorni',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        onChanged: (value) {
                          final days = int.tryParse(value);
                          if (days != null && days > 0) {
                            _updateSettings(_settings.copyWith(customAutoSaveDays: days));
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Le flash note verranno salvate nella cartella "Flash Notes" in Deep Note',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE: Raggruppamento per Data
          _buildSectionHeader('Raggruppamento per Data', Icons.calendar_month, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Ogni giorno'),
                    subtitle: const Text('Raggruppa le note per singolo giorno'),
                    value: 'daily',
                    groupValue: _settings.groupingMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(groupingMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Ogni settimana'),
                    subtitle: const Text('Raggruppa le note per settimana'),
                    value: 'weekly',
                    groupValue: _settings.groupingMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(groupingMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Ogni mese'),
                    subtitle: const Text('Raggruppa le note per mese (predefinito)'),
                    value: 'monthly',
                    groupValue: _settings.groupingMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(groupingMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Ogni anno'),
                    subtitle: const Text('Raggruppa le note per anno'),
                    value: 'yearly',
                    groupValue: _settings.groupingMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(groupingMode: value));
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE C: Formattazione Automatica
          _buildSectionHeader('Formattazione Automatica', Icons.auto_fix_high, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    title: const Text('Formattazione Semplice'),
                    subtitle: const Text('Prima riga in grassetto (+2pt), resto testo normale'),
                    value: 'simple',
                    groupValue: _settings.formattingPreset,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(formattingPreset: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Formattazione AI'),
                    subtitle: Text(
                      _settings.geminiEnabled
                          ? 'Titolo, paragrafi, elenchi e controllo ortografico automatico'
                          : 'Richiede Gemini AI attivo',
                      style: TextStyle(
                        color: _settings.geminiEnabled
                            ? null
                            : colorScheme.error,
                      ),
                    ),
                    value: 'ai',
                    groupValue: _settings.formattingPreset,
                    onChanged: _settings.geminiEnabled
                        ? (value) {
                            _updateSettings(_settings.copyWith(formattingPreset: value));
                          }
                        : null,
                  ),
                  RadioListTile<String>(
                    title: const Text('Formattazione Personalizzata'),
                    subtitle: Text(
                      _settings.geminiEnabled
                          ? 'Dai istruzioni personalizzate all\'AI'
                          : 'Richiede Gemini AI attivo',
                      style: TextStyle(
                        color: _settings.geminiEnabled
                            ? null
                            : colorScheme.error,
                      ),
                    ),
                    value: 'custom',
                    groupValue: _settings.formattingPreset,
                    onChanged: _settings.geminiEnabled
                        ? (value) {
                            _updateSettings(_settings.copyWith(formattingPreset: value));
                          }
                        : null,
                  ),
                  if (_settings.formattingPreset == 'custom' && _settings.geminiEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: TextField(
                        controller: _customInstructionsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Istruzioni di formattazione',
                          hintText: 'Descrivi come vuoi formattare le note...',
                          prefixIcon: Icon(Icons.edit_note),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (value) {
                          _updateSettings(_settings.copyWith(customFormatInstructions: value));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Livello di correzione AI',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _settings.aiCorrectionLevel,
                            min: 0.0,
                            max: 1.0,
                            divisions: 4,
                            label: _getCorrectionLabel(_settings.aiCorrectionLevel),
                            onChanged: (value) {
                              _updateSettings(_settings.copyWith(aiCorrectionLevel: value));
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Solo ortografia',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              Text('Riassunto',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              Text('Riscrittura',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _getCorrectionLabel(double value) {
    if (value <= 0.0) return 'Solo ortografia';
    if (value <= 0.25) return 'Ortografia e punteggiatura';
    if (value <= 0.5) return 'Riassunto leggero';
    if (value <= 0.75) return 'Riformulazione';
    return 'Riscrittura completa';
  }
}

class NoteProSettingsPage extends StatefulWidget {
  final NoteProSettings settings;
  final Function(NoteProSettings) onSave;

  const NoteProSettingsPage({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<NoteProSettingsPage> createState() => _NoteProSettingsPageState();
}

class _NoteProSettingsPageState extends State<NoteProSettingsPage> {
  late NoteProSettings _settings;
  late TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _pinController = TextEditingController(text: _settings.securityPin ?? '');
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _updateSettings(NoteProSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  void _saveAndPop() {
    widget.onSave(_settings);
    _settings.save();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impostazioni Deep Note salvate'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = Color(0xFFE53935);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Deep Note'),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saveAndPop,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Salva'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SEZIONE: Sicurezza
          _buildSectionHeader('Sicurezza', Icons.lock_outline, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cartella Privata',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Mostra la cartella protetta da PIN'),
                    value: _settings.showPrivateFolder,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(showPrivateFolder: value));
                    },
                  ),
                  if (_settings.showPrivateFolder) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'PIN di sicurezza',
                        hintText: 'Inserisci un PIN numerico...',
                        prefixIcon: Icon(Icons.pin),
                        counterText: '',
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          _updateSettings(_settings.copyWith(clearPin: true));
                        } else {
                          _updateSettings(_settings.copyWith(securityPin: value));
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Il PIN protegge l\'accesso alla cartella privata',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE: Esportazione PDF
          _buildSectionHeader('Esportazione PDF', Icons.picture_as_pdf, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Salvataggio Locale'),
                    subtitle: const Text('Scarica il PDF sul dispositivo'),
                    value: 'local',
                    groupValue: _settings.pdfSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(pdfSaveMode: value));
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Google Drive'),
                    subtitle: const Text('Salva automaticamente su Google Drive'),
                    value: 'google_drive',
                    groupValue: _settings.pdfSaveMode,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(pdfSaveMode: value));
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE: Font scaricati
          _buildSectionHeader('Font Scaricati', Icons.font_download, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _settings.downloadedFonts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Nessun font aggiuntivo scaricato',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: _settings.downloadedFonts.map((font) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.text_fields),
                          title: Text(font),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            onPressed: () {
                              final updated = List<String>.from(_settings.downloadedFonts)
                                ..remove(font);
                              _updateSettings(_settings.copyWith(downloadedFonts: updated));
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE: Template Personalizzati
          _buildSectionHeader('Template Personalizzati', Icons.description, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_settings.customTemplates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nessun template personalizzato',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ..._settings.customTemplates.asMap().entries.map((entry) {
                      final template = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.article),
                        title: Text(template['name'] ?? 'Template'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          onPressed: () {
                            final updated = List<Map<String, dynamic>>.from(
                                _settings.customTemplates)
                              ..removeAt(entry.key);
                            _updateSettings(
                                _settings.copyWith(customTemplates: updated));
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Creazione template in arrivo!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi Template'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SEZIONE: Cestino
          _buildSectionHeader('Cestino', Icons.delete_outline, accentColor),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abilita Cestino',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Le note eliminate verranno spostate nel cestino'),
                    value: _settings.trashEnabled,
                    onChanged: (value) {
                      _updateSettings(_settings.copyWith(trashEnabled: value));
                    },
                  ),
                  if (_settings.trashEnabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Conserva note per',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [7, 14, 30, 60, 90].map((days) {
                        final isSelected = _settings.trashRetentionDays == days;
                        return ChoiceChip(
                          label: Text('$days giorni'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _updateSettings(_settings.copyWith(trashRetentionDays: days));
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le note nel cestino verranno eliminate automaticamente dopo ${_settings.trashRetentionDays} giorni',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> with SingleTickerProviderStateMixin {
  List<TrashedNote> _trashedNotes = [];
  int _retentionDays = 30;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrash();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrash() async {
    final settings = await NoteProSettings.load();
    _retentionDays = settings.trashRetentionDays;
    await TrashedNote.cleanExpired(_retentionDays);
    final notes = await TrashedNote.load();
    setState(() => _trashedNotes = notes);
  }

  Future<void> _restoreNote(int index) async {
    final trashed = _trashedNotes[index];
    final prefs = await SharedPreferences.getInstance();
    if (trashed.type == 'pro') {
      final notesJson = prefs.getStringList('pro_notes') ?? [];
      notesJson.add(json.encode(trashed.noteJson));
      await prefs.setStringList('pro_notes', notesJson);
    } else {
      final notesJson = prefs.getStringList('flash_notes_v2') ?? [];
      notesJson.add(json.encode(trashed.noteJson));
      await prefs.setStringList('flash_notes_v2', notesJson);
    }
    setState(() => _trashedNotes.removeAt(index));
    await TrashedNote.saveAll(_trashedNotes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota ripristinata'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deletePermanently(int index) async {
    setState(() => _trashedNotes.removeAt(index));
    await TrashedNote.saveAll(_trashedNotes);
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Svuota Cestino'),
        content: const Text('Eliminare definitivamente tutte le note nel cestino?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Svuota')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _trashedNotes.clear());
      await TrashedNote.saveAll([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final proNotes = _trashedNotes.where((n) => n.type == 'pro').toList();
    final flashNotes = _trashedNotes.where((n) => n.type == 'flash').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cestino'),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.transparent,
        actions: [
          if (_trashedNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _emptyTrash,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Svuota'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description, size: 18),
                  const SizedBox(width: 6),
                  Text('Deep Note (${proNotes.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on, size: 18),
                  const SizedBox(width: 6),
                  Text('Flash Notes (${flashNotes.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrashList(proNotes, colorScheme, const Color(0xFFE53935)),
          _buildTrashList(flashNotes, colorScheme, const Color(0xFFFFA726)),
        ],
      ),
    );
  }

  Widget _buildTrashList(List<TrashedNote> notes, ColorScheme colorScheme, Color accentColor) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Cestino vuoto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final trashed = notes[index];
        final globalIndex = _trashedNotes.indexOf(trashed);
        final daysLeft = trashed.daysRemaining(_retentionDays);
        final title = trashed.type == 'pro'
            ? (trashed.noteJson['title'] ?? 'Senza titolo')
            : (trashed.noteJson['content'] ?? '').toString();
        final subtitle = trashed.type == 'pro'
            ? (trashed.noteJson['content'] ?? '').toString()
            : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: accentColor, width: 4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    child: Icon(
                      trashed.type == 'pro' ? Icons.description : Icons.flash_on,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          daysLeft > 0
                              ? 'Eliminazione tra $daysLeft giorni'
                              : 'In scadenza oggi',
                          style: TextStyle(
                            fontSize: 11,
                            color: daysLeft <= 3 ? colorScheme.error : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restore),
                    color: colorScheme.primary,
                    tooltip: 'Ripristina',
                    onPressed: () => _restoreNote(globalIndex),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    color: colorScheme.error,
                    tooltip: 'Elimina definitivamente',
                    onPressed: () => _deletePermanently(globalIndex),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FlashNotesPage extends StatefulWidget {
  const FlashNotesPage({super.key});

  @override
  State<FlashNotesPage> createState() => _FlashNotesPageState();
}

class _FlashNotesPageState extends State<FlashNotesPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<FlashNote> _notes = [];
  String _searchQuery = '';
  bool _isGridView = false;
  String _groupingMode = 'monthly';
  String? _selectedGroup; // null = "Tutte"

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadViewMode();
    _loadGroupingMode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = prefs.getBool('flash_view_mode_grid') ?? false);
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = !_isGridView);
    await prefs.setBool('flash_view_mode_grid', _isGridView);
  }

  Future<void> _loadGroupingMode() async {
    final settings = await FlashNotesSettings.load();
    setState(() => _groupingMode = settings.groupingMode);
  }

  static const _months = ['', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];

  String _getGroupKey(DateTime dt) {
    switch (_groupingMode) {
      case 'daily':
        return '${dt.day}/${dt.month}/${dt.year}';
      case 'weekly':
        // Start of week (Monday)
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        return '${monday.day}/${monday.month}/${monday.year}';
      case 'yearly':
        return '${dt.year}';
      case 'monthly':
      default:
        return '${_months[dt.month]} ${dt.year}';
    }
  }

  String _getGroupLabel(String key) {
    switch (_groupingMode) {
      case 'daily':
        return key; // already "dd/mm/yyyy"
      case 'weekly':
        return 'Sett. $key';
      case 'yearly':
        return key;
      case 'monthly':
      default:
        return key;
    }
  }

  IconData _getGroupIcon() {
    switch (_groupingMode) {
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.date_range;
      case 'yearly':
        return Icons.calendar_today;
      case 'monthly':
      default:
        return Icons.calendar_month;
    }
  }

  Map<String, List<FlashNote>> _getGroupedNotes(List<FlashNote> notes) {
    final groups = <String, List<FlashNote>>{};
    for (final note in notes) {
      final key = _getGroupKey(note.createdAt);
      groups.putIfAbsent(key, () => []).add(note);
    }
    return groups;
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('flash_notes_v2') ?? [];
    setState(() {
      _notes = notesJson
          .map((noteStr) => FlashNote.fromJson(json.decode(noteStr)))
          .toList();
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'flash_notes_v2',
      _notes.map((note) => json.encode(note.toJson())).toList(),
    );
  }

  void _addNote() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _notes.add(FlashNote(content: _controller.text));
        _controller.clear();
      });
      _saveNotes();
    }
  }

  Future<void> _createEventFromFlashNote(FlashNote note) async {
    final parsed = parseFlashNote(note.content);
    final titleCtrl = TextEditingController(text: parsed.title);
    DateTime startDate = parsed.startDate;
    DateTime endDate = parsed.endDate;
    bool isAllDay = parsed.isAllDay;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Crea Evento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text('${startDate.day}/${startDate.month}/${startDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = DateTime(picked.year, picked.month, picked.day, startDate.hour, startDate.minute);
                          endDate = DateTime(picked.year, picked.month, picked.day, endDate.hour, endDate.minute);
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tutto il giorno'),
                    value: isAllDay,
                    onChanged: (v) => setDialogState(() {
                      isAllDay = v;
                      if (v) {
                        startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0);
                        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59);
                      }
                    }),
                  ),
                  if (!isAllDay) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ora inizio'),
                      subtitle: Text('${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(startDate),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = DateTime(startDate.year, startDate.month, startDate.day, picked.hour, picked.minute);
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ora fine'),
                      subtitle: Text('${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(endDate),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDate = DateTime(endDate.year, endDate.month, endDate.day, picked.hour, picked.minute);
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crea')),
            ],
          );
        });
      },
    );

    if (confirmed == true && mounted) {
      final eventTitle = titleCtrl.text.trim().isEmpty ? note.content : titleCtrl.text.trim();
      final event = CalendarEventFull(
        title: eventTitle,
        startTime: startDate,
        endTime: endDate,
        calendar: 'Personale',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        final eventsJson = prefs.getString('calendar_events_full') ?? '{}';
        final Map<String, dynamic> decoded = json.decode(eventsJson);
        final key = '${startDate.year}-${startDate.month}-${startDate.day}';
        final List existing = decoded[key] ?? [];
        existing.add(event.toJson());
        decoded[key] = existing;
        await prefs.setString('calendar_events_full', json.encode(decoded));

        if (mounted) {
          final dateStr = '${startDate.day}/${startDate.month}/${startDate.year}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$eventTitle" aggiunto il $dateStr'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              action: SnackBarAction(
                label: 'Vedi',
                onPressed: () {
                  final homeState = context.findAncestorStateOfType<_HomePageState>();
                  if (homeState != null) {
                    homeState.setState(() {
                      homeState._selectedIndex = 1;
                      homeState._refreshKey++;
                    });
                  }
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Errore nel salvataggio dell\'evento'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
    titleCtrl.dispose();
  }

  Future<void> _deleteNote(int index) async {
    final note = _notes[index];
    // Move to trash if enabled
    final settings = await NoteProSettings.load();
    if (settings.trashEnabled) {
      final trashed = TrashedNote(
        type: 'flash',
        noteJson: note.toJson(),
        deletedAt: DateTime.now(),
      );
      final existing = await TrashedNote.load();
      existing.add(trashed);
      await TrashedNote.saveAll(existing);
    }
    setState(() => _notes.removeAt(index));
    _saveNotes();
  }

  Future<void> _openInNotePro(FlashNote flashNote) async {
    final prefs = await SharedPreferences.getInstance();
    // Load folders
    Map<String, FolderStyle> folders = {
      'Generale': const FolderStyle(Icons.folder, Colors.blue),
      'Lavoro': const FolderStyle(Icons.work, Colors.orange),
      'Personale': const FolderStyle(Icons.person, Colors.green),
      'Flash Notes': const FolderStyle(Icons.flash_on, Color(0xFFFFA726)),
    };
    final foldersJson = prefs.getString('custom_folders');
    if (foldersJson != null) {
      final Map<String, dynamic> decoded = json.decode(foldersJson);
      for (final entry in decoded.entries) {
        folders[entry.key] = FolderStyle.fromJson(entry.value);
      }
    }
    // Create a ProNote from the flash note
    final title = flashNote.content.length > 40
        ? flashNote.content.substring(0, 40)
        : flashNote.content;
    final proNote = ProNote(
      title: title,
      content: flashNote.content,
      createdAt: flashNote.createdAt,
      folder: 'Flash Notes',
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          folders: folders,
          existingNote: proNote,
          onSave: (savedNote) async {
            // Save to pro notes list
            final prefs = await SharedPreferences.getInstance();
            final notesJson = prefs.getStringList('pro_notes') ?? [];
            notesJson.add(json.encode(savedNote.toJson()));
            await prefs.setStringList('pro_notes', notesJson);
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0)
      return 'Oggi ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1)
      return 'Ieri ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7) return '${diff.inDays} giorni fa';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    var sortedNotes = List<FlashNote>.from(_notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      sortedNotes = sortedNotes.where((n) => n.content.toLowerCase().contains(q)).toList();
    }
    // Filter by selected group
    if (_selectedGroup != null) {
      sortedNotes = sortedNotes.where((n) => _getGroupKey(n.createdAt) == _selectedGroup).toList();
    }
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = Color(0xFFFFA726);

    // Build group list for sidebar (from all notes, not filtered)
    final allSorted = List<FlashNote>.from(_notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    final groupedNotes = _getGroupedNotes(allSorted);
    final groupKeys = groupedNotes.keys.toList();

    return Row(
      children: [
        // DATE SIDEBAR (LEFT)
        Container(
          width: 72,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildDateSidebarItem(null, Icons.apps, accentColor, colorScheme,
                  count: _notes.length),
              const Divider(height: 8, indent: 12, endIndent: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: groupKeys.map((key) {
                    return _buildDateSidebarItem(
                      key,
                      _getGroupIcon(),
                      accentColor,
                      colorScheme,
                      count: groupedNotes[key]!.length,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // CONTENT
        Expanded(
          child: Column(
            children: [
        // SEARCH BAR + VIEW TOGGLE
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca flash note...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 22),
                tooltip: _isGridView ? 'Vista elenco' : 'Vista griglia',
                onPressed: _toggleViewMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: sortedNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flash_on_outlined,
                        size: 64,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Nessun risultato per "$_searchQuery"'
                            : 'Nessuna Flash Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Scrivi la tua prima nota rapida!',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : _isGridView
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: sortedNotes.length,
                      itemBuilder: (context, index) {
                        final note = sortedNotes[index];
                        final originalIndex = _notes.indexOf(note);
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openInNotePro(note),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: const Border(left: BorderSide(color: accentColor, width: 4)),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.flash_on, color: accentColor, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _formatDateTime(note.createdAt),
                                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      note.content,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => _openInNotePro(note),
                                        child: Icon(Icons.edit_note, size: 18, color: colorScheme.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _createEventFromFlashNote(note),
                                        child: Icon(Icons.event, size: 18, color: const Color(0xFF1E88E5)),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _deleteNote(originalIndex),
                                        child: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedNotes.length,
                      itemBuilder: (context, index) {
                        final note = sortedNotes[index];
                        final originalIndex = _notes.indexOf(note);
                        return _SlideInItem(index: index, child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: accentColor.withValues(alpha: 0.12),
                              child: const Icon(Icons.flash_on, color: accentColor),
                            ),
                            title: Text(
                              note.content,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDateTime(note.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_note),
                                  color: colorScheme.primary,
                                  tooltip: 'Apri in Deep Note',
                                  onPressed: () => _openInNotePro(note),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.event),
                                  color: const Color(0xFF1E88E5),
                                  tooltip: 'Crea Evento',
                                  onPressed: () => _createEventFromFlashNote(note),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: colorScheme.error,
                                  onPressed: () => _deleteNote(originalIndex),
                                ),
                              ],
                            ),
                          ),
                        ));
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: accentColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Nuova Flash Note',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi la tua idea veloce...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Funzione foto in arrivo!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Foto'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Funzione registrazione vocale in arrivo!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.mic, size: 18),
                        label: const Text('Voce'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addNote,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Salva'),
                        ),
                      ),
                    ],
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
    );
  }

  Widget _buildDateSidebarItem(String? groupKey, IconData icon, Color accentColor,
      ColorScheme colorScheme, {required int count}) {
    final isSelected = _selectedGroup == groupKey;
    final label = groupKey == null ? 'Tutte' : _getGroupLabel(groupKey);
    return Tooltip(
      message: '$label ($count)',
      child: InkWell(
        onTap: () => setState(() => _selectedGroup = groupKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20,
                  color: isSelected ? accentColor : colorScheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? accentColor : colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected ? accentColor : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NOTE PRO
class FolderStyle {
  final IconData icon;
  final Color color;
  final bool isCustom;
  final bool isShared;
  final List<String> sharedEmails;
  const FolderStyle(this.icon, this.color, {this.isCustom = false, this.isShared = false, this.sharedEmails = const []});

  Map<String, dynamic> toJson() => {
    'iconCode': icon.codePoint,
    'colorValue': color.value,
    'isCustom': isCustom,
    'isShared': isShared,
    'sharedEmails': sharedEmails,
  };

  factory FolderStyle.fromJson(Map<String, dynamic> json) => FolderStyle(
    IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
    Color(json['colorValue']),
    isCustom: json['isCustom'] ?? false,
    isShared: json['isShared'] ?? false,
    sharedEmails: (json['sharedEmails'] as List?)?.cast<String>() ?? [],
  );
}

class ProNote {
  final String title;
  final String content;
  final String? contentDelta;
  final String? headerText;
  final String? footerText;
  final String? templatePreset;
  final DateTime createdAt;
  final String folder;
  final DateTime? linkedDate;

  ProNote({
    required this.title,
    required this.content,
    this.contentDelta,
    this.headerText,
    this.footerText,
    this.templatePreset,
    this.folder = 'Generale',
    this.linkedDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'contentDelta': contentDelta,
    'headerText': headerText,
    'footerText': footerText,
    'templatePreset': templatePreset,
    'folder': folder,
    'linkedDate': linkedDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ProNote.fromJson(Map<String, dynamic> json) => ProNote(
    title: json['title'],
    content: json['content'],
    contentDelta: json['contentDelta'],
    headerText: json['headerText'],
    footerText: json['footerText'],
    templatePreset: json['templatePreset'],
    folder: json['folder'] ?? 'Generale',
    linkedDate: json['linkedDate'] != null ? DateTime.parse(json['linkedDate']) : null,
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class BusinessTemplate {
  final String header;
  final List<Map<String, dynamic>> contentDelta;
  final String footer;

  const BusinessTemplate({
    required this.header,
    required this.contentDelta,
    required this.footer,
  });
}

class NoteProSettings {
  final String? securityPin;
  final bool showPrivateFolder;
  final String pdfSaveMode; // 'local' or 'google_drive'
  final List<Map<String, dynamic>> customTemplates;
  final List<String> downloadedFonts;
  final bool trashEnabled;
  final int trashRetentionDays;

  const NoteProSettings({
    this.securityPin,
    this.showPrivateFolder = false,
    this.pdfSaveMode = 'local',
    this.customTemplates = const [],
    this.downloadedFonts = const [],
    this.trashEnabled = true,
    this.trashRetentionDays = 30,
  });

  NoteProSettings copyWith({
    String? securityPin,
    bool? clearPin,
    bool? showPrivateFolder,
    String? pdfSaveMode,
    List<Map<String, dynamic>>? customTemplates,
    List<String>? downloadedFonts,
    bool? trashEnabled,
    int? trashRetentionDays,
  }) {
    return NoteProSettings(
      securityPin: clearPin == true ? null : (securityPin ?? this.securityPin),
      showPrivateFolder: showPrivateFolder ?? this.showPrivateFolder,
      pdfSaveMode: pdfSaveMode ?? this.pdfSaveMode,
      customTemplates: customTemplates ?? this.customTemplates,
      downloadedFonts: downloadedFonts ?? this.downloadedFonts,
      trashEnabled: trashEnabled ?? this.trashEnabled,
      trashRetentionDays: trashRetentionDays ?? this.trashRetentionDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'securityPin': securityPin,
    'showPrivateFolder': showPrivateFolder,
    'pdfSaveMode': pdfSaveMode,
    'customTemplates': customTemplates,
    'downloadedFonts': downloadedFonts,
    'trashEnabled': trashEnabled,
    'trashRetentionDays': trashRetentionDays,
  };

  factory NoteProSettings.fromJson(Map<String, dynamic> json) => NoteProSettings(
    securityPin: json['securityPin'],
    showPrivateFolder: json['showPrivateFolder'] ?? false,
    pdfSaveMode: json['pdfSaveMode'] ?? 'local',
    customTemplates: (json['customTemplates'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    downloadedFonts: (json['downloadedFonts'] as List?)?.cast<String>() ?? [],
    trashEnabled: json['trashEnabled'] ?? true,
    trashRetentionDays: json['trashRetentionDays'] ?? 30,
  );

  static Future<NoteProSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('note_pro_settings');
    if (jsonStr != null) {
      return NoteProSettings.fromJson(json.decode(jsonStr));
    }
    return const NoteProSettings();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_pro_settings', json.encode(toJson()));
  }
}

class TrashedNote {
  final String type; // 'pro' or 'flash'
  final Map<String, dynamic> noteJson;
  final DateTime deletedAt;

  const TrashedNote({
    required this.type,
    required this.noteJson,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'noteJson': noteJson,
    'deletedAt': deletedAt.toIso8601String(),
  };

  factory TrashedNote.fromJson(Map<String, dynamic> json) => TrashedNote(
    type: json['type'],
    noteJson: Map<String, dynamic>.from(json['noteJson']),
    deletedAt: DateTime.parse(json['deletedAt']),
  );

  int daysRemaining(int retentionDays) {
    final expiresAt = deletedAt.add(Duration(days: retentionDays));
    return expiresAt.difference(DateTime.now()).inDays;
  }

  static Future<List<TrashedNote>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('trashed_notes') ?? [];
    return list.map((e) => TrashedNote.fromJson(json.decode(e))).toList();
  }

  static Future<void> saveAll(List<TrashedNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'trashed_notes',
      notes.map((e) => json.encode(e.toJson())).toList(),
    );
  }

  static Future<void> cleanExpired(int retentionDays) async {
    final notes = await load();
    final now = DateTime.now();
    final valid = notes.where((n) =>
      now.difference(n.deletedAt).inDays < retentionDays
    ).toList();
    if (valid.length != notes.length) {
      await saveAll(valid);
    }
  }
}

class NotesProPage extends StatefulWidget {
  const NotesProPage({super.key});

  @override
  State<NotesProPage> createState() => _NotesProPageState();
}

class _NotesProPageState extends State<NotesProPage> {
  List<ProNote> _proNotes = [];
  Map<String, FolderStyle> _folders = {
    'Generale': const FolderStyle(Icons.folder, Colors.blue),
    'Lavoro': const FolderStyle(Icons.work, Colors.orange),
    'Personale': const FolderStyle(Icons.person, Colors.green),
    'Flash Notes': const FolderStyle(Icons.flash_on, Color(0xFFFFA726)),
  };
  String _selectedFolder = 'Tutte';
  NoteProSettings _settings = const NoteProSettings();
  bool _privateUnlocked = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;

  static const _availableIcons = [
    Icons.folder, Icons.work, Icons.person, Icons.school,
    Icons.star, Icons.favorite, Icons.bookmark, Icons.lightbulb,
    Icons.music_note, Icons.sports, Icons.code, Icons.palette,
  ];

  static const _availableColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    Colors.amber, Colors.cyan,
  ];

  @override
  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadCustomFolders();
    _loadSettings();
    _loadViewMode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = prefs.getBool('notes_view_mode_grid') ?? false);
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isGridView = !_isGridView);
    await prefs.setBool('notes_view_mode_grid', _isGridView);
  }

  Future<void> _loadSettings() async {
    final settings = await NoteProSettings.load();
    setState(() => _settings = settings);
  }

  Future<void> _loadCustomFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('custom_folders');
    if (foldersJson != null) {
      final Map<String, dynamic> decoded = json.decode(foldersJson);
      setState(() {
        for (final entry in decoded.entries) {
          _folders[entry.key] = FolderStyle.fromJson(entry.value);
        }
      });
    }
  }

  Future<void> _saveCustomFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final customOnly = Map.fromEntries(
      _folders.entries.where((e) => e.value.isCustom),
    );
    final encoded = customOnly.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString('custom_folders', json.encode(encoded));
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('pro_notes') ?? [];
    setState(() {
      _proNotes = notesJson
          .map((noteStr) => ProNote.fromJson(json.decode(noteStr)))
          .toList();
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'pro_notes',
      _proNotes.map((note) => json.encode(note.toJson())).toList(),
    );
  }

  void _createNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          folders: _folders,
          onSave: (note) {
            setState(() => _proNotes.add(note));
            _saveNotes();
          },
        ),
      ),
    );
  }

  void _editNote(int index) {
    final note = _proNotes[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          folders: _folders,
          existingNote: note,
          onSave: (updatedNote) {
            setState(() => _proNotes[index] = updatedNote);
            _saveNotes();
          },
        ),
      ),
    );
  }

  Future<void> _deleteNote(int index) async {
    final note = _proNotes[index];
    // Move to trash if enabled
    if (_settings.trashEnabled) {
      final trashed = TrashedNote(
        type: 'pro',
        noteJson: note.toJson(),
        deletedAt: DateTime.now(),
      );
      final existing = await TrashedNote.load();
      existing.add(trashed);
      await TrashedNote.saveAll(existing);
    }
    setState(() => _proNotes.removeAt(index));
    _saveNotes();
  }

  List<ProNote> get _filteredNotes {
    List<ProNote> notes;
    if (_selectedFolder == 'Tutte') {
      notes = _proNotes.where((n) => n.folder != 'Privata').toList();
    } else if (_selectedFolder == 'Privata' && !_privateUnlocked) {
      notes = [];
    } else {
      notes = _proNotes.where((note) => note.folder == _selectedFolder).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      notes = notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)
      ).toList();
    }
    return notes;
  }

  Map<String, FolderStyle> get _visibleFolders {
    final visible = Map<String, FolderStyle>.from(_folders);
    if (!_settings.showPrivateFolder) {
      visible.remove('Privata');
    }
    return visible;
  }

  void _onFolderTap(String folder) {
    if (folder == 'Privata') {
      if (_settings.securityPin == null) {
        _showCreatePinDialog(onSuccess: () {
          setState(() {
            _privateUnlocked = true;
            _selectedFolder = 'Privata';
          });
        });
      } else {
        _showEnterPinDialog(onSuccess: () {
          setState(() {
            _privateUnlocked = true;
            _selectedFolder = 'Privata';
          });
        });
      }
    } else {
      setState(() {
        _selectedFolder = folder;
        _privateUnlocked = false;
      });
    }
  }

  void _showEnterPinDialog({required VoidCallback onSuccess}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Inserisci PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'PIN di sicurezza'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (controller.text == _settings.securityPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN errato')),
                );
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showCreatePinDialog({required VoidCallback onSuccess}) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Crea PIN di Sicurezza'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Nuovo PIN (4-6 cifre)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Conferma PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              if (pinController.text.length >= 4 && pinController.text == confirmController.text) {
                final newSettings = _settings.copyWith(securityPin: pinController.text);
                newSettings.save();
                setState(() => _settings = newSettings);
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('I PIN non corrispondono o sono troppo corti')),
                );
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  void _moveToPrivate(int noteIndex) {
    void doMove() {
      setState(() {
        final note = _proNotes[noteIndex];
        _proNotes[noteIndex] = ProNote(
          title: note.title,
          content: note.content,
          contentDelta: note.contentDelta,
          headerText: note.headerText,
          footerText: note.footerText,
          templatePreset: note.templatePreset,
          folder: 'Privata',
          linkedDate: note.linkedDate,
          createdAt: note.createdAt,
        );
      });
      _saveNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota spostata in Privata')),
      );
    }

    if (_settings.securityPin == null) {
      _showCreatePinDialog(onSuccess: doMove);
    } else {
      _showEnterPinDialog(onSuccess: doMove);
    }
  }

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.folder;
    Color selectedColor = Colors.blue;
    bool isShared = false;
    final emailController = TextEditingController();
    List<String> sharedEmails = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Nuova Cartella'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome cartella',
                    hintText: 'Es: Progetti, Ricette...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icona', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.map((icon) {
                    final isSelected = selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? selectedColor : Colors.grey.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(icon, size: 22, color: isSelected ? selectedColor : Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Colore', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cartella condivisa'),
                  subtitle: const Text('Aggiungi persone che possono vedere e modificare'),
                  value: isShared,
                  onChanged: (v) => setDialogState(() => isShared = v),
                ),
                if (isShared) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email collaboratore',
                            prefixIcon: Icon(Icons.email, size: 20),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          if (emailController.text.contains('@')) {
                            setDialogState(() {
                              sharedEmails.add(emailController.text);
                              emailController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (sharedEmails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: sharedEmails.map((e) => Chip(
                        label: Text(e, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() => sharedEmails.remove(e)),
                      )).toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty && !_folders.containsKey(name)) {
                  setState(() {
                    _folders[name] = FolderStyle(
                      selectedIcon,
                      selectedColor,
                      isCustom: true,
                      isShared: isShared,
                      sharedEmails: sharedEmails,
                    );
                  });
                  _saveCustomFolders();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Crea'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = Color(0xFFE53935);
    final visibleFolders = _visibleFolders;

    return Scaffold(
      body: Row(
        children: [
          // NOTE LIST
          Expanded(
            child: Column(
              children: [
                // SEARCH BAR + VIEW TOGGLE
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cerca note...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 22),
                        tooltip: _isGridView ? 'Vista elenco' : 'Vista griglia',
                        onPressed: _toggleViewMode,
                      ),
                    ],
                  ),
                ),
                // NOTE LIST / GRID
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_outlined, size: 64, color: colorScheme.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Nessun risultato per "$_searchQuery"'
                                    : _selectedFolder == 'Tutte'
                                        ? 'Nessuna Deep Note'
                                        : 'Nessuna nota in "$_selectedFolder"',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Crea la tua prima nota!',
                                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _createNewNote,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Nuova Nota'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : _isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _filteredNotes.length,
                              itemBuilder: (context, index) {
                                final note = _filteredNotes[index];
                                final folderColor = _folders[note.folder]?.color ?? Colors.grey;
                                final noteIndex = _proNotes.indexOf(note);
                                return GestureDetector(
                                  onLongPress: note.folder != 'Privata'
                                      ? () => _showLongPressMenu(noteIndex)
                                      : null,
                                  child: Card(
                                    child: InkWell(
                                      onTap: () => _editNote(noteIndex),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border(left: BorderSide(color: folderColor, width: 4)),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(_folders[note.folder]?.icon, color: folderColor, size: 18),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(note.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: Text(note.content,
                                                  maxLines: 4,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: folderColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(note.folder,
                                                      style: TextStyle(fontSize: 10, color: folderColor, fontWeight: FontWeight.w600)),
                                                ),
                                                InkWell(
                                                  onTap: () => _deleteNote(noteIndex),
                                                  child: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 0, 16),
                              itemCount: _filteredNotes.length,
                              itemBuilder: (context, index) {
                                final note = _filteredNotes[index];
                                final folderColor = _folders[note.folder]?.color ?? Colors.grey;
                                final noteIndex = _proNotes.indexOf(note);
                                return _SlideInItem(
                                  index: index,
                                  child: GestureDetector(
                                    onLongPress: note.folder != 'Privata'
                                        ? () => _showLongPressMenu(noteIndex)
                                        : null,
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                        onTap: () => _editNote(noteIndex),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border(left: BorderSide(color: folderColor, width: 4)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: folderColor.withValues(alpha: 0.12),
                                                  child: Icon(_folders[note.folder]?.icon, color: folderColor, size: 22),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(note.title,
                                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                                          ),
                                                          if (note.linkedDate != null)
                                                            Padding(
                                                              padding: const EdgeInsets.only(left: 8),
                                                              child: Icon(Icons.calendar_today, size: 14, color: colorScheme.primary),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: folderColor.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(_folders[note.folder]?.icon, size: 12, color: folderColor),
                                                                const SizedBox(width: 4),
                                                                Text(note.folder,
                                                                    style: TextStyle(fontSize: 11, color: folderColor, fontWeight: FontWeight.w600)),
                                                              ],
                                                            ),
                                                          ),
                                                          if (note.linkedDate != null) ...[
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              '${note.linkedDate!.day}/${note.linkedDate!.month}/${note.linkedDate!.year}',
                                                              style: TextStyle(fontSize: 11, color: colorScheme.primary),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline),
                                                  color: colorScheme.error,
                                                  iconSize: 22,
                                                  onPressed: () => _deleteNote(noteIndex),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          // FOLDER SIDEBAR (RIGHT)
          Container(
            width: 72,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildSidebarItem('Tutte', Icons.apps, colorScheme.primary),
                const Divider(height: 8, indent: 12, endIndent: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: visibleFolders.entries.map((entry) {
                      return _buildSidebarItem(entry.key, entry.value.icon, entry.value.color);
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, indent: 12, endIndent: 12),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                  tooltip: 'Nuova cartella',
                  onPressed: _showCreateFolderDialog,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNote,
        icon: const Icon(Icons.add),
        label: const Text('Nuova Nota'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showLongPressMenu(int noteIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Sposta in Privata'),
              subtitle: const Text('Proteggi questa nota con PIN'),
              onTap: () {
                Navigator.pop(ctx);
                _moveToPrivate(noteIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String folder, IconData icon, Color color) {
    final isSelected = _selectedFolder == folder;
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: folder,
      child: InkWell(
        onTap: () => _onFolderTap(folder),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isSelected ? color : colorScheme.onSurfaceVariant, size: 22),
              ),
              const SizedBox(height: 2),
              Text(
                folder.length > 8 ? '${folder.substring(0, 7)}…' : folder,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected ? color : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final Function(ProNote) onSave;
  final Map<String, FolderStyle> folders;
  final ProNote? existingNote;

  const NoteEditorPage({
    super.key,
    required this.onSave,
    required this.folders,
    this.existingNote,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late quill.QuillController _quillController;
  late FocusNode _editorFocusNode;
  late ScrollController _editorScrollController;
  String _selectedFolder = 'Generale';
  bool _showHeader = false;
  bool _showFooter = false;
  String? _selectedTemplate;
  DateTime? _linkedDate;

  String _selectedFontFamily = 'Sans Serif';
  String _selectedFontSize = '16';

  static const _fontFamilies = {
    'Sans Serif': 'sans-serif',
    'Serif': 'serif',
    'Monospace': 'monospace',
    'Roboto': 'Roboto',
    'Open Sans': 'Open Sans',
    'Lato': 'Lato',
    'Poppins': 'Poppins',
    'Nunito': 'Nunito',
    'Raleway': 'Raleway',
    'Playfair': 'Playfair Display',
    'Merriweather': 'Merriweather',
    'Garamond': 'EB Garamond',
    'Courier': 'Courier Prime',
    'Times New Roman': 'Times New Roman',
    'Georgia': 'Georgia',
    'Arial': 'Arial',
  };

  static final _googleFontBuilders = <String, TextStyle Function()>{
    'Roboto': () => GoogleFonts.roboto(),
    'Open Sans': () => GoogleFonts.openSans(),
    'Lato': () => GoogleFonts.lato(),
    'Poppins': () => GoogleFonts.poppins(),
    'Nunito': () => GoogleFonts.nunito(),
    'Raleway': () => GoogleFonts.raleway(),
    'Playfair Display': () => GoogleFonts.playfairDisplay(),
    'Merriweather': () => GoogleFonts.merriweather(),
    'EB Garamond': () => GoogleFonts.ebGaramond(),
    'Courier Prime': () => GoogleFonts.courierPrime(),
  };

  TextStyle _customStyleBuilder(quill.Attribute attribute) {
    if (attribute.key == 'font' && attribute.value != null) {
      final fontValue = attribute.value as String;
      final builder = _googleFontBuilders[fontValue];
      if (builder != null) {
        return builder();
      }
    }
    return const TextStyle();
  }

  static const _fontSizes = ['10', '12', '14', '16', '18', '20', '24', '28', '32'];

  static final _businessTemplates = {
    'Lettera Formale': BusinessTemplate(
      header: 'Nome Cognome\nIndirizzo\nCAP Città\nTel: \nEmail: ',
      contentDelta: [
        {'insert': '\n\nSpett.le\n[Destinatario]\n[Indirizzo]\n\n'},
        {'insert': 'Oggetto: ', 'attributes': {'bold': true}},
        {'insert': '[Oggetto della lettera]\n\n'},
        {'insert': 'Egregio/a,\n\n[Corpo della lettera]\n\n'},
        {'insert': 'Distinti saluti,\n[Firma]\n'},
      ],
      footer: 'P.IVA: | CF: | PEC: ',
    ),
    'Lettera Commerciale': BusinessTemplate(
      header: 'Ragione Sociale S.r.l.\nVia Roma, 1\n00100 Roma (RM)\nTel: +39 06 1234567\nEmail: info@azienda.it',
      contentDelta: [
        {'insert': '\n\nSpett.le\n[Nome Azienda Destinataria]\n[Indirizzo]\n\n'},
        {'insert': 'Alla c.a. di ', 'attributes': {'bold': true}},
        {'insert': '[Nome Referente]\n\n'},
        {'insert': 'Oggetto: ', 'attributes': {'bold': true}},
        {'insert': '[Oggetto]\n\n'},
        {'insert': 'Con la presente siamo a comunicarVi che [corpo della lettera].\n\n'},
        {'insert': 'Restando a disposizione per ulteriori chiarimenti, porgiamo cordiali saluti.\n\n'},
        {'insert': '[Nome e Cognome]\n[Qualifica]\n'},
      ],
      footer: 'P.IVA: 01234567890 | REA: RM-123456 | Cap. Soc. € 10.000,00 i.v.',
    ),
    'Preventivo': BusinessTemplate(
      header: 'Ragione Sociale S.r.l.\nVia Roma, 1\n00100 Roma (RM)\nP.IVA: 01234567890',
      contentDelta: [
        {'insert': '\n\n'},
        {'insert': 'PREVENTIVO N. [Numero]', 'attributes': {'bold': true, 'size': '24'}},
        {'insert': '\nData: [GG/MM/AAAA]\n\n'},
        {'insert': 'Cliente: ', 'attributes': {'bold': true}},
        {'insert': '[Nome Cliente]\n[Indirizzo Cliente]\n\n'},
        {'insert': 'Descrizione dei servizi/prodotti:\n\n', 'attributes': {'bold': true}},
        {'insert': '1. [Voce 1] — € [Importo]\n'},
        {'insert': '2. [Voce 2] — € [Importo]\n'},
        {'insert': '3. [Voce 3] — € [Importo]\n\n'},
        {'insert': 'Totale imponibile: € [Totale]\nIVA 22%: € [IVA]\n', 'attributes': {'bold': true}},
        {'insert': 'TOTALE: € [Totale con IVA]\n\n', 'attributes': {'bold': true, 'size': '20'}},
        {'insert': 'Condizioni di pagamento: [Modalità]\nValidità offerta: 30 giorni dalla data del presente preventivo.\n\n'},
        {'insert': 'Cordiali saluti,\n[Firma]\n'},
      ],
      footer: 'P.IVA: 01234567890 | IBAN: IT00 X000 0000 0000 0000 0000 000',
    ),
    'Sollecito Pagamento': BusinessTemplate(
      header: 'Ragione Sociale S.r.l.\nVia Roma, 1\n00100 Roma (RM)\nP.IVA: 01234567890',
      contentDelta: [
        {'insert': '\n\n'},
        {'insert': 'SOLLECITO DI PAGAMENTO', 'attributes': {'bold': true, 'size': '24'}},
        {'insert': '\n\nSpett.le\n[Nome Debitore]\n[Indirizzo]\n\n'},
        {'insert': 'Oggetto: ', 'attributes': {'bold': true}},
        {'insert': 'Sollecito pagamento fattura n. [Numero] del [Data]\n\n'},
        {'insert': 'Con la presente ci permettiamo di segnalarVi che, alla data odierna, non risulta ancora pervenuto il pagamento della fattura in oggetto, '},
        {'insert': 'per un importo di € [Importo]', 'attributes': {'bold': true}},
        {'insert': ', con scadenza al [Data Scadenza].\n\n'},
        {'insert': 'Vi preghiamo cortesemente di provvedere al saldo entro e non oltre [Data Limite], tramite bonifico bancario al seguente IBAN:\n'},
        {'insert': '[IBAN]\n\n', 'attributes': {'bold': true}},
        {'insert': 'Qualora il pagamento fosse già stato effettuato, Vi preghiamo di considerare nulla la presente comunicazione.\n\n'},
        {'insert': 'Cordiali saluti,\n[Nome e Cognome]\n[Qualifica]\n'},
      ],
      footer: 'P.IVA: 01234567890 | PEC: azienda@pec.it',
    ),
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _headerController = TextEditingController();
    _footerController = TextEditingController();
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController();

    if (widget.existingNote != null) {
      final note = widget.existingNote!;
      _titleController.text = note.title;
      _selectedFolder = note.folder;
      _headerController.text = note.headerText ?? '';
      _footerController.text = note.footerText ?? '';
      _showHeader = (note.headerText ?? '').isNotEmpty;
      _showFooter = (note.footerText ?? '').isNotEmpty;
      _selectedTemplate = note.templatePreset;
      _linkedDate = note.linkedDate;

      if (note.contentDelta != null) {
        final deltaJson = json.decode(note.contentDelta!) as List;
        _quillController = quill.QuillController(
          document: quill.Document.fromJson(deltaJson),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _quillController = quill.QuillController(
          document: quill.Document()..insert(0, note.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      _quillController = quill.QuillController.basic();
    }
  }

  void _saveNote() {
    final plainText = _quillController.document.toPlainText().trim();
    if (_titleController.text.isNotEmpty && plainText.isNotEmpty) {
      final deltaJson = json.encode(_quillController.document.toDelta().toJson());
      widget.onSave(
        ProNote(
          title: _titleController.text,
          content: plainText,
          contentDelta: deltaJson,
          headerText: _showHeader ? _headerController.text : null,
          footerText: _showFooter ? _footerController.text : null,
          templatePreset: _selectedTemplate,
          folder: _selectedFolder,
          linkedDate: _linkedDate,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _pickLinkedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _linkedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _linkedDate = picked);
    }
  }

  void _applyTemplate(String name, BusinessTemplate template) {
    setState(() {
      _selectedTemplate = name;
      _headerController.text = template.header;
      _footerController.text = template.footer;
      _showHeader = true;
      _showFooter = true;
      _quillController = quill.QuillController(
        document: quill.Document.fromJson(template.contentDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void _insertLink() {
    final urlController = TextEditingController();
    final textController = TextEditingController();
    final selection = _quillController.selection;
    final hasSelection = !selection.isCollapsed;

    if (hasSelection) {
      textController.text = _quillController.document.getPlainText(
        selection.start,
        selection.end - selection.start,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserisci Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasSelection)
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Testo del link',
                  hintText: 'Es: Clicca qui',
                ),
              ),
            if (!hasSelection) const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              if (hasSelection) {
                _quillController.formatText(
                  selection.start,
                  selection.end - selection.start,
                  quill.LinkAttribute(url),
                );
              } else {
                final text = textController.text.trim().isEmpty
                    ? url
                    : textController.text.trim();
                final index = selection.baseOffset;
                _quillController.document.insert(index, text);
                _quillController.formatText(
                  index,
                  text.length,
                  quill.LinkAttribute(url),
                );
                _quillController.updateSelection(
                  TextSelection.collapsed(offset: index + text.length),
                  quill.ChangeSource.local,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Inserisci'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final delta = _quillController.document.toDelta();
    final headerText = _showHeader ? _headerController.text : null;
    final footerText = _showFooter ? _footerController.text : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: headerText != null && headerText.isNotEmpty
            ? (context) => pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                  ),
                  child: pw.Text(
                    headerText,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                )
            : null,
        footer: footerText != null && footerText.isNotEmpty
            ? (context) => pw.Container(
                  padding: const pw.EdgeInsets.only(top: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        footerText,
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Pag. ${context.pageNumber}/${context.pagesCount}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                )
            : null,
        build: (context) => _deltaToWidgets(delta),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  List<pw.Widget> _deltaToWidgets(quill_delta.Delta delta) {
    final widgets = <pw.Widget>[];
    final buffer = <pw.InlineSpan>[];
    bool isBulletList = false;
    bool isNumberedList = false;
    int listCounter = 0;

    void flushBuffer({String? listType}) {
      if (buffer.isEmpty) return;
      final richText = pw.RichText(text: pw.TextSpan(children: List.from(buffer)));
      if (listType == 'bullet') {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 14)),
              pw.Expanded(child: richText),
            ],
          ),
        ));
      } else if (listType == 'ordered') {
        listCounter++;
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$listCounter. ', style: const pw.TextStyle(fontSize: 14)),
              pw.Expanded(child: richText),
            ],
          ),
        ));
      } else {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: richText,
        ));
      }
      buffer.clear();
    }

    for (final op in delta.toList()) {
      if (op.data is! String) continue;
      final text = op.data as String;
      final attrs = op.attributes;

      pw.FontWeight fontWeight = pw.FontWeight.normal;
      pw.FontStyle fontStyle = pw.FontStyle.normal;
      pw.TextDecoration? textDecoration;
      double fontSize = 14;
      PdfColor color = PdfColors.black;
      PdfColor? linkColor;

      if (attrs != null) {
        if (attrs['bold'] == true) fontWeight = pw.FontWeight.bold;
        if (attrs['italic'] == true) fontStyle = pw.FontStyle.italic;
        if (attrs['underline'] == true) {
          textDecoration = pw.TextDecoration.underline;
        }
        if (attrs['link'] != null) {
          linkColor = PdfColors.blue;
          textDecoration = pw.TextDecoration.underline;
        }
        if (attrs['size'] != null) {
          final sizeStr = attrs['size'].toString();
          fontSize = double.tryParse(sizeStr) ?? 14;
        }
        if (attrs['header'] != null) {
          final level = attrs['header'] as int;
          fontSize = level == 1 ? 28 : level == 2 ? 22 : 18;
          fontWeight = pw.FontWeight.bold;
        }
      }

      final lines = text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (i > 0) {
          // Check block-level attributes for list
          String? listType;
          if (attrs != null) {
            if (attrs['list'] == 'bullet') {
              listType = 'bullet';
              isBulletList = true;
              isNumberedList = false;
            } else if (attrs['list'] == 'ordered') {
              listType = 'ordered';
              isNumberedList = true;
              isBulletList = false;
            } else {
              if (!isBulletList && !isNumberedList) listType = null;
              isBulletList = false;
              isNumberedList = false;
              listCounter = 0;
            }
          } else {
            isBulletList = false;
            isNumberedList = false;
            listCounter = 0;
          }
          flushBuffer(listType: listType);
        }
        if (lines[i].isNotEmpty) {
          buffer.add(pw.TextSpan(
            text: lines[i],
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              decoration: textDecoration,
              color: linkColor ?? color,
            ),
          ));
        }
      }
    }
    flushBuffer();
    return widgets;
  }

  Widget _buildQuillToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(width: 1, height: 22, color: colorScheme.outlineVariant),
    );
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: B I U | Font Size | H1 H2 H3
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                quill.QuillToolbarToggleStyleButton(
                  controller: _quillController,
                  attribute: quill.Attribute.bold,
                  options: const quill.QuillToolbarToggleStyleButtonOptions(iconSize: 18),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _quillController,
                  attribute: quill.Attribute.italic,
                  options: const quill.QuillToolbarToggleStyleButtonOptions(iconSize: 18),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _quillController,
                  attribute: quill.Attribute.underline,
                  options: const quill.QuillToolbarToggleStyleButtonOptions(iconSize: 18),
                ),
                divider(),
                _buildFontFamilyDropdown(),
                const SizedBox(width: 4),
                _buildFontSizeDropdown(),
                divider(),
                quill.QuillToolbarSelectHeaderStyleButtons(
                  controller: _quillController,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Row 2: UL OL | Color BgColor | Align | Link Header/Footer Templates
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                quill.QuillToolbarToggleStyleButton(
                  controller: _quillController,
                  attribute: quill.Attribute.ul,
                  options: const quill.QuillToolbarToggleStyleButtonOptions(iconSize: 18),
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _quillController,
                  attribute: quill.Attribute.ol,
                  options: const quill.QuillToolbarToggleStyleButtonOptions(iconSize: 18),
                ),
                divider(),
                _buildColorPickerButton(isBackground: false),
                _buildColorPickerButton(isBackground: true),
                divider(),
                quill.QuillToolbarSelectAlignmentButton(
                  controller: _quillController,
                ),
                divider(),
                IconButton(
                  icon: const Icon(Icons.link, size: 18),
                  tooltip: 'Inserisci link',
                  onPressed: _insertLink,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: Icon(
                    _showHeader || _showFooter
                        ? Icons.article
                        : Icons.article_outlined,
                    size: 18,
                  ),
                  tooltip: 'Intestazione/Piè di pagina',
                  onPressed: () {
                    setState(() {
                      if (_showHeader || _showFooter) {
                        _showHeader = false;
                        _showFooter = false;
                      } else {
                        _showHeader = true;
                        _showFooter = true;
                      }
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                _buildTemplateMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilyDropdown() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _selectedFontFamily,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
        items: _fontFamilies.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.key,
            child: Text(entry.key, style: TextStyle(fontFamily: entry.value)),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedFontFamily = value);
          _quillController.formatSelection(
            quill.Attribute.fromKeyValue('font', _fontFamilies[value]),
          );
        },
      ),
    );
  }

  Widget _buildFontSizeDropdown() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: _selectedFontSize,
        underline: const SizedBox(),
        isDense: true,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
        items: _fontSizes.map((size) {
          return DropdownMenuItem(value: size, child: Text('${size}pt'));
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedFontSize = value);
          _quillController.formatSelection(
            quill.Attribute.fromKeyValue('size', value),
          );
        },
      ),
    );
  }

  Widget _buildTemplateMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.description_outlined, size: 20),
      tooltip: 'Template Commerciali',
      itemBuilder: (context) => _businessTemplates.keys.map((name) {
        return PopupMenuItem(
          value: name,
          child: Row(
            children: [
              Icon(
                name == _selectedTemplate ? Icons.check : Icons.description,
                size: 18,
                color: name == _selectedTemplate ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(name),
            ],
          ),
        );
      }).toList(),
      onSelected: (name) {
        final template = _businessTemplates[name]!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Applicare "$name"?'),
            content: const Text(
              'Il contenuto attuale verrà sostituito con il template selezionato.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _applyTemplate(name, template);
                },
                child: const Text('Applica'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorPickerButton({required bool isBackground}) {
    return IconButton(
      icon: Icon(
        isBackground ? Icons.format_color_fill : Icons.format_color_text,
        size: 18,
      ),
      tooltip: isBackground ? 'Colore sfondo' : 'Colore testo',
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _showColorPickerPopup(isBackground: isBackground),
    );
  }

  void _applyColor(Color color, {required bool isBackground}) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    if (isBackground) {
      _quillController.formatSelection(
        quill.Attribute.fromKeyValue('background', hex),
      );
    } else {
      _quillController.formatSelection(
        quill.Attribute.fromKeyValue('color', hex),
      );
    }
  }

  void _showColorPickerPopup({required bool isBackground}) {
    final colorScheme = Theme.of(context).colorScheme;

    const quickColors = [
      Color(0xFF000000),
      Color(0xFFE53935),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return _ColorPickerDialog(
          isBackground: isBackground,
          quickColors: quickColors,
          colorScheme: colorScheme,
          onColorSelected: (color) {
            _applyColor(color, isBackground: isBackground);
          },
          onReset: () {
            if (isBackground) {
              _quillController.formatSelection(
                const quill.BackgroundAttribute(null),
              );
            } else {
              _quillController.formatSelection(
                const quill.ColorAttribute(null),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingNote != null ? 'Modifica Nota' : 'Nuova Deep Note'),
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _pickLinkedDate,
            icon: Icon(
              _linkedDate != null ? Icons.calendar_today : Icons.calendar_today_outlined,
              size: 22,
              color: _linkedDate != null ? colorScheme.primary : null,
            ),
            tooltip: 'Collega a data calendario',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // FOLDER SELECTOR
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.folders.entries.map((entry) {
                    final isSelected = _selectedFolder == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(entry.value.icon, size: 16,
                            color: isSelected ? colorScheme.onPrimary : entry.value.color),
                        label: Text(entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                            )),
                        selected: isSelected,
                        selectedColor: entry.value.color,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) => setState(() => _selectedFolder = entry.key),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // LINKED DATE CHIP
              if (_linkedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                      label: Text('${_linkedDate!.day}/${_linkedDate!.month}/${_linkedDate!.year}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _linkedDate = null),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // TITLE
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titolo nota',
                  hintText: 'Inserisci il titolo...',
                  prefixIcon: Icon(Icons.title, color: colorScheme.primary),
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // HEADER (collapsible)
              if (_showHeader) ...[
                TextField(
                  controller: _headerController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Intestazione (Header)',
                    hintText: 'Nome, indirizzo, contatti...',
                    prefixIcon: Icon(Icons.vertical_align_top, color: colorScheme.tertiary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _showHeader = false),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
              // QUILL EDITOR (Expanded)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: quill.QuillEditor(
                      controller: _quillController,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: quill.QuillEditorConfig(
                        placeholder: 'Scrivi qui la tua nota...',
                        padding: const EdgeInsets.all(16),
                        customStyleBuilder: _customStyleBuilder,
                        onLaunchUrl: (url) async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // FOOTER (collapsible)
              if (_showFooter) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _footerController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Piè di pagina (Footer)',
                    hintText: 'P.IVA, CF, PEC...',
                    prefixIcon: Icon(Icons.vertical_align_bottom, color: colorScheme.tertiary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _showFooter = false),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              // TOOLBAR (2 rows)
              _buildQuillToolbar(),
              const SizedBox(height: 8),
              // SAVE BUTTONS ROW
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Salva PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveNote,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Salva Nota'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }
}

// ── Color Picker Dialog with Hue Wheel ──

class _ColorPickerDialog extends StatefulWidget {
  final bool isBackground;
  final List<Color> quickColors;
  final ColorScheme colorScheme;
  final Function(Color) onColorSelected;
  final VoidCallback onReset;

  const _ColorPickerDialog({
    required this.isBackground,
    required this.quickColors,
    required this.colorScheme,
    required this.onColorSelected,
    required this.onReset,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  double _hue = 0;
  double _saturation = 1;
  double _brightness = 1;
  late TextEditingController _hexController;

  Color get _currentColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _brightness).toColor();

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateHex() {
    final hex = _currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    _hexController.text = hex;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            widget.isBackground ? Icons.format_color_fill : Icons.format_color_text,
            size: 20, color: cs.primary,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isBackground ? 'Colore Sfondo' : 'Colore Testo',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick colors
            Text('Rapidi', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    widget.onReset();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant, width: 2),
                    ),
                    child: Icon(Icons.format_color_reset, size: 18, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 8),
                ...widget.quickColors.map((color) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      widget.onColorSelected(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color == const Color(0xFFFFFFFF)
                              ? cs.outlineVariant : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 4, offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              ],
            ),

            const SizedBox(height: 16),

            // Hue wheel + SatBright square
            Text('Spettro colori', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            )),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  // Hue wheel
                  SizedBox(
                    width: 180, height: 180,
                    child: GestureDetector(
                      onPanStart: (d) => _onWheelPan(d.localPosition, 180),
                      onPanUpdate: (d) => _onWheelPan(d.localPosition, 180),
                      onTapDown: (d) => _onWheelPan(d.localPosition, 180),
                      child: CustomPaint(
                        painter: _HueWheelPainter(
                          selectedHue: _hue,
                          centerColor: _currentColor,
                        ),
                        size: const Size(180, 180),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Saturation / Brightness square
                  Expanded(
                    child: SizedBox(
                      height: 180,
                      child: GestureDetector(
                        onPanStart: (d) => _onSatBrightPan(d.localPosition, 180),
                        onPanUpdate: (d) => _onSatBrightPan(d.localPosition, 180),
                        onTapDown: (d) => _onSatBrightPan(d.localPosition, 180),
                        child: CustomPaint(
                          painter: _SatBrightPainter(
                            hue: _hue,
                            saturation: _saturation,
                            brightness: _brightness,
                          ),
                          size: const Size(double.infinity, 180),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preview + hex input
            Text('Codice colore', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                // Color preview
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: InputDecoration(
                      hintText: 'es. FF5722',
                      prefixText: '#',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    onChanged: (value) {
                      final hex = value.replaceAll('#', '').trim();
                      if (hex.length == 6) {
                        final cv = int.tryParse('FF$hex', radix: 16);
                        if (cv != null) {
                          final c = Color(cv);
                          final hsv = HSVColor.fromColor(c);
                          setState(() {
                            _hue = hsv.hue;
                            _saturation = hsv.saturation;
                            _brightness = hsv.value;
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onColorSelected(_currentColor);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Applica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onWheelPan(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final radius = size / 2;
    final innerRadius = radius * 0.65;

    // Only respond to clicks on the ring area
    if (dist < innerRadius - 5 || dist > radius + 5) return;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    final hue = angle / (2 * math.pi) * 360;

    setState(() {
      _hue = hue;
      _updateHex();
    });
  }

  void _onSatBrightPan(Offset position, double height) {
    final box = context.findRenderObject() as RenderBox?;
    // The square width is the remaining space; we use height as reference
    final w = 108.0; // approximate expanded width
    setState(() {
      _saturation = (position.dx / w).clamp(0, 1);
      _brightness = (1.0 - position.dy / height).clamp(0, 1);
      _updateHex();
    });
  }
}

class _HueWheelPainter extends CustomPainter {
  final double selectedHue;
  final Color centerColor;

  _HueWheelPainter({required this.selectedHue, required this.centerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringWidth = radius * 0.3;
    final innerRadius = radius - ringWidth;

    // Draw hue ring
    for (double angle = 0; angle < 360; angle += 1) {
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1, angle, 1, 1).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth + 1;
      final startAngle = (angle - 90) * math.pi / 180;
      final sweepAngle = 2 * math.pi / 360;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + ringWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Draw center filled circle with current color
    final centerPaint = Paint()..color = centerColor;
    canvas.drawCircle(center, innerRadius - 4, centerPaint);

    // Draw center border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, innerRadius - 4, borderPaint);

    // Draw selector on hue ring
    final selectorAngle = (selectedHue - 90) * math.pi / 180;
    final selectorRadius = innerRadius + ringWidth / 2;
    final selectorPos = Offset(
      center.dx + selectorRadius * math.cos(selectorAngle),
      center.dy + selectorRadius * math.sin(selectorAngle),
    );
    // White circle selector
    canvas.drawCircle(selectorPos, ringWidth / 2 + 2,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(selectorPos, ringWidth / 2 - 1,
        Paint()..color = HSVColor.fromAHSV(1, selectedHue, 1, 1).toColor());
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter old) =>
      old.selectedHue != selectedHue || old.centerColor != centerColor;
}

class _SatBrightPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double brightness;

  _SatBrightPainter({required this.hue, required this.saturation, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.save();
    canvas.clipRRect(rRect);

    // Base hue fill
    final basePaint = Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect, basePaint);

    // Saturation gradient (white to transparent, left to right)
    final satGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    );
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    // Brightness gradient (transparent to black, top to bottom)
    final brightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withValues(alpha: 0), Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = brightGradient.createShader(rect));

    canvas.restore();

    // Border
    final borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rRect, borderPaint);

    // Selector circle
    final sx = saturation * size.width;
    final sy = (1 - brightness) * size.height;
    canvas.drawCircle(Offset(sx, sy), 8,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(Offset(sx, sy), 6,
        Paint()..color = HSVColor.fromAHSV(1, hue, saturation, brightness).toColor());
  }

  @override
  bool shouldRepaint(covariant _SatBrightPainter old) =>
      old.hue != hue || old.saturation != saturation || old.brightness != brightness;
}

