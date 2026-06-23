import 'package:flutter/material.dart';

import '../../../services/firestore_service.dart';
import '../../../core/theme.dart';
import '../../widgets/app_loader.dart';

class ContractorProfileEditPage extends StatefulWidget {
  const ContractorProfileEditPage({super.key});

  @override
  State<ContractorProfileEditPage> createState() =>
      _ContractorProfileEditPageState();
}

class _ContractorProfileEditPageState
    extends State<ContractorProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();

  List<String> _availableServices = [];
  Set<String> _selectedServices = {};

  // Read-only identity display
  String _displayName = '';
  String _displayEmail = '';
  String _verificationStatus = '';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _companyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final id = await FirestoreService.instance.getMyContractorDocId();
      if (id != null) {
        final doc =
            await FirestoreService.instance.contractors.doc(id).get();
        final d = doc.data() ?? {};

        _displayName = (d['FullName'] ?? '').toString();
        _displayEmail = (d['Email'] ?? '').toString();
        _verificationStatus =
            (d['VerificationStatus'] ?? 'pending_upload').toString();
        _phoneCtrl.text = (d['PhoneNumber'] ?? '').toString();
        _companyCtrl.text = (d['CompanyName'] ?? '').toString();
        _companyPhoneCtrl.text =
            (d['CompanyContactPhone'] ?? '').toString();
        _selectedServices = Set.from(
          (d['ServiceTypes'] as List<dynamic>?)
                  ?.map((e) => e.toString()) ??
              [],
        );
      }

      final serviceNames =
          await FirestoreService.instance.fetchServiceNames();

      if (mounted) {
        setState(() {
          _availableServices = serviceNames;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service type'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateContractorProfile({
        'PhoneNumber': _phoneCtrl.text.trim(),
        'CompanyName': _companyCtrl.text.trim(),
        'CompanyContactPhone': _companyPhoneCtrl.text.trim(),
        'ServiceTypes': _selectedServices.toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : _buildForm(),
      bottomNavigationBar: _loading ? null : _buildSaveBar(),
    );
  }

  Widget _buildForm() {
    // Show union of available services + currently selected so nothing is lost
    // if the Services collection is missing some entries.
    final allOptions =
        {..._availableServices, ..._selectedServices}.toList()..sort();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Non-editable identity card
          _buildIdentityCard(),
          const SizedBox(height: 24),

          // ── Contact details ────────────────────────────────────────────
          _sectionLabel('Contact Details'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            hint: 'e.g. 012-3456789',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _companyCtrl,
            label: 'Company Name',
            hint: 'e.g. Ahmad Towing Services',
            icon: Icons.business,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _companyPhoneCtrl,
            label: 'Company Contact Phone',
            hint: 'e.g. 03-12345678 (optional)',
            icon: Icons.contact_phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),

          // ── Service types ──────────────────────────────────────────────
          _sectionLabel('Service Types Offered'),
          const SizedBox(height: 4),
          const Text(
            'Select all services you can provide',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          allOptions.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.white38, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No services found in Firestore Services collection.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allOptions.map((service) {
                      final selected = _selectedServices.contains(service);
                      return FilterChip(
                        label: Text(service),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedServices.add(service);
                            } else {
                              _selectedServices.remove(service);
                            }
                          });
                        },
                        selectedColor: kYellow.withOpacity(0.15),
                        checkmarkColor: kYellow,
                        labelStyle: TextStyle(
                          color: selected ? kYellow : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                        backgroundColor: kBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: selected ? kYellow : kBorder,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                      );
                    }).toList(),
                  ),
                ),

          const SizedBox(height: 100), // clearance for bottom bar
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    Color statusColor;
    IconData statusIcon;
    switch (_verificationStatus) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'under_review':
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_top;
        break;
      default: // pending_upload
        statusColor = Colors.orange;
        statusIcon = Icons.upload_file;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: kYellow.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: kYellow, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName.isNotEmpty ? _displayName : 'Contractor',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _displayEmail,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Name and email cannot be changed here',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  _readableStatus(_verificationStatus),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _readableStatus(String status) {
    switch (status) {
      case 'pending_upload':
        return 'Pending Upload';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kYellow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: Colors.black,
              disabledBackgroundColor: kYellow.withOpacity(0.35),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
