import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/customer/data/datasources/customer_cache_datasource.dart';
import 'package:suitapps/features/customer/data/datasources/route_sync_datasource.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:suitapps/features/auth/data/repositories/auth_session_repository.dart';
import 'package:suitapps/features/customer/data/datasources/customer_api_datasource.dart';
import 'package:suitapps/features/customer/presentation/pages/customer_details_page.dart';
import 'package:suitapps/features/customer/presentation/pages/customers_page.dart';

// â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _T {
  // Header gradient (matches the mockup's deep blue app bar)
  static const primaryBlue = Color(0xFF1D3FD6);
  static const primaryBlueDark = Color(0xFF15207A);
  static const secondaryBlue = Color(0xFF6F7FDB);
  static const background = Color(0xFFF5F7FB);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);

  // Spacing tightened globally so more rows fit per screen.
  static const xs = 3.0;
  static const sm = 6.0;
  static const md = 9.0;
  static const lg = 12.0;
  static const xl = 18.0;
  static const xxl = 24.0;

  static const rCard = 14.0;
  static const rButton = 10.0;
  static const rBadge = 16.0;

  // Cycling accent palette used for the route timeline dots / avatars,
  // mirroring the multi-colour route line in the mockup.
  static const List<Color> accents = [
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // purple
    Color(0xFF16A34A), // green
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
  ];

  static Color accentFor(int index) => accents[index % accents.length];

  static List<BoxShadow> get shadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static const String font = 'Inter';

  static const pageTitle = TextStyle(
    fontFamily: font,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: cardBg,
  );
  static const pageSubtitle = TextStyle(
    fontFamily: font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: Color(0xFFDCE3FF),
  );
  static const sectionTitle = TextStyle(
    fontFamily: font,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );
  // Card value (customer name) shrunk so each row takes less vertical space.
  static const cardValue = TextStyle(
    fontFamily: font,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: textPrimary,
  );
  static const cardTitle = TextStyle(
    fontFamily: font,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 0.3,
  );
  static const buttonText = TextStyle(
    fontFamily: font,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const inputText = TextStyle(
    fontFamily: font,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const smallText = TextStyle(
    fontFamily: font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
  static const caption = TextStyle(
    fontFamily: font,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
}

// Which segment of the All / Nearby / Favorites control is active.
enum _CustomerTab { all, nearby, favorites }

// â”€â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class ExistingCustomersPage extends StatefulWidget {
  const ExistingCustomersPage({super.key});

  @override
  State<ExistingCustomersPage> createState() => _ExistingCustomersPageState();
}

class _ExistingCustomersPageState extends State<ExistingCustomersPage> {
  final CustomerApiService _service = CustomerApiService();
  final CustomerLocalDbService _localDb = CustomerLocalDbService();
  final RouteSyncService _routeSync = RouteSyncService();

  // Route id that was allocated to the user for today (set at login).
  // Used to pin that route to the top of the route list below.
  String? _todayRouteId;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  List<Map<String, dynamic>> _sortedByDistanceCustomers = [];
  bool _loading = true;
  String? _error;
  late TextEditingController _searchController;

  // True while what's on screen came from the local cache and hasn't been
  // confirmed fresh by the API yet.
  bool _isShowingCachedData = false;

  Position? _userLocation;
  bool _gettingLocation = false;
  bool _showByDistance = false;

  // All / Nearby / Favorites segmented control.
  _CustomerTab _activeTab = _CustomerTab.all;

  // â”€â”€ Root dropdown state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Map<String, dynamic>> _roots = [];
  String? _selectedRootId;
  String? _selectedRootName;
  bool _loadingRoots = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_applyFilter);
    _initialLoad();
  }

  /// Loads roots first (which also syncs and preselects today's allocated
  /// route), and only then loads customers - so customers load for TODAY'S
  /// route instead of racing against it and loading the previously saved
  /// route instead.
  Future<void> _initialLoad() async {
    await _loadRoots();
    await _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // â”€â”€ Load Roots (for dropdown) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadRoots() async {
    setState(() => _loadingRoots = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final empId =
          (prefs.getInt('UserId') ?? prefs.getString('UserId'))
              ?.toString() ??
          '';

      debugPrint('LOGIN EMP ID = $empId');

      if (empId.isEmpty) {
        debugPrint('UserID not found');
        return;
      }

      // Sync "today's allocated route" for this employee right here, so the
      // route list below can be reordered/marked without needing any change
      // on the login page.
      final empIdInt = int.tryParse(empId);
      if (empIdInt != null) {
        final syncResult = await _routeSync.fetchAndSaveTodayRoute(empIdInt);
        debugPrint('TODAY ROUTE SYNC RESULT = $syncResult');
      } else {
        debugPrint(
          'TODAY ROUTE SYNC skipped: empId "$empId" is not a valid int',
        );
      }

      var roots = await _service.fetchRoots(empId: empId);

      debugPrint('ROOT COUNT = ${roots.length}');
      debugPrint('ROOT DATA = $roots');

      // Today's allocated route (just synced above) always goes first in the
      // list, so the user sees it without having to scroll/search for it.
      final todayRouteInfo = await _routeSync.getTodayRouteSyncInfo();
      final todayRouteId = todayRouteInfo?['routeId']?.toString();

      if (todayRouteId != null) {
        final index = roots.indexWhere(
          (r) => r['RootID'].toString() == todayRouteId,
        );
        if (index > 0) {
          final todayRoot = roots.removeAt(index);
          roots = [todayRoot, ...roots];
        }
      }

      if (!mounted) return;

      setState(() {
        _roots = roots;
        _todayRouteId = todayRouteId;
      });

      // Preselect current route: prefer today's allocated route, falling back
      // to whatever route was last active.
      if (_selectedRootId == null && roots.isNotEmpty) {
        String? currentId = todayRouteId;

        if (currentId == null) {
          final authService = AuthSessionService();
          final routeInfo = await authService.getRouteInfo();
          currentId = routeInfo['routeId'];
        }

        if (currentId != null) {
          final match = roots.firstWhere(
            (r) => r['RootID'].toString() == currentId.toString(),
            orElse: () => {},
          );

          if (match.isNotEmpty && mounted) {
            setState(() {
              _selectedRootId = match['RootID'].toString();
              _selectedRootName = match['RootName']?.toString() ?? '';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('ROOT ERROR = $e');
    } finally {
      if (mounted) {
        setState(() => _loadingRoots = false);
      }
    }
  }

  /// Loads customers for the current route/company.
  ///
  /// Flow:
  /// 1. Try to read from the local SQLite cache first and show it right
  ///    away (fast, works offline). Skipped when [forceRefresh] is true.
  /// 2. Call the API for the latest data.
  /// 3. On success, save the fresh list to the local cache and update the UI.
  /// 4. On failure, keep whatever is already on screen (cached or previous)
  ///    instead of wiping it, and let the user know via a snackbar.
  Future<void> _loadCustomers({bool forceRefresh = false}) async {
    setState(() {
      // Only show the full-page spinner if we have nothing to display yet.
      _loading = _customers.isEmpty;
      _error = null;
    });

    String? rootId = _selectedRootId;
    String companyId = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      companyId =
          prefs.getString('CompanyID') ??
          prefs.getString('SelectedCompanyId') ??
          '';

      if (rootId == null || rootId.isEmpty) {
        final authService = AuthSessionService();
        final routeInfo = await authService.getRouteInfo();
        rootId = routeInfo['routeId'];
      }

      if (rootId == null || rootId.isEmpty || companyId.isEmpty) {
        setState(() {
          _error = 'Missing route/company information';
          _loading = false;
        });
        return;
      }

      // 1. Show cached data immediately, if any.
      if (!forceRefresh) {
        final cached = await _localDb.getCustomers(
          rootId: rootId,
          companyId: companyId,
        );
        if (cached.isNotEmpty && mounted) {
          setState(() {
            _customers = cached;
            _filteredCustomers = cached;
            _showByDistance = false;
            _isShowingCachedData = true;
            _loading = false;
          });
          _applyFilter();
        }
      }

      // 2. Fetch the latest data from the API.
      final customers = await _service.fetchCustomers(
        rootId: rootId,
        companyId: companyId,
      );

      // 3. Persist it locally so next time the page loads instantly.
      await _localDb.saveCustomers(
        rootId: rootId,
        companyId: companyId,
        customers: customers,
      );

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _showByDistance = false; // reset distance sort whenever root changes
        _isShowingCachedData = false;
      });
      _applyFilter();
    } catch (e) {
      // If we already have something on screen (from cache or a previous
      // successful load), keep it instead of replacing it with an error.
      if (_customers.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not refresh - showing last saved customers',
              ),
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Unable to load customers\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openMap(String lat, String lng) async {
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to place call')));
    }
  }

  bool _hasLocation(Map<String, dynamic> c) =>
      c['Latitude'] != null &&
      c['Latitude'].toString().isNotEmpty &&
      c['Longitude'] != null &&
      c['Longitude'].toString().isNotEmpty;

  // Best-effort favourite flag - adapts to whatever key the backend
  // eventually uses, without requiring a schema change up front.
  bool _isFavorite(Map<String, dynamic> c) {
    final v = c['IsFavorite'] ?? c['isFavorite'] ?? c['Favorite'];
    if (v == null) return false;
    if (v is bool) return v;
    return v.toString() == '1' || v.toString().toLowerCase() == 'true';
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers.where((customer) {
          final name =
              customer['AccountName']?.toString().toLowerCase() ?? '';
          final place = customer['Place']?.toString().toLowerCase() ?? '';
          final city = customer['City']?.toString().toLowerCase() ?? '';
          final mobile = (customer['Mob']?.toString().isNotEmpty == true)
              ? customer['Mob'].toString().toLowerCase()
              : customer['Phone']?.toString().toLowerCase() ?? '';

          return name.contains(query) ||
              place.contains(query) ||
              city.contains(query) ||
              mobile.contains(query);
        }).toList();
      }

      if (_showByDistance) {
        _sortCustomersByDistance();
      }
    });
  }

  // â”€â”€ Haversine Distance Calculation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  // â”€â”€ Get Current User Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _getUserLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required')),
            );
          }
          setState(() => _gettingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _userLocation = position;
        _sortCustomersByDistance();
        _showByDistance = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // â”€â”€ Sort Customers by Distance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _sortCustomersByDistance() {
    if (_userLocation == null) return;

    final customersWithDistance = _filteredCustomers
        .where((customer) {
          final lat = customer['Latitude'];
          final lng = customer['Longitude'];
          return lat != null &&
              lng != null &&
              lat.toString().isNotEmpty &&
              lng.toString().isNotEmpty;
        })
        .map((customer) {
          final distance = _calculateDistance(
            _userLocation!.latitude,
            _userLocation!.longitude,
            double.parse(customer['Latitude'].toString()),
            double.parse(customer['Longitude'].toString()),
          );
          return {...customer, 'distance': distance};
        })
        .toList();

    customersWithDistance.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    setState(() => _sortedByDistanceCustomers = customersWithDistance);
  }

  Future<void> _onTabSelected(_CustomerTab tab) async {
    if (tab == _CustomerTab.nearby) {
      if (_userLocation == null) {
        await _getUserLocation();
      }
      if (_userLocation == null) return; // permission/location failed
      setState(() {
        _activeTab = tab;
        _showByDistance = true;
      });
    } else {
      setState(() {
        _activeTab = tab;
        _showByDistance = false;
      });
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> baseList = _showByDistance
        ? _sortedByDistanceCustomers
        : _filteredCustomers;

    if (_activeTab == _CustomerTab.favorites) {
      baseList = baseList.where(_isFavorite).toList();
    }

    final nearby = baseList.where(_hasLocation).toList();
    final noLoc = _showByDistance
        ? <Map<String, dynamic>>[]
        : baseList.where((c) => !_hasLocation(c)).toList();

    return Scaffold(
      backgroundColor: _T.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState(_error!)
          : Column(
              children: [
                _header(),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    children: [
                      _routeSummaryCard(),
                      const SizedBox(height: _T.sm),
                      _searchBar(),
                      const SizedBox(height: _T.sm),
                      _segmentedTabs(),
                      if (_isShowingCachedData) ...[
                        const SizedBox(height: _T.xs),
                        _cachedDataBanner(),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: baseList.isEmpty
                      ? _noResultsState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            _T.lg,
                            0,
                            _T.lg,
                            _T.xxl,
                          ),
                          children: [
                            if (_activeTab == _CustomerTab.favorites) ...[
                              _sectionHeader(
                                'Favorites',
                                _T.warning,
                                baseList.length,
                              ),
                              const SizedBox(height: _T.sm),
                              ..._buildTimelineCards(
                                baseList,
                                showDistance: false,
                              ),
                            ] else if (_showByDistance) ...[
                              _sectionHeader(
                                'Nearby Customers',
                                _T.success,
                                nearby.length,
                                showGpsBadge: true,
                              ),
                              const SizedBox(height: _T.sm),
                              ..._buildTimelineCards(
                                nearby,
                                showDistance: true,
                              ),
                            ] else ...[
                              _sectionHeader(
                                'Nearby Customers',
                                _T.success,
                                nearby.length,
                                showGpsBadge: true,
                              ),
                              const SizedBox(height: _T.sm),
                              ..._buildTimelineCards(
                                nearby,
                                showDistance: false,
                              ),
                              if (nearby.isNotEmpty)
                                const SizedBox(height: _T.lg),
                              if (noLoc.isNotEmpty)
                                _sectionHeader(
                                  'No Location',
                                  _T.warning,
                                  noLoc.length,
                                ),
                              if (noLoc.isNotEmpty)
                                const SizedBox(height: _T.sm),
                              ...noLoc.asMap().entries.map(
                                (e) => _customerCard(
                                  e.value,
                                  false,
                                  _T.accentFor(e.key),
                                  showDistance: false,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _T.primaryBlue,
        onPressed: () {
          // TODO: wire up to the actual "Add Customer" flow/route.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Customer - coming soon')),
          );
        },
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),

    );
  }

  // â”€â”€ Timeline-style customer list (mirrors the route line in the mockup) â”€â”€
  List<Widget> _buildTimelineCards(
    List<Map<String, dynamic>> list, {
    required bool showDistance,
  }) {
    return List.generate(list.length, (i) {
      final color = _T.accentFor(i);
      final isLast = i == list.length - 1;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  const SizedBox(height: _T.lg),
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: color, width: 2.5),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: _T.border),
                    ),
                ],
              ),
            ),
            const SizedBox(width: _T.xs),
            Expanded(
              child: _customerCard(
                list[i],
                true,
                color,
                showDistance: showDistance,
              ),
            ),
          ],
        ),
      );
    });
  }

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        _T.lg,
        MediaQuery.of(context).padding.top + _T.sm,
        _T.lg,
        _T.xxl + _T.sm,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.primaryBlue, _T.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            // TODO: wire up to the app's drawer / navigation shell.
            onTap: () {},
            borderRadius: BorderRadius.circular(_T.sm),
            child: const Padding(
              padding: EdgeInsets.all(_T.xs),
              child: Icon(Icons.menu_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: _T.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customers', style: _T.pageTitle),
                const SizedBox(height: 1),
                Text('Manage your customer network', style: _T.pageSubtitle),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await _loadRoots();
              await _loadCustomers(forceRefresh: true);
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  // TODO: hook up to real notifications.
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: _T.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: const Text(
                    '3',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Today's Route summary card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _routeSummaryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.lg),
      child: Material(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(_T.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(_T.rCard),
          onTap: _loadingRoots || _roots.isEmpty ? null : _openRootPicker,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_T.rCard),
              boxShadow: _T.shadow,
            ),
            padding: const EdgeInsets.all(_T.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _T.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(_T.sm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.alt_route_rounded,
                    size: 18,
                    color: _T.primaryBlue,
                  ),
                ),
                const SizedBox(width: _T.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todayRouteId != null
                            ? "Today's Route"
                            : 'Selected Route',
                        style: _T.smallText,
                      ),
                      const SizedBox(height: 1),
                      if (_loadingRoots)
                        Row(
                          children: [
                            const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: _T.xs),
                            Text(
                              'Loading routes...',
                              style: _T.inputText.copyWith(
                                color: _T.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          _roots.isEmpty
                              ? 'No routes available'
                              : (_selectedRootName?.isNotEmpty == true
                                    ? _selectedRootName!.toUpperCase()
                                    : 'Select Route'),
                          style: _T.cardValue.copyWith(
                            color: _selectedRootName?.isNotEmpty == true
                                ? _T.primaryBlue
                                : _T.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 1),
                      Text(
                        '${_customers.length} Customers',
                        style: _T.smallText,
                      ),
                    ],
                  ),
                ),
                if (!_loadingRoots && _roots.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(_T.xs),
                    decoration: BoxDecoration(
                      border: Border.all(color: _T.border),
                      borderRadius: BorderRadius.circular(_T.sm),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _T.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRootPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _T.cardBg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_T.rCard),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: _T.sm),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _T.border,
                      borderRadius: BorderRadius.circular(_T.xs),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _T.lg,
                      _T.lg,
                      _T.lg,
                      _T.sm,
                    ),
                    child: Row(
                      children: [
                        Text('Select Route', style: _T.sectionTitle),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _T.sm,
                            vertical: _T.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _T.primaryBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(_T.rBadge),
                          ),
                          child: Text(
                            '${_roots.length}',
                            style: _T.smallText.copyWith(
                              color: _T.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _T.border),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: _T.sm),
                      itemCount: _roots.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: _T.border,
                        indent: _T.lg,
                        endIndent: _T.lg,
                      ),
                      itemBuilder: (context, i) {
                        final root = _roots[i];
                        final id = root['RootID'].toString();
                        final name = root['RootName']?.toString() ?? id;
                        final selected = id == _selectedRootId;
                        final isToday = id == _todayRouteId;

                        return ListTile(
                          onTap: () => Navigator.pop(sheetContext, id),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: _T.inputText.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: selected
                                        ? _T.primaryBlue
                                        : _T.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: _T.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _T.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _T.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      _T.rBadge,
                                    ),
                                  ),
                                  child: Text(
                                    'TODAY',
                                    style: _T.caption.copyWith(
                                      color: _T.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: _T.primaryBlue,
                                  size: 20,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selectedId) async {
      if (selectedId == null || selectedId == _selectedRootId) return;

      final root = _roots.firstWhere(
        (r) => r['RootID'].toString() == selectedId,
      );
      final name = root['RootName']?.toString() ?? '';

      setState(() {
        _selectedRootId = selectedId;
        _selectedRootName = name;
      });

      await AuthSessionService().setRouteInfo(
        routeId: selectedId,
        routeName: name,
      );

      _searchController.clear();
      _loadCustomers();
    });
  }

  // â”€â”€ Cached Data Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _cachedDataBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: _T.md,
          vertical: _T.xs,
        ),
        decoration: BoxDecoration(
          color: _T.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(_T.rButton),
        ),
        child: Row(
          children: [
            const Icon(Icons.offline_bolt_rounded, size: 14, color: _T.warning),
            const SizedBox(width: _T.xs),
            Expanded(
              child: Text(
                'Showing saved data. Refreshing...',
                style: _T.caption.copyWith(
                  color: _T.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noResultsState() {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_T.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(_T.lg),
                  decoration: BoxDecoration(
                    color: _T.warning.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _activeTab == _CustomerTab.favorites
                        ? Icons.star_border_rounded
                        : Icons.search_off_rounded,
                    size: 32,
                    color: _T.warning,
                  ),
                ),
                const SizedBox(height: _T.lg),
                Text(
                  _activeTab == _CustomerTab.favorites
                      ? 'No favorites yet'
                      : 'No customers found',
                  style: _T.sectionTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _T.xs),
                Text(
                  _activeTab == _CustomerTab.favorites
                      ? 'Mark customers as favorite from\ntheir details page to see them here'
                      : 'Try searching with different keywords:\nname, place, city, or mobile number',
                  style: _T.inputText.copyWith(color: _T.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: _T.lg),
                if (_activeTab != _CustomerTab.favorites)
                  _ghostButton(
                    label: 'Clear Search',
                    icon: Icons.clear_rounded,
                    color: _T.primaryBlue,
                    onTap: () {
                      _searchController.clear();
                      _applyFilter();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.lg),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, place, city, mobile...',
                  hintStyle: _T.inputText.copyWith(
                    color: _T.textSecondary.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _T.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: _T.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _T.cardBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _T.md,
                    vertical: _T.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_T.rButton),
                    borderSide: const BorderSide(color: _T.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_T.rButton),
                    borderSide: const BorderSide(color: _T.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_T.rButton),
                    borderSide: const BorderSide(
                      color: _T.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
                style: _T.inputText,
              ),
            ),
          ),
          const SizedBox(width: _T.sm),
          Material(
            color: _T.cardBg,
            borderRadius: BorderRadius.circular(_T.rButton),
            child: InkWell(
              borderRadius: BorderRadius.circular(_T.rButton),
              onTap: () {
                // TODO: hook up real filter/sort options here.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filters - coming soon')),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  border: Border.all(color: _T.border),
                  borderRadius: BorderRadius.circular(_T.rButton),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _T.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Segmented Tabs: All / Nearby / Favorites â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _segmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.lg),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _tabChip(
              label: 'All (${_customers.length})',
              icon: null,
              active: _activeTab == _CustomerTab.all,
              onTap: () => _onTabSelected(_CustomerTab.all),
            ),
          ),
          const SizedBox(width: _T.sm),
          Expanded(
            child: _tabChip(
              label: 'Nearby',
              icon: Icons.place_outlined,
              active: _activeTab == _CustomerTab.nearby,
              isLoading: _gettingLocation,
              onTap: () => _onTabSelected(_CustomerTab.nearby),
            ),
          ),
          const SizedBox(width: _T.sm),
          Expanded(
            child: _tabChip(
              label: 'Favorites',
              icon: Icons.star_border_rounded,
              active: _activeTab == _CustomerTab.favorites,
              onTap: () => _onTabSelected(_CustomerTab.favorites),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required IconData? icon,
    required bool active,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: active ? _T.primaryBlue : _T.cardBg,
      borderRadius: BorderRadius.circular(_T.rButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(_T.rButton),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: _T.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_T.rButton),
            border: Border.all(color: active ? _T.primaryBlue : _T.border),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_T.primaryBlue),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 14,
                        color: active ? Colors.white : _T.textSecondary,
                      ),
                      const SizedBox(width: _T.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: _T.buttonText.copyWith(
                          color: active ? Colors.white : _T.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _errorState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_T.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(_T.lg),
              decoration: BoxDecoration(
                color: _T.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: _T.error,
              ),
            ),
            const SizedBox(height: _T.lg),
            Text(
              msg,
              style: _T.inputText.copyWith(color: _T.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _T.lg),
            _ghostButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              color: _T.primaryBlue,
              onTap: _loadCustomers,
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Section Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _sectionHeader(
    String title,
    Color color,
    int count, {
    bool showGpsBadge = false,
  }) {
    return Row(
      children: [
        Text(title, style: _T.sectionTitle),
        const SizedBox(width: _T.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _T.sm,
            vertical: _T.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(_T.rBadge),
          ),
          child: Text(
            '$count',
            style: _T.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        if (showGpsBadge)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: _T.sm,
              vertical: _T.xs,
            ),
            decoration: BoxDecoration(
              color: _T.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_T.rBadge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  size: 11,
                  color: _T.success,
                ),
                const SizedBox(width: _T.xs),
                Text(
                  'GPS',
                  style: _T.caption.copyWith(
                    color: _T.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // â”€â”€ Customer Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Compact layout: smaller avatar, tighter padding, single-line info,
  // and a slimmer action row so ~4-5 cards fit on a typical phone screen.
  Widget _customerCard(
    Map<String, dynamic> customer,
    bool hasLoc,
    Color accent, {
    bool showDistance = false,
  }) {
    final name = customer['AccountName']?.toString() ?? '';
    final place = customer['Place']?.toString() ?? '';
    final city = customer['City']?.toString() ?? '';
    final phone = (customer['Mob']?.toString().isNotEmpty == true)
        ? customer['Mob'].toString()
        : customer['Phone']?.toString() ?? '';
    final lat = customer['Latitude']?.toString() ?? '';
    final lng = customer['Longitude']?.toString() ?? '';
    final distance = customer['distance'] as double?;

    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';

    return InkWell(
      borderRadius: BorderRadius.circular(_T.rCard),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerInfoPage(customer: customer),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: _T.sm),
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(_T.rCard),
          boxShadow: _T.shadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _T.md,
                _T.sm,
                _T.md,
                _T.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontFamily: _T.font,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: _T.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: _T.cardValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Place/city and phone combined on one line to save
                        // vertical space.
                        Row(
                          children: [
                            if (place.isNotEmpty || city.isNotEmpty) ...[
                              const Icon(
                                Icons.place_rounded,
                                size: 12,
                                color: _T.secondaryBlue,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  [
                                    place,
                                    city,
                                  ].where((s) => s.isNotEmpty).join(' â€¢ '),
                                  style: _T.smallText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (phone.isNotEmpty) ...[
                              if (place.isNotEmpty || city.isNotEmpty)
                                const SizedBox(width: _T.sm),
                              const Icon(
                                Icons.phone_rounded,
                                size: 12,
                                color: _T.secondaryBlue,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  phone,
                                  style: _T.smallText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _T.xs),
                  if (showDistance && distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _T.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(_T.rBadge),
                      ),
                      child: Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: _T.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    _locationBadge(hasLoc),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _T.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _T.border),
            Padding(
              padding: const EdgeInsets.all(_T.xs),
              child: Row(
                children: [
                  Expanded(
                    child: _ghostButton(
                      label: 'Details',
                      icon: Icons.person_rounded,
                      color: accent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailsPage(customer: customer),
                        ),
                      ),
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(width: _T.xs),
                    Expanded(
                      child: _ghostButton(
                        label: 'Call',
                        icon: Icons.call_rounded,
                        color: accent,
                        onTap: () => _callNumber(phone),
                      ),
                    ),
                  ],
                  if (hasLoc) ...[
                    const SizedBox(width: _T.xs),
                    Expanded(
                      child: _ghostButton(
                        label: 'Maps',
                        icon: Icons.navigation_rounded,
                        color: accent,
                        onTap: () => _openMap(lat, lng),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Reusable widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _locationBadge(bool hasLoc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _T.sm, vertical: 2),
      margin: const EdgeInsets.only(right: _T.xs),
      decoration: BoxDecoration(
        color: hasLoc
            ? _T.success.withValues(alpha: 0.10)
            : _T.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_T.rBadge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasLoc ? Icons.location_on_rounded : Icons.location_off_rounded,
            size: 11,
            color: hasLoc ? _T.success : _T.textSecondary,
          ),
          const SizedBox(width: 2),
          Text(
            hasLoc ? 'GPS' : 'No GPS',
            style: _T.caption.copyWith(
              color: hasLoc ? _T.success : _T.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ghostButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(_T.rButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_T.rButton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: _T.sm),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: _T.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: _T.buttonText.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



}
