import 'package:flutter/material.dart';
import 'dart:io';
import 'package:suitapps/features/customer/data/models/customer_model.dart';
import 'package:suitapps/features/customer/data/datasources/customer_local_datasource.dart'; // <-- points at lib/features/customer/CustomerService.dart

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  // â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const Color primaryColor = Color(0xFF1433C3);
  static const Color primarySoft = Color(0xFFEEF1FD);
  static const Color primaryMid = Color(0xFF6F7FDB);
  static const Color bgColor = Color(0xFFF5F7FB);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color successColor = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFF0FDF4);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color footerBg = Color(0xFFFAFBFF);

  static const double radiusCard = 16;
  static const double radiusBtn = 12;
  static const double radiusInput = 12;
  static const double radiusBadge = 16;

  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 12;
  static const double spacingLG = 16;
  static const double spacingXL = 24;
  static const double spacingXXL = 32;

  static const TextStyle pageTitleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static const TextStyle cardValueStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: primaryColor,
  );
  static const TextStyle labelStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 0.4,
  );
  static const TextStyle valueStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
  static const TextStyle custNameStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const TextStyle gstinStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static const TextStyle statLabelStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 0.4,
  );
  static const TextStyle statDeltaStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: successColor,
  );

  // â”€â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    // NOTE: method is getAllCustomers() on the new CustomerService,
    // not getCustomers() (that name only existed on the old/duplicate service).
    final data = await CustomerService().getAllCustomers();
    setState(() {
      _allCustomers = data;
      _filtered = data;
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allCustomers.where((c) {
        final matchQ =
            q.isEmpty ||
            c.customerName.toLowerCase().contains(q) ||
            c.mobile.toLowerCase().contains(q) ||
            c.city.toLowerCase().contains(q);
        return matchQ;
      }).toList();
    });
  }

  Future<void> _deleteCustomer(int id) async {
    await CustomerService().deleteCustomer(id);
    _loadCustomers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Customer deleted'),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusBtn),
        ),
      ),
    );
  }

  void _confirmDelete(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        title: const Text(
          'Delete Customer',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove ${customer.customerName}? This cannot be undone.',
          style: const TextStyle(fontFamily: 'Inter', color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusBtn),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCustomer(customer.id!);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _avatarBg(int index) {
    const colors = [primarySoft, Color(0xFFFFF7ED), successSoft, warningSoft];
    return colors[index % colors.length];
  }

  Color _avatarFg(int index) {
    const colors = [
      primaryColor,
      Color(0xFFD97706),
      successColor,
      warningColor,
    ];
    return colors[index % colors.length];
  }

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoader() : _buildBody(),
      floatingActionButton: null,
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    titleSpacing: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('Customers', style: pageTitleStyle),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: spacingSM),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingXS,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(radiusBadge),
        ),
        child: Text(
          '${_allCustomers.length}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.tune_rounded, size: 22),
        onPressed: () {},
      ),
      const SizedBox(width: spacingXS),
    ],
  );

  Widget _buildLoader() =>
      const Center(child: CircularProgressIndicator(color: primaryColor));

  Widget _buildBody() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _buildSearch()),
      SliverToBoxAdapter(child: _buildStatsRow()),
      if (_filtered.isEmpty)
        const SliverFillRemaining(child: Center(child: _EmptyState()))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            spacingLG,
            0,
            spacingLG,
            spacingXXL + 56,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: spacingMD - 2),
                child: _buildCustomerCard(_filtered[i], i),
              ),
              childCount: _filtered.length,
            ),
          ),
        ),
    ],
  );

  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(
      spacingLG,
      spacingMD,
      spacingLG,
      spacingXS,
    ),
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radiusInput),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: .06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: spacingMD),
          const Icon(Icons.search_rounded, color: textSecondary, size: 20),
          const SizedBox(width: spacingSM),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search by name, mobile, city...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: textSecondary,
              ),
              onPressed: () {
                _searchCtrl.clear();
                _applyFilter();
              },
            ),
        ],
      ),
    ),
  );

  Widget _buildStatsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(
      spacingLG,
      spacingMD,
      spacingLG,
      spacingXS,
    ),
    child: Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${_allCustomers.length}',
            label: 'TOTAL',
            delta: 'â†‘ 3 new',
            valueColor: primaryColor,
          ),
        ),
      ],
    ),
  );

  Widget _buildCustomerCard(CustomerModel customer, int index) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(customer, index),
          _buildCardBody(customer),
          _buildCardFooter(customer),
        ],
      ),
    );
  }

  Widget _buildCardHeader(CustomerModel customer, int index) => Container(
    padding: const EdgeInsets.all(spacingMD),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: borderColor)),
    ),
    child: Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: customer.imagePath.isNotEmpty
                ? Colors.transparent
                : _avatarBg(index),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: customer.imagePath.isNotEmpty
              ? Image.file(File(customer.imagePath), fit: BoxFit.cover)
              : Center(
                  child: Text(
                    _initials(customer.customerName),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _avatarFg(index),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.customerName,
                style: custNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 12,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customer.mobile,
                      style: subtitleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildCardBody(CustomerModel customer) => Padding(
    padding: const EdgeInsets.all(spacingMD),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoCell(label: 'CITY', value: customer.city),
            ),
            Expanded(
              child: _InfoCell(label: 'PLACE', value: customer.place),
            ),
          ],
        ),
        const SizedBox(height: spacingSM),
        Row(
          children: [
            Expanded(
              child: _InfoCell(label: 'RATE TYPE', value: customer.rateType),
            ),
            Expanded(
              child: _InfoCell(
                label: 'CREDIT DAYS',
                value: customer.creditDays,
              ),
            ),
            Expanded(
              child: _InfoCell(label: 'RATE TYPE', value: customer.rateType),
            ),
          ],
        ),
        const SizedBox(height: spacingSM),
        Row(
          children: [
            Expanded(
              child: _InfoCell(
                label: 'DISCOUNT',
                value: '${customer.discountPercentage}%',
              ),
            ),
            Expanded(
              child: _InfoCell(label: 'PIN CODE', value: customer.pinNo),
            ),
          ],
        ),
        if (customer.email.isNotEmpty) ...[
          const SizedBox(height: spacingSM),
          _InfoCell(label: 'EMAIL', value: customer.email, fullWidth: true),
        ],
        if (customer.address.isNotEmpty) ...[
          const SizedBox(height: spacingSM),
          _InfoCell(label: 'ADDRESS', value: customer.address, fullWidth: true),
        ],
        // Additional images
        if (customer.additionalImages.isNotEmpty) ...[
          const SizedBox(height: spacingMD),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Additional Images',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(height: spacingSM),
          Wrap(
            spacing: spacingSM,
            runSpacing: spacingSM,
            children: customer.additionalImages
                .map(
                  (path) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(path),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );

  Widget _buildCardFooter(CustomerModel customer) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: spacingMD,
      vertical: spacingSM + 2,
    ),
    decoration: const BoxDecoration(
      color: footerBg,
      border: Border(top: BorderSide(color: borderColor)),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(radiusCard),
        bottomRight: Radius.circular(radiusCard),
      ),
    ),
    child: Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GSTIN', style: labelStyle),
            const SizedBox(height: 2),
            Text(
              customer.gstinNo.isNotEmpty ? customer.gstinNo : 'â€”',
              style: gstinStyle,
            ),
          ],
        ),
        const Spacer(),
        // Edit button
        _ActionButton(
          icon: Icons.edit_outlined,
          bg: primarySoft,
          fg: primaryColor,
          onTap: () {
            /* Navigate to edit page */
          },
        ),
        const SizedBox(width: spacingSM),
        // Delete button
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          bg: errorSoft,
          fg: errorColor,
          onTap: () => _confirmDelete(customer),
        ),
      ],
    ),
  );

  Widget _buildFAB() => FloatingActionButton(
    onPressed: () {
      /* Navigate to add customer */
    },
    backgroundColor: primaryColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 6,
    child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
  );
}

// â”€â”€â”€ Sub-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatCard extends StatelessWidget {
  final String value, label, delta;
  final Color valueColor;
  final Color deltaColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.delta,
    required this.valueColor,
  }) : deltaColor = _CustomerListPageState.successColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _CustomerListPageState.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _CustomerListPageState.borderColor),
      boxShadow: [
        BoxShadow(
          color: _CustomerListPageState.primaryColor.withValues(alpha: .04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: _CustomerListPageState.cardValueStyle.copyWith(
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: _CustomerListPageState.statLabelStyle),
        const SizedBox(height: 2),
        Text(
          delta,
          style: _CustomerListPageState.statDeltaStyle.copyWith(
            color: deltaColor,
          ),
        ),
      ],
    ),
  );
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  final bool fullWidth;
  const _InfoCell({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _CustomerListPageState.labelStyle),
      const SizedBox(height: 2),
      Text(
        value.isNotEmpty ? value : 'â€”',
        style: _CustomerListPageState.valueStyle,
        maxLines: fullWidth ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: fg, size: 18),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _CustomerListPageState.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.people_outline_rounded,
          size: 36,
          color: _CustomerListPageState.primaryColor,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'No Customers Found',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _CustomerListPageState.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Try adjusting your search or filters',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: _CustomerListPageState.textSecondary,
        ),
      ),
    ],
  );
}
