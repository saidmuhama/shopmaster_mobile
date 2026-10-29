import 'dart:convert';
import 'dart:io';
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
    // Guard against unexpectedly large responses (> 4 MB)
    if (res.contentLength != null && res.contentLength! > 4 * 1024 * 1024) {
      return {'ok': false, 'error': 'Response too large. Please contact support.'};
    }
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
    'Cache-Control': 'no-store, no-cache',
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

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/auth.php'),
      headers: _headers,
      body: {
        'action':           'change_password',
        'current_password': currentPassword,
        'new_password':     newPassword,
        'confirm_password': confirmPassword,
      },
    ).timeout(_timeout);
    return jsonDecode(res.body) as Map<String, dynamic>;
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

  static Future<List<BranchStats>> getAllBranchStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/dashboard.php?mode=branches'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['branches'] as List)
          .map((b) => BranchStats.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Future<CashierStats> getCashierStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/dashboard.php?mode=cashier'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) return CashierStats.fromJson(data);
    return CashierStats.empty();
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
      headers: {..._headers, 'Content-Type': 'application/json'},
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

  // ── Pending stock adjustment approvals ───────────────────────────────────────
  static Future<List<PendingAdjustment>> getPendingAdjustments() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ajax/mobile/pending_adjustments.php'),
        headers: _getHeaders,
      ).timeout(_timeout);
      final data = _decode(res);
      if (data['ok'] == true) {
        return (data['pending'] as List? ?? [])
            .map((j) => PendingAdjustment.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // Returns {ok, new_qty, old_qty} on success; {ok:false, error} on failure.
  static Future<Map<String, dynamic>> approvePendingAdjustment(int id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/pending_adjustments.php'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'approve', 'id': id}),
    ).timeout(_timeout);
    return _decode(res);
  }

  // Returns {ok:true} on success; {ok:false, error} on failure.
  static Future<Map<String, dynamic>> rejectPendingAdjustment(
      int id, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/pending_adjustments.php'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'reject', 'id': id, 'reason': reason}),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getStockMovements({
    int? productId,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (productId != null) params['product_id'] = productId.toString();
    final uri = Uri.parse('$baseUrl/ajax/mobile/stock_movements.php')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return List<Map<String, dynamic>>.from(data['movements'] ?? []);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getStockAdjustments({
    String date = 'month',
    String search = '',
    int? branchId,
    int limit = 200,
  }) async {
    final params = <String, String>{
      'action': 'adjustments',
      'date': date,
      'limit': limit.toString(),
    };
    if (search.isNotEmpty) params['q'] = search;
    if (branchId != null) params['branch_id'] = branchId.toString();
    final uri = Uri.parse('$baseUrl/ajax/mobile/stock_movements.php')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return List<Map<String, dynamic>>.from(data['movements'] ?? []);
    }
    return [];
  }

  static Future<Map<String, dynamic>> amendSale({
    required int saleId,
    String? paymentMethod,
    String? notes,
  }) async {
    final body = <String, String>{
      'action': 'amend',
      'sale_id': saleId.toString(),
    };
    if (paymentMethod != null) body['payment_method'] = paymentMethod;
    if (notes != null) body['notes'] = notes;
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/sales.php'),
      headers: _headers,
      body: body,
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
  static Future<Map<String, dynamic>> searchProductsRaw(String query) async {
    final params = <String, String>{'action': 'products'};
    if (query.isNotEmpty) params['q'] = query;
    final uri = Uri.parse('$baseUrl/ajax/mobile/pos.php').replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
    return _decode(res);
  }

  static Future<List<PosProduct>> searchProducts(String query) async {
    final data = await searchProductsRaw(query);
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
    List<Map<String, dynamic>>? payments,
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
      if (payments != null && payments.isNotEmpty) 'payments': payments,
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
    double wholesalePrice = 0,
    double minWholesaleQty = 0,
    double qty = 0,
    double reorderLevel = 0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/add_product.php'),
      headers: _getHeaders,
      body: {
        'action':            'add_product',
        'name':              name,
        'sku':               sku,
        'unit':              unit,
        'category_id':       categoryId?.toString() ?? '',
        'buying_price':      buyingPrice.toString(),
        'selling_price':     sellingPrice.toString(),
        'wholesale_price':   wholesalePrice.toString(),
        'min_wholesale_qty': minWholesaleQty.toString(),
        'qty':               qty.toString(),
        'reorder_level':     reorderLevel.toString(),
      },
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> uploadProductImage({
    required int productId,
    required File imageFile,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ajax/mobile/upload_image.php'),
    );
    req.headers.addAll(_getHeaders);
    req.fields['product_id'] = productId.toString();
    req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
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

  // ── Update product details ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProduct({
    required int productId,
    required String name,
    String sku = '',
    String unit = 'pcs',
    int? categoryId,
    required double buyingPrice,
    required double sellingPrice,
    double wholesalePrice = 0,
    double minWholesaleQty = 0,
    double reorderLevel = 0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/stock.php'),
      headers: _getHeaders,
      body: {
        'action':            'update_product',
        'product_id':        productId.toString(),
        'name':              name,
        'sku':               sku,
        'unit':              unit,
        'category_id':       categoryId?.toString() ?? '',
        'buying_price':      buyingPrice.toString(),
        'selling_price':     sellingPrice.toString(),
        'wholesale_price':   wholesalePrice.toString(),
        'min_wholesale_qty': minWholesaleQty.toString(),
        'reorder_level':     reorderLevel.toString(),
      },
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> bulkUpdateProducts(
      List<Map<String, dynamic>> products) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/stock.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'bulk_update', 'products': products}),
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
    final uri = Uri.parse('$baseUrl/ajax/mobile/users.php')
        .replace(queryParameters: {'action': 'permissions', 'user_id': userId.toString()});
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
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

  static Future<Map<String, dynamic>> editUser({
    required int userId,
    required String name,
    required String phone,
    required String role,
    int? branchId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'edit_user', 'user_id': userId,
        'name': name, 'phone': phone, 'role': role,
        'branch_id': branchId ?? '',
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'delete_user', 'user_id': userId}),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> resetUserPassword({
    required int userId,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/users.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'reset_password', 'user_id': userId, 'password': password}),
    ).timeout(_timeout);
    return _decode(res);
  }

  // ── Branch CRUD ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getBranchesManagement() async {
    final res = await http.get(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: _getHeaders,
    ).timeout(_timeout);
    final data = _decode(res);
    if (data['ok'] == true) {
      return (data['branches'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>> addBranch({
    required String name,
    String code = '',
    String address = '',
    String city = '',
    String phone = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'add_branch',
        'name': name, 'code': code, 'address': address,
        'city': city, 'phone': phone,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateBranch({
    required int branchId,
    required String name,
    String code = '',
    String address = '',
    String city = '',
    String phone = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'update_branch', 'branch_id': branchId,
        'name': name, 'code': code, 'address': address,
        'city': city, 'phone': phone,
      }),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> toggleBranch(int branchId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'toggle_branch', 'branch_id': branchId}),
    ).timeout(_timeout);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> deleteBranch(int branchId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ajax/mobile/branches.php'),
      headers: {..._getHeaders, 'Content-Type': 'application/json'},
      body: json.encode({'action': 'delete_branch', 'branch_id': branchId}),
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
    final uri = Uri.parse('$baseUrl/ajax/mobile/expenses.php')
        .replace(queryParameters: {'action': 'list', 'filter': filter});
    final res = await http.get(uri, headers: _getHeaders).timeout(_timeout);
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

  /// Returns [{slug, name, color, is_builtin}] — built-in enabled + custom methods.
  /// Falls back to hardcoded defaults on any error.
  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ajax/mobile/payment_methods.php'),
        headers: _getHeaders,
      ).timeout(_timeout);
      final data = _decode(res);
      if (data['ok'] == true && data['methods'] is List) {
        return List<Map<String, dynamic>>.from(
            (data['methods'] as List).map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (_) {}
    // Fallback defaults
    return [
      {'slug': 'cash',     'name': 'Cash',      'color': '#22c55e', 'is_builtin': true},
      {'slug': 'mpesa',    'name': 'M-Pesa',    'color': '#ef4444', 'is_builtin': true},
      {'slug': 'tigopesa', 'name': 'Tigo Pesa', 'color': '#3b82f6', 'is_builtin': true},
      {'slug': 'airtel',   'name': 'Airtel',    'color': '#f97316', 'is_builtin': true},
      {'slug': 'bank',     'name': 'Bank',      'color': '#6366f1', 'is_builtin': true},
      {'slug': 'credit',   'name': 'Credit',    'color': '#f59e0b', 'is_builtin': true},
    ];
  }
}
