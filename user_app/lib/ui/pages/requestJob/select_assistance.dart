import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_app/constants/colors.dart';
import 'battery_options.dart';
import 'fuel_options.dart';
import 'tyre_options.dart';
import 'other_assisstance.dart';
import 'package:user_app/ui/pages/map/select_car_location.dart';

// Material Icon glyph size for the legacy tiles. Icons fill their canvas
// almost edge-to-edge, so 42 px is what shows visually.
const double _kServiceIconSize = 42;

// Outer container size used by BOTH legacy Material Icons AND network images.
// Two reasons it's bigger than _kServiceIconSize:
//  1. Vertical alignment — the Column uses MainAxisAlignment.center, so any
//     difference in icon height between cards shifts the whole stack. Forcing
//     both code paths into the same box keeps icons/titles/subtitles aligned
//     across the row.
//  2. Optical size — uploaded PNGs have built-in transparent padding around
//     the artwork; with BoxFit.contain, the visible artwork is ~70 % of the
//     box. 72 / 0.7 ≈ 50 px of visible artwork, which roughly matches the
//     42 px Material Icons (which fill ~95 % of their 42 px canvas).
//  Tune this constant if the PNG you upload has more or less padding.
const double _kServiceIconBoxSize = 72;

class SelectAssistancePage extends StatefulWidget {
  const SelectAssistancePage({super.key});

  @override
  State<SelectAssistancePage> createState() => _SelectAssistancePageState();
}

class _SelectAssistancePageState extends State<SelectAssistancePage> {
  String? _selectedId;
  String? _selectedServiceName;
  double _selectedBasePrice = 0;

  void _continue(BuildContext context) {
    if (_selectedId == null) return;

    final serviceId = _selectedId!;
    final serviceName = _selectedServiceName ?? serviceId;
    final basePrice = _selectedBasePrice;

    switch (serviceId) {
      case 'battery-replacement':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BatteryOptionsPage(
              serviceName: serviceName,
              basePrice: basePrice,
            ),
          ),
        );
        break;

      case 'tyre-change':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TyreOptionsPage()),
        );
        break;

      case 'other-assistance':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OtherAssistancePage()),
        );
        break;

      case 'fuel-delivery':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FuelOptionsPage(serviceName: serviceName),
          ),
        );
        break;

      case 'towing':
      case 'car-locksmith-service':
      case 'minor-repair-service':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectCarLocationPage(
              serviceRequested: serviceName,
              totalAmount: basePrice,
            ),
          ),
        );
        break;

      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectCarLocationPage(
              serviceRequested: serviceName,
              totalAmount: basePrice,
            ),
          ),
        );
    }
  }

  /// Map a Firestore document ID to a Material icon.
  IconData _iconForService(String serviceId) {
    switch (serviceId) {
      case 'battery-replacement':
        return Icons.battery_charging_full;
      case 'tyre-change':
        return Icons.tire_repair;
      case 'fuel-delivery':
        return Icons.local_gas_station;
      case 'towing':
        return Icons.local_shipping;
      case 'car-locksmith-service':
        return Icons.lock;
      case 'minor-repair-service':
        return Icons.build;
      default:
        return Icons.miscellaneous_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Assistance Needed',
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: StreamBuilder<QuerySnapshot>(
          // Only surface services the Admin has marked Active. The field is
          // PascalCase 'Status' in Firestore (matches AdminPage/Services.aspx).
          // Sort is applied client-side by the 'Order' field below to avoid
          // a composite index requirement on (Status, Order).
          stream: FirebaseFirestore.instance
              .collection('Services')
              .where('Status', isEqualTo: 'Active')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kYellow),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No services available at the moment.\nPlease check back later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aData = a.data()! as Map<String, dynamic>;
                final bData = b.data()! as Map<String, dynamic>;
                final aOrder = (aData['Order'] ?? 999) as num;
                final bOrder = (bData['Order'] ?? 999) as num;
                return aOrder.compareTo(bOrder);
              });

            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data()! as Map<String, dynamic>;
                final serviceName =
                    data['ServiceName'] as String? ?? doc.id;
                final description =
                    data['Description'] as String? ?? '';
                final iconUrl =
                    (data['iconUrl'] as String?)?.trim() ?? '';

                return _option(
                  doc: doc,
                  fallbackIcon: _iconForService(doc.id),
                  iconUrl: iconUrl,
                  title: serviceName,
                  subtitle: description,
                );
              },
            );
          },
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedId == null
                  ? kYellow.withValues(alpha: 0.25)
                  : kYellow,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.black,
              disabledBackgroundColor: kYellow.withValues(alpha: 0.25),
              elevation: _selectedId == null ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed:
                _selectedId == null ? null : () => _continue(context),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _option({
    required DocumentSnapshot doc,
    required IconData fallbackIcon,
    required String iconUrl,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedId == doc.id;

    return InkWell(
      onTap: () {
        final docData = doc.data() as Map<String, dynamic>?;
        setState(() {
          _selectedId = doc.id;
          _selectedServiceName =
              docData?['ServiceName'] as String? ?? doc.id;
          _selectedBasePrice =
              double.tryParse((docData?['BasePrice'] ?? '').toString()) ??
                  0.0;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kYellow : Colors.grey.shade800,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kYellow.withValues(alpha: 0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ServiceIcon(iconUrl: iconUrl, fallback: fallbackIcon),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed-size service icon. Renders the network image when [iconUrl] is
/// non-empty, otherwise (and on load/error) shows [fallback] in the brand
/// yellow. Both code paths render inside the same [_kServiceIconBoxSize]
/// container so the grid stays vertically aligned regardless of which
/// services have iconUrls set.
class _ServiceIcon extends StatelessWidget {
  final String iconUrl;
  final IconData fallback;

  const _ServiceIcon({required this.iconUrl, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final fallbackIcon =
        Icon(fallback, size: _kServiceIconSize, color: kYellow);

    final Widget child = iconUrl.isEmpty
        ? Center(child: fallbackIcon)
        : CachedNetworkImage(
            imageUrl: iconUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => Center(
              child: Icon(
                fallback,
                size: _kServiceIconSize,
                color: kYellow.withValues(alpha: 0.4),
              ),
            ),
            errorWidget: (_, __, ___) => Center(child: fallbackIcon),
          );

    return SizedBox(
      width: _kServiceIconBoxSize,
      height: _kServiceIconBoxSize,
      child: child,
    );
  }
}
