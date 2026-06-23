import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../core/theme.dart';

// ── Malaysian states → cities map ──────────────────────────────────────────
const Map<String, List<String>> _malaysiaCities = {
  'Johor': [
    'Johor Bahru', 'Batu Pahat', 'Muar', 'Kluang', 'Pontian',
    'Segamat', 'Kulai', 'Kota Tinggi', 'Mersing', 'Tangkak',
  ],
  'Kedah': [
    'Alor Setar', 'Sungai Petani', 'Kulim', 'Langkawi', 'Jitra',
    'Baling', 'Pendang', 'Yan', 'Pokok Sena',
  ],
  'Kelantan': [
    'Kota Bharu', 'Pasir Mas', 'Tumpat', 'Bachok', 'Tanah Merah',
    'Machang', 'Kuala Krai', 'Gua Musang',
  ],
  'Melaka': [
    'Melaka City', 'Ayer Keroh', 'Alor Gajah', 'Jasin', 'Masjid Tanah',
  ],
  'Negeri Sembilan': [
    'Seremban', 'Port Dickson', 'Nilai', 'Bahau', 'Kuala Pilah',
    'Tampin', 'Rembau',
  ],
  'Pahang': [
    'Kuantan', 'Temerloh', 'Bentong', 'Raub', 'Pekan',
    'Cameron Highlands', 'Jerantut', 'Rompin',
  ],
  'Perak': [
    'Ipoh', 'Taiping', 'Teluk Intan', 'Sitiawan', 'Manjung',
    'Kampar', 'Batu Gajah', 'Lumut', 'Slim River',
  ],
  'Perlis': ['Kangar', 'Arau', 'Padang Besar'],
  'Pulau Pinang': [
    'George Town', 'Butterworth', 'Bukit Mertajam', 'Bayan Lepas',
    'Nibong Tebal', 'Balik Pulau',
  ],
  'Sabah': [
    'Kota Kinabalu', 'Sandakan', 'Tawau', 'Lahad Datu', 'Keningau',
    'Semporna', 'Beaufort', 'Papar', 'Ranau',
  ],
  'Sarawak': [
    'Kuching', 'Miri', 'Sibu', 'Bintulu', 'Limbang',
    'Sarikei', 'Sri Aman', 'Kapit',
  ],
  'Selangor': [
    'Shah Alam', 'Petaling Jaya', 'Subang Jaya', 'Klang', 'Ampang',
    'Kajang', 'Puchong', 'Rawang', 'Sepang', 'Cyberjaya',
  ],
  'Terengganu': [
    'Kuala Terengganu', 'Kemaman', 'Dungun', 'Besut', 'Marang',
    'Hulu Terengganu', 'Setiu',
  ],
  'W.P. Kuala Lumpur': [
    'Kuala Lumpur City', 'Cheras', 'Wangsa Maju', 'Kepong',
    'Setapak', 'Bukit Bintang', 'Bangsar',
  ],
  'W.P. Putrajaya': ['Putrajaya'],
  'W.P. Labuan': ['Labuan'],
};

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();

  bool _loading = false;
  bool _loadingServices = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _err;

  List<String> _availableServices = [];
  String? _serviceLoadError;
  final Set<String> _selectedServices = {};

  String? _selectedState;
  String? _selectedCity;

  // Live password validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _pass.addListener(_evaluatePassword);
  }

  @override
  void dispose() {
    _pass.removeListener(_evaluatePassword);
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    super.dispose();
  }

  void _evaluatePassword() {
    final p = _pass.text;
    setState(() {
      _hasMinLength = p.length >= 8;
      _hasUppercase = p.contains(RegExp(r'[A-Z]'));
      _hasLowercase = p.contains(RegExp(r'[a-z]'));
      _hasDigit = p.contains(RegExp(r'[0-9]'));
    });
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _serviceLoadError = null;
    });
    try {
      final names = await FirestoreService.instance.fetchServiceNames();
      if (mounted) {
        setState(() {
          _availableServices = names;
          _loadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serviceLoadError = 'Failed to load services: $e';
          _loadingServices = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      setState(() => _err = 'Please select at least one service type');
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final location = [_selectedCity, _selectedState]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');

      final phoneNumber = '+60${_phone.text.replaceAll('-', '').trim()}';

      // Auth user creation + Firestore profile write happen atomically
      // inside register() with router notifications suppressed, so the
      // MFA gate will never load before the phone number is persisted.
      await AuthService.instance.register(
        email: _email.text,
        password: _pass.text,
        fullName: _name.text.trim(),
        phoneNumber: phoneNumber,
        companyName: _company.text.trim().isEmpty
            ? 'Self-Employed'
            : _company.text.trim(),
        companyContactPhone: phoneNumber,
        location: location,
        serviceTypes: _selectedServices.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      context.go('/mfa', extra: phoneNumber);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _err = switch (e.code) {
          'email-already-in-use' => 'This email is already registered',
          'invalid-email' => 'Invalid email format',
          'weak-password' => 'Password is too weak',
          'operation-not-allowed' => 'Email/password accounts are not enabled',
          'network-request-failed' =>
            'Network error. Check your internet connection',
          _ => 'Registration failed: ${e.message ?? e.code}',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  InputDecoration _fieldDecor({
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kYellow, width: 1.5),
      ),
    );
  }

  // ── Section builders ─────────────────────────────────────────────────────

  Widget _buildServiceTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Service Types *'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: _loadingServices
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(
                        color: kYellow, strokeWidth: 2),
                  ),
                )
              : _serviceLoadError != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _serviceLoadError!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loadServices,
                          icon: const Icon(Icons.refresh,
                              size: 16, color: kYellow),
                          label: const Text('Retry',
                              style: TextStyle(color: kYellow)),
                        ),
                      ],
                    )
                  : _availableServices.isEmpty
                      ? const Text(
                          'No service types available. Contact admin.',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        )
                      : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableServices.map((service) {
                        final selected =
                            _selectedServices.contains(service);
                        return FilterChip(
                          label: Text(service),
                          selected: selected,
                          onSelected: (val) => setState(() {
                            if (val) {
                              _selectedServices.add(service);
                            } else {
                              _selectedServices.remove(service);
                            }
                          }),
                          selectedColor: kYellow.withValues(alpha: 0.2),
                          checkmarkColor: kYellow,
                          labelStyle: TextStyle(
                            color: selected ? kYellow : Colors.white70,
                            fontSize: 13,
                          ),
                          backgroundColor: kBg,
                          side: BorderSide(
                            color: selected ? kYellow : kBorder,
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReqLine(met: _hasMinLength, text: 'At least 8 characters'),
          _ReqLine(met: _hasUppercase, text: '1 uppercase letter (A-Z)'),
          _ReqLine(met: _hasLowercase, text: '1 lowercase letter (a-z)'),
          _ReqLine(met: _hasDigit, text: '1 number (0-9)'),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final states = _malaysiaCities.keys.toList();
    final cities = _selectedState != null
        ? (_malaysiaCities[_selectedState!] ?? [])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Location *'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedState,
          decoration: _fieldDecor(
            label: 'State',
            prefix: const Icon(Icons.map_outlined, size: 20),
          ),
          isExpanded: true,
          dropdownColor: kCard,
          items: states
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedState = v;
            _selectedCity = null;
          }),
          validator: (v) => v == null ? 'State is required' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: _fieldDecor(
            label: 'City / Town',
            prefix: const Icon(Icons.location_city_outlined, size: 20),
          ),
          isExpanded: true,
          dropdownColor: kCard,
          items: cities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCity = v),
          validator: (v) => v == null ? 'City is required' : null,
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final allMet = _hasMinLength && _hasUppercase && _hasLowercase && _hasDigit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as Contractor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
          tooltip: 'Back to Login',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Progress indicator ─────────────────────────────
                const _StepIndicator(),
                const SizedBox(height: 28),

                // ── Error banner ───────────────────────────────────
                if (_err != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.6),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_err!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // ── Personal Details ───────────────────────────────
                const _SectionLabel('Personal Details'),
                const SizedBox(height: 10),

                // Full Name
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecor(
                    label: 'Full Name *',
                    hint: 'Ahmad Bin Hassan',
                    prefix: const Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: _fieldDecor(
                    label: 'Email *',
                    hint: 'ahmad@example.com',
                    prefix: const Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!regex.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Number — +60 prefix + masked field
                const _SectionLabel('Phone Number *'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country code chip
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇲🇾', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 6),
                          Text(
                            '+60',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _PhoneMaskFormatter(),
                        ],
                        decoration: _fieldDecor(
                          label: 'Phone',
                          hint: '12-345-6789',
                        ),
                        validator: (v) {
                          final digits =
                              v?.replaceAll(RegExp(r'\D'), '') ?? '';
                          if (digits.isEmpty) return 'Phone is required';
                          if (digits.length < 9 || digits.length > 11) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Company Name
                TextFormField(
                  controller: _company,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecor(
                    label: 'Company Name (Optional)',
                    hint: 'Ahmad Towing Services',
                    prefix: const Icon(Icons.business_outlined, size: 20),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Location ───────────────────────────────────────
                _buildLocationSection(),

                const SizedBox(height: 24),

                // ── Services ───────────────────────────────────────
                _buildServiceTypesSection(),

                const SizedBox(height: 24),

                // ── Password ───────────────────────────────────────
                const _SectionLabel('Create Password'),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _pass,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecor(
                    label: 'Password *',
                    prefix: const Icon(Icons.lock_outline, size: 20),
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (!allMet) return 'Meet all requirements below';
                    return null;
                  },
                ),
                _buildPasswordRequirements(),

                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _passConfirm,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: _fieldDecor(
                    label: 'Confirm Password *',
                    prefix: const Icon(Icons.lock_outline, size: 20),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _pass.text) return 'Passwords do not match';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ── Create Account button ──────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kYellow,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: kYellow.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black54,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Login link ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(left: 4),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: kYellow,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white60,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ReqLine extends StatelessWidget {
  final bool met;
  final String text;
  const _ReqLine({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? kYellow : Colors.white30,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? kYellow : Colors.white30,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: kYellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: kYellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Phone mask formatter (XX-XXX-XXXX) ─────────────────────────────────────

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 2 || i == 5) buf.write('-');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
