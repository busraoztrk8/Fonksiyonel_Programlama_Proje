// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için
import '../services/api_service.dart'; // API servisi
import 'login_screen.dart'; // Çıkış yapıldığında yönlendirmek için

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controller'lar
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();
  final TextEditingController _epostaController = TextEditingController();
  final TextEditingController _dogumTarihiController = TextEditingController();
  final TextEditingController _kullaniciAdiController = TextEditingController(); // Görüntüleme için
  final TextEditingController _yeniSifreController = TextEditingController();
  final TextEditingController _yeniSifreTekrarController = TextEditingController();

  bool _isLoading = true;
  String? _kayitTarihi;
  DateTime? _selectedDate;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;


  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _epostaController.dispose();
    _dogumTarihiController.dispose();
    _kullaniciAdiController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreTekrarController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final profileData = await _apiService.getProfile();
      if (mounted) {
        if (profileData.containsKey('error') && profileData['error']) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil yüklenemedi: ${profileData['message']}')),
          );
        } else {
          _adController.text = profileData['ad'] ?? '';
          _soyadController.text = profileData['soyad'] ?? '';
          _epostaController.text = profileData['eposta'] ?? '';
          _kullaniciAdiController.text = profileData['kullanici_adi'] ?? ''; // Kullanıcı adı değiştirilemez

          if (profileData['dogum_tarihi'] != null) {
            _selectedDate = DateTime.tryParse(profileData['dogum_tarihi']);
            _dogumTarihiController.text = _selectedDate != null
                ? DateFormat('dd.MM.yyyy', 'tr_TR').format(_selectedDate!)
                : '';
          } else {
            _dogumTarihiController.clear();
            _selectedDate = null;
          }

          if (profileData['kayit_tarihi'] != null) {
             DateTime? kt = DateTime.tryParse(profileData['kayit_tarihi']);
            _kayitTarihi = kt != null ? DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(kt.toLocal()) : 'Bilinmiyor';
          }
        }
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil bilgileri alınırken bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      Map<String, dynamic> updateData = {
        'ad': _adController.text.trim(),
        'soyad': _soyadController.text.trim(),
        'eposta': _epostaController.text.trim(),
        // Backend YYYY-MM-DD formatını bekliyor. _selectedDate null ise null gönder.
        'dogum_tarihi': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
      };

      if (_yeniSifreController.text.isNotEmpty) {
        updateData['yeni_sifre'] = _yeniSifreController.text;
      }

      try {
        final response = await _apiService.updateProfile(updateData);
        if (mounted) {
          if (response.containsKey('error') && response['error']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profil güncellenemedi: ${response['message']}')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil başarıyla güncellendi!')),
            );
            // Şifre alanlarını temizle
            _yeniSifreController.clear();
            _yeniSifreTekrarController.clear();
            // İsteğe bağlı: profili yeniden yükle
            // _loadProfileData();
          }
        }
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil güncellenirken bir hata oluştu: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dogumTarihiController.text = DateFormat('dd.MM.yyyy', 'tr_TR').format(picked);
      });
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

   void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  Future<void> _logout() async {
    await _apiService.clearUserId(); // Saklanan user_id'yi sil
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // Tüm önceki route'ları kaldır
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        controller: _kullaniciAdiController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                        readOnly: true, // Kullanıcı adı değiştirilemez
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adController,
                        decoration: const InputDecoration(
                          labelText: 'Ad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value!.trim().isEmpty ? 'Ad boş bırakılamaz' : null,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _soyadController,
                        decoration: const InputDecoration(
                          labelText: 'Soyad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value!.trim().isEmpty ? 'Soyad boş bırakılamaz' : null,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _epostaController,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value!.trim().isEmpty) return 'E-posta boş bırakılamaz';
                          if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(value)) {
                            return 'Geçerli bir e-posta girin';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dogumTarihiController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Doğum Tarihi',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                           suffixIcon: IconButton(
                             icon: const Icon(Icons.edit_calendar_outlined),
                             onPressed: () => _selectDate(context),
                           )
                        ),
                        onTap: () => _selectDate(context),
                        // Doğum tarihi zorunlu değilse validator kaldırılabilir.
                        // validator: (value) => value!.isEmpty ? 'Doğum tarihi seçin' : null,
                      ),
                      const SizedBox(height: 24),
                      const Text("Şifre Değiştir (İsteğe Bağlı)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const Divider(),
                       TextFormField(
                        controller: _yeniSifreController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                           suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length < 6) {
                            return 'Şifre en az 6 karakter olmalıdır';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _yeniSifreTekrarController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre (Tekrar)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: _toggleConfirmPasswordVisibility,
                          ),
                        ),
                        validator: (value) {
                          if (_yeniSifreController.text.isNotEmpty && value != _yeniSifreController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('BİLGİLERİ GÜNCELLE'),
                      ),
                      const SizedBox(height: 16),
                       if (_kayitTarihi != null)
                        Center(child: Text('Kayıt Tarihi: $_kayitTarihi', style: TextStyle(color: Colors.grey[600], fontSize: 12))),

                    ],
                  ),
                ),
              ),
            ),
    );
  }
}