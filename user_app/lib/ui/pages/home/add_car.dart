import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:user_app/constants/colors.dart';
import 'package:user_app/services/user_firestore_service.dart';

const Color _kBg = Color(0xFF121212);
const Color _kSurface = Color(0xFF1E1E1E);

/// Which kind of catalog request the user is making.
enum _RequestKind { newBrand, newModel }

/// Add or edit a vehicle.
///
/// When [vehicleId] is null this page creates a new document in
/// `Users/{uid}/Vehicles`. When it is set, the page updates the
/// existing document and pre-fills the form with the current values.
class RideDetailsPage extends StatefulWidget {
  final String? vehicleId;
  final String? initialBrand;
  final String? initialModel;
  final String? initialYear;
  final String? initialPlate;

  const RideDetailsPage({
    super.key,
    this.vehicleId,
    this.initialBrand,
    this.initialModel,
    this.initialYear,
    this.initialPlate,
  });

  bool get isEditing => vehicleId != null;

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();

  List<CarBrand> _brands = [];
  CarBrand? _selectedBrand;
  String? _selectedModel;
  String? _selectedYear;

  bool _loadingBrands = true;
  bool _saving = false;

  final List<String> _years = [
    for (int y = DateTime.now().year; y >= 2000; y--) '$y'
  ];

  @override
  void initState() {
    super.initState();
    _brandController.text = widget.initialBrand ?? '';
    _modelController.text = widget.initialModel ?? '';
    _selectedYear = widget.initialYear;
    _plateController.text = widget.initialPlate ?? '';
    _brandController.addListener(_onTextChanged);
    _modelController.addListener(_onTextChanged);
    _loadBrands();
  }

  @override
  void dispose() {
    _brandController.removeListener(_onTextChanged);
    _modelController.removeListener(_onTextChanged);
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _brandFocus.dispose();
    _modelFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await UserFirestoreService.instance.fetchCarBrands();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loadingBrands = false;
        // Re-attach the selected brand if we're editing.
        final initial = widget.initialBrand;
        if (initial != null) {
          for (final b in brands) {
            if (b.name.toLowerCase() == initial.toLowerCase()) {
              _selectedBrand = b;
              _brandController.text = b.name;
              // If the saved model is in the brand's catalog, snap to it.
              final m = widget.initialModel;
              if (m != null && b.models.contains(m)) {
                _selectedModel = m;
                _modelController.text = m;
              }
              break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBrands = false);
      _snack('Could not load car brands: $e', Colors.redAccent);
    }
  }

  // ---------------------------------------------------------------------------
  // Contextual "Can't find?" detection
  // ---------------------------------------------------------------------------

  bool get _hasZeroBrandMatches {
    final query = _brandController.text.trim().toLowerCase();
    if (query.isEmpty || _loadingBrands) return false;
    if (_selectedBrand != null) return false;
    return !_brands.any((b) => b.name.toLowerCase().contains(query));
  }

  bool get _hasZeroModelMatches {
    if (_selectedBrand == null) return false;
    final query = _modelController.text.trim().toLowerCase();
    if (query.isEmpty) return false;
    if (_selectedModel != null) return false;
    return !_selectedBrand!.models
        .any((m) => m.toLowerCase().contains(query));
  }

  /// Returns the active "not found" context, or null when both fields
  /// either match the catalog or are still empty.
  _RequestKind? get _notFoundContext {
    if (_hasZeroBrandMatches) return _RequestKind.newBrand;
    if (_hasZeroModelMatches) return _RequestKind.newModel;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // ----- Top: scrollable form section -----
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'lib/images/Logo_2.png',
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        widget.isEditing
                            ? 'EDIT YOUR RIDE'
                            : "WHAT'S YOUR RIDE?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _brandField(),
                      _modelField(),
                      _dropdown(
                        icon: Icons.calendar_today,
                        hint: 'YEAR MADE',
                        value: _selectedYear,
                        items: _years,
                        onChanged: (v) => setState(() => _selectedYear = v),
                      ),
                      _textField(
                        icon: Icons.format_list_bulleted,
                        label: 'PLATE NUMBER',
                        controller: _plateController,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ----- Bottom: pinned not-found card + DONE button -----
              _notFoundCard(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saving ? null : _onSave,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          widget.isEditing ? 'UPDATE' : 'DONE',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pinned "Can't find?" card — switches between Brand and Model context
  // ---------------------------------------------------------------------------

  Widget _notFoundCard() {
    final ctx = _notFoundContext;
    if (ctx == null) return const SizedBox.shrink();

    final String title;
    final VoidCallback onTap;

    if (ctx == _RequestKind.newBrand) {
      final typed = _brandController.text.trim();
      title = 'Can\'t find Brand "$typed"?';
      onTap = () => _openRequestSheet(_RequestKind.newBrand);
    } else {
      title = 'Can\'t find your Model for ${_selectedBrand!.name}?';
      onTap = () => _openRequestSheet(_RequestKind.newModel);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kYellow.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.add_circle_outline, color: kYellow),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Click here to request it.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Brand search field — typed input + dropdown overlay of matches
  // ---------------------------------------------------------------------------

  Widget _brandField() {
    return _autocompleteShell(
      controller: _brandController,
      focusNode: _brandFocus,
      hint: 'CAR BRAND',
      icon: Icons.directions_car,
      loading: _loadingBrands,
      optionsBuilder: (value) {
        if (_loadingBrands) return const Iterable<String>.empty();
        final query = value.text.trim().toLowerCase();
        final names = _brands.map((b) => b.name);
        if (query.isEmpty) return names;
        return names.where((n) => n.toLowerCase().contains(query));
      },
      onSelected: (name) {
        final brand = _brands.firstWhere((b) => b.name == name);
        setState(() {
          _selectedBrand = brand;
          if (_selectedModel != null && !brand.models.contains(_selectedModel)) {
            _selectedModel = null;
            _modelController.clear();
          }
        });
        _brandFocus.unfocus();
      },
      onTextChanged: (text) {
        // Drop the cached selection if the user retypes the brand.
        if (_selectedBrand != null &&
            text.toLowerCase() != _selectedBrand!.name.toLowerCase()) {
          setState(() {
            _selectedBrand = null;
            _selectedModel = null;
            _modelController.clear();
          });
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Model search field — items come from the selected brand's CarTypes array
  // ---------------------------------------------------------------------------

  Widget _modelField() {
    final brand = _selectedBrand;
    final enabled = brand != null;

    return _autocompleteShell(
      controller: _modelController,
      focusNode: _modelFocus,
      hint: enabled ? 'CAR MODEL' : 'SELECT BRAND FIRST',
      icon: Icons.public,
      enabled: enabled,
      optionsBuilder: (value) {
        if (!enabled) return const Iterable<String>.empty();
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return brand.models;
        return brand.models.where((m) => m.toLowerCase().contains(query));
      },
      onSelected: (model) {
        setState(() => _selectedModel = model);
        _modelFocus.unfocus();
      },
      onTextChanged: (text) {
        if (_selectedModel != null &&
            text.toLowerCase() != _selectedModel!.toLowerCase()) {
          setState(() => _selectedModel = null);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Generic autocomplete chrome shared by Brand and Model
  // ---------------------------------------------------------------------------

  Widget _autocompleteShell({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required Iterable<String> Function(TextEditingValue) optionsBuilder,
    required ValueChanged<String> onSelected,
    required ValueChanged<String> onTextChanged,
    bool enabled = true,
    bool loading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      child: RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: optionsBuilder,
        onSelected: onSelected,
        fieldViewBuilder: (context, ctl, fn, onSubmit) {
          return TextField(
            controller: ctl,
            focusNode: fn,
            enabled: enabled,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            onChanged: onTextChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white, size: 18),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.search,
                      color: enabled ? Colors.white70 : Colors.white24,
                      size: 18,
                    ),
              hintText: hint,
              hintStyle: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
              ),
              border: InputBorder.none,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: _kSurface,
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 220, maxWidth: 360),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final opt = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(
                        opt,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => onSelected(opt),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Static form widgets (year dropdown, plate text)
  // ---------------------------------------------------------------------------

  Widget _dropdown({
    required IconData icon,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      child: DropdownButtonFormField<String>(
        dropdownColor: _kSurface,
        initialValue: safeValue,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(color: Colors.white),
        hint: Text(hint, style: const TextStyle(color: Colors.white)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white, size: 18),
          border: InputBorder.none,
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _textField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white, size: 18),
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit flow
  // ---------------------------------------------------------------------------

  Future<void> _onSave() async {
    final typedBrand = _brandController.text.trim();
    final plate = _plateController.text.trim();

    if (typedBrand.isEmpty || _selectedYear == null || plate.isEmpty) {
      _snack('Please complete all fields', Colors.redAccent);
      return;
    }

    if (_selectedBrand == null) {
      _snack(
        'That brand isn\'t in our list — tap "Click here to request it" to continue.',
        Colors.redAccent,
      );
      return;
    }

    if (_selectedModel == null) {
      // The user typed a model that isn't in the catalog — nudge to the card.
      if (_modelController.text.trim().isNotEmpty) {
        _snack(
          'That model isn\'t in our list — tap "Click here to request it" to continue.',
          Colors.redAccent,
        );
      } else {
        _snack('Please choose a car model', Colors.redAccent);
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final svc = UserFirestoreService.instance;
      final customId = await svc.getCustomUserId();
      if (customId.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        _snack('No linked profile found.', Colors.redAccent);
        return;
      }

      if (widget.isEditing) {
        await svc.updateVehicle(
          vehicleId: widget.vehicleId!,
          ownerID: customId,
          make: _selectedBrand!.name,
          model: _selectedModel!,
          year: _selectedYear!,
          numberPlate: plate,
        );
      } else {
        await svc.addVehicle(
          ownerID: customId,
          make: _selectedBrand!.name,
          model: _selectedModel!,
          year: _selectedYear!,
          numberPlate: plate,
        );
      }

      if (!mounted) return;
      _snack(
        widget.isEditing
            ? 'Vehicle updated successfully'
            : 'Vehicle added successfully',
        Colors.green,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Error: $e', Colors.redAccent);
    }
  }

  // ---------------------------------------------------------------------------
  // "Request New" bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _openRequestSheet(_RequestKind kind) async {
    if (_selectedYear == null || _plateController.text.trim().isEmpty) {
      _snack('Please fill in Year and Plate Number first', Colors.redAccent);
      return;
    }

    final brandForSheet = kind == _RequestKind.newBrand
        ? _brandController.text.trim()
        : _selectedBrand!.name;

    final modelForSheet = kind == _RequestKind.newModel
        ? _modelController.text.trim()
        : '';

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RequestNewSheet(
        kind: kind,
        brandName: brandForSheet,
        prefilledModel: modelForSheet,
        year: _selectedYear!,
        plate: _plateController.text.trim(),
      ),
    );

    if (submitted == true && mounted) {
      _snack(
        'Request submitted! Your vehicle is added as Undefined.',
        Colors.green,
      );
      Navigator.pop(context);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// =============================================================================
// Request New (Brand or Model) bottom sheet
// =============================================================================

class _RequestNewSheet extends StatefulWidget {
  final _RequestKind kind;
  final String brandName;
  final String prefilledModel;
  final String year;
  final String plate;

  const _RequestNewSheet({
    required this.kind,
    required this.brandName,
    required this.prefilledModel,
    required this.year,
    required this.plate,
  });

  @override
  State<_RequestNewSheet> createState() => _RequestNewSheetState();
}

class _RequestNewSheetState extends State<_RequestNewSheet> {
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  XFile? _picked;
  bool _submitting = false;

  bool get _isNewModel => widget.kind == _RequestKind.newModel;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController(text: widget.brandName);
    _modelCtrl = TextEditingController(text: widget.prefilledModel);
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  /// Show a small modal asking whether to launch the camera or the gallery.
  /// Returns null if the user dismisses without picking a source.
  Future<void> _onUploadPhotoTap() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: kYellow),
              title: const Text(
                'Take Photo with Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kYellow),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      // pickImage returns null when the user backs out of the camera or
      // gallery without selecting anything — leave existing state untouched.
      if (file != null && mounted) setState(() => _picked = file);
    } catch (e) {
      if (!mounted) return;
      _sheetSnack('Could not get image: $e');
    }
  }

  Future<void> _submit() async {
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();

    if (brand.isEmpty) {
      _sheetSnack('Brand is required');
      return;
    }
    if (model.isEmpty) {
      _sheetSnack('Manual model name is required');
      return;
    }

    setState(() => _submitting = true);
    try {
      final svc = UserFirestoreService.instance;
      final ownerID = await svc.getCustomUserId();
      if (ownerID.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _sheetSnack('No linked profile found.');
        return;
      }

      // 1. Upload the photo (if any) first so the URL can be embedded
      //    in the VehicleRequests doc on creation.
      String? imageUrl;
      if (_picked != null) {
        imageUrl = await svc.uploadVehicleRequestImage(
          file: File(_picked!.path),
        );
      }

      // 2. Create the VehicleRequests document an admin will review.
      final requestType = _isNewModel ? 'New Model' : 'New Brand';
      final requestId = await svc.createVehicleRequest(
        brandName: brand,
        modelName: model,
        requestType: requestType,
        imageUrl: imageUrl,
      );

      // 3. Add a temporary vehicle to the user's list with brand=Undefined
      //    so they can keep using the app immediately. Year, plate and the
      //    typed model are preserved.
      await svc.addUndefinedVehicle(
        ownerID: ownerID,
        manualBrand: brand,
        manualModel: model,
        year: widget.year,
        numberPlate: widget.plate,
        supportTicketId: requestId,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _sheetSnack('Could not submit request: $e');
    }
  }

  void _sheetSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = _isNewModel
        ? 'Add New Model to ${widget.brandName}'
        : 'Request New Brand: ${widget.brandName}';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Brand: editable for New Brand, locked for New Model.
          _sheetField(
            controller: _brandCtrl,
            icon: Icons.directions_car,
            label: 'BRAND NAME',
            capitalization: TextCapitalization.words,
            readOnly: _isNewModel,
          ),

          _sheetField(
            controller: _modelCtrl,
            icon: Icons.public,
            label: 'MANUAL MODEL NAME',
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _submitting ? null : _onUploadPhotoTap,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(
              _picked == null
                  ? 'UPLOAD PHOTO'
                  : 'Photo selected (tap to change)',
            ),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_picked!.path),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _submitting
                          ? null
                          : () => setState(() => _picked = null),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                          semanticLabel: 'Remove photo',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'SUBMIT REQUEST',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextCapitalization capitalization = TextCapitalization.none,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        textCapitalization: capitalization,
        cursorColor: Colors.white,
        style: TextStyle(
          color: readOnly ? Colors.white70 : Colors.white,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: readOnly ? Colors.white54 : Colors.white,
            size: 18,
          ),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline,
                  color: Colors.white38, size: 16)
              : null,
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
