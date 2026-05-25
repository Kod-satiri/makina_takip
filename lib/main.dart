import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_preview/device_preview.dart'; 
import 'package:pdf/pdf.dart'; 
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// --- 🛠️ GELİŞTİRİCİ AYARLARI ---
const bool devicePreviewAcik = false; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
    label: 'DepoZeka',
    primaryColor: 0xFF00BFA5,
  ));

  runApp(
    DevicePreview(
      enabled: devicePreviewAcik && !kReleaseMode, 
      builder: (context) => const DepoZekaUygulamasi(),
    ),
  );
}

final ValueNotifier<ThemeMode> temaYoneticisi = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> bakimPaneliniGoster = ValueNotifier(false);

// --- DEPOZEKA YENİ KURUMSAL RENKLER ---
const Color kDepoZekaPrimary = Color(0xFF00BFA5); 
const Color kDepoZekaSecondary = Color(0xFFFFB300); 
const Color kDepoZekaDarkBg = Color(0xFF0F172A); 

// --- YARDIMCI FONKSİYONLAR ---
String anlikTarihSaatGetir() {
  DateTime suAn = DateTime.now();
  return "${suAn.day.toString().padLeft(2, '0')}/${suAn.month.toString().padLeft(2, '0')}/${suAn.year} - ${suAn.hour.toString().padLeft(2, '0')}:${suAn.minute.toString().padLeft(2, '0')}";
}

DateTime tarihCozumle(String tarihStr) { 
  try { 
    var p = tarihStr.split(' - '); 
    var d = p[0].split('/'); 
    var t = p[1].split(':'); 
    return DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]), int.parse(t[0]), int.parse(t[1])); 
  } catch (e) { return DateTime(2000); } 
}

// BÜTÜN METİNLERİ TÜRKÇE KURALLARA UYGUN BÜYÜTÜR
String metniBuyut(String metin) {
  if (metin.trim().isEmpty) return metin;
  return metin.trim()
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ş', 'Ş')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ç', 'Ç')
      .replaceAll('ö', 'Ö')
      .replaceAll('ü', 'Ü')
      .toUpperCase();
}

String kelimeIlkHarfleriBuyut(String metin) {
  if (metin.trim().isEmpty) return metin;
  return metin.trim().split(' ').map((kelime) {
    if (kelime.isEmpty) return '';
    return kelime[0].toUpperCase() + kelime.substring(1).toLowerCase();
  }).join(' ');
}

String cumleIlkHarfBuyut(String metin) {
  if (metin.trim().isEmpty) return metin;
  String t = metin.trim();
  return t[0].toUpperCase() + t.substring(1);
}

// EXCEL CSV TÜRKÇE KARAKTER DÜZELTİCİ
String csvIcerikCoz(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (e) {
    StringBuffer sb = StringBuffer();
    for (int b in bytes) {
      if (b < 128) { 
        sb.writeCharCode(b); 
      } else {
        switch (b) {
          case 0xFC: sb.write('ü'); break;
          case 0xDC: sb.write('Ü'); break;
          case 0xFE: sb.write('ş'); break;
          case 0xDE: sb.write('Ş'); break;
          case 0xFD: sb.write('ı'); break;
          case 0xDD: sb.write('İ'); break;
          case 0xF0: sb.write('ğ'); break;
          case 0xD0: sb.write('Ğ'); break;
          case 0xE7: sb.write('ç'); break;
          case 0xC7: sb.write('Ç'); break;
          case 0xF6: sb.write('ö'); break;
          case 0xD6: sb.write('Ö'); break;
          default: sb.writeCharCode(b);
        }
      }
    }
    return sb.toString();
  }
}

// --- TASARIM: KENDİ YÜKLEDİĞİN LOGON ---
class DepoZekaLogo extends StatelessWidget {
  final double size;

  const DepoZekaLogo({
    super.key, 
    this.size = 24, 
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/logo.png',
            height: size * 3.5,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.memory, color: Colors.white, size: size * 3.5);
            },
          ),
        ),
        SizedBox(width: size * 0.6),
        Flexible(
          child: RichText(
            overflow: TextOverflow.visible,
            text: TextSpan(
              style: TextStyle(fontSize: size * 1.1, letterSpacing: 1.5, fontFamily: 'Roboto'),
              children: const [
                TextSpan(text: 'DEPO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                TextSpan(text: 'ZEKA', style: TextStyle(fontWeight: FontWeight.w300, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget depoZekaAppBarBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF00BFA5), Color(0xFF00897B), Color(0xFF004D40)], 
        begin: Alignment.topLeft, 
        end: Alignment.bottomRight
      )
    )
  );
}

// --- VERİ MODELLERİ ---
class IsGorevi {
  String id;
  String baslik;
  bool tamamlandi;
  int hedefSayi;
  int yapilanSayi;    

  IsGorevi({
    required this.id, 
    required this.baslik, 
    this.tamamlandi = false, 
    this.hedefSayi = 1, 
    this.yapilanSayi = 0
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'baslik': baslik, 'tamamlandi': tamamlandi, 'hedefSayi': hedefSayi, 'yapilanSayi': yapilanSayi
  };

  factory IsGorevi.fromJson(Map<String, dynamic>? json) {
    if (json == null) return IsGorevi(id: '0', baslik: 'Bilinmiyor');
    return IsGorevi(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), 
      baslik: json['baslik']?.toString() ?? '', 
      tamamlandi: json['tamamlandi'] ?? false, 
      hedefSayi: json['hedefSayi'] ?? 1, 
      yapilanSayi: json['yapilanSayi'] ?? 0
    );
  }
}

class Revizyon {
  String tarihSaat; 
  String aciklama; 
  String makinaAdi;

  Revizyon({required this.tarihSaat, required this.aciklama, required this.makinaAdi});

  Map<String, dynamic> toJson() => {
    'tarihSaat': tarihSaat, 'aciklama': aciklama, 'makinaAdi': makinaAdi
  };

  factory Revizyon.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Revizyon(tarihSaat: 'Bilinmiyor', aciklama: 'Yok', makinaAdi: 'Genel');
    return Revizyon(
      tarihSaat: json['tarihSaat']?.toString() ?? 'Tarih Bilinmiyor', 
      aciklama: json['aciklama']?.toString() ?? 'Açıklama Yok', 
      makinaAdi: json['makinaAdi']?.toString() ?? 'Genel'
    );
  }
}

class Kart {
  String stokNo; 
  String tip; 
  String eklenmeTarihi; 
  List<Revizyon> revizyonlar; 

  Kart({required this.stokNo, required this.tip, required this.eklenmeTarihi, required this.revizyonlar});

  Map<String, dynamic> toJson() => {
    'stokNo': stokNo, 'tip': tip, 'eklenmeTarihi': eklenmeTarihi, 'revizyonlar': revizyonlar.map((r) => r.toJson()).toList()
  };

  factory Kart.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Kart(stokNo: 'Bilinmeyen', tip: 'Yok', eklenmeTarihi: 'Bilinmiyor', revizyonlar: []);
    return Kart(
      stokNo: json['stokNo']?.toString() ?? 'Bilinmeyen', 
      tip: json['tip']?.toString() ?? 'Belirtilmedi', 
      eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? 'Eski Kayıt', 
      revizyonlar: json['revizyonlar'] != null ? (json['revizyonlar'] as List).map((r) => Revizyon.fromJson(r as Map<String, dynamic>?)).toList() : []
    );
  }
}

class Makina {
  String kod; 
  String ad; 
  String eklenmeTarihi; 
  List<Kart> bagliKartlar;

  Makina({required this.kod, required this.ad, required this.eklenmeTarihi, required this.bagliKartlar});

  Map<String, dynamic> toJson() => {
    'kod': kod, 'ad': ad, 'eklenmeTarihi': eklenmeTarihi, 'bagliKartlar': bagliKartlar.map((k) => k.toJson()).toList()
  };

  factory Makina.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Makina(kod: 'Bilinmiyor', ad: 'İsimsiz', eklenmeTarihi: 'Bilinmiyor', bagliKartlar: []);
    return Makina(
      kod: json['kod']?.toString() ?? 'Bilinmiyor', 
      ad: json['ad']?.toString() ?? 'İsimsiz', 
      eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? 'Eski Kayıt', 
      bagliKartlar: json['bagliKartlar'] != null ? (json['bagliKartlar'] as List).map((k) => Kart.fromJson(k as Map<String, dynamic>?)).toList() : []
    );
  }
}

class Malzeme {
  String shKodu; 
  String hKodu; 
  String raf; 
  String urunIsmi; 
  String urunKodu; 
  String depoTipi; 
  String eklenmeTarihi;

  Malzeme({
    this.shKodu = '', this.hKodu = '', this.raf = '', 
    this.urunIsmi = '', this.urunKodu = '', 
    required this.depoTipi, required this.eklenmeTarihi
  });
  
  Map<String, dynamic> toJson() => {
    'shKodu': shKodu, 'hKodu': hKodu, 'raf': raf, 
    'urunIsmi': urunIsmi, 'urunKodu': urunKodu, 
    'depoTipi': depoTipi, 'eklenmeTarihi': eklenmeTarihi
  };
  
  factory Malzeme.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Malzeme(depoTipi: 'SMD Raf', eklenmeTarihi: 'Bilinmiyor');
    return Malzeme(
      shKodu: json['shKodu']?.toString() ?? json['kod']?.toString() ?? '', 
      hKodu: json['hKodu']?.toString() ?? '', 
      raf: json['raf']?.toString() ?? '', 
      urunIsmi: json['urunIsmi']?.toString() ?? json['ad']?.toString() ?? '', 
      urunKodu: json['urunKodu']?.toString() ?? json['kod']?.toString() ?? '', 
      depoTipi: json['depoTipi']?.toString() ?? 'SMD Raf', 
      eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? 'Eski Kayıt'
    );
  }
}

class OzelMakinaBakim {
  String ad; 
  String sonBakim; 
  String siradakiBakim; 
  String durum; 

  OzelMakinaBakim({required this.ad, required this.sonBakim, required this.siradakiBakim, required this.durum});

  Map<String, dynamic> toJson() => {
    'ad': ad, 'sonBakim': sonBakim, 'siradakiBakim': siradakiBakim, 'durum': durum
  };

  factory OzelMakinaBakim.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OzelMakinaBakim(ad: 'Bilinmeyen', sonBakim: '-', siradakiBakim: '-', durum: 'Normal');
    return OzelMakinaBakim(
      ad: json['ad']?.toString() ?? 'Bilinmeyen', 
      sonBakim: json['sonBakim']?.toString() ?? '-', 
      siradakiBakim: json['siradakiBakim']?.toString() ?? '-', 
      durum: json['durum']?.toString() ?? 'Normal'
    );
  }
}

class PcbKart {
  String stokNo; 
  String isim; 
  String eklenmeTarihi;

  PcbKart({required this.stokNo, required this.isim, required this.eklenmeTarihi});

  Map<String, dynamic> toJson() => {
    'stokNo': stokNo, 'isim': isim, 'eklenmeTarihi': eklenmeTarihi
  };

  factory PcbKart.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PcbKart(stokNo: 'Bilinmiyor', isim: 'Yok', eklenmeTarihi: '-');
    return PcbKart(
      stokNo: json['stokNo']?.toString() ?? '', 
      isim: json['isim']?.toString() ?? '', 
      eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? ''
    );
  }
}

// --- GLOBAL DEĞİŞKENLER ---
String gecerliAdminSifresi = '1234'; 

List<IsGorevi> gunlukIsler = []; 
List<Kart> tumKartlarDeposu = []; 
List<Makina> tumMakinalar = []; 
List<Kart> arsivlenmisKartlar = []; 
List<Makina> arsivlenmisMakinalar = []; 
List<Malzeme> smdMalzemeler = []; 
List<Malzeme> bacakliMalzemeler = []; 
List<Malzeme> smdDepoMalzemeler = []; 
List<Malzeme> bacakliDepoMalzemeler = []; 
List<Malzeme> arsivlenmisMalzemeler = [];
List<PcbKart> tumPcbDeposu = []; 
List<PcbKart> arsivlenmisPcbler = [];

List<OzelMakinaBakim> ozelBakimListesi = [
  OzelMakinaBakim(ad: 'POTA MAKİNASI', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'SMD DİZGİ MAKİNASI', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'LEHİM ÇEKME MAKİNASI', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'FIRIN', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
];

Future<void> verileriKaydet() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('gunlukIsler', jsonEncode(gunlukIsler.map((g) => g.toJson()).toList())); 
  await prefs.setString('kayitliKartlar', jsonEncode(tumKartlarDeposu.map((k) => k.toJson()).toList())); 
  await prefs.setString('kayitliMakinalar', jsonEncode(tumMakinalar.map((m) => m.toJson()).toList())); 
  await prefs.setString('arsivliKartlar', jsonEncode(arsivlenmisKartlar.map((k) => k.toJson()).toList())); 
  await prefs.setString('arsivliMakinalar', jsonEncode(arsivlenmisMakinalar.map((m) => m.toJson()).toList())); 
  await prefs.setString('smdMalzemeler', jsonEncode(smdMalzemeler.map((m) => m.toJson()).toList())); 
  await prefs.setString('bacakliMalzemeler', jsonEncode(bacakliMalzemeler.map((m) => m.toJson()).toList())); 
  await prefs.setString('smdDepoMalzemeler', jsonEncode(smdDepoMalzemeler.map((m) => m.toJson()).toList())); 
  await prefs.setString('bacakliDepoMalzemeler', jsonEncode(bacakliDepoMalzemeler.map((m) => m.toJson()).toList())); 
  await prefs.setString('arsivliMalzemeler', jsonEncode(arsivlenmisMalzemeler.map((m) => m.toJson()).toList()));
  await prefs.setString('ozelBakimListesi', jsonEncode(ozelBakimListesi.map((m) => m.toJson()).toList()));
  await prefs.setString('kayitliPcbler', jsonEncode(tumPcbDeposu.map((p) => p.toJson()).toList()));
  await prefs.setString('arsivliPcbler', jsonEncode(arsivlenmisPcbler.map((p) => p.toJson()).toList()));
  await prefs.setString('adminSifresi', gecerliAdminSifresi); 
}

// --- UYGULAMA ANA YAPISI ---
class DepoZekaUygulamasi extends StatelessWidget {
  const DepoZekaUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaYoneticisi,
      builder: (context, guncelTema, child) {
        return MaterialApp(
          useInheritedMediaQuery: true, 
          locale: DevicePreview.locale(context), 
          builder: DevicePreview.appBuilder, 
          debugShowCheckedModeBanner: false,
          title: 'DepoZeka',
          theme: ThemeData.light().copyWith(
            primaryColor: kDepoZekaPrimary, 
            scaffoldBackgroundColor: Colors.grey[100], 
            colorScheme: const ColorScheme.light(primary: kDepoZekaPrimary, secondary: kDepoZekaSecondary),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false, iconTheme: IconThemeData(color: Colors.white)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: Colors.white, 
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDepoZekaPrimary, width: 2))
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kDepoZekaPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: kDepoZekaPrimary, 
            scaffoldBackgroundColor: kDepoZekaDarkBg, 
            colorScheme: const ColorScheme.dark(primary: kDepoZekaPrimary, secondary: kDepoZekaSecondary),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false, iconTheme: IconThemeData(color: Colors.white)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: Colors.grey[850], 
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDepoZekaPrimary, width: 2))
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kDepoZekaPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
          ),
          themeMode: guncelTema, 
          home: const AcilisEkrani(), 
        );
      },
    );
  }
}

// --- ANİMASYONLU AÇILIŞ EKRANI ---
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});
  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> with SingleTickerProviderStateMixin {
  late AnimationController _animasyonKontrolcusu;
  late Animation<double> _logoOlcekAnimasyonu;
  late Animation<double> _logoGecisAnimasyonu;
  late Animation<double> _altKisimGecisAnimasyonu;

  @override
  void initState() { 
    super.initState(); 

    _animasyonKontrolcusu = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 2000)
    );

    _logoOlcekAnimasyonu = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrolcusu, curve: Curves.easeOutBack)
    );

    _logoGecisAnimasyonu = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrolcusu, curve: const Interval(0.0, 0.5, curve: Curves.easeIn))
    );

    _altKisimGecisAnimasyonu = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrolcusu, curve: const Interval(0.5, 1.0, curve: Curves.easeIn))
    );

    _animasyonKontrolcusu.forward();
    hafizadanVerileriYukle(); 
  }

  @override
  void dispose() {
    _animasyonKontrolcusu.dispose();
    super.dispose();
  }
  
  Future<void> hafizadanVerileriYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      temaYoneticisi.value = (prefs.getBool('isDarkTheme') ?? false) ? ThemeMode.dark : ThemeMode.light;
      bakimPaneliniGoster.value = prefs.getBool('bakimPaneliGoster') ?? false;
      gecerliAdminSifresi = prefs.getString('adminSifresi') ?? '1234';

      if (prefs.getString('gunlukIsler') != null) { gunlukIsler = List<IsGorevi>.from(jsonDecode(prefs.getString('gunlukIsler')!).map((x) => IsGorevi.fromJson(x))); }
      if (prefs.getString('kayitliKartlar') != null) { tumKartlarDeposu = List<Kart>.from(jsonDecode(prefs.getString('kayitliKartlar')!).map((x) => Kart.fromJson(x))); }
      if (prefs.getString('kayitliMakinalar') != null) { tumMakinalar = List<Makina>.from(jsonDecode(prefs.getString('kayitliMakinalar')!).map((x) => Makina.fromJson(x))); }
      if (prefs.getString('arsivliKartlar') != null) { arsivlenmisKartlar = List<Kart>.from(jsonDecode(prefs.getString('arsivliKartlar')!).map((x) => Kart.fromJson(x))); }
      if (prefs.getString('arsivliMakinalar') != null) { arsivlenmisMakinalar = List<Makina>.from(jsonDecode(prefs.getString('arsivliMakinalar')!).map((x) => Makina.fromJson(x))); }
      if (prefs.getString('smdMalzemeler') != null) { smdMalzemeler = List<Malzeme>.from(jsonDecode(prefs.getString('smdMalzemeler')!).map((x) => Malzeme.fromJson(x))); }
      if (prefs.getString('bacakliMalzemeler') != null) { bacakliMalzemeler = List<Malzeme>.from(jsonDecode(prefs.getString('bacakliMalzemeler')!).map((x) => Malzeme.fromJson(x))); }
      if (prefs.getString('smdDepoMalzemeler') != null) { smdDepoMalzemeler = List<Malzeme>.from(jsonDecode(prefs.getString('smdDepoMalzemeler')!).map((x) => Malzeme.fromJson(x))); }
      if (prefs.getString('bacakliDepoMalzemeler') != null) { bacakliDepoMalzemeler = List<Malzeme>.from(jsonDecode(prefs.getString('bacakliDepoMalzemeler')!).map((x) => Malzeme.fromJson(x))); }
      if (prefs.getString('arsivliMalzemeler') != null) { arsivlenmisMalzemeler = List<Malzeme>.from(jsonDecode(prefs.getString('arsivliMalzemeler')!).map((x) => Malzeme.fromJson(x))); }
      if (prefs.getString('ozelBakimListesi') != null) { ozelBakimListesi = List<OzelMakinaBakim>.from(jsonDecode(prefs.getString('ozelBakimListesi')!).map((x) => OzelMakinaBakim.fromJson(x))); }
      if (prefs.getString('kayitliPcbler') != null) { tumPcbDeposu = List<PcbKart>.from(jsonDecode(prefs.getString('kayitliPcbler')!).map((x) => PcbKart.fromJson(x))); }
      if (prefs.getString('arsivliPcbler') != null) { arsivlenmisPcbler = List<PcbKart>.from(jsonDecode(prefs.getString('arsivliPcbler')!).map((x) => PcbKart.fromJson(x))); }
    } catch (e) { 
      // Hata durumunda yoksay
    }
    
    // Animasyon bekleme
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (mounted) { 
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaGezinmeSayfasi())); 
    }
  }
  
  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            FadeTransition(
              opacity: _logoGecisAnimasyonu,
              child: ScaleTransition(
                scale: _logoOlcekAnimasyonu,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95, 
                  constraints: const BoxConstraints(maxWidth: 800), 
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 440, 
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.memory, color: kDepoZekaPrimary, size: 200);
                      },
                    ),
                  )
                )
              )
            ), 
            const SizedBox(height: 60),
            FadeTransition(
              opacity: _altKisimGecisAnimasyonu,
              child: Column(
                children: [
                  const SizedBox(
                    width: 250,
                    child: LinearProgressIndicator(
                      color: kDepoZekaPrimary,
                      backgroundColor: Color(0xFF1E293B),
                      minHeight: 8,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ), 
                  const SizedBox(height: 25), 
                  Text('Sistem Başlatılıyor...', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 16))
                ]
              )
            )
          ]
        )
      )
    ); 
  }
}

// --- KULLANIM KILAVUZU SAYFASI ---
class KullanimKilavuzuSayfasi extends StatelessWidget {
  const KullanimKilavuzuSayfasi({super.key});

  Widget _kilavuzKarti(BuildContext context, String baslik, String aciklama, IconData ikon, Color renk) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 6, shadowColor: renk.withOpacity(0.2), margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: renk.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: renk.withOpacity(0.3))), 
              child: Icon(ikon, size: 36, color: renk)
            ), 
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(baslik, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), 
                  const SizedBox(height: 8), 
                  Text(aciklama, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[800]))
                ]
              )
            ),
          ]
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(flexibleSpace: depoZekaAppBarBackground(), centerTitle: true, title: const Text('Kullanım Kılavuzu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDepoZekaPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: kDepoZekaPrimary.withOpacity(0.3))), 
            child: const Column(
              children: [
                Icon(Icons.info_outline, size: 40, color: kDepoZekaPrimary), 
                SizedBox(height: 10), 
                Text('DepoZeka Sistemine Hoş Geldiniz!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
                SizedBox(height: 5), 
                Text('Bu yazılım, fabrikanızdaki makinaları, kartları, malzemeleri ve bakım süreçlerini dijital olarak takip etmeniz için tasarlanmış, tamamen çevrimdışı ve güvenli bir akıllı ERP çözümüdür.', textAlign: TextAlign.center)
              ]
            )
          ), 
          const SizedBox(height: 20),
          _kilavuzKarti(context, '1. Yönetici (Admin) Girişi', 'Sistem varsayılan olarak "İzleme Modunda" başlar. Yeni bir makina eklemek, kart bağlamak veya veri silmek için üst sağdaki "Giriş" ikonuna tıklayıp şifreyi girmelisiniz.', Icons.admin_panel_settings, Colors.redAccent),
          _kilavuzKarti(context, '2. Süper Arama Motoru', 'Ekranın üstündeki Büyüteç ikonuna basarak sistemdeki HER ŞEYİ tek bir yerden arayabilirsiniz.', Icons.search, kDepoZekaPrimary),
          _kilavuzKarti(context, '3. Ana Ekran Paneli', 'Ortadaki renkli kutular deponuzun anlık özetidir. Herhangi bir kutuya tıkladığınızda o bölümün detaylı listesine ulaşırsınız.', Icons.dashboard, kDepoZekaSecondary),
          _kilavuzKarti(context, '4. Raporlama (Excel & PDF)', 'Ana sayfadaki Excel veya PDF butonlarına basarak sistemin o anki tam özetini tek tıkla resmi bir rapor halinde indirebilirsiniz.', Icons.picture_as_pdf, Colors.red),
          _kilavuzKarti(context, '5. Revizyon (İşlem) Kaydetme', 'Bir karta müdahale ettiğinizde o kartın detayına girip "Revizyon Ekle" diyebilirsiniz. Sistem bunu tarih/saat ile birlikte sonsuza dek kayıt altına alır.', Icons.history_edu, Colors.purple),
          _kilavuzKarti(context, '6. Sistemi Yedekleme', 'Ekranın en altındaki "Yedekle" butonuna basarak tüm fabrikanın verisini (.json) dosyası olarak indirebilirsiniz.', Icons.cloud_sync, Colors.green),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class AnaGezinmeSayfasi extends StatefulWidget {
  const AnaGezinmeSayfasi({super.key});
  @override
  State<AnaGezinmeSayfasi> createState() => _AnaGezinmeSayfasiState();
}

class _AnaGezinmeSayfasiState extends State<AnaGezinmeSayfasi> {
  bool isAdmin = false; 

  void sifreDegistirmePenceresi() {
    TextEditingController eskiSifreKontrolcusu = TextEditingController();
    TextEditingController yeniSifreKontrolcusu = TextEditingController();
    
    void degistir() async {
      if (eskiSifreKontrolcusu.text == gecerliAdminSifresi) {
        if (yeniSifreKontrolcusu.text.isNotEmpty) {
          setState(() { gecerliAdminSifresi = yeniSifreKontrolcusu.text; });
          await verileriKaydet(); 
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre başarıyla değiştirildi!'), backgroundColor: Colors.green));
        } else { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni şifre boş olamaz!'), backgroundColor: Colors.orange)); 
        }
      } else { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eski şifre hatalı!'), backgroundColor: Colors.red)); 
      }
    }
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.password, color: kDepoZekaPrimary), SizedBox(width: 10), Text('Admin Şifresini Değiştir')]),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: eskiSifreKontrolcusu, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut Şifre', prefixIcon: Icon(Icons.lock_outline))), 
            const SizedBox(height: 10), 
            TextField(controller: yeniSifreKontrolcusu, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni Şifre', prefixIcon: Icon(Icons.lock)), onSubmitted: (_) => degistir())
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: degistir, child: const Text('Değiştir'))
        ]
    ));
  }

  void adminGirisiYap() {
    TextEditingController sifreKontrolcusu = TextEditingController();
    
    void girisTetikle() {
      if (sifreKontrolcusu.text == gecerliAdminSifresi) { 
        setState(() => isAdmin = true); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin yetkileri aktif!'), backgroundColor: Colors.green));
      } else { 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı şifre!'), backgroundColor: Colors.red)); 
      }
    }
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.admin_panel_settings, color: kDepoZekaPrimary), SizedBox(width: 10), Text('Yönetici Girişi')]),
        content: TextField(controller: sifreKontrolcusu, obscureText: true, decoration: const InputDecoration(hintText: 'Şifrenizi girin', prefixIcon: Icon(Icons.lock)), textInputAction: TextInputAction.done, onSubmitted: (_) => girisTetikle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: girisTetikle, child: const Text('Giriş Yap'))
        ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: depoZekaAppBarBackground(), 
        titleSpacing: 16,
        centerTitle: false, 
        toolbarHeight: 85, 
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: DepoZekaLogo(size: 24)
        ),
        actions: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.50),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, 
              reverse: true, 
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  IconButton(icon: const Icon(Icons.help_outline, color: Colors.lightBlueAccent), tooltip: 'Kılavuz', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KullanimKilavuzuSayfasi()))), 
                  const SizedBox(width: 5),
                  IconButton(icon: const Icon(Icons.search, color: Colors.white), tooltip: 'Arama', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SuperAramaSayfasi(isAdmin: isAdmin))).then((_) => setState((){}))),
                  IconButton(icon: const Icon(Icons.smart_toy, color: Colors.yellowAccent), tooltip: 'Asistan', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AkilliAsistanSayfasi()))),
                  IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.white70), tooltip: 'Arşiv', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ArsivSayfasi(isAdmin: isAdmin))).then((_) => setState((){}))),
                  if (isAdmin) 
                    IconButton(icon: const Icon(Icons.vpn_key, color: Colors.greenAccent), tooltip: 'Şifre Değiştir', onPressed: sifreDegistirmePenceresi),
                  
                  IconButton(icon: Icon(temaYoneticisi.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode, color: Colors.yellowAccent), onPressed: () async { 
                    setState(() => temaYoneticisi.value = temaYoneticisi.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light); 
                    final prefs = await SharedPreferences.getInstance(); 
                    await prefs.setBool('isDarkTheme', temaYoneticisi.value == ThemeMode.dark); 
                  }),
                  IconButton(icon: Icon(isAdmin ? Icons.logout : Icons.login, color: isAdmin ? Colors.redAccent : Colors.white), onPressed: () { 
                    if (isAdmin) { 
                      setState(() => isAdmin = false); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çıkış yapıldı.'))); 
                    } else { 
                      adminGirisiYap(); 
                    } 
                  }),
                ]
              )
            )
          )
        ], 
      ),
      body: OzetPaneliSayfasi(isAdmin: isAdmin),
    );
  }
}

// --- SÜPER ARAMA SAYFASI ---
class SuperAramaSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const SuperAramaSayfasi({super.key, required this.isAdmin});
  @override
  State<SuperAramaSayfasi> createState() => _SuperAramaSayfasiState();
}

class _SuperAramaSayfasiState extends State<SuperAramaSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<Map<String, dynamic>> sonuclar = [];

  void tumSistemiTara(String aranan) {
    sonuclar.clear(); 
    if (aranan.trim().isEmpty) { 
      setState(() {}); 
      return; 
    } 
    String s = aranan.toLowerCase().trim();

    for (var k in tumKartlarDeposu) { 
      if (k.stokNo.toLowerCase().contains(s) || k.tip.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'Depo Kartı', 'ikon': Icons.inventory_2, 'renk': Colors.orange, 'baslik': '${k.tip} (${k.stokNo})', 'altbaslik': 'Depoda - Revizyon: ${k.revizyonlar.length}', 'nesne': k}); 
      } 
    }
    
    for (var m in tumMakinalar) { 
      if (m.ad.toLowerCase().contains(s) || m.kod.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'Makina', 'ikon': Icons.precision_manufacturing, 'renk': Colors.blue, 'baslik': '${m.ad} (${m.kod})', 'altbaslik': 'Bağlı Kart: ${m.bagliKartlar.length}', 'nesne': m}); 
      }
      for (var k in m.bagliKartlar) { 
        if (k.stokNo.toLowerCase().contains(s) || k.tip.toLowerCase().contains(s)) { 
          sonuclar.add({'tip': 'Aktif Kart', 'ikon': Icons.memory, 'renk': Colors.green, 'baslik': '${k.tip} (${k.stokNo})', 'altbaslik': 'Makina: ${m.ad}', 'nesne': k}); 
        } 
      } 
    }
    
    for (var mal in smdMalzemeler) { 
      if (mal.shKodu.toLowerCase().contains(s) || mal.hKodu.toLowerCase().contains(s) || mal.raf.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'SMD Raf', 'ikon': Icons.developer_board, 'renk': kDepoZekaPrimary, 'baslik': 'SH: ${mal.shKodu}', 'altbaslik': 'H: ${mal.hKodu} | Raf: ${mal.raf}', 'nesne': mal}); 
      } 
    }
    
    for (var mal in bacakliMalzemeler) { 
      if (mal.shKodu.toLowerCase().contains(s) || mal.hKodu.toLowerCase().contains(s) || mal.raf.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'Bacaklı Raf', 'ikon': Icons.hub, 'renk': Colors.cyan, 'baslik': 'SH: ${mal.shKodu}', 'altbaslik': 'H: ${mal.hKodu} | Raf: ${mal.raf}', 'nesne': mal}); 
      } 
    }
    
    for (var mal in smdDepoMalzemeler) { 
      if (mal.urunIsmi.toLowerCase().contains(s) || mal.urunKodu.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'SMD Depo', 'ikon': Icons.inventory, 'renk': Colors.orangeAccent, 'baslik': mal.urunIsmi, 'altbaslik': 'Kod: ${mal.urunKodu}', 'nesne': mal}); 
      } 
    }
    
    for (var mal in bacakliDepoMalzemeler) { 
      if (mal.urunIsmi.toLowerCase().contains(s) || mal.urunKodu.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'Bacaklı Depo', 'ikon': Icons.dns, 'renk': Colors.purpleAccent, 'baslik': mal.urunIsmi, 'altbaslik': 'Kod: ${mal.urunKodu}', 'nesne': mal}); 
      } 
    }
    
    for (var p in tumPcbDeposu) { 
      if (p.isim.toLowerCase().contains(s) || p.stokNo.toLowerCase().contains(s)) { 
        sonuclar.add({'tip': 'PCB', 'ikon': Icons.layers, 'renk': Colors.teal, 'baslik': p.stokNo, 'altbaslik': 'Kod: ${p.isim} | Eklenme: ${p.eklenmeTarihi}', 'nesne': p}); 
      } 
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: depoZekaAppBarBackground(), 
        titleSpacing: 16, 
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: aramaKontrolcusu, 
                autofocus: true, 
                style: const TextStyle(color: Colors.white, fontSize: 18), 
                decoration: const InputDecoration(hintText: 'Arama Yapın...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none, focusedBorder: InputBorder.none, filled: false), 
                onChanged: tumSistemiTara
              )
            ), 
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white), 
              onPressed: () { 
                aramaKontrolcusu.clear(); 
                tumSistemiTara(""); 
              }
            )
          ]
        ), 
        actions: const [SizedBox.shrink()]
      ),
      body: aramaKontrolcusu.text.isEmpty 
        ? Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  Icon(Icons.search_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)), 
                  const SizedBox(height: 10), 
                  Text('Sistem genelinde arama yapın', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6)))
                ]
              )
            )
          ) 
        : sonuclar.isEmpty 
          ? const Center(child: Text('Hiçbir sonuç bulunamadı.')) 
          : ListView.builder(
              padding: const EdgeInsets.all(8), 
              itemCount: sonuclar.length, 
              itemBuilder: (context, index) {
                final s = sonuclar[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8), 
                      decoration: BoxDecoration(color: (s['renk'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle), 
                      child: Icon(s['ikon'] as IconData, color: s['renk'] as Color, size: 28)
                    ), 
                    title: Text(s['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.bold)), 
                    subtitle: Text(s['altbaslik'] as String, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])), 
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      decoration: BoxDecoration(color: (s['renk'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), 
                      child: Text(s['tip'] as String, style: TextStyle(fontSize: 10, color: s['renk'] as Color, fontWeight: FontWeight.bold))
                    ),
                    onTap: () { 
                      if (s['nesne'] != null) { 
                        if (s['tip'] == 'Makina') { 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MakinaDetaySayfasi(makina: s['nesne'] as Makina, isAdmin: widget.isAdmin))); 
                        } 
                        else if (s['tip'] == 'Depo Kartı' || s['tip'] == 'Aktif Kart') { 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => KartRevizyonSayfasi(kart: s['nesne'] as Kart, isAdmin: widget.isAdmin))); 
                        } 
                        else if (s['tip'] == 'PCB') { 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PcbDeposuSayfasi(isAdmin: widget.isAdmin))); 
                        } 
                      } 
                    },
                  )
                );
              }
            ),
    );
  }
}

// --- ARŞİV SAYFASI ---
class ArsivSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const ArsivSayfasi({super.key, required this.isAdmin});
  @override
  State<ArsivSayfasi> createState() => _ArsivSayfasiState();
}

class _ArsivSayfasiState extends State<ArsivSayfasi> with SingleTickerProviderStateMixin {
  late TabController _tabController; 
  bool secimModu = false;
  Set<Kart> seciliKartlar = {}; 
  Set<Makina> seciliMakinalar = {}; 
  Set<Malzeme> seciliMalzemeler = {};
  
  int get toplamSecili => seciliKartlar.length + seciliMakinalar.length + seciliMalzemeler.length;
  
  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 3, vsync: this); 
    _tabController.addListener(() { 
      if (_tabController.indexIsChanging) { 
        secimiKapat(); 
      } 
    }); 
  }

  @override
  void dispose() { 
    _tabController.dispose(); 
    super.dispose(); 
  }

  void secimiKapat() { 
    setState(() { 
      secimModu = false; 
      seciliKartlar.clear(); 
      seciliMakinalar.clear(); 
      seciliMalzemeler.clear(); 
    }); 
  }
  
  void tumunuSec() { 
    setState(() { 
      if (_tabController.index == 0) { 
        if (seciliKartlar.length == arsivlenmisKartlar.length) { 
          seciliKartlar.clear(); 
          secimModu = false; 
        } else { 
          seciliKartlar.addAll(arsivlenmisKartlar); 
          secimModu = true; 
        } 
      } 
      else if (_tabController.index == 1) { 
        if (seciliMakinalar.length == arsivlenmisMakinalar.length) { 
          seciliMakinalar.clear(); 
          secimModu = false; 
        } else { 
          seciliMakinalar.addAll(arsivlenmisMakinalar); 
          secimModu = true; 
        } 
      } 
      else if (_tabController.index == 2) { 
        if (seciliMalzemeler.length == arsivlenmisMalzemeler.length) { 
          seciliMalzemeler.clear(); 
          secimModu = false; 
        } else { 
          seciliMalzemeler.addAll(arsivlenmisMalzemeler); 
          secimModu = true; 
        } 
      } 
    }); 
  }
  
  void topluGeriYukle() { 
    setState(() { 
      for(var k in seciliKartlar) { 
        arsivlenmisKartlar.remove(k); 
        tumKartlarDeposu.add(k); 
      } 
      for(var m in seciliMakinalar) { 
        arsivlenmisMakinalar.remove(m); 
        tumMakinalar.add(m); 
      } 
      for(var mal in seciliMalzemeler) { 
        arsivlenmisMalzemeler.remove(mal); 
        if(mal.depoTipi.contains('SMD Raf') || mal.depoTipi == 'SMD') { smdMalzemeler.add(mal); } 
        else if(mal.depoTipi.contains('Bacaklı Raf') || mal.depoTipi == 'Bacaklı') { bacakliMalzemeler.add(mal); } 
        else if(mal.depoTipi == 'SMD Depo') { smdDepoMalzemeler.add(mal); } 
        else if(mal.depoTipi == 'Bacaklı Depo') { bacakliDepoMalzemeler.add(mal); } 
      } 
    }); 
    verileriKaydet(); 
    secimiKapat(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler başarıyla geri yüklendi!'), backgroundColor: Colors.green)); 
  }
  
  void topluKaliciSil() { 
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text('$toplamSecili Öğe Kalıcı Silinsin mi?'), 
        content: const Text('Bu işlem geri alınamaz. Veritabanından tamamen silinecektir.'), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () { 
              setState(() { 
                for(var k in seciliKartlar) { arsivlenmisKartlar.remove(k); } 
                for(var m in seciliMakinalar) { arsivlenmisMakinalar.remove(m); } 
                for(var mal in seciliMalzemeler) { arsivlenmisMalzemeler.remove(mal); } 
              }); 
              verileriKaydet(); 
              secimiKapat(); 
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler sonsuza dek silindi.'))); 
            }, 
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white))
          ) 
        ]
      )
    ); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : depoZekaAppBarBackground(), 
        backgroundColor: secimModu ? Colors.blueGrey[700] : null, 
        titleSpacing: 16, 
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Flexible(child: Text(secimModu ? '$toplamSecili Seçildi' : 'Sistem Arşivi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), 
            if (secimModu) 
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, 
                  reverse: true, 
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), tooltip: 'Tümünü Seç', onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.restore, color: Colors.white), tooltip: 'Geri Yükle', onPressed: topluGeriYukle), 
                      IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'Kalıcı Sil', onPressed: topluKaliciSil)
                    ]
                  )
                )
              )
          ]
        ), 
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: secimiKapat) : null, 
        actions: const [SizedBox.shrink()], 
        bottom: TabBar(
          controller: _tabController, 
          indicatorColor: Colors.white, 
          labelColor: Colors.white, 
          unselectedLabelColor: Colors.white70, 
          isScrollable: true, 
          tabs: const [ 
            Tab(icon: Icon(Icons.memory), text: 'Kartlar'), 
            Tab(icon: Icon(Icons.precision_manufacturing), text: 'Makinalar'), 
            Tab(icon: Icon(Icons.developer_board), text: 'Ürünler') 
          ]
        )
      ),
      body: TabBarView(
        controller: _tabController, 
        children: [
          arsivlenmisKartlar.isEmpty 
            ? const Center(child: Text('Arşiv boş.')) 
            : ListView.builder(
                padding: const EdgeInsets.all(8), 
                itemCount: arsivlenmisKartlar.length, 
                itemBuilder: (context, index) { 
                  final kart = arsivlenmisKartlar[index]; 
                  bool seciliMi = seciliKartlar.contains(kart); 
                  return Card(
                    color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.2) : null, 
                    child: ListTile(
                      onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliKartlar.add(kart); }); } : null, 
                      onTap: secimModu ? () { setState((){ if (seciliMi) { seciliKartlar.remove(kart); if(toplamSecili==0) secimModu=false; } else { seciliKartlar.add(kart); } }); } : null, 
                      title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(decoration: TextDecoration.lineThrough)), 
                      subtitle: Text('Silinme Öncesi: ${kart.eklenmeTarihi}'), 
                      trailing: secimModu ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliKartlar.add(kart); } else { seciliKartlar.remove(kart); if(toplamSecili==0) secimModu=false; } }); }) : null, 
                    )
                  ); 
                }
              ),
          arsivlenmisMakinalar.isEmpty 
            ? const Center(child: Text('Arşiv boş.')) 
            : ListView.builder(
                padding: const EdgeInsets.all(8), 
                itemCount: arsivlenmisMakinalar.length, 
                itemBuilder: (context, index) { 
                  final makina = arsivlenmisMakinalar[index]; 
                  bool seciliMi = seciliMakinalar.contains(makina); 
                  return Card(
                    color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.2) : null, 
                    child: ListTile(
                      onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliMakinalar.add(makina); }); } : null, 
                      onTap: secimModu ? () { setState((){ if (seciliMi) { seciliMakinalar.remove(makina); if(toplamSecili==0) secimModu=false; } else { seciliMakinalar.add(makina); } }); } : null, 
                      title: Text('${makina.ad} (${makina.kod})', style: const TextStyle(decoration: TextDecoration.lineThrough)), 
                      subtitle: Text('Silinme Öncesi: ${makina.eklenmeTarihi}'), 
                      trailing: secimModu ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliMakinalar.add(makina); } else { seciliMakinalar.remove(makina); if(toplamSecili==0) secimModu=false; } }); }) : null, 
                    )
                  ); 
                }
              ),
          arsivlenmisMalzemeler.isEmpty 
            ? const Center(child: Text('Arşiv boş.')) 
            : ListView.builder(
                padding: const EdgeInsets.all(8), 
                itemCount: arsivlenmisMalzemeler.length, 
                itemBuilder: (context, index) { 
                  final malz = arsivlenmisMalzemeler[index]; 
                  bool seciliMi = seciliMalzemeler.contains(malz); 
                  bool isRaf = malz.depoTipi.contains('Raf') || malz.depoTipi == 'SMD' || malz.depoTipi == 'Bacaklı'; 
                  return Card(
                    color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.2) : null, 
                    child: ListTile(
                      onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliMalzemeler.add(malz); }); } : null, 
                      onTap: secimModu ? () { setState((){ if (seciliMi) { seciliMalzemeler.remove(malz); if(toplamSecili==0) secimModu=false; } else { seciliMalzemeler.add(malz); } }); } : null, 
                      title: Text(isRaf ? 'SH: ${malz.shKodu} - H: ${malz.hKodu}' : malz.urunIsmi, style: const TextStyle(decoration: TextDecoration.lineThrough)), 
                      subtitle: Text(isRaf ? 'Raf: ${malz.raf}\nSilinme: ${malz.eklenmeTarihi}' : 'Kod: ${malz.urunKodu}\nSilinme: ${malz.eklenmeTarihi}'), 
                      trailing: secimModu ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliMalzemeler.add(malz); } else { seciliMalzemeler.remove(malz); if(toplamSecili==0) secimModu=false; } }); }) : null, 
                    )
                  ); 
                }
              ),
      ])
    );
  }
}

// --- ÖZET PANELİ VE İŞ TAKİBİ ---
class OzetPaneliSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const OzetPaneliSayfasi({super.key, required this.isAdmin});
  @override
  State<OzetPaneliSayfasi> createState() => _OzetPaneliSayfasiState();
}

class _OzetPaneliSayfasiState extends State<OzetPaneliSayfasi> {
  TextEditingController gorevKontrolcusu = TextEditingController(); 
  TextEditingController adetKontrolcusu = TextEditingController(text: '1'); 

  Future<void> _genelCsvYukle({required String baslik, required String bilgi, required Function(List<String>) satirIsleyici}) async {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text(baslik), 
        content: Text(bilgi), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDepoZekaPrimary), 
            onPressed: () async { 
              Navigator.pop(context); 
              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']); 
              if (result != null) { 
                try { 
                  File file = File(result.files.single.path!); 
                  List<int> bytes = await file.readAsBytes(); 
                  String contents = csvIcerikCoz(bytes); 
                  
                  if (contents.startsWith('\uFEFF') || contents.startsWith('\xEF\xBB\xBF')) { 
                    contents = contents.substring(1); 
                  }
                  
                  List<String> lines = contents.split(RegExp(r'\r\n|\n|\r')); 
                  int islenenSatir = 0; 
                  
                  for (int i = 0; i < lines.length; i++) { 
                    String line = lines[i].trim(); 
                    if (line.isEmpty) continue; 
                    if (i == 0 && (line.toLowerCase().contains('makina') || line.toLowerCase().contains('kart') || line.toLowerCase().contains('kod') || line.toLowerCase().contains('ürün') || line.toLowerCase().contains('sh'))) {
                      continue; 
                    }
                    List<String> cols = line.split(RegExp(r'[;,]')); 
                    satirIsleyici(cols); 
                    islenenSatir++; 
                  } 
                  
                  setState(() {}); 
                  verileriKaydet(); 
                  
                  if (context.mounted) { 
                    if (islenenSatir > 0) { 
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$islenenSatir kayıt yüklendi!'), backgroundColor: Colors.green)); 
                    } else { 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt bulunamadı.'), backgroundColor: Colors.orange)); 
                    } 
                  } 
                } catch (e) { 
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red)); 
                } 
              } 
            }, 
            child: const Text('Dosya Seç', style: TextStyle(color: Colors.white))
          ) 
        ]
      )
    );
  }

  void _bakimCsvYukle() { 
    _genelCsvYukle(
      baslik: 'Bakım Periyodu Yükle (CSV)', 
      bilgi: "Sütunlar: Makina Adı ; Son Bakım ; Sıradaki Bakım ; Durum", 
      satirIsleyici: (cols) { 
        if (cols.length >= 3) { 
          String arananMakina = metniBuyut(cols[0]); 
          for (var b in ozelBakimListesi) { 
            if (metniBuyut(b.ad) == arananMakina) { 
              b.sonBakim = cols[1].trim(); 
              b.siradakiBakim = cols[2].trim(); 
              b.durum = cols.length >= 4 ? metniBuyut(cols[3]) : 'Normal'; 
            } 
          } 
        } 
      }
    ); 
  }
  
  void _makinaYuke() { 
    _genelCsvYukle(
      baslik: 'Makina Listesi Yükle', 
      bilgi: "Sütunlar: Makina Adı, Makina Kodu", 
      satirIsleyici: (cols) { 
        if (cols.length >= 2 && cols[0].trim().isNotEmpty) { 
          tumMakinalar.add(Makina(ad: metniBuyut(cols[0]), kod: metniBuyut(cols[1]), eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: [])); 
        } else if (cols.isNotEmpty && cols[0].trim().isNotEmpty) { 
          tumMakinalar.add(Makina(ad: metniBuyut(cols[0]), kod: '-', eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: [])); 
        } 
      }
    ); 
  }
  
  void _kartYukle() { 
    _genelCsvYukle(
      baslik: 'Kart Listesi Yükle', 
      bilgi: "Sütunlar: Kart İsmi, Kart Kodu", 
      satirIsleyici: (cols) { 
        if (cols.length >= 2 && cols[0].trim().isNotEmpty && cols[1].trim().isNotEmpty) { 
          tumKartlarDeposu.add(Kart(tip: metniBuyut(cols[0]), stokNo: metniBuyut(cols[1]), eklenmeTarihi: anlikTarihSaatGetir(), revizyonlar: [])); 
        } 
      }
    ); 
  }
  
  void _pcbYukle() { 
    _genelCsvYukle(
      baslik: 'PCB Listesi Yükle', 
      bilgi: "Sütunlar: Stok Kodu, İsim", 
      satirIsleyici: (cols) { 
        if (cols.length >= 2 && cols[0].trim().isNotEmpty) { 
          tumPcbDeposu.add(PcbKart(
            stokNo: metniBuyut(cols[0]), 
            isim: metniBuyut(cols[1]), 
            eklenmeTarihi: anlikTarihSaatGetir()
          )); 
        } 
      }
    ); 
  }
  
  void _malzemeYukle(String tip) { 
    bool isRaf = tip.contains('Raf'); 
    String bilgi = isRaf ? "Sütunlar: SH Kodu, H Kodu, Raf" : "Sütunlar: Ürün İsmi, Ürün Kodu"; 
    _genelCsvYukle(
      baslik: '$tip Yükle', 
      bilgi: bilgi, 
      satirIsleyici: (cols) { 
        if (isRaf && cols.length >= 3 && cols[0].trim().isNotEmpty) { 
          Malzeme m = Malzeme(shKodu: metniBuyut(cols[0]), hKodu: metniBuyut(cols[1]), raf: metniBuyut(cols[2]), depoTipi: tip, eklenmeTarihi: anlikTarihSaatGetir()); 
          if (tip == 'SMD Raf') { smdMalzemeler.add(m); } else { bacakliMalzemeler.add(m); } 
        } else if (!isRaf && cols.length >= 2 && cols[0].trim().isNotEmpty) { 
          Malzeme m = Malzeme(urunIsmi: metniBuyut(cols[0]), urunKodu: metniBuyut(cols[1]), depoTipi: tip, eklenmeTarihi: anlikTarihSaatGetir()); 
          if (tip == 'SMD Depo') { smdDepoMalzemeler.add(m); } else { bacakliDepoMalzemeler.add(m); } 
        } 
      }
    ); 
  }
  
  void _revizyonYukle() { 
    _genelCsvYukle(
      baslik: 'Revizyon Yükle', 
      bilgi: "Sütunlar: Kart İsmi(veya Kodu), Makina Adı, Açıklama, Tarih(Ops)", 
      satirIsleyici: (cols) { 
        if (cols.length >= 3 && cols[0].trim().isNotEmpty && cols[2].trim().isNotEmpty) { 
          String kArama = metniBuyut(cols[0]); 
          String mAdi = metniBuyut(cols[1]); 
          String acik = metniBuyut(cols[2]); 
          String trh = cols.length > 3 && cols[3].trim().isNotEmpty ? cols[3].trim() : anlikTarihSaatGetir(); 
          Kart? hKart; 
          
          for(var k in tumKartlarDeposu) { 
            if (metniBuyut(k.stokNo) == kArama || metniBuyut(k.tip) == kArama) { hKart = k; break; } 
          } 
          if (hKart == null) { 
            for(var m in tumMakinalar) { 
              for(var k in m.bagliKartlar) { 
                if (metniBuyut(k.stokNo) == kArama || metniBuyut(k.tip) == kArama) { hKart = k; break; } 
              } 
              if (hKart != null) break; 
            } 
          } 
          if (hKart != null) { 
            hKart.revizyonlar.add(Revizyon(tarihSaat: trh, aciklama: acik, makinaAdi: mAdi)); 
          } 
        } 
      }
    ); 
  }

  Future<void> excelRaporuIndir(BuildContext context) async {
    String csvVerisi = "Makina Adi;Makina Kodu;Bagli Kart Sayisi;Kart Ismi;Kart Kodu;Revizyon Sayisi;Eklenme Tarihi\n";
    for (var makina in tumMakinalar) { 
      if (makina.bagliKartlar.isEmpty) { 
        csvVerisi += "${makina.ad};${makina.kod};0;Yok;Yok;0;${makina.eklenmeTarihi}\n"; 
      } else { 
        for (var kart in makina.bagliKartlar) { 
          csvVerisi += "${makina.ad};${makina.kod};${makina.bagliKartlar.length};${kart.tip};${kart.stokNo};${kart.revizyonlar.length};${kart.eklenmeTarihi}\n"; 
        } 
      } 
    }
    try { 
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) { 
        String? kayitYeri = await FilePicker.platform.saveFile(dialogTitle: 'Kaydet', fileName: 'Sistem_Raporu.csv', type: FileType.custom, allowedExtensions: ['csv']); 
        if (kayitYeri != null) { 
          File dosya = File(kayitYeri); 
          await dosya.writeAsString('\uFEFF$csvVerisi', encoding: utf8); 
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel başarıyla kaydedildi!'), backgroundColor: Colors.green)); 
        } 
      } else { 
        final dir = await getApplicationDocumentsDirectory(); 
        final dosyaYolu = '${dir.path}/Sistem_Raporu.csv'; 
        File dosya = File(dosyaYolu); 
        await dosya.writeAsString('\uFEFF$csvVerisi', encoding: utf8); 
        await Future.delayed(const Duration(milliseconds: 500)); 
        await Share.shareXFiles([XFile(dosyaYolu)]); 
      } 
    } catch (e) { 
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata.'), backgroundColor: Colors.red)); 
    }
  }

  Future<void> _pdfRaporuOlustur(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: kDepoZekaPrimary)));
    try {
      final pdf = pw.Document(); 
      pw.Font? fTtf; 
      pw.Font? fBld;
      try { 
        fTtf = await PdfGoogleFonts.robotoRegular(); 
        fBld = await PdfGoogleFonts.robotoBold(); 
      } catch(e) {}
      
      List<Kart> cokRev = [...tumKartlarDeposu]; 
      for(var m in tumMakinalar) { cokRev.addAll(m.bagliKartlar); }
      
      cokRev.sort((a, b) => b.revizyonlar.length.compareTo(a.revizyonlar.length)); 
      cokRev = cokRev.where((k) => k.revizyonlar.isNotEmpty).toList();
      
      List<Map<String, dynamic>> bRev = [];
      void rTopla(List<Kart> krt) { 
        for (var k in krt) { 
          for (var r in k.revizyonlar) { 
            bRev.add({'kart': k, 'revizyon': r}); 
          } 
        } 
      }
      rTopla(tumKartlarDeposu); 
      for(var m in tumMakinalar) rTopla(m.bagliKartlar);
      
      bRev.sort((a, b) { 
        return tarihCozumle((b['revizyon'] as Revizyon).tarihSaat).compareTo(tarihCozumle((a['revizyon'] as Revizyon).tarihSaat)); 
      });
      
      int tKSay = tumMakinalar.fold(0, (sum, m) => sum + m.bagliKartlar.length);
      
      pdf.addPage(pw.MultiPage(
        theme: fTtf != null ? pw.ThemeData.withFont(base: fTtf, bold: fBld) : null, 
        margin: const pw.EdgeInsets.all(32), 
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20), 
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2))), 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text('DEPOZEKA YÖNETİM SİSTEMİ', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)), 
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end, 
                    children: [
                      pw.Text('Yönetim Raporu', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)), 
                      pw.Text('Tarih: ${anlikTarihSaatGetir().split(' - ')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
                    ]
                  )
                ]
              )
            ),
            pw.SizedBox(height: 20), 
            pw.Text('SİSTEM ÖZETİ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), 
            pw.SizedBox(height: 10),
            pw.Row(children: [
              _pdfOzetKutusu('Makina', tumMakinalar.length.toString()), 
              _pdfOzetKutusu('Depo Kart', tumKartlarDeposu.length.toString()), 
              _pdfOzetKutusu('Takılı Kart', tKSay.toString()), 
              _pdfOzetKutusu('Revizyon', bRev.length.toString()), 
              _pdfOzetKutusu('PCB', tumPcbDeposu.length.toString())
            ]),
            pw.SizedBox(height: 10), 
            pw.Row(children: [
              _pdfOzetKutusu('SMD Raf', smdMalzemeler.length.toString()), 
              _pdfOzetKutusu('Bacaklı Raf', bacakliMalzemeler.length.toString()), 
              _pdfOzetKutusu('SMD Depo', smdDepoMalzemeler.length.toString()), 
              _pdfOzetKutusu('Bacaklı Depo', bacakliDepoMalzemeler.length.toString())
            ]),
            pw.SizedBox(height: 30), 
            pw.Text('KARTLAR', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), 
            pw.SizedBox(height: 10),
            cokRev.isEmpty 
              ? pw.Text('Revizyon yok.') 
              : pw.TableHelper.fromTextArray(
                  headers: ['Kod', 'İsim', 'Toplam'], 
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), 
                  cellStyle: const pw.TextStyle(fontSize: 10), 
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800), 
                  data: cokRev.map((k) => [k.stokNo, k.tip, k.revizyonlar.length.toString()]).toList()
                ),
            pw.SizedBox(height: 30), 
            pw.Text('SON İŞLEMLER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), 
            pw.SizedBox(height: 10),
            bRev.isEmpty 
              ? pw.Text('İşlem yok.') 
              : pw.TableHelper.fromTextArray(
                  headers: ['Tarih', 'Makina', 'Kart', 'Açıklama'], 
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), 
                  cellStyle: const pw.TextStyle(fontSize: 9), 
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800), 
                  columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(2.5), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(4.5)}, 
                  data: bRev.map((item) { 
                    Revizyon r = item['revizyon']; 
                    Kart k = item['kart']; 
                    return [r.tarihSaat.split(' - ')[0], r.makinaAdi, k.stokNo, r.aciklama]; 
                  }).toList()
                ),
          ];
        }
      ));
      
      Navigator.pop(context); 
      
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) { 
        String? kY = await FilePicker.platform.saveFile(dialogTitle: 'Kaydet', fileName: 'Rapor.pdf', type: FileType.custom, allowedExtensions: ['pdf']); 
        if (kY != null) { 
          File d = File(kY); 
          await d.writeAsBytes(await pdf.save()); 
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Kaydedildi!'), backgroundColor: Colors.green)); 
        } 
      } else { 
        final dir = await getApplicationDocumentsDirectory(); 
        final dY = '${dir.path}/Rapor.pdf'; 
        File d = File(dY); 
        await d.writeAsBytes(await pdf.save()); 
        await Future.delayed(const Duration(milliseconds: 500)); 
        await Share.shareXFiles([XFile(dY)]); 
      }
    } catch (e) { 
      if(context.mounted) Navigator.pop(context); 
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Hatası.'), backgroundColor: Colors.red)); 
    }
  }

  pw.Widget _pdfOzetKutusu(String baslik, String deger) { 
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3), 
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5), 
        decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))), 
        child: pw.Column(
          children: [
            pw.Text(deger, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)), 
            pw.SizedBox(height: 4), 
            pw.Text(baslik, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))
          ]
        )
      )
    ); 
  }

  Future<void> _sistemiYedekle(BuildContext context) async {
    try {
      Map<String, dynamic> tamYedek = {
        'versiyon': '1.0', 
        'tarih': anlikTarihSaatGetir(), 
        'gunlukIsler': gunlukIsler.map((e) => e.toJson()).toList(), 
        'kartlar': tumKartlarDeposu.map((e) => e.toJson()).toList(), 
        'makinalar': tumMakinalar.map((e) => e.toJson()).toList(), 
        'smdMalzemeler': smdMalzemeler.map((e) => e.toJson()).toList(), 
        'bacakliMalzemeler': bacakliMalzemeler.map((e) => e.toJson()).toList(), 
        'smdDepoMalzemeler': smdDepoMalzemeler.map((e) => e.toJson()).toList(), 
        'bacakliDepoMalzemeler': bacakliDepoMalzemeler.map((e) => e.toJson()).toList(), 
        'arsivKartlar': arsivlenmisKartlar.map((e) => e.toJson()).toList(), 
        'arsivMakinalar': arsivlenmisMakinalar.map((e) => e.toJson()).toList(), 
        'arsivMalzemeler': arsivlenmisMalzemeler.map((e) => e.toJson()).toList(), 
        'ozelBakimListesi': ozelBakimListesi.map((e) => e.toJson()).toList(), 
        'kayitliPcbler': tumPcbDeposu.map((e) => e.toJson()).toList(), 
        'arsivliPcbler': arsivlenmisPcbler.map((e) => e.toJson()).toList(),
      };
      String jsonVerisi = jsonEncode(tamYedek);
      
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) { 
        String? kY = await FilePicker.platform.saveFile(dialogTitle: 'Kaydet', fileName: 'Yedek.json', type: FileType.custom, allowedExtensions: ['json']); 
        if (kY != null) { 
          await File(kY).writeAsString(jsonVerisi, encoding: utf8); 
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi!'), backgroundColor: Colors.green)); 
        } 
      } else { 
        final dir = await getApplicationDocumentsDirectory(); 
        final dY = '${dir.path}/Yedek.json'; 
        await File(dY).writeAsString(jsonVerisi, encoding: utf8); 
        await Future.delayed(const Duration(milliseconds: 500)); 
        await Share.shareXFiles([XFile(dY)]); 
      }
    } catch (e) { 
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata.'), backgroundColor: Colors.red)); 
    }
  }

  Future<void> _sistemiGeriYukle(BuildContext context) async {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Text('Sistemi İçe Aktar'), 
        content: const Text('Mevcut veriler silinip yedek yüklenecek. Emin misiniz?'), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () async { 
              Navigator.pop(context); 
              FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']); 
              if (res != null) { 
                try { 
                  File f = File(res.files.single.path!); 
                  List<int> b = await f.readAsBytes(); 
                  String c = utf8.decode(b, allowMalformed: true); 
                  if (c.startsWith('\uFEFF')) c = c.substring(1); 
                  Map<String, dynamic> v = jsonDecode(c); 
                  
                  setState(() {
                    if (v.containsKey('gunlukIsler')) gunlukIsler = List<IsGorevi>.from(v['gunlukIsler'].map((x) => IsGorevi.fromJson(x))); 
                    if (v.containsKey('kartlar')) tumKartlarDeposu = List<Kart>.from(v['kartlar'].map((x) => Kart.fromJson(x))); 
                    if (v.containsKey('makinalar')) tumMakinalar = List<Makina>.from(v['makinalar'].map((x) => Makina.fromJson(x))); 
                    if (v.containsKey('smdMalzemeler')) smdMalzemeler = List<Malzeme>.from(v['smdMalzemeler'].map((x) => Malzeme.fromJson(x))); 
                    if (v.containsKey('bacakliMalzemeler')) bacakliMalzemeler = List<Malzeme>.from(v['bacakliMalzemeler'].map((x) => Malzeme.fromJson(x))); 
                    if (v.containsKey('smdDepoMalzemeler')) smdDepoMalzemeler = List<Malzeme>.from(v['smdDepoMalzemeler'].map((x) => Malzeme.fromJson(x))); 
                    if (v.containsKey('bacakliDepoMalzemeler')) bacakliDepoMalzemeler = List<Malzeme>.from(v['bacakliDepoMalzemeler'].map((x) => Malzeme.fromJson(x))); 
                    if (v.containsKey('arsivKartlar')) arsivlenmisKartlar = List<Kart>.from(v['arsivKartlar'].map((x) => Kart.fromJson(x))); 
                    if (v.containsKey('arsivMakinalar')) arsivlenmisMakinalar = List<Makina>.from(v['arsivMakinalar'].map((x) => Makina.fromJson(x))); 
                    if (v.containsKey('arsivMalzemeler')) arsivlenmisMalzemeler = List<Malzeme>.from(v['arsivMalzemeler'].map((x) => Malzeme.fromJson(x))); 
                    if (v.containsKey('ozelBakimListesi')) ozelBakimListesi = List<OzelMakinaBakim>.from(v['ozelBakimListesi'].map((x) => OzelMakinaBakim.fromJson(x))); 
                    if (v.containsKey('kayitliPcbler')) tumPcbDeposu = List<PcbKart>.from(v['kayitliPcbler'].map((x) => PcbKart.fromJson(x))); 
                    if (v.containsKey('arsivliPcbler')) arsivlenmisPcbler = List<PcbKart>.from(v['arsivliPcbler'].map((x) => PcbKart.fromJson(x))); 
                  }); 
                  
                  verileriKaydet(); 
                  
                  if (context.mounted) { 
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaGezinmeSayfasi())); 
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yüklendi!'), backgroundColor: Colors.green)); 
                  } 
                } catch (e) { 
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata.'), backgroundColor: Colors.red)); 
                } 
              } 
            }, 
            child: const Text('Yükle')
          )
        ]
      )
    );
  }

  void _yeniIsEkle() {
    if (gorevKontrolcusu.text.trim().isNotEmpty) {
      int hedef = int.tryParse(adetKontrolcusu.text) ?? 1; 
      if (hedef < 1) hedef = 1;
      setState(() { 
        gunlukIsler.insert(0, IsGorevi(id: DateTime.now().millisecondsSinceEpoch.toString(), baslik: metniBuyut(gorevKontrolcusu.text), hedefSayi: hedef)); 
        gorevKontrolcusu.clear(); 
        adetKontrolcusu.text = '1'; 
      }); 
      verileriKaydet();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    int toplamMakina = tumMakinalar.length; 
    int depodakiKart = tumKartlarDeposu.length; 
    int makinalardakiToplamKart = tumMakinalar.fold(0, (sum, m) => sum + m.bagliKartlar.length);
    int smdRafSayisi = smdMalzemeler.length; 
    int bacakliRafSayisi = bacakliMalzemeler.length;
    int smdDepoSayisi = smdDepoMalzemeler.length; 
    int bacakliDepoSayisi = bacakliDepoMalzemeler.length;
    int toplamRevizyonSayisi = 0; 
    
    List<Kart> tumSistemdekiKartlar = [...tumKartlarDeposu]; 
    for(var m in tumMakinalar) { tumSistemdekiKartlar.addAll(m.bagliKartlar); } 
    for(var k in tumSistemdekiKartlar) { toplamRevizyonSayisi += k.revizyonlar.length; }
    
    int kalanIs = gunlukIsler.where((i) => !i.tamamlandi).length; 
    int kalanAdet = gunlukIsler.where((i) => !i.tamamlandi).fold(0, (sum, i) => sum + (i.hedefSayi - i.yapilanSayi));
    
    double eG = MediaQuery.of(context).size.width; 
    double kG = eG > 600 ? 220 : (eG / 2) - 24; 
    if (kG < 150) kG = eG - 32;

    return SingleChildScrollView( 
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity, 
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15), 
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]), 
            child: Wrap(
              alignment: WrapAlignment.spaceBetween, 
              crossAxisAlignment: WrapCrossAlignment.center, 
              spacing: 10, runSpacing: 10, 
              children: [
                Text('ANASAYFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Theme.of(context).colorScheme.primary)), 
                Wrap(
                  spacing: 6, runSpacing: 6, 
                  children: [
                    ElevatedButton.icon(onPressed: () => excelRaporuIndir(context), icon: const Icon(Icons.table_view, size: 16), label: const Text('Excel'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)), 
                    ElevatedButton.icon(onPressed: () => _pdfRaporuOlustur(context), icon: const Icon(Icons.picture_as_pdf, size: 16), label: const Text('PDF'), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent))
                  ]
                )
              ]
            )
          ),
          
          const SizedBox(height: 25),
          
          Wrap(
            spacing: 16, runSpacing: 16, 
            children: [
              _buildResponsiveKutu('Makinalar', toplamMakina.toString(), Icons.precision_manufacturing, kDepoZekaPrimary, const Color(0xFF00695C), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MakinalarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _makinaYuke),
              _buildResponsiveKutu('Depo Kart', depodakiKart.toString(), Icons.inventory_2, const Color(0xFF5C6BC0), const Color(0xFF283593), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => KartlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _kartYukle),
              _buildResponsiveKutu('PCB Depo', tumPcbDeposu.length.toString(), Icons.layers, const Color(0xFF00897B), const Color(0xFF004D40), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => PcbDeposuSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _pcbYukle),
              _buildResponsiveKutu('Takılı Kart', makinalardakiToplamKart.toString(), Icons.memory, const Color(0xFF66BB6A), const Color(0xFF2E7D32), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => AktifKartlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }), 
              _buildResponsiveKutu('Revizyonlar', toplamRevizyonSayisi.toString(), Icons.history_edu, const Color(0xFFAB47BC), const Color(0xFF6A1B9A), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => TumRevizyonlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _revizyonYukle),
              _buildResponsiveKutu('SMD Raf', smdRafSayisi.toString(), Icons.developer_board, const Color(0xFF8D6E63), const Color(0xFF4E342E), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'SMD Raf'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('SMD Raf')),
              _buildResponsiveKutu('Bacaklı Raf', bacakliRafSayisi.toString(), Icons.hub, const Color(0xFF78909C), const Color(0xFF37474F), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'Bacaklı Raf'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('Bacaklı Raf')),
              _buildResponsiveKutu('SMD Depo', smdDepoSayisi.toString(), Icons.inventory, kDepoZekaSecondary, const Color(0xFFE65100), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'SMD Depo'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('SMD Depo')),
              _buildResponsiveKutu('Bacaklı Depo', bacakliDepoSayisi.toString(), Icons.dns, const Color(0xFF26C6DA), const Color(0xFF006064), kG, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'Bacaklı Depo'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('Bacaklı Depo')),
            ]
          ),
          
          const SizedBox(height: 30), 
          const Divider(height: 40), 
          
          Wrap(
            alignment: WrapAlignment.spaceBetween, 
            crossAxisAlignment: WrapCrossAlignment.center, 
            children: [
              Text('Günlük İş Takibi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)), 
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: kalanIs > 0 ? Colors.orange : Colors.green, borderRadius: BorderRadius.circular(20)), child: Text('$kalanIs İş ($kalanAdet Adet) Kaldı', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))
            ]
          ),
          
          const SizedBox(height: 15),
          
          Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: TextField(controller: gorevKontrolcusu, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: "Örn: İşlem", prefixIcon: Icon(Icons.task_alt)), onSubmitted: (_) => _yeniIsEkle())), 
                    const SizedBox(width: 8), 
                    Expanded(flex: 1, child: TextField(controller: adetKontrolcusu, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Adet", prefixIcon: Icon(Icons.numbers)), onSubmitted: (_) => _yeniIsEkle())), 
                    const SizedBox(width: 8), 
                    Container(decoration: const BoxDecoration(color: kDepoZekaPrimary, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _yeniIsEkle))
                  ]
                ),
                
                if (gunlukIsler.isNotEmpty) ...[
                  const SizedBox(height: 15), 
                  ListView.builder(
                    shrinkWrap: true, 
                    physics: const NeverScrollableScrollPhysics(), 
                    itemCount: gunlukIsler.length, 
                    itemBuilder: (context, index) { 
                      final g = gunlukIsler[index]; 
                      return Card(
                        elevation: 0, 
                        color: g.tamamlandi ? (isDark ? Colors.grey[800] : Colors.grey.withValues(alpha: 0.1)) : Theme.of(context).scaffoldBackgroundColor, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))), 
                        margin: const EdgeInsets.only(bottom: 8), 
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), 
                          child: Row(
                            children: [
                              Checkbox(
                                activeColor: Colors.green, 
                                value: g.tamamlandi, 
                                onChanged: (v) { 
                                  setState(() { g.tamamlandi = v ?? false; if (g.tamamlandi) g.yapilanSayi = g.hedefSayi; }); 
                                  verileriKaydet(); 
                                }
                              ), 
                              Expanded(
                                child: Text(g.baslik, style: TextStyle(decoration: g.tamamlandi ? TextDecoration.lineThrough : null, color: g.tamamlandi ? Colors.grey : null, fontWeight: FontWeight.bold))
                              ), 
                              Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: g.tamamlandi ? null : () { if (g.yapilanSayi > 0) { setState(() { g.yapilanSayi--; }); verileriKaydet(); } }), 
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('${g.yapilanSayi} / ${g.hedefSayi}', style: TextStyle(fontWeight: FontWeight.bold, color: g.tamamlandi ? Colors.grey : kDepoZekaPrimary))), 
                                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: g.tamamlandi ? null : () { setState(() { g.yapilanSayi++; if (g.yapilanSayi >= g.hedefSayi) g.tamamlandi = true; }); verileriKaydet(); })
                                ]
                              ), 
                              const SizedBox(width: 8), 
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { setState(() { gunlukIsler.removeAt(index); }); verileriKaydet(); }), 
                              const SizedBox(width: 4)
                            ]
                          )
                        )
                      ); 
                    }
                  )
                ] else ...[
                  const Padding(padding: EdgeInsets.only(top: 16.0), child: Center(child: Text("Bugün için tüm işler tamamlandı! 🎉", style: TextStyle(color: Colors.grey))))
                ]
              ]
            )
          ),
          
          const SizedBox(height: 30), 
          
          ValueListenableBuilder<bool>(
            valueListenable: bakimPaneliniGoster, 
            builder: (context, aktifMi, child) { 
              if (!aktifMi) return const SizedBox.shrink(); 
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Divider(height: 40), 
                  Wrap(
                    alignment: WrapAlignment.spaceBetween, 
                    crossAxisAlignment: WrapCrossAlignment.center, 
                    children: [
                      Text('Kritik Makina Bakımları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)), 
                      if (widget.isAdmin) 
                        IconButton(icon: const Icon(Icons.upload_file, color: kDepoZekaPrimary), onPressed: _bakimCsvYukle)
                    ]
                  ), 
                  const SizedBox(height: 10), 
                  Wrap(
                    spacing: 12, 
                    runSpacing: 12, 
                    children: ozelBakimListesi.map((m) { 
                      Color kR; 
                      IconData kI; 
                      if (m.durum == 'Gecikti') kR = Colors.red; 
                      else if (m.durum == 'Yaklaştı') kR = Colors.orange; 
                      else kR = kDepoZekaPrimary; 
                      
                      if (m.ad.contains('POTA')) kI = Icons.water_drop; 
                      else if (m.ad.contains('SMD')) kI = Icons.precision_manufacturing; 
                      else if (m.ad.contains('LEHİM')) kI = Icons.hardware; 
                      else kI = Icons.local_fire_department; 
                      
                      return _buildBakimKutusu(m.ad, m.siradakiBakim, m.durum, kI, kR, kG); 
                    }).toList()
                  ), 
                  const SizedBox(height: 20)
                ]
              ); 
            }
          ),
          
          const SizedBox(height: 30), 
          const Divider(height: 40), 
          
          Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                if (widget.isAdmin) ...[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween, 
                    crossAxisAlignment: WrapCrossAlignment.center, 
                    children: [
                      const Text('Bakım Panelini Göster', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), 
                      ValueListenableBuilder<bool>(
                        valueListenable: bakimPaneliniGoster, 
                        builder: (context, aktifMi, child) { 
                          return Switch(
                            value: aktifMi, 
                            activeThumbColor: kDepoZekaPrimary, 
                            onChanged: (v) async { 
                              bakimPaneliniGoster.value = v; 
                              final prefs = await SharedPreferences.getInstance(); 
                              await prefs.setBool('bakimPaneliGoster', v); 
                            }
                          ); 
                        }
                      )
                    ]
                  ), 
                  const Divider(height: 20)
                ], 
                Wrap(
                  alignment: WrapAlignment.spaceBetween, 
                  crossAxisAlignment: WrapCrossAlignment.center, 
                  spacing: 10, runSpacing: 10, 
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        const Icon(Icons.settings_system_daydream, color: kDepoZekaSecondary, size: 18), 
                        const SizedBox(width: 8), 
                        Flexible(child: Text('Sistem (Yedekle/Yükle)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)))
                      ]
                    ), 
                    Wrap(
                      spacing: 8, runSpacing: 8, 
                      children: [
                        ElevatedButton.icon(onPressed: () => _sistemiYedekle(context), icon: const Icon(Icons.upload, size: 16), label: const Text('Yedekle'), style: ElevatedButton.styleFrom(backgroundColor: kDepoZekaPrimary)), 
                        ElevatedButton.icon(onPressed: () => _sistemiGeriYukle(context), icon: const Icon(Icons.download, size: 16), label: const Text('Yükle'), style: ElevatedButton.styleFrom(backgroundColor: kDepoZekaSecondary))
                      ]
                    )
                  ]
                )
              ]
            )
          ), 
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBakimKutusu(String baslik, String deger, String durum, IconData ikon, Color renk, double genislik) { 
    return SizedBox(
      width: genislik, 
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 2))]), 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), 
          child: Material(
            color: Theme.of(context).cardColor, 
            child: Container(
              width: double.infinity, constraints: const BoxConstraints(minHeight: 120), 
              decoration: BoxDecoration(border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.5), borderRadius: BorderRadius.circular(15)), 
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), 
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, 
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(ikon, size: 20, color: renk), 
                        const SizedBox(width: 8), 
                        Flexible(child: Text(baslik, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)))
                      ]
                    ), 
                    const SizedBox(height: 12), 
                    Text(deger, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: renk)), 
                    const SizedBox(height: 4), 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), 
                      child: Text(durum, style: TextStyle(fontSize: 10, color: renk, fontWeight: FontWeight.bold))
                    )
                  ]
                )
              )
            )
          )
        )
      )
    ); 
  }

  Widget _buildResponsiveKutu(String baslik, String deger, IconData ikon, Color acikRenk, Color koyuRenk, double genislik, VoidCallback? tiklamaGorevi, {VoidCallback? yuklemeGorevi}) { 
    return SizedBox(
      width: genislik, 
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: acikRenk.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))]), 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), 
              child: Material(
                color: Colors.transparent, 
                child: InkWell(
                  onTap: tiklamaGorevi, 
                  child: Container(
                    width: double.infinity, constraints: const BoxConstraints(minHeight: 140), 
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [acikRenk, koyuRenk], begin: Alignment.topLeft, end: Alignment.bottomRight)), 
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0), 
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, 
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(ikon, size: 32, color: Colors.white)), 
                          const SizedBox(height: 12), 
                          Text(deger, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)), 
                          const SizedBox(height: 4), 
                          Text(baslik, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5))
                        ]
                      )
                    )
                  )
                )
              )
            )
          ), 
          if (yuklemeGorevi != null && widget.isAdmin) 
            Positioned(
              top: 10, right: 10, 
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle), 
                child: IconButton(icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 20), onPressed: yuklemeGorevi, constraints: const BoxConstraints(), padding: const EdgeInsets.all(8))
              )
            )
        ]
      )
    ); 
  }
}

// --- MALZEME DEPOSU SAYFASI ---
class MalzemeDepoSayfasi extends StatefulWidget {
  final bool isAdmin; 
  final String depoTipi;
  const MalzemeDepoSayfasi({super.key, required this.isAdmin, required this.depoTipi});
  @override
  State<MalzemeDepoSayfasi> createState() => _MalzemeDepoSayfasiState();
}

class _MalzemeDepoSayfasiState extends State<MalzemeDepoSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<Malzeme> ekrandakiMalzemeler = []; 
  bool get isRaf => widget.depoTipi.contains('Raf');
  
  List<Malzeme> get hedefDepo { 
    if (widget.depoTipi == 'SMD Raf') return smdMalzemeler; 
    if (widget.depoTipi == 'Bacaklı Raf') return bacakliMalzemeler; 
    if (widget.depoTipi == 'SMD Depo') return smdDepoMalzemeler; 
    return bacakliDepoMalzemeler; 
  }
  
  bool secimModu = false; 
  Set<Malzeme> secilenler = {};
  
  @override
  void initState() { 
    super.initState(); 
    _aramaYap(""); 
  }
  
  void _aramaYap(String aranan) { 
    setState(() { 
      ekrandakiMalzemeler = hedefDepo.where((m) { 
        if (isRaf) { 
          return m.shKodu.toLowerCase().contains(aranan.toLowerCase()) || m.hKodu.toLowerCase().contains(aranan.toLowerCase()) || m.raf.toLowerCase().contains(aranan.toLowerCase()); 
        } else { 
          return m.urunIsmi.toLowerCase().contains(aranan.toLowerCase()) || m.urunKodu.toLowerCase().contains(aranan.toLowerCase()); 
        } 
      }).toList(); 
    }); 
  }
  
  void tumunuSec() { 
    setState(() { 
      if (secilenler.length == ekrandakiMalzemeler.length) { 
        secilenler.clear(); secimModu = false; 
      } else { 
        secilenler.addAll(ekrandakiMalzemeler); secimModu = true; 
      } 
    }); 
  }
  
  void manuelEkle({Malzeme? varOlanMalzeme}) { 
    TextEditingController shK = TextEditingController(text: varOlanMalzeme?.shKodu ?? ''); 
    TextEditingController hK = TextEditingController(text: varOlanMalzeme?.hKodu ?? ''); 
    TextEditingController rK = TextEditingController(text: varOlanMalzeme?.raf ?? ''); 
    TextEditingController uiK = TextEditingController(text: varOlanMalzeme?.urunIsmi ?? ''); 
    TextEditingController ukK = TextEditingController(text: varOlanMalzeme?.urunKodu ?? ''); 
    
    void kaydetTetikle() { 
      bool isGecerli = isRaf ? shK.text.isNotEmpty : uiK.text.isNotEmpty; 
      if (isGecerli) { 
        setState(() { 
          if (varOlanMalzeme == null) { 
            hedefDepo.add(Malzeme(
              shKodu: metniBuyut(shK.text), 
              hKodu: metniBuyut(hK.text), 
              raf: metniBuyut(rK.text), 
              urunIsmi: metniBuyut(uiK.text), 
              urunKodu: metniBuyut(ukK.text), 
              depoTipi: widget.depoTipi, 
              eklenmeTarihi: anlikTarihSaatGetir()
            )); 
          } else { 
            if (isRaf) { 
              varOlanMalzeme.shKodu = metniBuyut(shK.text); 
              varOlanMalzeme.hKodu = metniBuyut(hK.text); 
              varOlanMalzeme.raf = metniBuyut(rK.text); 
            } else { 
              varOlanMalzeme.urunIsmi = metniBuyut(uiK.text); 
              varOlanMalzeme.urunKodu = metniBuyut(ukK.text); 
            } 
          } 
          _aramaYap(aramaKontrolcusu.text); 
        }); 
        verileriKaydet(); Navigator.pop(context); 
      } 
    }
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text(varOlanMalzeme == null ? 'Yeni Ekle' : 'Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: isRaf 
            ? [
                TextField(controller: shK, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'SH Kodu')), 
                const SizedBox(height: 10), 
                TextField(controller: hK, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'H Kodu')), 
                const SizedBox(height: 10), 
                TextField(controller: rK, textCapitalization: TextCapitalization.words, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Raf Numarası'))
              ] 
            : [
                TextField(controller: uiK, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Ürün İsmi')), 
                const SizedBox(height: 10), 
                TextField(controller: ukK, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Ürün Kodu'))
              ]
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet')) 
        ]
      )
    ); 
  }
  
  void topluArsiveGonder() { 
    setState(() { 
      for(var m in secilenler) { 
        hedefDepo.remove(m); 
        arsivlenmisMalzemeler.add(m); 
      } 
      secimModu=false; secilenler.clear(); _aramaYap(aramaKontrolcusu.text); 
    }); 
    verileriKaydet(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arşive Taşındı.'), backgroundColor: Colors.orange)); 
  }
  
  @override
  Widget build(BuildContext context) {
    IconData depoIkon = widget.depoTipi.contains('SMD') ? Icons.developer_board : Icons.hub;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : depoZekaAppBarBackground(), 
        backgroundColor: secimModu ? Colors.blueGrey[700] : null, 
        titleSpacing: 16, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Flexible(child: Text(secimModu ? '${secilenler.length} Seçildi' : widget.depoTipi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), 
            if (secimModu) 
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, 
                  reverse: true, 
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ]
                  )
                )
              )
          ]
        ), 
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: () => manuelEkle(), backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Ekle', style: TextStyle(color: Colors.white))) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0), 
            child: TextField(controller: aramaKontrolcusu, onChanged: _aramaYap, decoration: InputDecoration(labelText: isRaf ? 'SH, H Kodu veya Raf Ara...' : 'İsim veya Kod Ara...', prefixIcon: const Icon(Icons.search, color: kDepoZekaPrimary)))
          ), 
          Expanded(
            child: ekrandakiMalzemeler.isEmpty 
              ? const Center(child: Text('Kayıt bulunamadı.')) 
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8), 
                  itemCount: ekrandakiMalzemeler.length, 
                  itemBuilder: (context, index) { 
                    final malz = ekrandakiMalzemeler[index]; 
                    bool seciliMi = secilenler.contains(malz); 
                    return Card(
                      color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.1) : null, 
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                      child: ListTile(
                        onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(malz); }); } : null, 
                        onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(malz); if(secilenler.isEmpty) secimModu=false; } else { secilenler.add(malz); } }); } : null, 
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kDepoZekaPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(depoIkon, color: kDepoZekaPrimary, size: 28)), 
                        title: Text(isRaf ? 'SH: ${malz.shKodu}' : malz.urunIsmi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                        subtitle: Text(isRaf ? 'H Kodu: ${malz.hKodu}   •   Raf: ${malz.raf}\nEklenme: ${malz.eklenmeTarihi}' : 'Kod: ${malz.urunKodu}\nEklenme: ${malz.eklenmeTarihi}', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])), 
                        trailing: secimModu 
                          ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(malz); } else { secilenler.remove(malz); if(secilenler.isEmpty) secimModu=false; } }); }) 
                          : (widget.isAdmin 
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, 
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit, color: kDepoZekaPrimary), onPressed: () => manuelEkle(varOlanMalzeme: malz)) 
                                    ]
                                  )
                                ) 
                              : null)
                      )
                    ); 
                  }
                )
          )
        ]
      )
    );
  }
}

// --- KARTLAR SAYFASI ---
class KartlarSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const KartlarSayfasi({super.key, required this.isAdmin});
  @override
  State<KartlarSayfasi> createState() => _KartlarSayfasiState();
}

class _KartlarSayfasiState extends State<KartlarSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<Kart> ekrandakiKartlar = []; 
  bool secimModu = false; 
  Set<Kart> secilenler = {};
  
  @override
  void initState() { super.initState(); _filtreleriUygula(); }
  
  void _filtreleriUygula() { 
    setState(() { 
      ekrandakiKartlar = tumKartlarDeposu.where((k) => k.stokNo.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase()) || k.tip.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase())).toList(); 
    }); 
  }
  
  void tumunuSec() { 
    setState(() { 
      if (secilenler.length == ekrandakiKartlar.length) { 
        secilenler.clear(); secimModu = false; 
      } else { 
        secilenler.addAll(ekrandakiKartlar); secimModu = true; 
      } 
    }); 
  }
  
  void kartPenceresiAc({Kart? varOlanKart}) { 
    TextEditingController isimKontrolcusu = TextEditingController(text: varOlanKart?.tip ?? ''); 
    TextEditingController koduKontrolcusu = TextEditingController(text: varOlanKart?.stokNo ?? ''); 
    
    void kaydetTetikle() { 
      if (koduKontrolcusu.text.isNotEmpty && isimKontrolcusu.text.isNotEmpty) { 
        setState(() { 
          String formatliKod = metniBuyut(koduKontrolcusu.text); 
          String formatliIsim = metniBuyut(isimKontrolcusu.text); 
          if (varOlanKart == null) { 
            tumKartlarDeposu.add(Kart(stokNo: formatliKod, tip: formatliIsim, eklenmeTarihi: anlikTarihSaatGetir(), revizyonlar: [])); 
          } else { 
            varOlanKart.stokNo = formatliKod; 
            varOlanKart.tip = formatliIsim; 
          } 
          _filtreleriUygula(); 
        }); 
        verileriKaydet(); Navigator.pop(context); 
      } 
    }
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text(varOlanKart == null ? 'Yeni Kart' : 'Kartı Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: isimKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Kart İsmi')), 
            const SizedBox(height: 10), 
            TextField(controller: koduKontrolcusu, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Kart Kodu'))
          ]
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet'))
        ]
      )
    ); 
  }
  
  void topluArsiveGonder() { 
    setState(() { 
      for(var kart in secilenler) { 
        tumKartlarDeposu.remove(kart); 
        for (var m in tumMakinalar) { m.bagliKartlar.removeWhere((k) => k.stokNo == kart.stokNo); } 
        arsivlenmisKartlar.add(kart); 
      } 
      secimModu=false; secilenler.clear(); _filtreleriUygula(); 
    }); 
    verileriKaydet(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arşive Taşındı.'), backgroundColor: Colors.orange)); 
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : depoZekaAppBarBackground(), 
        backgroundColor: secimModu ? Colors.blueGrey[700] : null, 
        titleSpacing: 16, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Flexible(child: Text(secimModu ? '${secilenler.length} Seçildi' : 'Kart Deposu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), 
            if (secimModu) 
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, 
                  reverse: true, 
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ]
                  )
                )
              )
          ]
        ), 
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: () => kartPenceresiAc(), backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Ekle', style: TextStyle(color: Colors.white))) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0), 
            child: TextField(controller: aramaKontrolcusu, onChanged: (v) => _filtreleriUygula(), decoration: const InputDecoration(labelText: 'Kart İsmi veya Kodu...', prefixIcon: Icon(Icons.search, color: kDepoZekaPrimary)))
          ), 
          Expanded(
            child: ekrandakiKartlar.isEmpty 
              ? const Center(child: Text('Bulunamadı.')) 
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8), 
                  itemCount: ekrandakiKartlar.length, 
                  itemBuilder: (context, index) { 
                    final kart = ekrandakiKartlar[index]; 
                    bool seciliMi = secilenler.contains(kart); 
                    return Card(
                      color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.1) : null, 
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                      child: ListTile(
                        onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(kart); }); } : null, 
                        onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(kart); if(secilenler.isEmpty) secimModu=false; } else { secilenler.add(kart); } }); } : null, 
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kDepoZekaPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: kDepoZekaPrimary, size: 28)), 
                        title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                        subtitle: Text('Revizyon: ${kart.revizyonlar.length} | Eklenme: ${kart.eklenmeTarihi}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), 
                        trailing: secimModu 
                          ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(kart); } else { secilenler.remove(kart); if(secilenler.isEmpty) secimModu=false; } }); }) 
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal, 
                              child: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  IconButton(icon: const Icon(Icons.history, color: Colors.indigo), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => KartRevizyonSayfasi(kart: kart, isAdmin: widget.isAdmin))).then((v) => setState((){ _filtreleriUygula();})); }), 
                                  if (widget.isAdmin) IconButton(icon: const Icon(Icons.edit, color: kDepoZekaPrimary), onPressed: () => kartPenceresiAc(varOlanKart: kart)) 
                                ]
                              )
                            )
                      )
                    ); 
                  }
                )
          )
        ]
      )
    );
  }
}

// --- MAKİNALAR SAYFASI ---
class MakinalarSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const MakinalarSayfasi({super.key, required this.isAdmin});
  @override
  State<MakinalarSayfasi> createState() => _MakinalarSayfasiState();
}

class _MakinalarSayfasiState extends State<MakinalarSayfasi> {
  TextEditingController makinaAdiKontrolcusu = TextEditingController(); 
  TextEditingController makinaKoduKontrolcusu = TextEditingController(); 
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<Makina> ekrandakiMakinalar = []; 
  bool secimModu = false; Set<Makina> secilenler = {};
  
  @override
  void initState() { super.initState(); ekrandakiMakinalar = tumMakinalar; }
  
  void aramaYap(String aranan) { 
    setState(() => ekrandakiMakinalar = tumMakinalar.where((m) => m.ad.toLowerCase().contains(aranan.toLowerCase()) || m.kod.toLowerCase().contains(aranan.toLowerCase())).toList()); 
  }
  
  void tumunuSec() { 
    setState(() { 
      if (secilenler.length == ekrandakiMakinalar.length) { 
        secilenler.clear(); secimModu = false; 
      } else { 
        secilenler.addAll(ekrandakiMakinalar); secimModu = true; 
      } 
    }); 
  }
  
  void makinaEkle() { 
    void kaydetTetikle() { 
      if (makinaAdiKontrolcusu.text.isNotEmpty && makinaKoduKontrolcusu.text.isNotEmpty) { 
        setState(() { 
          tumMakinalar.add(Makina(kod: metniBuyut(makinaKoduKontrolcusu.text), ad: metniBuyut(makinaAdiKontrolcusu.text), eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: [])); 
          aramaYap(aramaKontrolcusu.text); 
        }); 
        verileriKaydet(); makinaAdiKontrolcusu.clear(); makinaKoduKontrolcusu.clear(); Navigator.pop(context); 
      } 
    }
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Text('Yeni Makina', style: TextStyle(fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: makinaAdiKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Adı')), 
            const SizedBox(height: 10), 
            TextField(controller: makinaKoduKontrolcusu, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Kodu'))
          ]
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: kaydetTetikle, child: const Text('Ekle'))
        ]
      )
    ); 
  }
  
  void topluArsiveGonder() { 
    setState(() { 
      for(var m in secilenler) { 
        tumMakinalar.remove(m); arsivlenmisMakinalar.add(m); 
      } 
      secimModu=false; secilenler.clear(); aramaYap(aramaKontrolcusu.text); 
    }); 
    verileriKaydet(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arşive Taşındı!'), backgroundColor: Colors.orange)); 
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : depoZekaAppBarBackground(), 
        backgroundColor: secimModu ? Colors.blueGrey[700] : null, 
        titleSpacing: 16, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Flexible(child: Text(secimModu ? '${secilenler.length} Seçildi' : 'Makinalar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), 
            if (secimModu) 
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, 
                  reverse: true, 
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ]
                  )
                )
              )
          ]
        ), 
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: makinaEkle, backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Ekle', style: TextStyle(color: Colors.white))) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0), 
            child: TextField(controller: aramaKontrolcusu, onChanged: aramaYap, decoration: const InputDecoration(labelText: 'Ad veya Kod...', prefixIcon: Icon(Icons.search, color: kDepoZekaPrimary)))
          ), 
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8), 
              itemCount: ekrandakiMakinalar.length, 
              itemBuilder: (context, index) { 
                final makina = ekrandakiMakinalar[index]; 
                bool seciliMi = secilenler.contains(makina); 
                return Card(
                  color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.1) : null, 
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                  child: ListTile(
                    onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(makina); }); } : null, 
                    onTap: () { 
                      if (secimModu) { 
                        setState((){ if (seciliMi) { secilenler.remove(makina); if(secilenler.isEmpty) secimModu=false; } else { secilenler.add(makina); } }); 
                      } else { 
                        Navigator.push(context, MaterialPageRoute(builder: (context) => MakinaDetaySayfasi(makina: makina, isAdmin: widget.isAdmin))).then((v) => setState(() {})); 
                      } 
                    }, 
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kDepoZekaPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.precision_manufacturing, color: kDepoZekaPrimary, size: 28)), 
                    title: Text('${makina.ad} (${makina.kod})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                    subtitle: Text('Bağlı Kart: ${makina.bagliKartlar.length} | Eklenme: ${makina.eklenmeTarihi}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), 
                    trailing: secimModu ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(makina); } else { secilenler.remove(makina); if(secilenler.isEmpty) secimModu=false; } }); }) : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                  )
                ); 
              }
            )
          )
        ]
      )
    );
  }
}

// --- AKTİF KARTLAR SAYFASI ---
class AktifKartlarSayfasi extends StatelessWidget {
  final bool isAdmin; 
  const AktifKartlarSayfasi({super.key, required this.isAdmin});
  
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> takiliKartlar = []; 
    for (var m in tumMakinalar) { 
      for (var k in m.bagliKartlar) { 
        takiliKartlar.add({'makina': m, 'kart': k}); 
      } 
    }
    return Scaffold(
      appBar: AppBar(flexibleSpace: depoZekaAppBarBackground(), title: const Text('Sahadaki Aktif Kartlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: takiliKartlar.isEmpty 
        ? const Center(child: Text('Hiçbir makinaya kart bağlanmamış.')) 
        : ListView.builder(
            padding: const EdgeInsets.all(8), 
            itemCount: takiliKartlar.length, 
            itemBuilder: (context, index) { 
              final k = takiliKartlar[index]['kart'] as Kart; 
              final m = takiliKartlar[index]['makina'] as Makina; 
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: Colors.green, size: 28)), 
                  title: Text('${k.tip} - ${k.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                  subtitle: Text('Makina: ${m.ad} (${m.kod})', style: const TextStyle(color: kDepoZekaPrimary, fontWeight: FontWeight.w600)), 
                  trailing: isAdmin 
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red), 
                        onPressed: () { 
                          m.bagliKartlar.removeWhere((x) => x.stokNo == k.stokNo); 
                          verileriKaydet(); 
                          (context as Element).markNeedsBuild(); 
                        }
                      ) 
                    : null
                )
              ); 
            }
          ),
    );
  }
}

// --- MAKİNA DETAY SAYFASI ---
class MakinaDetaySayfasi extends StatefulWidget {
  final Makina makina; 
  final bool isAdmin; 
  const MakinaDetaySayfasi({super.key, required this.makina, required this.isAdmin});
  @override
  State<MakinaDetaySayfasi> createState() => _MakinaDetaySayfasiState();
}

class _MakinaDetaySayfasiState extends State<MakinaDetaySayfasi> {
  void makinayaKartBagla() { 
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Text('Depodan Kart Seç'), 
        content: SizedBox(
          width: double.maxFinite, 
          child: ListView.builder(
            shrinkWrap: true, 
            itemCount: tumKartlarDeposu.length, 
            itemBuilder: (context, index) { 
              final sK = tumKartlarDeposu[index]; 
              return ListTile(
                leading: const Icon(Icons.memory, color: Colors.grey), 
                title: Text('${sK.tip} (${sK.stokNo})'), 
                subtitle: Text('Revizyon: ${sK.revizyonlar.length}'), 
                trailing: const Icon(Icons.add_circle, color: kDepoZekaPrimary), 
                onTap: () { 
                  if (!widget.makina.bagliKartlar.any((k) => k.stokNo == sK.stokNo)) { 
                    setState(() { widget.makina.bagliKartlar.add(sK); }); 
                    verileriKaydet(); 
                  } 
                  Navigator.pop(context); 
                }
              ); 
            }
          )
        )
      )
    ); 
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(flexibleSpace: depoZekaAppBarBackground(), title: Text('${widget.makina.ad} (${widget.makina.kod})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: makinayaKartBagla, backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.link, color: Colors.white), label: const Text("Kart Ekle", style: TextStyle(color: Colors.white))) : null,
      body: widget.makina.bagliKartlar.isEmpty 
        ? const Center(child: Text('Kart bağlanmamış.')) 
        : ListView.builder(
            padding: const EdgeInsets.all(8), 
            itemCount: widget.makina.bagliKartlar.length, 
            itemBuilder: (context, index) { 
              final k = widget.makina.bagliKartlar[index]; 
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: Colors.green, size: 28)), 
                  title: Text('${k.tip} - ${k.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                  subtitle: Text('Revizyon: ${k.revizyonlar.length}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), 
                  trailing: widget.isAdmin 
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red), 
                        onPressed: () { 
                          setState(() { widget.makina.bagliKartlar.removeWhere((x) => x.stokNo == k.stokNo); }); 
                          verileriKaydet(); 
                        }
                      ) 
                    : null
                )
              ); 
            }
          ),
    );
  }
}

// --- TÜM REVİZYONLAR SAYFASI ---
class TumRevizyonlarSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const TumRevizyonlarSayfasi({super.key, required this.isAdmin});
  @override
  State<TumRevizyonlarSayfasi> createState() => _TumRevizyonlarSayfasiState();
}

class _TumRevizyonlarSayfasiState extends State<TumRevizyonlarSayfasi> {
  String seciliMakinaFiltresi = 'Tümü';
  
  void revizyonPenceresiAc(Kart k, {Revizyon? varOlanRevizyon}) { 
    TextEditingController aciklamaKontrolcusu = TextEditingController(text: varOlanRevizyon?.aciklama ?? ''); 
    String sMA = varOlanRevizyon?.makinaAdi ?? 'Genel'; 
    List<String> makinaSecenekleri = ['Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    
    showDialog(
      context: context, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setD) { 
            void kaydetTetikle() { 
              if (aciklamaKontrolcusu.text.isNotEmpty) { 
                setState(() { 
                  String fA = metniBuyut(aciklamaKontrolcusu.text); 
                  if (varOlanRevizyon == null) { 
                    k.revizyonlar.add(Revizyon(tarihSaat: anlikTarihSaatGetir(), aciklama: fA, makinaAdi: sMA)); 
                  } else { 
                    varOlanRevizyon.aciklama = fA; 
                    varOlanRevizyon.makinaAdi = sMA; 
                  } 
                }); 
                verileriKaydet(); Navigator.pop(context); 
              } 
            } 
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
              title: Text(varOlanRevizyon == null ? 'Yeni Revizyon' : 'Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
              content: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Text('Makina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), 
                  const SizedBox(height: 8), 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12), 
                    decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(12)), 
                    child: DropdownButton<String>(
                      isExpanded: true, 
                      underline: const SizedBox(), 
                      value: makinaSecenekleri.contains(sMA) ? sMA : 'Genel', 
                      items: makinaSecenekleri.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(), 
                      onChanged: (v) { setD(() { sMA = v!; }); }
                    )
                  ), 
                  const SizedBox(height: 15), 
                  TextField(controller: aciklamaKontrolcusu, textCapitalization: TextCapitalization.sentences, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(hintText: 'İşlemi yazın...'), maxLines: 3)
                ]
              ), 
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
                ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet')) 
              ]
            ); 
          }
        ); 
      }
    ); 
  }
  
  Future<void> exceldenCSVYukle() async {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Text('CSV Yükle'), 
        content: const Text("Sütunlar: Kart İsmi (veya Kodu), Makina Adı, Açıklama, Tarih(Ops)"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), 
          ElevatedButton(
            onPressed: () async { 
              Navigator.pop(context); 
              FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']); 
              if (res != null) { 
                try { 
                  File f = File(res.files.single.path!); 
                  List<int> b = await f.readAsBytes(); 
                  String c = csvIcerikCoz(b); 
                  if (c.startsWith('\uFEFF')) c = c.substring(1); 
                  List<String> lines = c.split(RegExp(r'\r\n|\n|\r')); 
                  int e = 0; 
                  for (String l in lines) { 
                    if (l.trim().isEmpty || l.toLowerCase().startsWith('kart') || l.toLowerCase().startsWith('makina')) continue; 
                    List<String> cols = l.split(RegExp(r'[;,]')); 
                    if (cols.length >= 3) { 
                      String kA = metniBuyut(cols[0]); 
                      String mA = metniBuyut(cols[1]); 
                      String aC = metniBuyut(cols[2]); 
                      String trh = cols.length > 3 && cols[3].trim().isNotEmpty ? cols[3].trim() : anlikTarihSaatGetir(); 
                      if(kA.isNotEmpty && aC.isNotEmpty) { 
                        Kart? hK; 
                        for(var k in tumKartlarDeposu) { 
                          if (metniBuyut(k.stokNo) == kA || metniBuyut(k.tip) == kA) { hK = k; break; } 
                        } 
                        if (hK == null) { 
                          for(var m in tumMakinalar) { 
                            for(var k in m.bagliKartlar) { 
                              if (metniBuyut(k.stokNo) == kA || metniBuyut(k.tip) == kA) { hK = k; break; } 
                            } 
                            if (hK != null) break; 
                          } 
                        } 
                        if (hK != null) { 
                          hK.revizyonlar.add(Revizyon(tarihSaat: trh, aciklama: aC, makinaAdi: mA)); e++; 
                        } 
                      } 
                    } 
                  } 
                  setState(() { }); verileriKaydet(); 
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e revizyon işlendi!'), backgroundColor: Colors.green)); 
                } catch (e) { 
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata.'), backgroundColor: Colors.red)); 
                } 
              } 
            }, 
            child: const Text('Dosya Seç', style: TextStyle(color: Colors.white))
          ) 
        ]
      )
    );
  }
  
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; 
    List<String> filtreSecenekleri = ['Tümü', 'Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    List<Map<String, dynamic>> butunRevizyonlar = []; 
    Set<String> ekl = {}; 
    
    void rTopla(List<Kart> kr) { 
      for (var k in kr) { 
        for (var r in k.revizyonlar) { 
          String kY = "${k.stokNo}_${r.tarihSaat}_${r.aciklama}"; 
          if (!ekl.contains(kY)) { 
            ekl.add(kY); butunRevizyonlar.add({'kart': k, 'revizyon': r}); 
          } 
        } 
      } 
    }
    
    rTopla(tumKartlarDeposu); 
    for (var m in tumMakinalar) { rTopla(m.bagliKartlar); } 
    butunRevizyonlar.sort((a, b) => tarihCozumle((b['revizyon'] as Revizyon).tarihSaat).compareTo(tarihCozumle((a['revizyon'] as Revizyon).tarihSaat)));
    
    List<Map<String, dynamic>> gosterilecekRevizyonlar = butunRevizyonlar.where((r) { 
      if (seciliMakinaFiltresi == 'Tümü') return true; 
      return (r['revizyon'] as Revizyon).makinaAdi == seciliMakinaFiltresi; 
    }).toList();
    
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: depoZekaAppBarBackground(), titleSpacing: 16, 
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            const Flexible(child: Text('Tüm Revizyon Geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), 
            if (widget.isAdmin) 
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, reverse: true, 
                  child: Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      IconButton(icon: const Icon(Icons.upload_file, color: Colors.white), onPressed: exceldenCSVYukle)
                    ]
                  )
                )
              )
          ]
        ), 
        actions: const [SizedBox.shrink()]
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]), 
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center, 
              children: [
                const Icon(Icons.filter_list, color: kDepoZekaPrimary), 
                const SizedBox(width: 10), 
                const Text('Makina Filtresi: ', style: TextStyle(fontWeight: FontWeight.bold)), 
                DropdownButton<String>(
                  value: filtreSecenekleri.contains(seciliMakinaFiltresi) ? seciliMakinaFiltresi : 'Tümü', 
                  underline: const SizedBox(), 
                  items: filtreSecenekleri.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(), 
                  onChanged: (v) { setState(() { seciliMakinaFiltresi = v!; }); }
                )
              ]
            )
          ), 
          Expanded(
            child: gosterilecekRevizyonlar.isEmpty 
              ? const Center(child: Text('Kayıt yok.')) 
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0), 
                  itemCount: gosterilecekRevizyonlar.length, 
                  itemBuilder: (context, index) { 
                    final k = gosterilecekRevizyonlar[index]['kart'] as Kart; 
                    final r = gosterilecekRevizyonlar[index]['revizyon'] as Revizyon; 
                    return Card(
                      elevation: 2, 
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), 
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kDepoZekaPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.engineering, color: kDepoZekaPrimary, size: 28)), 
                        title: Text(r.aciklama, style: const TextStyle(fontWeight: FontWeight.bold)), 
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Text('Kart: ${k.tip} (${k.stokNo})', style: TextStyle(color: isDark ? Colors.lightBlueAccent : kDepoZekaPrimary, fontWeight: FontWeight.bold)), 
                              Text('Makina: ${r.makinaAdi}'), 
                              Text('Tarih: ${r.tarihSaat}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                            ]
                          )
                        ), 
                        trailing: widget.isAdmin 
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal, 
                              child: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => revizyonPenceresiAc(k, varOlanRevizyon: r)), 
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                    onPressed: () { 
                                      setState(() { k.revizyonlar.remove(r); }); 
                                      verileriKaydet(); 
                                    }
                                  )
                                ]
                              )
                            ) 
                          : null
                      )
                    ); 
                  }
                )
          )
        ]
      )
    );
  }
}

// --- KART REVIZYON SAYFASI ---
class KartRevizyonSayfasi extends StatefulWidget {
  final Kart kart; 
  final bool isAdmin; 
  const KartRevizyonSayfasi({super.key, required this.kart, required this.isAdmin});
  @override
  State<KartRevizyonSayfasi> createState() => _KartRevizyonSayfasiState();
}

class _KartRevizyonSayfasiState extends State<KartRevizyonSayfasi> {
  String seciliMakinaFiltresi = 'Tümü';
  
  void revizyonPenceresiAc({Revizyon? varOlanRevizyon}) { 
    TextEditingController aciklamaKontrolcusu = TextEditingController(text: varOlanRevizyon?.aciklama ?? ''); 
    String sMA = varOlanRevizyon?.makinaAdi ?? 'Genel'; 
    List<String> makinaSecenekleri = ['Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    
    showDialog(
      context: context, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setD) { 
            void kaydetTetikle() { 
              if (aciklamaKontrolcusu.text.isNotEmpty) { 
                setState(() { 
                  String fA = metniBuyut(aciklamaKontrolcusu.text); 
                  if (varOlanRevizyon == null) { 
                    widget.kart.revizyonlar.add(Revizyon(tarihSaat: anlikTarihSaatGetir(), aciklama: fA, makinaAdi: sMA)); 
                  } else { 
                    varOlanRevizyon.aciklama = fA; 
                    varOlanRevizyon.makinaAdi = sMA; 
                  } 
                }); 
                verileriKaydet(); Navigator.pop(context); 
              } 
            } 
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
              title: Text(varOlanRevizyon == null ? 'Yeni Revizyon Ekle' : 'Revizyonu Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
              content: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Text('İşlem Yapılan Makina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), 
                  const SizedBox(height: 8), 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12), 
                    decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(12)), 
                    child: DropdownButton<String>(
                      isExpanded: true, 
                      underline: const SizedBox(), 
                      value: makinaSecenekleri.contains(sMA) ? sMA : 'Genel', 
                      items: makinaSecenekleri.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(), 
                      onChanged: (v) { setD(() { sMA = v!; }); }
                    )
                  ), 
                  const SizedBox(height: 15), 
                  TextField(controller: aciklamaKontrolcusu, textCapitalization: TextCapitalization.sentences, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(hintText: 'Açıklama...'), maxLines: 3)
                ]
              ), 
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
                ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet')) 
              ]
            ); 
          }
        ); 
      }
    ); 
  }
  
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; 
    List<String> fS = ['Tümü', 'Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    List<Revizyon> gR = widget.kart.revizyonlar.where((r) { 
      if (seciliMakinaFiltresi == 'Tümü') return true; 
      return r.makinaAdi == seciliMakinaFiltresi; 
    }).toList();
    
    return Scaffold(
      appBar: AppBar(flexibleSpace: depoZekaAppBarBackground(), title: Text('${widget.kart.tip} Geçmişi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => revizyonPenceresiAc(), backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Ekle', style: TextStyle(color: Colors.white))) : null,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
            color: isDark ? Colors.grey[850] : Colors.grey[200], 
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center, 
              children: [
                const Icon(Icons.filter_list), 
                const SizedBox(width: 10), 
                const Text('Filtre: ', style: TextStyle(fontWeight: FontWeight.bold)), 
                DropdownButton<String>(
                  value: fS.contains(seciliMakinaFiltresi) ? seciliMakinaFiltresi : 'Tümü', 
                  underline: const SizedBox(), 
                  items: fS.map((s) => DropdownMenuItem<String>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(), 
                  onChanged: (v) { setState(() { seciliMakinaFiltresi = v!; }); }
                )
              ]
            )
          ), 
          Expanded(
            child: gR.isEmpty 
              ? const Center(child: Text('Kayıt yok.')) 
              : ListView.builder(
                  itemCount: gR.length, 
                  reverse: true, 
                  itemBuilder: (context, index) { 
                    final rev = gR[index]; 
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kDepoZekaPrimary.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.engineering, color: kDepoZekaPrimary, size: 28)), 
                        title: Text(rev.aciklama, style: const TextStyle(fontWeight: FontWeight.bold)), 
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text('Makina: ${rev.makinaAdi}', style: TextStyle(color: isDark ? Colors.tealAccent : Colors.teal, fontWeight: FontWeight.w600)), 
                            Text('Tarih & Saat: ${rev.tarihSaat}', style: const TextStyle(color: Colors.grey))
                          ]
                        ), 
                        trailing: widget.isAdmin 
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal, 
                              child: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => revizyonPenceresiAc(varOlanRevizyon: rev)), 
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20), 
                                    onPressed: () { 
                                      setState(() { widget.kart.revizyonlar.remove(rev); }); 
                                      verileriKaydet(); 
                                    }
                                  )
                                ]
                              )
                            ) 
                          : null
                      )
                    ); 
                  }
                )
          )
        ]
      )
    );
  }
}

// --- PCB DEPOSU SADELEŞTİRİLDİ ---
class PcbDeposuSayfasi extends StatefulWidget {
  final bool isAdmin; 
  const PcbDeposuSayfasi({super.key, required this.isAdmin});
  @override
  State<PcbDeposuSayfasi> createState() => _PcbDeposuSayfasiState();
}

class _PcbDeposuSayfasiState extends State<PcbDeposuSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<PcbKart> ekrandakiPcbler = []; 
  bool secimModu = false; 
  Set<PcbKart> secilenler = {};

  @override
  void initState() { super.initState(); _filtreleriUygula(); }

  void _filtreleriUygula() { 
    setState(() { 
      ekrandakiPcbler = tumPcbDeposu.where((p) => 
        p.stokNo.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase()) || 
        p.isim.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase())
      ).toList(); 
    }); 
  }

  void tumunuSec() { 
    setState(() { 
      if (secilenler.length == ekrandakiPcbler.length) { 
        secilenler.clear(); secimModu = false; 
      } else { 
        secilenler.addAll(ekrandakiPcbler); secimModu = true; 
      } 
    }); 
  }

  void pcbPenceresiAc({PcbKart? varOlanPcb}) { 
    // Excel ile ters yüklendiği için UI'da isim ve kod değişkenleri kendi içinde yer değiştirdi.
    TextEditingController isimKontrolcusu = TextEditingController(text: varOlanPcb?.stokNo ?? ''); 
    TextEditingController koduKontrolcusu = TextEditingController(text: varOlanPcb?.isim ?? ''); 

    void kaydetTetikle() {
      if (koduKontrolcusu.text.isNotEmpty && isimKontrolcusu.text.isNotEmpty) { 
        setState(() { 
          String formatliKod = metniBuyut(koduKontrolcusu.text);
          String formatliIsim = metniBuyut(isimKontrolcusu.text);
          if (varOlanPcb == null) { 
            tumPcbDeposu.add(PcbKart(
              stokNo: formatliIsim, 
              isim: formatliKod, 
              eklenmeTarihi: anlikTarihSaatGetir()
            )); 
          } else { 
            varOlanPcb.stokNo = formatliIsim; 
            varOlanPcb.isim = formatliKod; 
          } 
          _filtreleriUygula(); 
        }); 
        verileriKaydet(); Navigator.pop(context); 
      }
    }

    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: Text(varOlanPcb == null ? 'Yeni PCB Kaydı' : 'PCB Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: koduKontrolcusu, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Stok Kodu', prefixIcon: Icon(Icons.qr_code))), 
              const SizedBox(height: 10),
              TextField(controller: isimKontrolcusu, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'PCB İsmi / Proje Adı', prefixIcon: Icon(Icons.developer_board)), onSubmitted: (_) => kaydetTetikle()),
            ]
          )
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), 
          ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet') ) 
        ]
      )
    ); 
  }

  void topluArsiveGonder() { 
    setState(() { 
      for(var pcb in secilenler) { 
        tumPcbDeposu.remove(pcb); arsivlenmisPcbler.add(pcb); 
      } 
      secimModu=false; secilenler.clear(); _filtreleriUygula(); 
    }); 
    verileriKaydet(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler Arşive Taşındı.'), backgroundColor: Colors.orange)); 
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : depoZekaAppBarBackground(), 
        backgroundColor: secimModu ? Colors.blueGrey[700] : null,
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(secimModu ? '${secilenler.length} Seçildi' : 'PCB Deposu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (secimModu)
              Expanded(
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: tumunuSec), 
                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                ]))
              )
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null,
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: () => pcbPenceresiAc(), backgroundColor: kDepoZekaPrimary, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0), 
            child: TextField(controller: aramaKontrolcusu, onChanged: (v) => _filtreleriUygula(), decoration: const InputDecoration(labelText: 'PCB İsmi veya Kodu Ara...', prefixIcon: Icon(Icons.search, color: kDepoZekaPrimary)))
          ),
          Expanded(
            child: ekrandakiPcbler.isEmpty 
            ? const Center(child: Text('Kriterlere uygun PCB bulunamadı.')) 
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8), 
                itemCount: ekrandakiPcbler.length, 
                itemBuilder: (context, index) { 
                  final pcb = ekrandakiPcbler[index]; bool seciliMi = secilenler.contains(pcb);
                  return Card(
                    color: seciliMi ? kDepoZekaPrimary.withValues(alpha: 0.1) : null, 
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), 
                    child: ListTile(
                      onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(pcb); }); } : null, 
                      onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(pcb); if(secilenler.isEmpty) { secimModu=false; } } else { secilenler.add(pcb); } }); } : null,
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.layers, color: Colors.teal, size: 28)), 
                      title: Text(pcb.stokNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                      subtitle: Text('Kod: ${pcb.isim}\nEklenme: ${pcb.eklenmeTarihi}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 13)), 
                      trailing: secimModu ? Checkbox(activeColor: kDepoZekaPrimary, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(pcb); } else { secilenler.remove(pcb); if(secilenler.isEmpty) { secimModu=false; } } }); }) : (widget.isAdmin ? IconButton(icon: const Icon(Icons.edit, color: kDepoZekaPrimary), onPressed: () => pcbPenceresiAc(varOlanPcb: pcb)) : null), 
                    )
                  ); 
                }
              )
          )
        ],
      ),
    );
  }
}

// --- AKILLI ASİSTAN (YAPAY ZEKA SOHBET) DOĞRUDAN DÖKÜM (SEÇİMSİZ) ---
class AsistanMesaji {
  final String metin; 
  final bool kullaniciMi; 
  AsistanMesaji(this.metin, this.kullaniciMi);
}

class AkilliAsistanSayfasi extends StatefulWidget {
  const AkilliAsistanSayfasi({super.key});
  @override
  State<AkilliAsistanSayfasi> createState() => _AkilliAsistanSayfasiState();
}

class _AkilliAsistanSayfasiState extends State<AkilliAsistanSayfasi> {
  final TextEditingController _mesajKontrolcusu = TextEditingController();
  final ScrollController _scrollKontrolcusu = ScrollController();
  List<AsistanMesaji> sohbet = [];

  void _mesajGonder() {
    String soru = _mesajKontrolcusu.text.trim(); if (soru.isEmpty) return;
    setState(() { sohbet.add(AsistanMesaji(soru, true)); _mesajKontrolcusu.clear(); }); 
    _asagiKaydir();
    
    Future.delayed(const Duration(milliseconds: 600), () { 
      String cevap = _cevapUret(soru); 
      setState(() { sohbet.add(AsistanMesaji(cevap, false)); }); 
      _asagiKaydir(); 
    });
  }

  void _asagiKaydir() { 
    Future.delayed(const Duration(milliseconds: 100), () { 
      if (_scrollKontrolcusu.hasClients) { 
        _scrollKontrolcusu.animateTo(_scrollKontrolcusu.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); 
      } 
    }); 
  }

  String _cevapUret(String soru) {
    String s = soru.toLowerCase().trim();
    
    if (s.contains('neler yapabilirsin') || s.contains('ne yapabilirsin') || s.contains('özelliklerin') || s.contains('yardımcı ol')) {
      return "🤖 *Neler Yapabilirim?*\n\n"
             "1️⃣ *Makina Sorgulama:* Bir makina adı veya kodu yazarak o makinaya takılı tüm kartları listeleyebilirim.\n"
             "2️⃣ *Kart Revizyon Geçmişi:* Herhangi bir kartın adını veya kodunu yazarsanız, o karta bugüne kadar yapılan tüm işlemleri dökerim.\n"
             "3️⃣ *Malzeme ve Raf Bulma:* Bir malzeme kodu yazdığınızda, malzemenin ismini, nerede olduğunu ve tam olarak hangi rafta bulunduğunu anında söylerim.\n"
             "4️⃣ *Genel İstatistikler:* 'Sistemde kaç makina var?' veya 'Kaç kart takılı?' gibi sorularınıza yanıt veririm.\n\n"
             "Sadece aradığınız kelimeyi veya kodu yazmanız yeterlidir!";
    }
    
    if (s == 'merhaba' || s == 'selam' || s == 'sa') return "Merhaba! Size nasıl yardımcı olabilirim? Herhangi bir kod veya isim aratabilirsiniz.";
    if (s.contains('teşekkür') || s.contains('sağol')) return "Rica ederim, işinizde kolaylıklar dilerim!";
    if (s.contains('kaç') && s.contains('makina')) return "Sistemimizde şu an toplam ${tumMakinalar.length} adet makina kayıtlıdır.";
    if (s.contains('kaç') && s.contains('kart')) { 
      int tK = tumMakinalar.fold(0, (sum, m) => sum + m.bagliKartlar.length); 
      return "Depomuzda ${tumKartlarDeposu.length} adet boş kart var. Sahadaki makinaların üzerinde ise toplam $tK adet kart takılı çalışıyor."; 
    }

    List<dynamic> bS = [];
    
    for (var m in tumMakinalar) { 
      if (m.ad.toLowerCase().contains(s) || m.kod.toLowerCase().contains(s)) if (!bS.contains(m)) bS.add(m); 
    }
    
    List<Kart> tSK = [...tumKartlarDeposu]; 
    for (var m in tumMakinalar) { tSK.addAll(m.bagliKartlar); }
    for (var k in tSK) { 
      if (k.tip.toLowerCase().contains(s) || k.stokNo.toLowerCase().contains(s)) if (!bS.contains(k)) bS.add(k); 
    }
    
    List<Malzeme> tM = [...smdMalzemeler, ...bacakliMalzemeler, ...smdDepoMalzemeler, ...bacakliDepoMalzemeler];
    for (var m in tM) { 
      if (m.shKodu.toLowerCase().contains(s) || m.urunIsmi.toLowerCase().contains(s) || m.urunKodu.toLowerCase().contains(s) || m.hKodu.toLowerCase().contains(s)) if (!bS.contains(m)) bS.add(m); 
    }
    
    for (var p in tumPcbDeposu) { 
      if (p.isim.toLowerCase().contains(s) || p.stokNo.toLowerCase().contains(s)) if (!bS.contains(p)) bS.add(p); 
    }

    if (bS.isEmpty) return "Sistemdeki hiçbir bilgi kutusunda '$soru' ile ilgili bir kayıt bulamadım.";

    String cvp = "🔍 Sistemde '${soru}' ile ilgili ${bS.length} kayıt buldum:\n\n";
    for (var n in bS) {
      if (n is Makina) {
        cvp += "⚙️ MAKİNA:\nAdı: ${n.ad} (${n.kod})\n";
        if (n.bagliKartlar.isEmpty) { 
          cvp += "Durum: Hiçbir kart bağlı değil.\n\n"; 
        } else { 
          cvp += "Takılı Kartlar (${n.bagliKartlar.length} adet):\n"; 
          for (var k in n.bagliKartlar) { cvp += " • ${k.tip} (${k.stokNo})\n"; } 
          cvp += "\n"; 
        }
      }
      else if (n is Kart) {
        cvp += "💾 KART:\nİsmi: ${n.tip}\nKodu: ${n.stokNo}\n";
        if (n.revizyonlar.isEmpty) { 
          cvp += "Durum: Henüz revizyon görmemiş.\n\n"; 
        } else { 
          cvp += "Revizyon Geçmişi:\n"; 
          for (var r in n.revizyonlar) { cvp += " 🗓️ ${r.tarihSaat} - ${r.makinaAdi} - ${r.aciklama}\n"; } 
          cvp += "\n"; 
        }
      }
      else if (n is Malzeme) {
        cvp += "📦 MALZEME:\n";
        if (n.hKodu.isNotEmpty) cvp += "H Kodu: ${n.hKodu}\n";
        if (n.shKodu.isNotEmpty) cvp += "SH Kodu: ${n.shKodu}\n";
        if (n.urunIsmi.isNotEmpty) cvp += "İsmi: ${n.urunIsmi}\n";
        if (n.urunKodu.isNotEmpty) cvp += "Ürün Kodu: ${n.urunKodu}\n";
        if (n.raf.isNotEmpty) cvp += "Raf: ${n.raf}\n";
        cvp += "Bulunduğu Yer: ${n.depoTipi}\n\n";
      }
      else if (n is PcbKart) {
        // İsim ve kod yer değiştirdiği için mantığı da düzelttik
        cvp += "🟩 PCB:\nİsmi: ${n.stokNo}\nKod: ${n.isim}\nEklenme Tarihi: ${n.eklenmeTarihi}\n\n";
      }
    }
    return cvp.trim();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: depoZekaAppBarBackground(), 
        centerTitle: false,
        title: const Row(children: [Icon(Icons.smart_toy, color: Colors.yellowAccent), SizedBox(width: 10), Text('Akıllı Asistan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])
      ),
      body: Column(children: [
        Expanded(
          child: sohbet.isEmpty 
          ? Center(child: Text("Asistanınız hazır.\nAramak istediğiniz kodu veya ismi yazın.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 16))) 
          : ListView.builder(
              controller: _scrollKontrolcusu, 
              padding: const EdgeInsets.all(16), 
              itemCount: sohbet.length, 
              itemBuilder: (context, index) { 
                final m = sohbet[index]; 
                return Align(
                  alignment: m.kullaniciMi ? Alignment.centerRight : Alignment.centerLeft, 
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12), 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), 
                    decoration: BoxDecoration(
                      color: m.kullaniciMi ? kDepoZekaPrimary : (isDark ? Colors.grey[800] : Colors.white), 
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(m.kullaniciMi ? 16 : 0), bottomRight: Radius.circular(m.kullaniciMi ? 0 : 16)), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
                    ), 
                    child: Text(m.metin, style: TextStyle(fontSize: 15, height: 1.5, color: m.kullaniciMi ? Colors.white : (isDark ? Colors.white : Colors.black87)))
                  )
                ); 
              }
            )
        ),
        Container(
          padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]), 
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _mesajKontrolcusu, 
                  textCapitalization: TextCapitalization.sentences, 
                  decoration: InputDecoration(hintText: "Mesajınızı yazın...", hintStyle: TextStyle(color: Colors.grey[500]), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), 
                  onSubmitted: (_) => _mesajGonder()
                )
              ), 
              const SizedBox(width: 10), 
              Container(
                decoration: const BoxDecoration(color: kDepoZekaPrimary, shape: BoxShape.circle), 
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _mesajGonder)
              )
            ])
          )
        ),
      ]),
    );
  }
}
// SON SÜSLÜ PARANTEZ BURADA BİTİYOR, LÜTFEN EKSİK KOPYALAMAYIN