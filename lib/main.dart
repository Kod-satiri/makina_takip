import 'package:flutter/material.dart';
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
  runApp(
    DevicePreview(
      enabled: devicePreviewAcik && !kReleaseMode, 
      builder: (context) => const MakinaTakipUygulamasi(),
    ),
  );
}

final ValueNotifier<ThemeMode> temaYoneticisi = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> bakimPaneliniGoster = ValueNotifier(false);

// --- KURUMSAL RENKLER ---
const Color kKolarcBlue = Color(0xFF26A69A); 
const Color kKolarcOrange = Color(0xFF37474F); 
const Color kKolarcDarkBg = Color(0xFF121212); 

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

// --- VERİ MODELLERİ ---
class Revizyon {
  String tarihSaat; String aciklama; String makinaAdi;
  Revizyon({required this.tarihSaat, required this.aciklama, required this.makinaAdi});
  Map<String, dynamic> toJson() => {'tarihSaat': tarihSaat, 'aciklama': aciklama, 'makinaAdi': makinaAdi};
  factory Revizyon.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Revizyon(tarihSaat: 'Bilinmiyor', aciklama: 'Yok', makinaAdi: 'Genel');
    return Revizyon(tarihSaat: json['tarihSaat']?.toString() ?? 'Tarih Bilinmiyor', aciklama: json['aciklama']?.toString() ?? 'Açıklama Yok', makinaAdi: json['makinaAdi']?.toString() ?? 'Genel');
  }
}

class Kart {
  String stokNo; String tip; String eklenmeTarihi; List<Revizyon> revizyonlar; 
  Kart({required this.stokNo, required this.tip, required this.eklenmeTarihi, required this.revizyonlar});
  Map<String, dynamic> toJson() => {'stokNo': stokNo, 'tip': tip, 'eklenmeTarihi': eklenmeTarihi, 'revizyonlar': revizyonlar.map((r) => r.toJson()).toList()};
  factory Kart.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Kart(stokNo: 'Bilinmeyen', tip: 'Yok', eklenmeTarihi: 'Bilinmiyor', revizyonlar: []);
    return Kart(stokNo: json['stokNo']?.toString() ?? 'Bilinmeyen', tip: json['tip']?.toString() ?? 'Belirtilmedi', eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? 'Eski Kayıt', revizyonlar: json['revizyonlar'] != null ? (json['revizyonlar'] as List).map((r) => Revizyon.fromJson(r as Map<String, dynamic>?)).toList() : []);
  }
}

class Makina {
  String kod; String ad; String eklenmeTarihi; List<Kart> bagliKartlar;
  Makina({required this.kod, required this.ad, required this.eklenmeTarihi, required this.bagliKartlar});
  Map<String, dynamic> toJson() => {'kod': kod, 'ad': ad, 'eklenmeTarihi': eklenmeTarihi, 'bagliKartlar': bagliKartlar.map((k) => k.toJson()).toList()};
  factory Makina.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Makina(kod: 'Bilinmiyor', ad: 'İsimsiz', eklenmeTarihi: 'Bilinmiyor', bagliKartlar: []);
    return Makina(kod: json['kod']?.toString() ?? 'Bilinmiyor', ad: json['ad']?.toString() ?? 'İsimsiz', eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? 'Eski Kayıt', bagliKartlar: json['bagliKartlar'] != null ? (json['bagliKartlar'] as List).map((k) => Kart.fromJson(k as Map<String, dynamic>?)).toList() : []);
  }
}

class Malzeme {
  String shKodu; String hKodu; String raf;
  String urunIsmi; String urunKodu;
  String depoTipi; String eklenmeTarihi;

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
  String ad; String sonBakim; String siradakiBakim; String durum; 
  OzelMakinaBakim({required this.ad, required this.sonBakim, required this.siradakiBakim, required this.durum});
  Map<String, dynamic> toJson() => {'ad': ad, 'sonBakim': sonBakim, 'siradakiBakim': siradakiBakim, 'durum': durum};
  factory OzelMakinaBakim.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OzelMakinaBakim(ad: 'Bilinmeyen', sonBakim: '-', siradakiBakim: '-', durum: 'Normal');
    return OzelMakinaBakim(ad: json['ad']?.toString() ?? 'Bilinmeyen', sonBakim: json['sonBakim']?.toString() ?? '-', siradakiBakim: json['siradakiBakim']?.toString() ?? '-', durum: json['durum']?.toString() ?? 'Normal');
  }
}

class PcbKart {
  String stokNo; String isim; String katman; String kalinlik; 
  String yuzeyKaplama; String maskeRengi; String eklenmeTarihi;
  
  PcbKart({
    required this.stokNo, required this.isim, required this.katman, 
    required this.kalinlik, required this.yuzeyKaplama, 
    required this.maskeRengi, required this.eklenmeTarihi
  });
  
  Map<String, dynamic> toJson() => {
    'stokNo': stokNo, 'isim': isim, 'katman': katman, 
    'kalinlik': kalinlik, 'yuzeyKaplama': yuzeyKaplama, 
    'maskeRengi': maskeRengi, 'eklenmeTarihi': eklenmeTarihi
  };
  
  factory PcbKart.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PcbKart(stokNo: 'Bilinmiyor', isim: 'Yok', katman: '-', kalinlik: '-', yuzeyKaplama: '-', maskeRengi: '-', eklenmeTarihi: '-');
    return PcbKart(
      stokNo: json['stokNo']?.toString() ?? '',
      isim: json['isim']?.toString() ?? '',
      katman: json['katman']?.toString() ?? '',
      kalinlik: json['kalinlik']?.toString() ?? '',
      yuzeyKaplama: json['yuzeyKaplama']?.toString() ?? '',
      maskeRengi: json['maskeRengi']?.toString() ?? '',
      eklenmeTarihi: json['eklenmeTarihi']?.toString() ?? ''
    );
  }
}

// --- GLOBAL DEĞİŞKENLER ---
String gecerliAdminSifresi = '1234'; 

List<Kart> tumKartlarDeposu = []; List<Makina> tumMakinalar = []; List<Kart> arsivlenmisKartlar = []; List<Makina> arsivlenmisMakinalar = []; 
List<Malzeme> smdMalzemeler = []; List<Malzeme> bacakliMalzemeler = []; List<Malzeme> smdDepoMalzemeler = []; List<Malzeme> bacakliDepoMalzemeler = []; 
List<Malzeme> arsivlenmisMalzemeler = [];
List<PcbKart> tumPcbDeposu = []; List<PcbKart> arsivlenmisPcbler = [];

List<OzelMakinaBakim> ozelBakimListesi = [
  OzelMakinaBakim(ad: 'Pota Makinası', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'SMD Dizgi Makinası', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'Lehim Çekme Makinası', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
  OzelMakinaBakim(ad: 'Fırın', sonBakim: 'Veri Bekleniyor', siradakiBakim: 'Veri Bekleniyor', durum: 'Normal'),
];

Future<void> verileriKaydet() async {
  final prefs = await SharedPreferences.getInstance();
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
class MakinaTakipUygulamasi extends StatelessWidget {
  const MakinaTakipUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaYoneticisi,
      builder: (context, guncelTema, child) {
        return MaterialApp(
          useInheritedMediaQuery: true, locale: DevicePreview.locale(context), builder: DevicePreview.appBuilder, debugShowCheckedModeBanner: false,
          title: 'Makina Takip Uygulaması',
          theme: ThemeData.light().copyWith(
            primaryColor: kKolarcBlue,
            scaffoldBackgroundColor: Colors.grey[100],
            colorScheme: const ColorScheme.light(primary: kKolarcBlue, secondary: kKolarcOrange),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true, iconTheme: IconThemeData(color: Colors.white)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kKolarcBlue, width: 2)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kKolarcBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: kKolarcBlue,
            scaffoldBackgroundColor: kKolarcDarkBg,
            colorScheme: const ColorScheme.dark(primary: kKolarcBlue, secondary: kKolarcOrange),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true, iconTheme: IconThemeData(color: Colors.white)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: Colors.grey[850],
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kKolarcBlue, width: 2)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: kKolarcBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
          ),
          themeMode: guncelTema, 
          home: const AcilisEkrani(), 
        );
      },
    );
  }
}

class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});
  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> {
  @override
  void initState() { super.initState(); hafizadanVerileriYukle(); }
  
  Future<void> hafizadanVerileriYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isDark = prefs.getBool('isDarkTheme') ?? false;
      temaYoneticisi.value = isDark ? ThemeMode.dark : ThemeMode.light;
      bakimPaneliniGoster.value = prefs.getBool('bakimPaneliGoster') ?? false;
      
      gecerliAdminSifresi = prefs.getString('adminSifresi') ?? '1234';

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
    } catch (e) { }
    if (mounted) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaGezinmeSayfasi())); }
  }
  @override
  Widget build(BuildContext context) { return const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: kKolarcBlue), SizedBox(height: 20), Text('Sistem Başlatılıyor...', style: TextStyle(fontWeight: FontWeight.bold))]))); }
}

Widget kolarcAppBarBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF26A69A), Color(0xFF00796B), Color(0xFF004D40)], 
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
  );
}

// --- KULLANIM KILAVUZU SAYFASI ---
class KullanimKilavuzuSayfasi extends StatelessWidget {
  const KullanimKilavuzuSayfasi({super.key});

  Widget _kilavuzKarti(BuildContext context, String baslik, String aciklama, IconData ikon, Color renk) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 6,
      shadowColor: renk.withValues(alpha: 0.2),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: renk.withValues(alpha: 0.3))),
              child: Icon(ikon, size: 36, color: renk),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(aciklama, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: kolarcAppBarBackground(),
        title: const Text('Kullanım Kılavuzu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: kKolarcBlue.withValues(alpha: 0.3))),
            child: const Column(
              children: [
                Icon(Icons.info_outline, size: 40, color: kKolarcBlue),
                SizedBox(height: 10),
                Text('Makina Takip Sistemine Hoş Geldiniz!', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text('Bu yazılım, fabrikanızdaki makinaları, kartları, malzemeleri ve bakım süreçlerini dijital olarak takip etmeniz için tasarlanmış, tamamen çevrimdışı ve güvenli bir ERP çözümüdür.', textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _kilavuzKarti(context, '1. Yönetici (Admin) Girişi', 'Sistem varsayılan olarak "İzleme Modunda" başlar. Yeni bir makina eklemek, kart bağlamak veya veri silmek için üst sağdaki "Giriş" ikonuna tıklayıp şifreyi girmelisiniz. Admin olduğunuzda ekranın sağ alt köşesinde ekleme (+) butonları belirecektir.', Icons.admin_panel_settings, Colors.redAccent),
          _kilavuzKarti(context, '2. Süper Arama Motoru', 'Ekranın üstündeki Büyüteç ikonuna basarak sistemdeki HER ŞEYİ tek bir yerden arayabilirsiniz. Bir kod veya isim yazdığınızda sistem; depodaki kartları, makinaları, makinalara takılı kartları ve malzemeleri saniyeler içinde tarayıp karşınıza getirir.', Icons.search, kKolarcBlue),
          _kilavuzKarti(context, '3. Ana Ekran Paneli', 'Ortadaki renkli kutular deponuzun anlık özetidir. Herhangi bir kutuya tıkladığınızda o bölümün detaylı listesine ulaşırsınız. (Örneğin "Toplam Makina" kutusuna tıklayarak makinaların listesine gidebilirsiniz).', Icons.dashboard, kKolarcOrange),
          _kilavuzKarti(context, '4. Raporlama (Excel & PDF)', 'Ana sayfadaki Excel veya PDF butonlarına basarak sistemin o anki tam özetini (Tüm makinalar, işlem gören kartlar ve revizyon geçmişi) tek tıkla resmi bir rapor halinde indirebilirsiniz.', Icons.picture_as_pdf, Colors.red),
          _kilavuzKarti(context, '5. Makina ve Kart Yönetimi', 'Makinalar listesinden bir makinaya tıkladığınızda içine girebilir ve "Depodan Kart Ekle" diyerek sistemdeki boş bir kartı o makinaya bağlayabilirsiniz. Bir kart makinaya bağlandığında, ana ekranda "Takılı Kartlar" bölümüne geçer.', Icons.precision_manufacturing, Colors.indigo),
          _kilavuzKarti(context, '6. Revizyon (İşlem) Kaydetme', 'Bir karta müdahale ettiğinizde (lehim, parça değişimi vs.), o kartın detayına girip "Revizyon Ekle" diyebilirsiniz. Hangi makinada ne işlem yaptığınızı yazdığınızda, sistem bunu tarih/saat ile birlikte sonsuza dek kayıt altına alır.', Icons.history_edu, Colors.purple),
          _kilavuzKarti(context, '7. Çöp Kutusu (Sistem Arşivi)', 'Bir makina, kart veya malzemeyi sildiğinizde aslında tamamen silinmez. Üst çubuktaki "Çöp Kutusu" ikonuna basarak Sistem Arşivine gidebilirsiniz. Buradan yanlışlıkla sildiğiniz verileri geri yükleyebilir veya kalıcı olarak silebilirsiniz.', Icons.delete_sweep, kKolarcBlue),
          _kilavuzKarti(context, '8. Sistemi Yedekleme ve Aktarma', 'Ekranın en altındaki "Yedekle" butonuna basarak tüm fabrikanın verisini küçük bir (.json) dosyası olarak indirebilirsiniz. Bu dosyayı flash bellek veya WhatsApp ile başka bir bilgisayara/tablete atıp, oradaki uygulamadan "Yükle" diyerek tüm sistemi saniyeler içinde yeni cihaza aktarabilirsiniz.', Icons.cloud_sync, Colors.green),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- ANA GEZİNME VE DASHBOARD ---
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
        title: const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.password, color: kKolarcBlue), SizedBox(width: 10), Text('Admin Şifresini Değiştir')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: eskiSifreKontrolcusu, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut Şifre', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 10),
            TextField(controller: yeniSifreKontrolcusu, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni Şifre', prefixIcon: Icon(Icons.lock)), onSubmitted: (_) => degistir()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))),
          ElevatedButton(onPressed: degistir, child: const Text('Değiştir'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: kolarcAppBarBackground(),
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('MAKİNA TAKİP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.help_outline, color: Colors.lightBlueAccent), tooltip: 'Kullanım Kılavuzu', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KullanimKilavuzuSayfasi()))),
                    const SizedBox(width: 5),
                    IconButton(icon: const Icon(Icons.search, color: Colors.white), tooltip: 'Sistemde Ara', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SuperAramaSayfasi(isAdmin: isAdmin))).then((_) => setState((){}))),
                    IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.white70), tooltip: 'Sistem Arşivi', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ArsivSayfasi(isAdmin: isAdmin))).then((_) => setState((){}))),
                    
                    if (isAdmin)
                      IconButton(icon: const Icon(Icons.vpn_key, color: Colors.greenAccent), tooltip: 'Şifreyi Değiştir', onPressed: sifreDegistirmePenceresi),

                    IconButton(
                      icon: Icon(temaYoneticisi.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode, color: Colors.yellowAccent), 
                      onPressed: () async { 
                        setState(() => temaYoneticisi.value = temaYoneticisi.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light); 
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isDarkTheme', temaYoneticisi.value == ThemeMode.dark);
                      }
                    ),
                    IconButton(icon: Icon(isAdmin ? Icons.logout : Icons.login, color: isAdmin ? Colors.redAccent : Colors.white), onPressed: () { if (isAdmin) { setState(() => isAdmin = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çıkış yapıldı.'))); } else { adminGirisiYap(); } }),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: const [SizedBox.shrink()], 
      ),
      body: OzetPaneliSayfasi(isAdmin: isAdmin),
    );
  }

  void adminGirisiYap() {
    TextEditingController sifreKontrolcusu = TextEditingController();
    void girisTetikle() {
      if (sifreKontrolcusu.text == gecerliAdminSifresi) { 
        setState(() => isAdmin = true); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin yetkileri aktif!'), backgroundColor: Colors.green));
      } else { 
        Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı şifre!'), backgroundColor: Colors.red)); 
      }
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.admin_panel_settings, color: kKolarcBlue), SizedBox(width: 10), Text('Yönetici Girişi')]),
        content: TextField(controller: sifreKontrolcusu, obscureText: true, decoration: const InputDecoration(hintText: 'Şifrenizi girin', prefixIcon: Icon(Icons.lock)), textInputAction: TextInputAction.done, onSubmitted: (_) => girisTetikle()),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: girisTetikle, child: const Text('Giriş Yap'))],
      ),
    );
  }
}

// SÜPER ARAMA SAYFASI
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
    if (aranan.trim().isEmpty) { setState(() {}); return; }
    
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
          sonuclar.add({'tip': 'Aktif Kart', 'ikon': Icons.memory, 'renk': Colors.green, 'baslik': '${k.tip} (${k.stokNo})', 'altbaslik': 'Şu Makinada Takılı: ${m.ad}', 'nesne': k});
        }
      }
    }
    for (var mal in smdMalzemeler) {
      if (mal.shKodu.toLowerCase().contains(s) || mal.hKodu.toLowerCase().contains(s) || mal.raf.toLowerCase().contains(s)) {
        sonuclar.add({'tip': 'SMD Raf', 'ikon': Icons.developer_board, 'renk': kKolarcBlue, 'baslik': 'SH: ${mal.shKodu}', 'altbaslik': 'H: ${mal.hKodu} | Raf: ${mal.raf}', 'nesne': mal});
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
      if (p.stokNo.toLowerCase().contains(s) || p.isim.toLowerCase().contains(s)) {
        sonuclar.add({'tip': 'PCB', 'ikon': Icons.layers, 'renk': Colors.teal, 'baslik': '${p.isim} (${p.stokNo})', 'altbaslik': 'Katman: ${p.katman} | Kalınlık: ${p.kalinlik}', 'nesne': p});
      }
    }
    for (var k in arsivlenmisKartlar) {
      if (k.stokNo.toLowerCase().contains(s) || k.tip.toLowerCase().contains(s)) {
        sonuclar.add({'tip': 'Silinmiş Kart', 'ikon': Icons.delete_outline, 'renk': Colors.redAccent, 'baslik': '${k.tip} (${k.stokNo})', 'altbaslik': 'Çöp Kutusunda', 'nesne': null});
      }
    }
    for (var m in arsivlenmisMakinalar) {
      if (m.ad.toLowerCase().contains(s) || m.kod.toLowerCase().contains(s)) {
        sonuclar.add({'tip': 'Silinmiş Makina', 'ikon': Icons.delete_outline, 'renk': Colors.redAccent, 'baslik': '${m.ad} (${m.kod})', 'altbaslik': 'Çöp Kutusunda', 'nesne': null});
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: kolarcAppBarBackground(),
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: aramaKontrolcusu,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Makina, Kart veya Ürün Ara...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: tumSistemiTara,
              ),
            ),
            IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { aramaKontrolcusu.clear(); tumSistemiTara(""); })
          ],
        ),
        actions: const [SizedBox.shrink()],
      ),
      body: aramaKontrolcusu.text.isEmpty 
        ? Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)), const SizedBox(height: 10), Text('Sistem genelinde arama yapın', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6)))])))
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
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (s['renk'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(s['ikon'] as IconData, color: s['renk'] as Color, size: 28)),
                    title: Text(s['baslik'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(s['altbaslik'] as String, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                    trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (s['renk'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(s['tip'] as String, style: TextStyle(fontSize: 10, color: s['renk'] as Color, fontWeight: FontWeight.bold))),
                    onTap: () {
                      if (s['nesne'] != null) {
                        if (s['tip'] == 'Makina') { Navigator.push(context, MaterialPageRoute(builder: (context) => MakinaDetaySayfasi(makina: s['nesne'] as Makina, isAdmin: widget.isAdmin))); }
                        else if (s['tip'] == 'Depo Kartı' || s['tip'] == 'Aktif Kart') { Navigator.push(context, MaterialPageRoute(builder: (context) => KartRevizyonSayfasi(kart: s['nesne'] as Kart, isAdmin: widget.isAdmin))); }
                        else if (s['tip'] == 'PCB') { Navigator.push(context, MaterialPageRoute(builder: (context) => PcbDeposuSayfasi(isAdmin: widget.isAdmin))); }
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- ARŞİV SAYFASI ---
class ArsivSayfasi extends StatefulWidget {
  final bool isAdmin; const ArsivSayfasi({super.key, required this.isAdmin});
  @override
  State<ArsivSayfasi> createState() => _ArsivSayfasiState();
}

class _ArsivSayfasiState extends State<ArsivSayfasi> with SingleTickerProviderStateMixin {
  late TabController _tabController; bool secimModu = false;
  Set<Kart> seciliKartlar = {}; Set<Makina> seciliMakinalar = {}; Set<Malzeme> seciliMalzemeler = {};
  int get toplamSecili => seciliKartlar.length + seciliMakinalar.length + seciliMalzemeler.length;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); _tabController.addListener(() { if (_tabController.indexIsChanging) { secimiKapat(); } }); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }
  void secimiKapat() { setState(() { secimModu = false; seciliKartlar.clear(); seciliMakinalar.clear(); seciliMalzemeler.clear(); }); }

  void tumunuSec() {
    setState(() {
      if (_tabController.index == 0) { 
        if (seciliKartlar.length == arsivlenmisKartlar.length) { seciliKartlar.clear(); secimModu = false; } else { seciliKartlar.addAll(arsivlenmisKartlar); secimModu = true; } 
      } else if (_tabController.index == 1) { 
        if (seciliMakinalar.length == arsivlenmisMakinalar.length) { seciliMakinalar.clear(); secimModu = false; } else { seciliMakinalar.addAll(arsivlenmisMakinalar); secimModu = true; } 
      } else if (_tabController.index == 2) { 
        if (seciliMalzemeler.length == arsivlenmisMalzemeler.length) { seciliMalzemeler.clear(); secimModu = false; } else { seciliMalzemeler.addAll(arsivlenmisMalzemeler); secimModu = true; } 
      }
    });
  }

  void topluGeriYukle() { 
    setState(() { 
      for(var k in seciliKartlar) { arsivlenmisKartlar.remove(k); tumKartlarDeposu.add(k); } 
      for(var m in seciliMakinalar) { arsivlenmisMakinalar.remove(m); tumMakinalar.add(m); } 
      for(var mal in seciliMalzemeler) { 
        arsivlenmisMalzemeler.remove(mal); 
        if(mal.depoTipi == 'SMD Raf' || mal.depoTipi == 'SMD') { smdMalzemeler.add(mal); } 
        else if(mal.depoTipi == 'Bacaklı Raf' || mal.depoTipi == 'Bacaklı') { bacakliMalzemeler.add(mal); } 
        else if(mal.depoTipi == 'SMD Depo') { smdDepoMalzemeler.add(mal); }
        else if(mal.depoTipi == 'Bacaklı Depo') { bacakliDepoMalzemeler.add(mal); }
      } 
    }); 
    verileriKaydet(); secimiKapat(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler başarıyla geri yüklendi!'), backgroundColor: Colors.green)); 
  }

  void topluKaliciSil() { 
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text('$toplamSecili Öğe Kalıcı Silinsin mi?'), content: const Text('Bu işlem geri alınamaz. Veritabanından tamamen silinecektir.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { setState(() { for(var k in seciliKartlar) { arsivlenmisKartlar.remove(k); } for(var m in seciliMakinalar) { arsivlenmisMakinalar.remove(m); } for(var mal in seciliMalzemeler) { arsivlenmisMalzemeler.remove(mal); } }); verileriKaydet(); secimiKapat(); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler sonsuza dek silindi.'))); }, child: const Text('Evet, Sil', style: TextStyle(color: Colors.white))) ])); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : kolarcAppBarBackground(),
        backgroundColor: secimModu ? Colors.blueGrey[700] : null,
        titleSpacing: 16,
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
                      IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), tooltip: 'Kalıcı Sil', onPressed: topluKaliciSil),
                    ],
                  ),
                ),
              ),
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: secimiKapat) : null,
        actions: const [SizedBox.shrink()],
        bottom: TabBar(
          controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, isScrollable: true,
          tabs: const [ Tab(icon: Icon(Icons.memory), text: 'Kartlar'), Tab(icon: Icon(Icons.precision_manufacturing), text: 'Makinalar'), Tab(icon: Icon(Icons.developer_board), text: 'Ürünler') ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          arsivlenmisKartlar.isEmpty ? const Center(child: Text('Arşiv boş.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: arsivlenmisKartlar.length, itemBuilder: (context, index) { 
            final kart = arsivlenmisKartlar[index]; bool seciliMi = seciliKartlar.contains(kart); 
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.2) : null, child: ListTile(onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliKartlar.add(kart); }); } : null, onTap: secimModu ? () { setState((){ if (seciliMi) { seciliKartlar.remove(kart); if(toplamSecili==0) { secimModu=false; } } else { seciliKartlar.add(kart); } }); } : null, title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(decoration: TextDecoration.lineThrough)), subtitle: Text('Silinme Öncesi: ${kart.eklenmeTarihi}'), trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliKartlar.add(kart); } else { seciliKartlar.remove(kart); if(toplamSecili==0) { secimModu=false; } } }); }) : null, )); 
          }),
          arsivlenmisMakinalar.isEmpty ? const Center(child: Text('Arşiv boş.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: arsivlenmisMakinalar.length, itemBuilder: (context, index) { 
            final makina = arsivlenmisMakinalar[index]; bool seciliMi = seciliMakinalar.contains(makina); 
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.2) : null, child: ListTile(onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliMakinalar.add(makina); }); } : null, onTap: secimModu ? () { setState((){ if (seciliMi) { seciliMakinalar.remove(makina); if(toplamSecili==0) { secimModu=false; } } else { seciliMakinalar.add(makina); } }); } : null, title: Text('${makina.ad} (${makina.kod})', style: const TextStyle(decoration: TextDecoration.lineThrough)), subtitle: Text('Silinme Öncesi: ${makina.eklenmeTarihi}'), trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliMakinalar.add(makina); } else { seciliMakinalar.remove(makina); if(toplamSecili==0) { secimModu=false; } } }); }) : null, )); 
          }),
          arsivlenmisMalzemeler.isEmpty ? const Center(child: Text('Arşiv boş.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: arsivlenmisMalzemeler.length, itemBuilder: (context, index) { 
            final malz = arsivlenmisMalzemeler[index]; bool seciliMi = seciliMalzemeler.contains(malz); 
            bool isRaf = malz.depoTipi.contains('Raf') || malz.depoTipi == 'SMD' || malz.depoTipi == 'Bacaklı';
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.2) : null, child: ListTile(onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; seciliMalzemeler.add(malz); }); } : null, onTap: secimModu ? () { setState((){ if (seciliMi) { seciliMalzemeler.remove(malz); if(toplamSecili==0) { secimModu=false; } } else { seciliMalzemeler.add(malz); } }); } : null, 
            title: Text(isRaf ? 'SH: ${malz.shKodu} - H: ${malz.hKodu}' : malz.urunIsmi, style: const TextStyle(decoration: TextDecoration.lineThrough)), 
            subtitle: Text(isRaf ? 'Raf: ${malz.raf}\nSilinme Öncesi: ${malz.eklenmeTarihi}' : 'Kod: ${malz.urunKodu}\nSilinme Öncesi: ${malz.eklenmeTarihi}'), 
            trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { seciliMalzemeler.add(malz); } else { seciliMalzemeler.remove(malz); if(toplamSecili==0) { secimModu=false; } } }); }) : null, )); 
          }),
        ],
      )
    );
  }
}

// --- ÖZET PANELİ ---
class OzetPaneliSayfasi extends StatefulWidget {
  final bool isAdmin;
  const OzetPaneliSayfasi({super.key, required this.isAdmin});
  @override
  State<OzetPaneliSayfasi> createState() => _OzetPaneliSayfasiState();
}

class _OzetPaneliSayfasiState extends State<OzetPaneliSayfasi> {

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
            style: ElevatedButton.styleFrom(backgroundColor: kKolarcBlue), 
            onPressed: () async { 
              Navigator.pop(context); 
              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']); 
              if (result != null) { 
                try { 
                  File file = File(result.files.single.path!); 
                  List<int> bytes = await file.readAsBytes();
                  String contents = utf8.decode(bytes, allowMalformed: true);
                  
                  if (contents.startsWith('\uFEFF') || contents.startsWith('\xEF\xBB\xBF')) { contents = contents.substring(1); }
                  List<String> lines = contents.split(RegExp(r'\r\n|\n|\r')); 
                  
                  int islenenSatir = 0;
                  for (int i = 0; i < lines.length; i++) { 
                    String line = lines[i].trim();
                    if (line.isEmpty) continue; 
                    if (i == 0 && (line.toLowerCase().contains('makina') || line.toLowerCase().contains('kart') || line.toLowerCase().contains('kod') || line.toLowerCase().contains('ürün') || line.toLowerCase().contains('isim') || line.toLowerCase().contains('sh'))) { continue; }
                    List<String> cols = line.split(RegExp(r'[;,]')); 
                    satirIsleyici(cols); 
                    islenenSatir++;
                  } 
                  
                  setState(() {}); verileriKaydet(); 
                  if (context.mounted) { 
                    if (islenenSatir > 0) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$islenenSatir kayıt başarıyla yüklendi!'), backgroundColor: Colors.green)); } 
                    else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosyada uygun kayıt bulunamadı.'), backgroundColor: Colors.orange)); }
                  } 
                } catch (e) { 
                  if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red)); } 
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
      bilgi: "Excel Formatı Sütunları:\n\nMakina Adı ; Son Bakım Tarihi ; Sıradaki Bakım Tarihi ; Durum (Normal/Yaklaştı/Gecikti)", 
      satirIsleyici: (cols) {
        if (cols.length >= 3) {
          String arananMakina = kelimeIlkHarfleriBuyut(cols[0]);
          for (var b in ozelBakimListesi) {
            if (b.ad == arananMakina) {
              b.sonBakim = cols[1].trim();
              b.siradakiBakim = cols[2].trim();
              b.durum = cols.length >= 4 ? cumleIlkHarfBuyut(cols[3]) : 'Normal';
            }
          }
        }
      }
    );
  }

  void _makinaYuke() { 
    _genelCsvYukle(baslik: 'Makina Listesi Yükle', bilgi: "Sütunlar: Makina Adı, Makina Kodu", satirIsleyici: (cols) { 
      if (cols.length >= 2 && cols[0].trim().isNotEmpty) {
        tumMakinalar.add(Makina(ad: kelimeIlkHarfleriBuyut(cols[0]), kod: cols[1].trim().toUpperCase(), eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: [])); 
      } else if (cols.isNotEmpty && cols[0].trim().isNotEmpty) {
        tumMakinalar.add(Makina(ad: kelimeIlkHarfleriBuyut(cols[0]), kod: '-', eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: []));
      }
    }); 
  }
  
  void _kartYukle() { 
    _genelCsvYukle(baslik: 'Kart Listesi Yükle', bilgi: "Sütunlar: Kart İsmi, Kart Kodu", satirIsleyici: (cols) { 
      if (cols.length >= 2 && cols[0].trim().isNotEmpty && cols[1].trim().isNotEmpty) {
        tumKartlarDeposu.add(Kart(tip: kelimeIlkHarfleriBuyut(cols[0]), stokNo: cols[1].trim().toUpperCase(), eklenmeTarihi: anlikTarihSaatGetir(), revizyonlar: [])); 
      }
    }); 
  }

  void _pcbYukle() { 
    _genelCsvYukle(baslik: 'PCB Listesi Yükle', bilgi: "Sütunlar: Stok Kodu, İsim, Katman, Kalınlık, Yüzey, Maske", satirIsleyici: (cols) { 
      if (cols.length >= 2 && cols[0].trim().isNotEmpty) {
        tumPcbDeposu.add(PcbKart(
          stokNo: cols[0].trim().toUpperCase(),
          isim: kelimeIlkHarfleriBuyut(cols[1]),
          katman: cols.length > 2 ? cols[2].trim() : '2 Layer',
          kalinlik: cols.length > 3 ? cols[3].trim() : '1.6 mm',
          yuzeyKaplama: cols.length > 4 ? cols[4].trim() : 'HASL',
          maskeRengi: cols.length > 5 ? cols[5].trim() : 'Yeşil',
          eklenmeTarihi: anlikTarihSaatGetir()
        )); 
      }
    }); 
  }
  
  void _malzemeYukle(String tip) { 
    bool isRaf = tip.contains('Raf');
    String bilgiMetni = isRaf ? "Sütunlar: SH Kodu, H Kodu, Raf" : "Sütunlar: Ürün İsmi, Ürün Kodu";
    
    _genelCsvYukle(baslik: '$tip Listesi Yükle', bilgi: bilgiMetni, satirIsleyici: (cols) { 
      if (isRaf && cols.length >= 3 && cols[0].trim().isNotEmpty) { 
        Malzeme m = Malzeme(
          shKodu: cols[0].trim().toUpperCase(), 
          hKodu: cols[1].trim().toUpperCase(), 
          raf: kelimeIlkHarfleriBuyut(cols[2]), 
          depoTipi: tip, 
          eklenmeTarihi: anlikTarihSaatGetir()
        ); 
        if (tip == 'SMD Raf') { smdMalzemeler.add(m); } 
        else if (tip == 'Bacaklı Raf') { bacakliMalzemeler.add(m); } 
      } else if (!isRaf && cols.length >= 2 && cols[0].trim().isNotEmpty) {
        Malzeme m = Malzeme(
          urunIsmi: kelimeIlkHarfleriBuyut(cols[0]), 
          urunKodu: cols[1].trim().toUpperCase(), 
          depoTipi: tip, 
          eklenmeTarihi: anlikTarihSaatGetir()
        );
        if (tip == 'SMD Depo') { smdDepoMalzemeler.add(m); }
        else if (tip == 'Bacaklı Depo') { bacakliDepoMalzemeler.add(m); }
      }
    }); 
  }
  
  void _revizyonYukle() { 
    _genelCsvYukle(baslik: 'Revizyon Geçmişi Yükle', bilgi: "Sütunlar: Kart İsmi (veya Kodu), Makina Adı, Açıklama, Tarih(Ops)", satirIsleyici: (cols) { 
      if (cols.length >= 3 && cols[0].trim().isNotEmpty && cols[2].trim().isNotEmpty) { 
        String kartArama = cols[0].trim().toUpperCase(); 
        String makinaAdi = kelimeIlkHarfleriBuyut(cols[1]); 
        String aciklama = cumleIlkHarfBuyut(cols[2]); 
        String tarih = cols.length > 3 && cols[3].trim().isNotEmpty ? cols[3].trim() : anlikTarihSaatGetir(); 
        
        Kart? hedefKart; 
        for(var k in tumKartlarDeposu) { if (k.stokNo.toUpperCase() == kartArama || k.tip.toUpperCase() == kartArama) { hedefKart = k; break; } } 
        if (hedefKart == null) { 
          for(var m in tumMakinalar) { 
            for(var k in m.bagliKartlar) { if (k.stokNo.toUpperCase() == kartArama || k.tip.toUpperCase() == kartArama) { hedefKart = k; break; } } 
            if (hedefKart != null) { break; } 
          } 
        } 
        if (hedefKart != null) { hedefKart.revizyonlar.add(Revizyon(tarihSaat: tarih, aciklama: aciklama, makinaAdi: makinaAdi)); } 
      } 
    }); 
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
        String? kayitYeri = await FilePicker.platform.saveFile(
          dialogTitle: 'Excel Raporunu Kaydet',
          fileName: 'Sistem_Raporu.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (kayitYeri != null) {
          File dosya = File(kayitYeri);
          await dosya.writeAsString('\uFEFF$csvVerisi', encoding: utf8); 
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel başarıyla bilgisayara kaydedildi!'), backgroundColor: Colors.green));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor oluşturulamadı.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pdfRaporuOlustur(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: kKolarcBlue)));

    try {
      final pdf = pw.Document();
      
      pw.Font? fontTtf;
      pw.Font? fontBoldTtf;
      try {
        fontTtf = await PdfGoogleFonts.robotoRegular();
        fontBoldTtf = await PdfGoogleFonts.robotoBold();
      } catch(e) { /* Yoksay */ }

      List<Kart> cokRevizyonGorenler = [...tumKartlarDeposu];
      for(var m in tumMakinalar) { 
        cokRevizyonGorenler.addAll(m.bagliKartlar); 
      }
      
      cokRevizyonGorenler.sort((a, b) => b.revizyonlar.length.compareTo(a.revizyonlar.length));
      cokRevizyonGorenler = cokRevizyonGorenler.where((k) => k.revizyonlar.isNotEmpty).toList();

      List<Map<String, dynamic>> butunRevizyonlar = [];
      void revizyonTopla(List<Kart> kartlar) { 
        for (var k in kartlar) { 
          for (var r in k.revizyonlar) { 
            butunRevizyonlar.add({'kart': k, 'revizyon': r}); 
          } 
        } 
      }
      revizyonTopla(tumKartlarDeposu);
      for(var m in tumMakinalar) { revizyonTopla(m.bagliKartlar); }
      
      butunRevizyonlar.sort((a, b) {
        DateTime tA = tarihCozumle((a['revizyon'] as Revizyon).tarihSaat);
        DateTime tB = tarihCozumle((b['revizyon'] as Revizyon).tarihSaat);
        return tB.compareTo(tA);
      });
      
      int takiliKartSayisi = tumMakinalar.fold(0, (sum, m) => sum + m.bagliKartlar.length);

      pdf.addPage(
        pw.MultiPage(
          theme: fontTtf != null ? pw.ThemeData.withFont(base: fontTtf, bold: fontBoldTtf) : null,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal800, width: 2))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MAKİNA TAKİP SİSTEMİ', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Resmi Yönetim Raporu', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('Tarih: ${anlikTarihSaatGetir().split(' - ')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ]
                    )
                  ]
                )
              ),
              pw.SizedBox(height: 20),

              pw.Text('SİSTEM ÖZETİ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 10),
              
              pw.Row(
                children: [
                  _pdfOzetKutusu('Makina', tumMakinalar.length.toString()),
                  _pdfOzetKutusu('Depo Kart', tumKartlarDeposu.length.toString()),
                  _pdfOzetKutusu('Takılı Kart', takiliKartSayisi.toString()),
                  _pdfOzetKutusu('Revizyon', butunRevizyonlar.length.toString()),
                  _pdfOzetKutusu('PCB', tumPcbDeposu.length.toString()),
                ]
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  _pdfOzetKutusu('SMD Raf', smdMalzemeler.length.toString()),
                  _pdfOzetKutusu('Bacaklı Raf', bacakliMalzemeler.length.toString()),
                  _pdfOzetKutusu('SMD Depo', smdDepoMalzemeler.length.toString()),
                  _pdfOzetKutusu('Bacaklı Depo', bacakliDepoMalzemeler.length.toString()),
                ]
              ),

              pw.SizedBox(height: 30),

              pw.Text('İŞLEM GÖREN TÜM KARTLAR (REVİZYON SAYISINA GÖRE)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
              pw.SizedBox(height: 10),
              cokRevizyonGorenler.isEmpty 
                ? pw.Text('Sistemde henüz revizyon gören kart bulunmamaktadır.', style: const pw.TextStyle(color: PdfColors.grey))
                : pw.TableHelper.fromTextArray(
                    headers: ['Kart Kodu', 'Kart İsmi', 'Toplam Revizyon'],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    data: cokRevizyonGorenler.map((k) => [k.stokNo, k.tip, k.revizyonlar.length.toString()]).toList(),
                  ),
              
              pw.SizedBox(height: 30),

              pw.Text('SAHADA YAPILAN TÜM İŞLEMLER (REVİZYON GEÇMİŞİ)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 10),
              butunRevizyonlar.isEmpty
                ? pw.Text('Sistemde henüz hiç revizyon işlemi yapılmamış.')
                : pw.TableHelper.fromTextArray(
                    headers: ['Tarih', 'Makina', 'Kart Kodu', 'Açıklama'],
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2.5),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(4.5),
                    },
                    data: butunRevizyonlar.map((item) {
                      Revizyon r = item['revizyon'];
                      Kart k = item['kart'];
                      return [r.tarihSaat.split(' - ')[0], r.makinaAdi, k.stokNo, r.aciklama];
                    }).toList(),
                  ),
            ];
          }
        )
      );

      Navigator.pop(context); 
      
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        String? kayitYeri = await FilePicker.platform.saveFile(
          dialogTitle: 'PDF Raporunu Kaydet',
          fileName: 'Sistem_Raporu.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (kayitYeri != null) {
          File dosya = File(kayitYeri);
          await dosya.writeAsBytes(await pdf.save());
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF başarıyla bilgisayara kaydedildi!'), backgroundColor: Colors.green));
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final dosyaYolu = '${dir.path}/Sistem_Raporu.pdf';
        File dosya = File(dosyaYolu);
        await dosya.writeAsBytes(await pdf.save());
        
        await Future.delayed(const Duration(milliseconds: 500));
        await Share.shareXFiles([XFile(dosyaYolu)]);
      }

    } catch (e) {
      if(context.mounted) Navigator.pop(context);
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF oluşturulurken hata oluştu.'), backgroundColor: Colors.red));
    }
  }

  pw.Widget _pdfOzetKutusu(String baslik, String deger) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))
        ),
        child: pw.Column(
          children: [
            pw.Text(deger, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
            pw.SizedBox(height: 4),
            pw.Text(baslik, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
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
        String? kayitYeri = await FilePicker.platform.saveFile(
          dialogTitle: 'Yedeği Nereye Kaydetmek İstersiniz?',
          fileName: 'Sistem_Yedek.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (kayitYeri != null) {
          File dosya = File(kayitYeri);
          await dosya.writeAsString(jsonVerisi, encoding: utf8);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yedek başarıyla bilgisayara kaydedildi!'), backgroundColor: Colors.green));
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final dosyaYolu = '${dir.path}/Sistem_Yedek.json';
        File dosya = File(dosyaYolu);
        await dosya.writeAsString(jsonVerisi, encoding: utf8);
        
        await Future.delayed(const Duration(milliseconds: 500));
        await Share.shareXFiles([XFile(dosyaYolu)]);
      }
    } catch (e) {
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yedekleme sırasında bir hata oluştu.'), backgroundColor: Colors.red)); }
    }
  }

  Future<void> _sistemiGeriYukle(BuildContext context) async {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('⚠️ DİKKAT: Sistemi İçe Aktar'),
      content: const Text('Bu işlem, mevcut telefondaki tüm verileri silip yerine yükleyeceğiniz yedek dosyasındaki verileri koyacaktır.\n\nEmin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']); 
            if (result != null) { 
              try { 
                File file = File(result.files.single.path!); 
                List<int> bytes = await file.readAsBytes();
                String contents = utf8.decode(bytes, allowMalformed: true);
                if (contents.startsWith('\uFEFF')) { contents = contents.substring(1); }
                
                Map<String, dynamic> gelenVeri = jsonDecode(contents);
                
                setState(() {
                  if (gelenVeri.containsKey('kartlar')) { tumKartlarDeposu = List<Kart>.from((gelenVeri['kartlar'] as List).map((x) => Kart.fromJson(x))); }
                  if (gelenVeri.containsKey('makinalar')) { tumMakinalar = List<Makina>.from((gelenVeri['makinalar'] as List).map((x) => Makina.fromJson(x))); }
                  if (gelenVeri.containsKey('smdMalzemeler')) { smdMalzemeler = List<Malzeme>.from((gelenVeri['smdMalzemeler'] as List).map((x) => Malzeme.fromJson(x))); }
                  if (gelenVeri.containsKey('bacakliMalzemeler')) { bacakliMalzemeler = List<Malzeme>.from((gelenVeri['bacakliMalzemeler'] as List).map((x) => Malzeme.fromJson(x))); }
                  if (gelenVeri.containsKey('smdDepoMalzemeler')) { smdDepoMalzemeler = List<Malzeme>.from((gelenVeri['smdDepoMalzemeler'] as List).map((x) => Malzeme.fromJson(x))); }
                  if (gelenVeri.containsKey('bacakliDepoMalzemeler')) { bacakliDepoMalzemeler = List<Malzeme>.from((gelenVeri['bacakliDepoMalzemeler'] as List).map((x) => Malzeme.fromJson(x))); }
                  if (gelenVeri.containsKey('arsivKartlar')) { arsivlenmisKartlar = List<Kart>.from((gelenVeri['arsivKartlar'] as List).map((x) => Kart.fromJson(x))); }
                  if (gelenVeri.containsKey('arsivMakinalar')) { arsivlenmisMakinalar = List<Makina>.from((gelenVeri['arsivMakinalar'] as List).map((x) => Makina.fromJson(x))); }
                  if (gelenVeri.containsKey('arsivMalzemeler')) { arsivlenmisMalzemeler = List<Malzeme>.from((gelenVeri['arsivMalzemeler'] as List).map((x) => Malzeme.fromJson(x))); }
                  if (gelenVeri.containsKey('ozelBakimListesi')) { ozelBakimListesi = List<OzelMakinaBakim>.from((gelenVeri['ozelBakimListesi'] as List).map((x) => OzelMakinaBakim.fromJson(x))); }
                  if (gelenVeri.containsKey('kayitliPcbler')) { tumPcbDeposu = List<PcbKart>.from((gelenVeri['kayitliPcbler'] as List).map((x) => PcbKart.fromJson(x))); }
                  if (gelenVeri.containsKey('arsivliPcbler')) { arsivlenmisPcbler = List<PcbKart>.from((gelenVeri['arsivliPcbler'] as List).map((x) => PcbKart.fromJson(x))); }
                });
                
                verileriKaydet();
                
                if (context.mounted) { 
                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaGezinmeSayfasi()));
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sistem başarıyla yeni cihazınıza yüklendi!'), backgroundColor: Colors.green)); 
                } 
              } catch (e) { 
                if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bozuk veya geçersiz yedek dosyası.'), backgroundColor: Colors.red)); } 
              } 
            } 
          }, 
          child: const Text('Evet, Yükle', style: TextStyle(color: Colors.white))
        )
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    int toplamMakina = tumMakinalar.length; int depodakiKart = tumKartlarDeposu.length; int makinalardakiToplamKart = tumMakinalar.fold(0, (sum, m) => sum + m.bagliKartlar.length);
    int smdRafSayisi = smdMalzemeler.length; int bacakliRafSayisi = bacakliMalzemeler.length;
    int smdDepoSayisi = smdDepoMalzemeler.length; int bacakliDepoSayisi = bacakliDepoMalzemeler.length;
    int toplamRevizyonSayisi = 0; List<Kart> tumSistemdekiKartlar = [...tumKartlarDeposu]; for(var m in tumMakinalar) { tumSistemdekiKartlar.addAll(m.bagliKartlar); } for(var k in tumSistemdekiKartlar) { toplamRevizyonSayisi += k.revizyonlar.length; }

    double ekranGenisligi = MediaQuery.of(context).size.width; 
    double kutuGenisligi; 
    if (ekranGenisligi > 600) { 
      kutuGenisligi = 220; 
    } else { 
      kutuGenisligi = (ekranGenisligi / 2) - 24; 
      if (kutuGenisligi < 150) { kutuGenisligi = ekranGenisligi - 32; } 
    }

    return SingleChildScrollView( 
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2)]),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10, runSpacing: 10,
              children: [
                Text('ANASAYFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Theme.of(context).colorScheme.primary), overflow: TextOverflow.ellipsis),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    ElevatedButton.icon(onPressed: () => excelRaporuIndir(context), icon: const Icon(Icons.table_view, size: 16), label: const Text('Excel'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 12))),
                    ElevatedButton.icon(onPressed: () => _pdfRaporuOlustur(context), icon: const Icon(Icons.picture_as_pdf, size: 16), label: const Text('PDF'), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 12))),
                  ]
                )
              ],
            ),
          ),
          const SizedBox(height: 25),
          
          Wrap(
            spacing: 16, runSpacing: 16, 
            children: [
              _buildResponsiveKutu('Toplam Makina', toplamMakina.toString(), Icons.precision_manufacturing, const Color(0xFF26A69A), const Color(0xFF00695C), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MakinalarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _makinaYuke),
              _buildResponsiveKutu('Depo Kartları', depodakiKart.toString(), Icons.inventory_2, const Color(0xFF5C6BC0), const Color(0xFF283593), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => KartlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _kartYukle),
              _buildResponsiveKutu('PCB Deposu', tumPcbDeposu.length.toString(), Icons.layers, const Color(0xFF00897B), const Color(0xFF004D40), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => PcbDeposuSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _pcbYukle),
              _buildResponsiveKutu('Takılı Kartlar', makinalardakiToplamKart.toString(), Icons.memory, const Color(0xFF66BB6A), const Color(0xFF2E7D32), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => AktifKartlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }), 
              _buildResponsiveKutu('Revizyonlar', toplamRevizyonSayisi.toString(), Icons.history_edu, const Color(0xFFAB47BC), const Color(0xFF6A1B9A), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => TumRevizyonlarSayfasi(isAdmin: widget.isAdmin))).then((_) => setState((){})); }, yuklemeGorevi: _revizyonYukle),
              
              _buildResponsiveKutu('SMD Raf', smdRafSayisi.toString(), Icons.developer_board, const Color(0xFF8D6E63), const Color(0xFF4E342E), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'SMD Raf'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('SMD Raf')),
              _buildResponsiveKutu('Bacaklı Raf', bacakliRafSayisi.toString(), Icons.hub, const Color(0xFF78909C), const Color(0xFF37474F), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'Bacaklı Raf'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('Bacaklı Raf')),
              
              _buildResponsiveKutu('SMD Depo', smdDepoSayisi.toString(), Icons.inventory, const Color(0xFFFFA726), const Color(0xFFE65100), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'SMD Depo'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('SMD Depo')),
              _buildResponsiveKutu('Bacaklı Depo', bacakliDepoSayisi.toString(), Icons.dns, const Color(0xFF26C6DA), const Color(0xFF006064), kutuGenisligi, () { Navigator.push(context, MaterialPageRoute(builder: (context) => MalzemeDepoSayfasi(isAdmin: widget.isAdmin, depoTipi: 'Bacaklı Depo'))).then((_) => setState((){})); }, yuklemeGorevi: () => _malzemeYukle('Bacaklı Depo')),
            ],
          ),

          const SizedBox(height: 30), 

          ValueListenableBuilder<bool>(
            valueListenable: bakimPaneliniGoster,
            builder: (context, aktifMi, child) {
              if (!aktifMi) return const SizedBox.shrink(); 
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 40, thickness: 1), 
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Kritik Makina Bakım Durumları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                      if (widget.isAdmin)
                        IconButton(icon: const Icon(Icons.upload_file, color: kKolarcBlue), tooltip: 'Bakım Exceli Yükle', onPressed: _bakimCsvYukle)
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: ozelBakimListesi.map((makina) {
                      Color kartRengi; IconData kartIkoni;
                      if (makina.durum == 'Gecikti') { kartRengi = Colors.red; } 
                      else if (makina.durum == 'Yaklaştı') { kartRengi = Colors.orange; } 
                      else { kartRengi = kKolarcBlue; }

                      if (makina.ad.contains('Pota')) { kartIkoni = Icons.water_drop; }
                      else if (makina.ad.contains('SMD')) { kartIkoni = Icons.precision_manufacturing; }
                      else if (makina.ad.contains('Lehim')) { kartIkoni = Icons.hardware; }
                      else { kartIkoni = Icons.local_fire_department; }

                      return _buildBakimKutusu(makina.ad, makina.siradakiBakim, makina.durum, kartIkoni, kartRengi, kutuGenisligi);
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }
          ),

          const SizedBox(height: 30),
          const Divider(height: 40, thickness: 1), 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isAdmin) ...[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Özel Bakım Panelini Sahada Göster', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ValueListenableBuilder<bool>(
                        valueListenable: bakimPaneliniGoster,
                        builder: (context, aktifMi, child) {
                          return Switch(
                            value: aktifMi, 
                            activeThumbColor: kKolarcBlue,
                            onChanged: (v) async { 
                              bakimPaneliniGoster.value = v; 
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('bakimPaneliGoster', v);
                            }
                          );
                        }
                      )
                    ],
                  ),
                  const Divider(height: 20),
                ],
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.settings_system_daydream, color: kKolarcOrange, size: 18), 
                        const SizedBox(width: 8), 
                        Flexible(child: Text('Sistem Yönetimi (Cihaz Aktarımı)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), overflow: TextOverflow.ellipsis))
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(onPressed: () => _sistemiYedekle(context), icon: const Icon(Icons.upload, size: 16), label: const Text('Yedekle'), style: ElevatedButton.styleFrom(backgroundColor: kKolarcBlue)),
                        ElevatedButton.icon(onPressed: () => _sistemiGeriYukle(context), icon: const Icon(Icons.download, size: 16), label: const Text('Yükle'), style: ElevatedButton.styleFrom(backgroundColor: kKolarcOrange)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: renk.withValues(alpha: 0.2), 
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: Theme.of(context).cardColor,
            child: Container(
              width: double.infinity, constraints: const BoxConstraints(minHeight: 120), 
              decoration: BoxDecoration(
                border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ), 
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), 
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, 
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ikon, size: 20, color: renk), const SizedBox(width: 8),
                        Flexible(child: Text(baslik, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis))),
                      ],
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
          ),
        ),
      )
    ); 
  }

  Widget _buildResponsiveKutu(String baslik, String deger, IconData ikon, Color acikRenk, Color koyuRenk, double genislik, VoidCallback? tiklamaGorevi, {VoidCallback? yuklemeGorevi}) { 
    return SizedBox(
      width: genislik, 
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: acikRenk.withValues(alpha: 0.3), 
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: tiklamaGorevi,
                  child: Container(
                    width: double.infinity, constraints: const BoxConstraints(minHeight: 140), 
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [acikRenk, koyuRenk], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    ), 
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
            ),
          ),
          if (yuklemeGorevi != null && widget.isAdmin)
            Positioned(top: 10, right: 10, child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 20), tooltip: 'Hızlı CSV Yükle', onPressed: yuklemeGorevi, constraints: const BoxConstraints(), padding: const EdgeInsets.all(8))))
        ],
      )
    ); 
  }
}

// --- MALZEME DEPOSU ---
class MalzemeDepoSayfasi extends StatefulWidget {
  final bool isAdmin; final String depoTipi;
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
    if (widget.depoTipi == 'Bacaklı Depo') return bacakliDepoMalzemeler;
    return smdMalzemeler;
  }

  bool secimModu = false; Set<Malzeme> secilenler = {};
  @override
  void initState() { super.initState(); _aramaYap(""); }
  
  void _aramaYap(String aranan) { 
    setState(() { 
      ekrandakiMalzemeler = hedefDepo.where((m) {
        if (isRaf) {
          return m.shKodu.toLowerCase().contains(aranan.toLowerCase()) || 
                 m.hKodu.toLowerCase().contains(aranan.toLowerCase()) ||
                 m.raf.toLowerCase().contains(aranan.toLowerCase());
        } else {
          return m.urunIsmi.toLowerCase().contains(aranan.toLowerCase()) || 
                 m.urunKodu.toLowerCase().contains(aranan.toLowerCase());
        }
      }).toList(); 
    }); 
  }
  
  void tumunuSec() { setState(() { if (secilenler.length == ekrandakiMalzemeler.length) { secilenler.clear(); secimModu = false; } else { secilenler.addAll(ekrandakiMalzemeler); secimModu = true; } }); }
  
  void manuelEkle({Malzeme? varOlanMalzeme}) { 
    // Raf için
    TextEditingController shKontrolcusu = TextEditingController(text: varOlanMalzeme?.shKodu ?? ''); 
    TextEditingController hKontrolcusu = TextEditingController(text: varOlanMalzeme?.hKodu ?? ''); 
    TextEditingController rafKontrolcusu = TextEditingController(text: varOlanMalzeme?.raf ?? ''); 
    // Depo için
    TextEditingController urunIsmiKontrolcusu = TextEditingController(text: varOlanMalzeme?.urunIsmi ?? ''); 
    TextEditingController urunKoduKontrolcusu = TextEditingController(text: varOlanMalzeme?.urunKodu ?? ''); 

    void kaydetTetikle() {
      bool isGecerli = isRaf ? shKontrolcusu.text.isNotEmpty : urunIsmiKontrolcusu.text.isNotEmpty;
      
      if (isGecerli) { 
        setState(() { 
          if (varOlanMalzeme == null) { 
            hedefDepo.add(Malzeme(
              shKodu: shKontrolcusu.text.trim().toUpperCase(), 
              hKodu: hKontrolcusu.text.trim().toUpperCase(), 
              raf: kelimeIlkHarfleriBuyut(rafKontrolcusu.text), 
              urunIsmi: kelimeIlkHarfleriBuyut(urunIsmiKontrolcusu.text),
              urunKodu: urunKoduKontrolcusu.text.trim().toUpperCase(),
              depoTipi: widget.depoTipi, 
              eklenmeTarihi: anlikTarihSaatGetir()
            )); 
          } else { 
            if (isRaf) {
              varOlanMalzeme.shKodu = shKontrolcusu.text.trim().toUpperCase(); 
              varOlanMalzeme.hKodu = hKontrolcusu.text.trim().toUpperCase(); 
              varOlanMalzeme.raf = kelimeIlkHarfleriBuyut(rafKontrolcusu.text); 
            } else {
              varOlanMalzeme.urunIsmi = kelimeIlkHarfleriBuyut(urunIsmiKontrolcusu.text);
              varOlanMalzeme.urunKodu = urunKoduKontrolcusu.text.trim().toUpperCase();
            }
          } 
          _aramaYap(aramaKontrolcusu.text); 
        }); verileriKaydet(); Navigator.pop(context); 
      }
    }
    
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(varOlanMalzeme == null ? 'Yeni Kayıt Ekle' : 'Kaydı Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
      content: Column(mainAxisSize: MainAxisSize.min, children: isRaf ? [
        TextField(controller: shKontrolcusu, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'SH Kodu')), const SizedBox(height: 10),
        TextField(controller: hKontrolcusu, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'H Kodu')), const SizedBox(height: 10),
        TextField(controller: rafKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Raf Numarası')), 
      ] : [
        TextField(controller: urunIsmiKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Ürün İsmi')), const SizedBox(height: 10),
        TextField(controller: urunKoduKontrolcusu, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Ürün Kodu')), 
      ]), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet') ) ]
    )); 
  }

  void topluArsiveGonder() { setState(() { for(var m in secilenler) { hedefDepo.remove(m); arsivlenmisMalzemeler.add(m); } secimModu=false; secilenler.clear(); _aramaYap(aramaKontrolcusu.text); }); verileriKaydet(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler Arşive Taşındı.'), backgroundColor: Colors.orange)); }

  @override
  Widget build(BuildContext context) {
    IconData depoIkon = widget.depoTipi.contains('SMD') ? Icons.developer_board : Icons.hub;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : kolarcAppBarBackground(),
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
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), tooltip: 'Tümünü Seç / Kaldır', onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ],
                  ),
                ),
              ),
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null,
        actions: const [SizedBox.shrink()],
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: manuelEkle, backgroundColor: kKolarcBlue, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12.0), child: TextField(controller: aramaKontrolcusu, onChanged: _aramaYap, decoration: InputDecoration(labelText: isRaf ? 'SH, H Kodu veya Raf Ara...' : 'Ürün İsmi veya Kodu Ara...', prefixIcon: const Icon(Icons.search, color: kKolarcBlue)))),
          Expanded(child: ekrandakiMalzemeler.isEmpty ? const Center(child: Text('Kayıt bulunamadı.')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: ekrandakiMalzemeler.length, itemBuilder: (context, index) { 
            final malz = ekrandakiMalzemeler[index]; bool seciliMi = secilenler.contains(malz); 
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.1) : null, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(
              onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(malz); }); } : null, 
              onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(malz); if(secilenler.isEmpty) { secimModu=false; } } else { secilenler.add(malz); } }); } : null, 
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(depoIkon, color: kKolarcBlue, size: 28)), 
              title: Text(isRaf ? 'SH: ${malz.shKodu}' : malz.urunIsmi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
              subtitle: Text(isRaf ? 'H Kodu: ${malz.hKodu}   •   Raf: ${malz.raf}\nEklenme: ${malz.eklenmeTarihi}' : 'Kod: ${malz.urunKodu}\nEklenme: ${malz.eklenmeTarihi}', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])), 
              trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(malz); } else { secilenler.remove(malz); if(secilenler.isEmpty) { secimModu=false; } } }); }) : (widget.isAdmin ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: kKolarcBlue), onPressed: () => manuelEkle(varOlanMalzeme: malz)) ])) : null), 
            )); 
          }))
        ],
      ),
    );
  }
}

// --- KART DEPOSU SAYFASI ---
class KartlarSayfasi extends StatefulWidget {
  final bool isAdmin;
  const KartlarSayfasi({super.key, required this.isAdmin});
  @override
  State<KartlarSayfasi> createState() => _KartlarSayfasiState();
}

class _KartlarSayfasiState extends State<KartlarSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); List<Kart> ekrandakiKartlar = []; 
  bool secimModu = false; Set<Kart> secilenler = {};

  @override
  void initState() { super.initState(); _filtreleriUygula(); }

  void _filtreleriUygula() { setState(() { ekrandakiKartlar = tumKartlarDeposu.where((k) { return k.stokNo.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase()) || k.tip.toLowerCase().contains(aramaKontrolcusu.text.toLowerCase()); }).toList(); }); }
  void tumunuSec() { setState(() { if (secilenler.length == ekrandakiKartlar.length) { secilenler.clear(); secimModu = false; } else { secilenler.addAll(ekrandakiKartlar); secimModu = true; } }); }
  
  void kartPenceresiAc({Kart? varOlanKart}) { 
    TextEditingController isimKontrolcusu = TextEditingController(text: varOlanKart?.tip ?? ''); TextEditingController koduKontrolcusu = TextEditingController(text: varOlanKart?.stokNo ?? ''); 
    void kaydetTetikle() {
      if (koduKontrolcusu.text.isNotEmpty && isimKontrolcusu.text.isNotEmpty) { 
        setState(() { 
          String formatliKod = koduKontrolcusu.text.trim().toUpperCase();
          String formatliIsim = kelimeIlkHarfleriBuyut(isimKontrolcusu.text);
          if (varOlanKart == null) { 
            tumKartlarDeposu.add(Kart(stokNo: formatliKod, tip: formatliIsim, eklenmeTarihi: anlikTarihSaatGetir(), revizyonlar: [])); 
          } else { 
            varOlanKart.stokNo = formatliKod; varOlanKart.tip = formatliIsim; 
          } 
          _filtreleriUygula(); 
        }); verileriKaydet(); Navigator.pop(context); 
      }
    }
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text(varOlanKart == null ? 'Yeni Kart Ekle' : 'Kartı Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: isimKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Kart İsmi')), const SizedBox(height: 10), 
        TextField(controller: koduKontrolcusu, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Kart Kodu'))
      ])), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet') ) ]
    )); 
  }

  void topluArsiveGonder() { setState(() { for(var kart in secilenler) { tumKartlarDeposu.remove(kart); for (var makina in tumMakinalar) { makina.bagliKartlar.removeWhere((k) => k.stokNo == kart.stokNo); } arsivlenmisKartlar.add(kart); } secimModu=false; secilenler.clear(); _filtreleriUygula(); }); verileriKaydet(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler Arşive Taşındı.'), backgroundColor: Colors.orange)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : kolarcAppBarBackground(), backgroundColor: secimModu ? Colors.blueGrey[700] : null,
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
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), tooltip: 'Tümünü Seç / Kaldır', onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ],
                  ),
                ),
              ),
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null,
        actions: const [SizedBox.shrink()],
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: () => kartPenceresiAc(), backgroundColor: kKolarcBlue, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12.0), child: TextField(controller: aramaKontrolcusu, onChanged: (v) => _filtreleriUygula(), decoration: const InputDecoration(labelText: 'Kart İsmi veya Kodu Ara...', prefixIcon: Icon(Icons.search, color: kKolarcBlue)))),
          Expanded(child: ekrandakiKartlar.isEmpty ? const Center(child: Text('Kriterlere uygun kart bulunamadı.')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: ekrandakiKartlar.length, itemBuilder: (context, index) { 
            final kart = ekrandakiKartlar[index]; bool seciliMi = secilenler.contains(kart);
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.1) : null, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(
              onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(kart); }); } : null, onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(kart); if(secilenler.isEmpty) { secimModu=false; } } else { secilenler.add(kart); } }); } : null,
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: kKolarcBlue, size: 28)), 
              title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Revizyon: ${kart.revizyonlar.length} | Eklenme: ${kart.eklenmeTarihi}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), 
              trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(kart); } else { secilenler.remove(kart); if(secilenler.isEmpty) { secimModu=false; } } }); }) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.history, color: Colors.indigo), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => KartRevizyonSayfasi(kart: kart, isAdmin: widget.isAdmin))).then((value) => setState((){ _filtreleriUygula();})); }), if (widget.isAdmin) IconButton(icon: const Icon(Icons.edit, color: kKolarcBlue), onPressed: () => kartPenceresiAc(varOlanKart: kart)) ])), 
            )); 
          }))
        ],
      ),
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
  void aramaYap(String aranan) { setState(() => ekrandakiMakinalar = tumMakinalar.where((m) => m.ad.toLowerCase().contains(aranan.toLowerCase()) || m.kod.toLowerCase().contains(aranan.toLowerCase())).toList()); }
  void tumunuSec() { setState(() { if (secilenler.length == ekrandakiMakinalar.length) { secilenler.clear(); secimModu = false; } else { secilenler.addAll(ekrandakiMakinalar); secimModu = true; } }); }
  
  void makinaEkle() { 
    void kaydetTetikle() {
      if (makinaAdiKontrolcusu.text.isNotEmpty && makinaKoduKontrolcusu.text.isNotEmpty) { 
        setState(() { tumMakinalar.add(Makina(kod: makinaKoduKontrolcusu.text.trim().toUpperCase(), ad: kelimeIlkHarfleriBuyut(makinaAdiKontrolcusu.text), eklenmeTarihi: anlikTarihSaatGetir(), bagliKartlar: [])); aramaYap(aramaKontrolcusu.text); }); 
        verileriKaydet(); makinaAdiKontrolcusu.clear(); makinaKoduKontrolcusu.clear(); Navigator.pop(context); 
      }
    }
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Yeni Makina Ekle', style: TextStyle(fontWeight: FontWeight.bold)), 
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: makinaAdiKontrolcusu, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Makina Adı')),
          const SizedBox(height: 10),
          TextField(controller: makinaKoduKontrolcusu, textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(labelText: 'Makina Kodu')),
        ]
      ), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Ekle') ) ]
    )); 
  }

  void topluArsiveGonder() { setState(() { for(var m in secilenler) { tumMakinalar.remove(m); arsivlenmisMakinalar.add(m); } secimModu=false; secilenler.clear(); aramaYap(aramaKontrolcusu.text); }); verileriKaydet(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler Arşive Taşındı!'), backgroundColor: Colors.orange)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : kolarcAppBarBackground(), backgroundColor: secimModu ? Colors.blueGrey[700] : null,
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
                      IconButton(icon: const Icon(Icons.select_all, color: Colors.white), tooltip: 'Tümünü Seç / Kaldır', onPressed: tumunuSec), 
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
                    ],
                  ),
                ),
              ),
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null,
        actions: const [SizedBox.shrink()],
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: makinaEkle, backgroundColor: kKolarcBlue, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12.0), child: TextField(controller: aramaKontrolcusu, onChanged: aramaYap, decoration: const InputDecoration(labelText: 'Makina Adı veya Kodu Ara...', prefixIcon: Icon(Icons.search, color: kKolarcBlue)))),
          Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: ekrandakiMakinalar.length, itemBuilder: (context, index) { 
            final makina = ekrandakiMakinalar[index]; bool seciliMi = secilenler.contains(makina);
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.1) : null, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(
              onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(makina); }); } : null,
              onTap: () { if (secimModu) { setState((){ if (seciliMi) { secilenler.remove(makina); if(secilenler.isEmpty) { secimModu=false; } } else { secilenler.add(makina); } }); } else { Navigator.push(context, MaterialPageRoute(builder: (context) => MakinaDetaySayfasi(makina: makina, isAdmin: widget.isAdmin))).then((value) => setState(() {})); } },
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.precision_manufacturing, color: kKolarcBlue, size: 28)), 
              title: Text('${makina.ad} (${makina.kod})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), subtitle: Text('Bağlı Kart Sayısı: ${makina.bagliKartlar.length} | Eklenme: ${makina.eklenmeTarihi}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), 
              trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(makina); } else { secilenler.remove(makina); if(secilenler.isEmpty) { secimModu=false; } } }); }) : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            )); 
          }))
        ],
      ),
    );
  }
}

// --- AKTİF KARTLAR VE MAKİNA DETAY ---
class AktifKartlarSayfasi extends StatefulWidget {
  final bool isAdmin;
  const AktifKartlarSayfasi({super.key, required this.isAdmin});
  @override
  State<AktifKartlarSayfasi> createState() => _AktifKartlarSayfasiState();
}
class _AktifKartlarSayfasiState extends State<AktifKartlarSayfasi> {
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> takiliKartlar = [];
    for (var makina in tumMakinalar) { for (var kart in makina.bagliKartlar) { takiliKartlar.add({'makina': makina, 'kart': kart}); } }
    return Scaffold(
      appBar: AppBar(flexibleSpace: kolarcAppBarBackground(), title: const Text('Sahadaki Aktif Kartlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: takiliKartlar.isEmpty ? const Center(child: Text('Şu an hiçbir makinaya kart bağlanmamış.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: takiliKartlar.length, itemBuilder: (context, index) { final kart = takiliKartlar[index]['kart'] as Kart; final makina = takiliKartlar[index]['makina'] as Makina; return Card(margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: Colors.green, size: 28)), title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Makina: ${makina.ad} (${makina.kod})', style: const TextStyle(color: kKolarcBlue, fontWeight: FontWeight.w600)), trailing: widget.isAdmin ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () { setState(() { makina.bagliKartlar.removeWhere((k) => k.stokNo == kart.stokNo); }); verileriKaydet(); }) : null, )); }),
    );
  }
}

class MakinaDetaySayfasi extends StatefulWidget {
  final Makina makina; final bool isAdmin; 
  const MakinaDetaySayfasi({super.key, required this.makina, required this.isAdmin});
  @override
  State<MakinaDetaySayfasi> createState() => _MakinaDetaySayfasiState();
}
class _MakinaDetaySayfasiState extends State<MakinaDetaySayfasi> {
  void makinayaKartBagla() { showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Depodan Kart Seç'), content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: tumKartlarDeposu.length, itemBuilder: (context, index) { final secilenKart = tumKartlarDeposu[index]; return ListTile(leading: const Icon(Icons.memory, color: Colors.grey), title: Text('${secilenKart.tip} (${secilenKart.stokNo})'), subtitle: Text('Revizyon: ${secilenKart.revizyonlar.length}'), trailing: const Icon(Icons.add_circle, color: kKolarcBlue), onTap: () { bool zatenVarMi = widget.makina.bagliKartlar.any((k) => k.stokNo == secilenKart.stokNo); if (!zatenVarMi) { setState(() { widget.makina.bagliKartlar.add(secilenKart); }); verileriKaydet(); } Navigator.pop(context); }, ); }, ), ), )); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(flexibleSpace: kolarcAppBarBackground(), title: Text('${widget.makina.ad} (${widget.makina.kod})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: makinayaKartBagla, backgroundColor: kKolarcBlue, icon: const Icon(Icons.link, color: Colors.white), label: const Text("Depodan Kart Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: widget.makina.bagliKartlar.isEmpty ? const Center(child: Text('Bu makinaya henüz kart bağlanmamış.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: widget.makina.bagliKartlar.length, itemBuilder: (context, index) { final kart = widget.makina.bagliKartlar[index]; return Card(margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.memory, color: Colors.green, size: 28)), title: Text('${kart.tip} - ${kart.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Revizyon: ${kart.revizyonlar.length}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)), trailing: widget.isAdmin ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () { setState(() { widget.makina.bagliKartlar.removeWhere((k) => k.stokNo == kart.stokNo); }); verileriKaydet(); }) : null, )); }, ),
    );
  }
}

// --- REVİZYON SAYFASI ---
class TumRevizyonlarSayfasi extends StatefulWidget {
  final bool isAdmin; const TumRevizyonlarSayfasi({super.key, required this.isAdmin});
  @override
  State<TumRevizyonlarSayfasi> createState() => _TumRevizyonlarSayfasiState();
}
class _TumRevizyonlarSayfasiState extends State<TumRevizyonlarSayfasi> {
  String seciliMakinaFiltresi = 'Tümü';

  void revizyonPenceresiAc(Kart kart, Revizyon? varOlanRevizyon) { 
    TextEditingController aciklamaKontrolcusu = TextEditingController(text: varOlanRevizyon?.aciklama ?? ''); 
    String seciliMakinaAdi = varOlanRevizyon?.makinaAdi ?? 'Genel'; 
    List<String> makinaSecenekleri = ['Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    
    showDialog(context: context, builder: (context) { 
      return StatefulBuilder(builder: (context, setStateDialog) { 

        void kaydetTetikle() {
          if (aciklamaKontrolcusu.text.isNotEmpty) { 
            setState(() { 
              String formatliAciklama = cumleIlkHarfBuyut(aciklamaKontrolcusu.text);
              if (varOlanRevizyon == null) { kart.revizyonlar.add(Revizyon(tarihSaat: anlikTarihSaatGetir(), aciklama: formatliAciklama, makinaAdi: seciliMakinaAdi)); } 
              else { varOlanRevizyon.aciklama = formatliAciklama; varOlanRevizyon.makinaAdi = seciliMakinaAdi; } 
            }); verileriKaydet(); Navigator.pop(context); 
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(varOlanRevizyon == null ? 'Yeni Revizyon Ekle' : 'Revizyonu Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('İşlem Yapılan Makina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(12)), child: DropdownButton<String>(isExpanded: true, underline: const SizedBox(), value: makinaSecenekleri.contains(seciliMakinaAdi) ? seciliMakinaAdi : 'Genel', items: makinaSecenekleri.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(), onChanged: (String? val) { setStateDialog(() { seciliMakinaAdi = val!; }); })), 
            const SizedBox(height: 15), 
            TextField(controller: aciklamaKontrolcusu, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(hintText: 'Yapılan işlemi yazın...'), maxLines: 3), 
          ]), 
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet')) ]
        ); 
      }); 
    }); 
  }
  
  Future<void> exceldenCSVYukle() async {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('CSV Revizyon Geçmişi Yükle'), 
      content: const Text("Excel'den 'CSV (Virgülle Ayrılmış)' olarak kaydedin.\n\nSütunlar: Kart İsmi (veya Kodu), Makina Adı, Açıklama, Tarih(Ops)"), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')), 
        ElevatedButton(onPressed: () async { 
          Navigator.pop(context); 
          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']); 
          if (result != null) { 
            try { 
              File file = File(result.files.single.path!); 
              
              List<int> bytes = await file.readAsBytes();
              String contents = utf8.decode(bytes, allowMalformed: true);
              if (contents.startsWith('\uFEFF')) { contents = contents.substring(1); }
              
              List<String> lines = contents.split(RegExp(r'\r\n|\n|\r')); 
              int e = 0; 
              
              for (String line in lines) { 
                if (line.trim().isEmpty) { continue; } 
                
                if (line.toLowerCase().startsWith('kart') || line.toLowerCase().startsWith('makina')) {
                  continue;
                }

                List<String> cols = line.split(RegExp(r'[;,]')); 
                if (cols.length >= 3) { 
                  String kartArama = cols[0].trim().toUpperCase(); 
                  String makinaAdi = kelimeIlkHarfleriBuyut(cols[1]); 
                  String aciklama = cumleIlkHarfBuyut(cols[2]); 
                  String tarih = cols.length > 3 && cols[3].trim().isNotEmpty ? cols[3].trim() : anlikTarihSaatGetir(); 
                  
                  if(kartArama.isNotEmpty && aciklama.isNotEmpty) { 
                    Kart? hedefKart; 
                    for(var k in tumKartlarDeposu) { if (k.stokNo.toUpperCase() == kartArama || k.tip.toUpperCase() == kartArama) { hedefKart = k; break; } } 
                    if (hedefKart == null) { 
                      for(var m in tumMakinalar) { 
                        for(var k in m.bagliKartlar) { if (k.stokNo.toUpperCase() == kartArama || k.tip.toUpperCase() == kartArama) { hedefKart = k; break; } } 
                        if (hedefKart != null) { break; } 
                      } 
                    } 
                    if (hedefKart != null) { hedefKart.revizyonlar.add(Revizyon(tarihSaat: tarih, aciklama: aciklama, makinaAdi: makinaAdi)); e++; } 
                  } 
                } 
              } 
              setState(() { }); verileriKaydet(); 
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e revizyon ilgili kartlara işlendi!'), backgroundColor: Colors.green)); } 
            } catch (e) { 
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.'), backgroundColor: Colors.red)); } 
            } 
          } 
        }, child: const Text('Dosya Seç', style: TextStyle(color: Colors.white))) 
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; List<String> filtreSecenekleri = ['Tümü', 'Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; List<Map<String, dynamic>> butunRevizyonlar = []; Set<String> eklenenler = {}; 
    void revizyonTopla(List<Kart> kartlar) { for (var k in kartlar) { for (var r in k.revizyonlar) { String key = "${k.stokNo}_${r.tarihSaat}_${r.aciklama}"; if (!eklenenler.contains(key)) { eklenenler.add(key); butunRevizyonlar.add({'kart': k, 'revizyon': r}); } } } }
    revizyonTopla(tumKartlarDeposu); for (var m in tumMakinalar) { revizyonTopla(m.bagliKartlar); } butunRevizyonlar.sort((a, b) => tarihCozumle((b['revizyon'] as Revizyon).tarihSaat).compareTo(tarihCozumle((a['revizyon'] as Revizyon).tarihSaat)));
    List<Map<String, dynamic>> gosterilecekRevizyonlar = butunRevizyonlar.where((r) { if (seciliMakinaFiltresi == 'Tümü') return true; return (r['revizyon'] as Revizyon).makinaAdi == seciliMakinaFiltresi; }).toList();
    
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: kolarcAppBarBackground(), 
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(child: Text('Tüm Revizyon Geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (widget.isAdmin)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.upload_file, color: Colors.white), tooltip: 'Excel Yükle', onPressed: exceldenCSVYukle)
                    ],
                  ),
                ),
              )
          ]
        ),
        actions: const [SizedBox.shrink()],
      ),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0,2))]), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [const Icon(Icons.filter_list, color: kKolarcBlue), const SizedBox(width: 10), const Text('Makina Filtresi: ', style: TextStyle(fontWeight: FontWeight.bold)), DropdownButton<String>(value: filtreSecenekleri.contains(seciliMakinaFiltresi) ? seciliMakinaFiltresi : 'Tümü', underline: const SizedBox(), items: filtreSecenekleri.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(), onChanged: (String? val) { setState(() { seciliMakinaFiltresi = val!; }); }), ])),
          Expanded(child: gosterilecekRevizyonlar.isEmpty ? const Center(child: Text('Kayıt bulunamadı.')) : ListView.builder(padding: const EdgeInsets.all(8.0), itemCount: gosterilecekRevizyonlar.length, itemBuilder: (context, index) { final k = gosterilecekRevizyonlar[index]['kart'] as Kart; final r = gosterilecekRevizyonlar[index]['revizyon'] as Revizyon; return Card(elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.engineering, color: kKolarcBlue, size: 28)), title: Text(r.aciklama, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Kart: ${k.tip} (${k.stokNo})', style: TextStyle(color: isDark ? Colors.lightBlueAccent : kKolarcBlue, fontWeight: FontWeight.bold)), Text('Makina: ${r.makinaAdi}'), Text('Tarih: ${r.tarihSaat}', style: const TextStyle(fontSize: 12, color: Colors.grey))])), trailing: widget.isAdmin ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => revizyonPenceresiAc(k, r)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () { setState(() { k.revizyonlar.remove(r); }); verileriKaydet(); }), ])) : null, )); }, ), ),
        ],
      ),
    );
  }
}

class KartRevizyonSayfasi extends StatefulWidget {
  final Kart kart; final bool isAdmin;
  const KartRevizyonSayfasi({super.key, required this.kart, required this.isAdmin});
  @override
  State<KartRevizyonSayfasi> createState() => _KartRevizyonSayfasiState();
}
class _KartRevizyonSayfasiState extends State<KartRevizyonSayfasi> {
  String seciliMakinaFiltresi = 'Tümü';
  void revizyonPenceresiAc({Revizyon? varOlanRevizyon}) { 
    TextEditingController aciklamaKontrolcusu = TextEditingController(text: varOlanRevizyon?.aciklama ?? ''); 
    String seciliMakinaAdi = varOlanRevizyon?.makinaAdi ?? 'Genel'; 
    List<String> makinaSecenekleri = ['Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; 
    
    showDialog(context: context, builder: (context) { 
      return StatefulBuilder(builder: (context, setStateDialog) { 

        void kaydetTetikle() {
          if (aciklamaKontrolcusu.text.isNotEmpty) { 
            setState(() { 
              String formatliAciklama = cumleIlkHarfBuyut(aciklamaKontrolcusu.text);
              if (varOlanRevizyon == null) { widget.kart.revizyonlar.add(Revizyon(tarihSaat: anlikTarihSaatGetir(), aciklama: formatliAciklama, makinaAdi: seciliMakinaAdi)); } 
              else { varOlanRevizyon.aciklama = formatliAciklama; varOlanRevizyon.makinaAdi = seciliMakinaAdi; } 
            }); verileriKaydet(); Navigator.pop(context); 
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(varOlanRevizyon == null ? 'Yeni Revizyon Ekle' : 'Revizyonu Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('İşlem Yapılan Makina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(12)), child: DropdownButton<String>(isExpanded: true, underline: const SizedBox(), value: makinaSecenekleri.contains(seciliMakinaAdi) ? seciliMakinaAdi : 'Genel', items: makinaSecenekleri.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(), onChanged: (String? val) { setStateDialog(() { seciliMakinaAdi = val!; }); })), 
            const SizedBox(height: 15), 
            TextField(controller: aciklamaKontrolcusu, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.done, onSubmitted: (_) => kaydetTetikle(), decoration: const InputDecoration(hintText: 'Yapılan işlemi yazın...'), maxLines: 3), 
          ]), 
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet')) ]
        ); 
      }); 
    }); 
  }
  
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; List<String> filtreSecenekleri = ['Tümü', 'Genel', ...tumMakinalar.map((m) => '${m.ad} (${m.kod})')]; List<Revizyon> gosterilecekRevizyonlar = widget.kart.revizyonlar.where((r) { if (seciliMakinaFiltresi == 'Tümü') return true; return r.makinaAdi == seciliMakinaFiltresi; }).toList();
    return Scaffold(
      appBar: AppBar(flexibleSpace: kolarcAppBarBackground(), title: Text('${widget.kart.tip} Geçmişi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      floatingActionButton: widget.isAdmin ? FloatingActionButton.extended(onPressed: () => revizyonPenceresiAc(), backgroundColor: kKolarcBlue, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Revizyon Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: isDark ? Colors.grey[850] : Colors.grey[200], child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [const Icon(Icons.filter_list), const SizedBox(width: 10), const Text('Filtre: ', style: TextStyle(fontWeight: FontWeight.bold)), DropdownButton<String>(value: filtreSecenekleri.contains(seciliMakinaFiltresi) ? seciliMakinaFiltresi : 'Tümü', underline: const SizedBox(), items: filtreSecenekleri.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(), onChanged: (String? val) { setState(() { seciliMakinaFiltresi = val!; }); }), ])),
          Expanded(child: gosterilecekRevizyonlar.isEmpty ? const Center(child: Text('Kayıt bulunamadı.')) : ListView.builder(itemCount: gosterilecekRevizyonlar.length, reverse: true, itemBuilder: (context, index) { final rev = gosterilecekRevizyonlar[index]; return Card(margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kKolarcBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.engineering, color: kKolarcBlue, size: 28)), title: Text(rev.aciklama, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Makina: ${rev.makinaAdi}', style: TextStyle(color: isDark ? Colors.tealAccent : Colors.teal, fontWeight: FontWeight.w600)), Text('Tarih & Saat: ${rev.tarihSaat}', style: const TextStyle(color: Colors.grey))]), trailing: widget.isAdmin ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => revizyonPenceresiAc(varOlanRevizyon: rev)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () { setState(() { widget.kart.revizyonlar.remove(rev); }); verileriKaydet(); })])) : null, )); }), ),
        ],
      ),
    );
  }
}

// --- PCB DEPOSU SAYFASI ---
class PcbDeposuSayfasi extends StatefulWidget {
  final bool isAdmin;
  const PcbDeposuSayfasi({super.key, required this.isAdmin});
  @override
  State<PcbDeposuSayfasi> createState() => _PcbDeposuSayfasiState();
}

class _PcbDeposuSayfasiState extends State<PcbDeposuSayfasi> {
  TextEditingController aramaKontrolcusu = TextEditingController(); 
  List<PcbKart> ekrandakiPcbler = []; 
  bool secimModu = false; Set<PcbKart> secilenler = {};

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

  void tumunuSec() { setState(() { if (secilenler.length == ekrandakiPcbler.length) { secilenler.clear(); secimModu = false; } else { secilenler.addAll(ekrandakiPcbler); secimModu = true; } }); }

  void pcbPenceresiAc({PcbKart? varOlanPcb}) { 
    TextEditingController isimKontrolcusu = TextEditingController(text: varOlanPcb?.isim ?? ''); 
    TextEditingController koduKontrolcusu = TextEditingController(text: varOlanPcb?.stokNo ?? ''); 
    TextEditingController katmanKontrolcusu = TextEditingController(text: varOlanPcb?.katman ?? '2 Layer'); 
    TextEditingController kalinlikKontrolcusu = TextEditingController(text: varOlanPcb?.kalinlik ?? '1.6 mm'); 
    TextEditingController yuzeyKontrolcusu = TextEditingController(text: varOlanPcb?.yuzeyKaplama ?? 'HASL Kurşunsuz'); 
    TextEditingController maskeKontrolcusu = TextEditingController(text: varOlanPcb?.maskeRengi ?? 'Yeşil'); 

    void kaydetTetikle() {
      if (koduKontrolcusu.text.isNotEmpty && isimKontrolcusu.text.isNotEmpty) { 
        setState(() { 
          String formatliKod = koduKontrolcusu.text.trim().toUpperCase();
          String formatliIsim = kelimeIlkHarfleriBuyut(isimKontrolcusu.text);
          if (varOlanPcb == null) { 
            tumPcbDeposu.add(PcbKart(
              stokNo: formatliKod, isim: formatliIsim, 
              katman: katmanKontrolcusu.text.trim(), kalinlik: kalinlikKontrolcusu.text.trim(), 
              yuzeyKaplama: yuzeyKontrolcusu.text.trim(), maskeRengi: maskeKontrolcusu.text.trim(), 
              eklenmeTarihi: anlikTarihSaatGetir()
            )); 
          } else { 
            varOlanPcb.stokNo = formatliKod; varOlanPcb.isim = formatliIsim; 
            varOlanPcb.katman = katmanKontrolcusu.text.trim(); varOlanPcb.kalinlik = kalinlikKontrolcusu.text.trim();
            varOlanPcb.yuzeyKaplama = yuzeyKontrolcusu.text.trim(); varOlanPcb.maskeRengi = maskeKontrolcusu.text.trim();
          } 
          _filtreleriUygula(); 
        }); verileriKaydet(); Navigator.pop(context); 
      }
    }

    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
      title: Text(varOlanPcb == null ? 'Yeni PCB Kaydı' : 'PCB Düzenle', style: const TextStyle(fontWeight: FontWeight.bold)), 
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: koduKontrolcusu, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Stok Kodu', prefixIcon: Icon(Icons.qr_code))), const SizedBox(height: 10),
        TextField(controller: isimKontrolcusu, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'PCB İsmi / Proje Adı', prefixIcon: Icon(Icons.developer_board))), const SizedBox(height: 10), 
        Row(children: [
          Expanded(child: TextField(controller: katmanKontrolcusu, decoration: const InputDecoration(labelText: 'Katman (Layer)'))), const SizedBox(width: 10),
          Expanded(child: TextField(controller: kalinlikKontrolcusu, decoration: const InputDecoration(labelText: 'Kalınlık (mm)'))),
        ]), const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: yuzeyKontrolcusu, decoration: const InputDecoration(labelText: 'Yüzey Kaplama'))), const SizedBox(width: 10),
          Expanded(child: TextField(controller: maskeKontrolcusu, decoration: const InputDecoration(labelText: 'Maske Rengi'))),
        ]),
      ])), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: kaydetTetikle, child: const Text('Kaydet') ) ]
    )); 
  }

  void topluArsiveGonder() { setState(() { for(var pcb in secilenler) { tumPcbDeposu.remove(pcb); arsivlenmisPcbler.add(pcb); } secimModu=false; secilenler.clear(); _filtreleriUygula(); }); verileriKaydet(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilenler Arşive Taşındı.'), backgroundColor: Colors.orange)); }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: secimModu ? null : kolarcAppBarBackground(), backgroundColor: secimModu ? Colors.blueGrey[700] : null,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(secimModu ? '${secilenler.length} Seçildi' : 'PCB Deposu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (secimModu)
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: tumunuSec), 
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: topluArsiveGonder)
              ])))
          ]
        ),
        leading: secimModu ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: (){ setState((){secimModu=false; secilenler.clear();}); }) : null,
      ),
      floatingActionButton: (!secimModu && widget.isAdmin) ? FloatingActionButton.extended(onPressed: () => pcbPenceresiAc(), backgroundColor: kKolarcBlue, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12.0), child: TextField(controller: aramaKontrolcusu, onChanged: (v) => _filtreleriUygula(), decoration: const InputDecoration(labelText: 'PCB İsmi veya Kodu Ara...', prefixIcon: Icon(Icons.search, color: kKolarcBlue)))),
          Expanded(child: ekrandakiPcbler.isEmpty ? const Center(child: Text('Kriterlere uygun PCB bulunamadı.')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: ekrandakiPcbler.length, itemBuilder: (context, index) { 
            final pcb = ekrandakiPcbler[index]; bool seciliMi = secilenler.contains(pcb);
            return Card(color: seciliMi ? kKolarcBlue.withValues(alpha: 0.1) : null, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: ListTile(
              onLongPress: widget.isAdmin ? () { setState((){ secimModu = true; secilenler.add(pcb); }); } : null, 
              onTap: secimModu ? () { setState((){ if (seciliMi) { secilenler.remove(pcb); if(secilenler.isEmpty) { secimModu=false; } } else { secilenler.add(pcb); } }); } : null,
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.layers, color: Colors.teal, size: 28)), 
              title: Text('${pcb.isim} - ${pcb.stokNo}', style: const TextStyle(fontWeight: FontWeight.bold)), 
              subtitle: Text('Katman: ${pcb.katman} | Kalınlık: ${pcb.kalinlik}\nKaplama: ${pcb.yuzeyKaplama} | Maske: ${pcb.maskeRengi}\nEklenme: ${pcb.eklenmeTarihi}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 12)), 
              trailing: secimModu ? Checkbox(activeColor: kKolarcBlue, value: seciliMi, onChanged: (v){ setState((){ if (v!) { secilenler.add(pcb); } else { secilenler.remove(pcb); if(secilenler.isEmpty) { secimModu=false; } } }); }) : (widget.isAdmin ? IconButton(icon: const Icon(Icons.edit, color: kKolarcBlue), onPressed: () => pcbPenceresiAc(varOlanPcb: pcb)) : null), 
            )); 
          }))
        ],
      ),
    );
  }
}