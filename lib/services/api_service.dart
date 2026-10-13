import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'https://mdspro.co.tz';
  static const Duration _timeout = Duration(seconds: 20);

  static String? _token; // PHP session ID sent as X-Session-ID header

  // Global navigator key — set this in main.dart to enable session-expiry redirect
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('mobile_token');
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mobile_token', token);
  }

  static Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobile_token');
    await prefs.remove('cached_user');
  }

  // Decode response — on 401 clears session and navigates to login
  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      data = json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      // Non-JSON body — return a meaningful error based on status code
      String msg;
      if (res.statusCode == 404) {
        msg = 'Endpoint not found on server (404). Please contact support.';
      } else if (res.statusCode == 401) {
        msg = 'Session expired. Please log in again.';
      } else if (res.statusCode >= 500) {
        msg = 'Server error (${res.statusCode}). Please try again later.';
      } else {
        msg = 'Unexpected response (${res.statusCode}). Please try again.';
      }
      data = {'ok': false, 'code': res.statusCode, 'error': msg};
    }
    if (res.statusCode == 401 || data['code'] == 401) {
      clearSession();
      navigatorKey?.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
    return data;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (_token != null) 'X-Session-ID': _token!,
  };

  static Map<String, String> get _getHeaders => {
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (_token != null) 'X-Session-ID': _token!,
  };

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/auth.php'),
      headers: _headers,
      body: {'action': 'login', 'email': email, 'password': password},
    ).timeout(_timeout);

    final data = json.decode(res.body) as Map<String, dynamic>;

    if (data['ok'] == true) {
      // Store the session token returned by the server
      if (data['token'] != null) {
        await _saveToken(data['token'].toString());
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user', json.encode(data['user']));
    }
    return data;
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/ajax/mobile/auth.php'),
        headers: _headers,
        body: {'action': 'logout'},
      ).timeout(_timeout);
    } catch (_) {}
    await clearSession();
  }

  static Future<AuthUser?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_user');
    if (raw == null) return null;
    try { return AuthUser.fromJson(json.decode(raw)); } catch (_) { return null; }
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static Future<DashboardStats> getDashboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/dashboard.php'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) return DashboardStats.fromJson(data['data']);
    throw Exception(data['error'] ?? 'Failed to load dashboard');
  }

  static Future<List<SalesChartPoint>> getWeeklyChart() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/dashboard.php?chart=weekly'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['chart'] as List)
          .map((p) => SalesChartPoint(
                label: p['label'] ?? '',
                value: double.tryParse(p['value']?.toString() ?? '0') ?? 0,
              ))
          .toList();
    }
    return [];
  }

  // ── Sales ─────────────────────────────────────────────────────────────────
  static Future<List<Sale>> getSales({
    String filter = 'today',
    int page = 1,
    String? search,
  }) async {
    final params = {'filter': filter, 'page': page.toString()};
    if (search != null && search.isNotEmpty) params['q'] = search;
    final uri = Uri.parse('$baseUrl/ajax/mobile/sales.php')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['sales'] as List).map((s) => Sale.fromJson(s)).toList();
    }
    return [];
  }

  // ── Stock ─────────────────────────────────────────────────────────────────
  static Future<List<StockItem>> getStock({
    String? search,
    bool lowStockOnly = false,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (lowStockOnly) params['low_stock'] = '1';
    final uri = Uri.parse('$baseUrl/ajax/mobile/stock.php')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['stock'] as List).map((s) => StockItem.fromJson(s)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> adjustStock({
    required int productId,
    required String type, // add | remove | set
    required double qty,
    required String reason,
    String notes = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/adjust_stock.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'product_id': productId,
        'type': type,
        'qty': qty,
        'reason': reason,
        'notes': notes,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── Recent sales (for notification polling) ───────────────────────────────
  static Future<List<Sale>> getRecentSales() => getSales(filter: 'today', page: 1);

  // ── Sale detail ───────────────────────────────────────────────────────────
  static Future<SaleDetail> getSaleDetail(int saleId) async {
    final uri = Uri.parse('$baseUrl/ajax/mobile/sales.php')
        .replace(queryParameters: {'action': 'detail', 'sale_id': saleId.toString()});
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return SaleDetail.fromJson(data['sale'], data['items'] as List);
    }
    throw Exception(data['error'] ?? 'Failed to load invoice');
  }

  // ── Branches ──────────────────────────────────────────────────────────────
  static Future<List<Branch>> getBranches() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['branches'] as List).map((b) => Branch.fromJson(b)).toList();
    }
    return [];
  }

  // ── POS ───────────────────────────────────────────────────────────────────
  static Future<List<PosProduct>> searchProducts(String query) async {
    final params = <String, String>{};
    if (query.isNotEmpty) params['q'] = query;
    params['action'] = 'products';
    final uri = Uri.parse('$baseUrl/ajax/mobile/pos.php').replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['products'] as List).map((p) => PosProduct.fromJson(p)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createSale({
    required List<CartItem> items,
    required String paymentMethod,
    required double paidAmount,
    double discount = 0,
    String customerName = '',
    String customerPhone = '',
    String notes = '',
  }) async {
    final body = json.encode({
      'items': items.map((c) => {
        'id': c.product.id,
        'name': c.product.name,
        'sku': c.product.sku,
        'unit': c.product.unit,
        'qty': c.quantity,
        'price': c.price,
      }).toList(),
      'payment_method': paymentMethod,
      'paid_amount': paidAmount,
      'discount': discount,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'notes': notes,
    });
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/pos.php'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<bool> switchBranch(int branchId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/switch_branch.php'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: json.encode({'branch_id': branchId}),
    ).timeout(_timeout);
    return _decode(res)['ok'] == true;
  }

  // Update the branchId stored in the cached user after a branch switch
  static Future<void> updateCachedBranch(int branchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_user');
    if (raw == null) return;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      map['branch_id'] = branchId;
      await prefs.setString('cached_user', json.encode(map));
    } catch (_) {}
  }

  // ── Debt collection ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> collectPayment({
    required int saleId,
    required double amount,
    required String paymentMethod,
    String reference = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/collect_payment.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'sale_id': saleId,
        'amount': amount,
        'payment_method': paymentMethod,
        'reference': reference,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<void> registerFcmToken(String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/ajax/mobile/register_token.php'),
        headers: _headers,
        body: {'fcm_token': token},
      ).timeout(_timeout);
    } catch (_) {}
  }

  // ── Add product ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/add_product.php'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['categories'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addProduct({
    required String name,
    String sku = '',
    String unit = 'pcs',
    int? categoryId,
    required double buyingPrice,
    required double sellingPrice,
    double qty = 0,
    double reorderLevel = 0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/add_product.php'),
      headers: _getHeaders,
      body: {
        'action':        'add_product',
        'name':          name,
        'sku':           sku,
        'unit':          unit,
        'category_id':   categoryId?.toString() ?? '',
        'buying_price':  buyingPrice.toString(),
        'selling_price': sellingPrice.toString(),
        'qty':           qty.toString(),
        'reorder_level': reorderLevel.toString(),
      },
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> bulkAddProducts(
      List<Map<String, dynamic>> products) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/add_product.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'bulk_add', 'products': products}),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── User management ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/users.php?action=list'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['users'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> getUserPermissions(int userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/users.php?action=permissions&user_id=$userId'),
      headers: _getHeaders,
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getManagementBranches() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/users.php?action=branches'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['branches'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addUser({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String password,
    int? branchId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'add_user',
        'name': name, 'email': email, 'phone': phone,
        'role': role, 'password': password,
        'branch_id': branchId?.toString() ?? '',
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updatePermissions({
    required int userId,
    required List<String> modules,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'update_permissions', 'user_id': userId, 'modules': modules}),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> toggleUserStatus(int userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'toggle_status', 'user_id': userId}),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── Registration ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerOwner({
    required String shopName,
    required String ownerName,
    required String email,
    required String phone,
    required String password,
    String currency = 'TZS',
    String country  = 'Tanzania',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/register.php'),
      headers: {'Content-Type': 'application/json',
                 'Accept': 'application/json',
                 'X-Requested-With': 'XMLHttpRequest'},
      body: json.encode({
        'shop_name': shopName, 'owner_name': ownerName,
        'email': email, 'phone': phone, 'password': password,
        'currency': currency, 'country': country,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── Product categories ───────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProductCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/categories.php'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['categories'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addProductCategory(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/categories.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'add', 'name': name}),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── Expenses ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getExpenses({String filter = 'month'}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/expenses.php?action=list&filter=$filter'),
      headers: _getHeaders,
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/expenses.php?action=categories'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['categories'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addExpense({
    required String title,
    required int categoryId,
    required double amount,
    required String date,
    String paymentMethod = 'cash',
    String note = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/expenses.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'add', 'title': title,
        'category_id': categoryId, 'amount': amount,
        'date': date, 'payment_method': paymentMethod, 'note': note,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> addExpenseCategory(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/expenses.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'add_category', 'name': name}),
    ).timeout(_timeout);
    return _decode(res);
  }
}
