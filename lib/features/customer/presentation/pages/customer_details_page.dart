import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _T {
  // Colors
  static const primaryBlue    = Color.fromARGB(255, 35, 0, 196);
  static const secondaryBlue  = Color(0xFF6F7FDB);
  static const background     = Color(0xFFF5F7FB);
  static const cardBg         = Color(0xFFFFFFFF);
  static const textPrimary    = Color(0xFF111827);
  static const textSecondary  = Color(0xFF6B7280);
  static const border         = Color(0xFFE5E7EB);
  static const success        = Color(0xFF16A34A);
  static const warning        = Color(0xFFF59E0B);
  static const error          = Color(0xFFDC2626);

  // Spacing
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const xxl = 32.0;

  // Radius
  static const rCard    = 16.0;
  static const rButton  = 12.0;
  static const rBadge   = 16.0;

  // Shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Typography (Inter)
  static const String font = 'Inter';

  static const pageTitle    = TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w700, color: cardBg);
  static const sectionTitle = TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary);
  static const cardValue    = TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary);
  static const cardTitle    = TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.4);
  static const buttonText   = TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600);
  static const inputText    = TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary);
  static const smallText    = TextStyle(fontFamily: font, fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary);
  static const caption      = TextStyle(fontFamily: font, fontSize: 10, fontWeight: FontWeight.w400, color: textSecondary);
}

// â”€â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class CustomerDetailsPage extends StatelessWidget {
  final Map<String, dynamic> customer;

  const CustomerDetailsPage({super.key, required this.customer});

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _str(String key) => customer[key]?.toString() ?? '';

  Future<void> _callCustomer() async {
    final mobile = _str('Mob');
    if (mobile.isEmpty) return;
    await launchUrl(Uri.parse('tel:$mobile'));
  }

  Future<void> _openMap() async {
    final lat = _str('Latitude');
    final lng = _str('Longitude');
    if (lat.isEmpty || lng.isEmpty) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  String get _initials {
    final name = _str('AccountName');
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // â”€â”€ Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _heroCard() {
    return Container(
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(_T.rCard),
        boxShadow: _T.cardShadow,
      ),
      padding: const EdgeInsets.all(_T.xl),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_T.primaryBlue, _T.secondaryBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_T.rCard),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                fontFamily: _T.font,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: _T.lg),

          // Name + code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _str('AccountName'),
                  style: _T.cardValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _T.xs),
                _badge(
                  label: _str('AccountCode'),
                  color: _T.primaryBlue.withValues(alpha: 0.08),
                  textColor: _T.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({required String label, required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _T.sm, vertical: _T.xs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_T.rBadge),
      ),
      child: Text(
        label.isEmpty ? 'â€”' : label,
        style: _T.smallText.copyWith(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionRow() {
    return Row(
      children: [
        Expanded(child: _ghostButton(
          icon: Icons.call_rounded,
          label: 'Call',
          onTap: _callCustomer,
          color: _T.primaryBlue,
        )),
        const SizedBox(width: _T.md),
        Expanded(child: _ghostButton(
          icon: Icons.open_in_new_rounded,
          label: 'Open in Maps',
          onTap: _openMap,
          color: _T.success,
        )),
      ],
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(_T.rButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_T.rButton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: _T.sm),
              Text(
                label,
                style: _T.buttonText.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required List<_InfoRow> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(_T.rCard),
        boxShadow: _T.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_T.lg, _T.lg, _T.lg, _T.md),
            child: Text(title, style: _T.sectionTitle),
          ),
          const Divider(height: 1, thickness: 1, color: _T.border),
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return _rowTile(row: e.value, showDivider: !isLast);
          }),
        ],
      ),
    );
  }

  Widget _rowTile({required _InfoRow row, required bool showDivider}) {
    final value = row.value.isEmpty ? 'â€”' : row.value;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _T.lg, vertical: _T.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _T.background,
                  borderRadius: BorderRadius.circular(_T.sm),
                ),
                alignment: Alignment.center,
                child: Icon(row.icon, size: 18, color: _T.secondaryBlue),
              ),
              const SizedBox(width: _T.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label.toUpperCase(), style: _T.cardTitle),
                    const SizedBox(height: _T.xs),
                    Text(value, style: _T.inputText),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: _T.border,
            indent: _T.lg + 36 + _T.md,
          ),
      ],
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.background,

      appBar: AppBar(
        backgroundColor: _T.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text('Customer Details', style: _T.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 24),
            onPressed: () {},
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(_T.lg),
        children: [
          _heroCard(),
          const SizedBox(height: _T.lg),

          _actionRow(),
          const SizedBox(height: _T.lg),

          _infoCard(
            title: 'Contact Info',
            rows: [
              _InfoRow(Icons.phone_rounded, 'Mobile', _str('Mob')),
              _InfoRow(Icons.place_rounded, 'Place', _str('Place')),
              _InfoRow(Icons.location_city_rounded, 'City', _str('City')),
              _InfoRow(Icons.flag_rounded, 'Country', _str('Country')),
            ],
          ),
          const SizedBox(height: _T.sm),

          _infoCard(
            title: 'Business Info',
            rows: [
              _InfoRow(Icons.local_offer_rounded, 'Rate Type', _str('RateType')),
              _InfoRow(Icons.receipt_long_rounded, 'GSTIN', _str('GSTinNo')),
              _InfoRow(Icons.home_rounded, 'Address', _str('Address')),
            ],
          ),
          const SizedBox(height: _T.xxl),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}
