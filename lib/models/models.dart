// ─── Auth ────────────────────────────────────────────────────────────────────
class AuthUser {
  final int    id;
  final int    tenantId;
  final int    branchId;
  final String name;
  final String email;
  final String role;
  final String currency;
  final String shopName;

  const AuthUser({
    required this.id, required this.tenantId, required this.branchId,
    required this.name, required this.email, required this.role,
    required this.currency, required this.shopName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['user_id'] ?? 0,
    tenantId: j['tenant_id'] ?? 0,
    branchId: j['branch_id'] ?? 0,
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'owner',
    currency: j['currency'] ?? 'TZS',
    shopName: j['shop_name'] ?? 'My Shop',
  );
}

// ─── Dashboard ───────────────────────────────────────────────────────────────
class DashboardStats {
  final double todaySales;
  final double todayRevenue;
  final double monthRevenue;
  final double monthExpenses;
  final int    todayTransactions;
  final int    lowStockCount;
  final int    pendingOrders;
  final double outstandingCredits;

  const DashboardStats({
    required this.todaySales,
    required this.todayRevenue,
    required this.monthRevenue,
    required this.monthExpenses,
    required this.todayTransactions,
    required this.lowStockCount,
    required this.pendingOrders,
    required this.outstandingCredits,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
    todaySales: _d(j['today_sales']),
    todayRevenue: _d(j['today_revenue']),
    monthRevenue: _d(j['month_revenue']),
    monthExpenses: _d(j['month_expenses']),
    todayTransactions: _i(j['today_transactions']),
    lowStockCount: _i(j['low_stock_count']),
    pendingOrders: _i(j['pending_orders']),
    outstandingCredits: _d(j['outstanding_credits']),
  );

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  static int    _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  factory DashboardStats.empty() => const DashboardStats(
    todaySales: 0, todayRevenue: 0, monthRevenue: 0, monthExpenses: 0,
    todayTransactions: 0, lowStockCount: 0, pendingOrders: 0, outstandingCredits: 0,
  );
}

// ─── Sale ─────────────────────────────────────────────────────────────────────
class Sale {
  final int    id;
  final String invoiceNo;
  final String customerName;
  final double totalAmount;
  final double paidAmount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  const Sale({
    required this.id, required this.invoiceNo, required this.customerName,
    required this.totalAmount, required this.paidAmount,
    required this.paymentMethod, required this.status, required this.createdAt,
  });

  bool get isPaid => (totalAmount - paidAmount).abs() < 0.01;

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'] ?? 0,
    invoiceNo: j['invoice_no'] ?? '',
    customerName: j['cust_name'] ?? 'Cash Customer',
    totalAmount: double.tryParse(j['total_amount']?.toString() ?? '0') ?? 0,
    paidAmount: double.tryParse(j['paid_amount']?.toString() ?? '0') ?? 0,
    paymentMethod: j['payment_method'] ?? 'cash',
    status: j['status'] ?? 'paid',
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );
}

// ─── Product / Stock ──────────────────────────────────────────────────────────
class StockItem {
  final int    id;
  final String name;
  final String sku;
  final String unit;
  final double qty;
  final double reorderLevel;
  final double buyingPrice;
  final double sellingPrice;
  final String categoryName;

  const StockItem({
    required this.id, required this.name, required this.sku,
    required this.unit, required this.qty, required this.reorderLevel,
    required this.buyingPrice, required this.sellingPrice,
    required this.categoryName,
  });

  bool get isLowStock => qty <= reorderLevel && reorderLevel > 0;
  bool get isOutOfStock => qty <= 0;

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
    id: j['id'] ?? 0,
    name: j['name'] ?? '',
    sku: j['sku'] ?? '',
    unit: j['unit'] ?? 'pcs',
    qty: double.tryParse(j['qty']?.toString() ?? '0') ?? 0,
    reorderLevel: double.tryParse(j['reorder_level']?.toString() ?? '0') ?? 0,
    buyingPrice: double.tryParse(j['buying_price']?.toString() ?? '0') ?? 0,
    sellingPrice: double.tryParse(j['selling_price']?.toString() ?? '0') ?? 0,
    categoryName: j['category_name'] ?? 'General',
  );
}

// ─── Branch ───────────────────────────────────────────────────────────────────
class Branch {
  final int    id;
  final String name;
  final String code;
  final bool   isMain;

  const Branch({required this.id, required this.name, required this.code, required this.isMain});

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    id: j['id'] ?? 0,
    name: j['name'] ?? '',
    code: j['code'] ?? '',
    isMain: (j['is_main'] == 1 || j['is_main'] == true),
  );
}

// ─── Sale Detail ──────────────────────────────────────────────────────────────
class SaleDetail {
  final int    id;
  final String invoiceNo;
  final String custName;
  final String custPhone;
  final double totalAmount;
  final double paidAmount;
  final double discountAmount;
  final double taxAmount;
  final String paymentMethod;
  final String status;
  final String notes;
  final String servedBy;
  final String branchName;
  final DateTime createdAt;
  final List<SaleItem> items;

  const SaleDetail({
    required this.id, required this.invoiceNo, required this.custName,
    required this.custPhone, required this.totalAmount, required this.paidAmount,
    required this.discountAmount, required this.taxAmount,
    required this.paymentMethod, required this.status, required this.notes,
    required this.servedBy, required this.branchName,
    required this.createdAt, required this.items,
  });

  factory SaleDetail.fromJson(Map<String, dynamic> s, List<dynamic> itemsJson) => SaleDetail(
    id: s['id'] ?? 0,
    invoiceNo: s['invoice_no'] ?? '',
    custName: s['cust_name'] ?? 'Cash Customer',
    custPhone: s['cust_phone'] ?? '',
    totalAmount: double.tryParse(s['total_amount']?.toString() ?? '0') ?? 0,
    paidAmount: double.tryParse(s['paid_amount']?.toString() ?? '0') ?? 0,
    discountAmount: double.tryParse(s['discount']?.toString() ?? '0') ?? 0,
    taxAmount: double.tryParse(s['tax_amount']?.toString() ?? '0') ?? 0,
    paymentMethod: s['payment_method'] ?? 'cash',
    status: s['status'] ?? 'paid',
    notes: s['notes'] ?? '',
    servedBy: s['served_by'] ?? '',
    branchName: s['branch_name'] ?? '',
    createdAt: DateTime.tryParse(s['created_at'] ?? '') ?? DateTime.now(),
    items: itemsJson.map((i) => SaleItem.fromJson(i)).toList(),
  );
}

class SaleItem {
  final int    productId;
  final String productName;
  final String sku;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;

  const SaleItem({
    required this.productId, required this.productName, required this.sku,
    required this.unit, required this.quantity, required this.unitPrice,
    required this.discount, required this.total,
  });

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
    productId: j['product_id'] ?? 0,
    productName: j['product_name'] ?? '',
    sku: j['sku'] ?? '',
    unit: j['unit'] ?? 'pcs',
    quantity: double.tryParse(j['quantity']?.toString() ?? '0') ?? 0,
    unitPrice: double.tryParse(j['unit_price']?.toString() ?? '0') ?? 0,
    discount: double.tryParse(j['discount']?.toString() ?? '0') ?? 0,
    total: double.tryParse(j['total']?.toString() ?? '0') ?? 0,
  );
}

// ─── POS Product ──────────────────────────────────────────────────────────────
class PosProduct {
  final int    id;
  final String name;
  final String sku;
  final String unit;
  final double sellingPrice;
  final double wholesalePrice;
  final double buyingPrice;
  final double qty;
  final String categoryName;

  const PosProduct({
    required this.id, required this.name, required this.sku,
    required this.unit, required this.sellingPrice,
    required this.wholesalePrice, required this.buyingPrice,
    required this.qty, required this.categoryName,
  });

  bool get inStock => qty > 0;

  factory PosProduct.fromJson(Map<String, dynamic> j) => PosProduct(
    id: j['id'] ?? 0,
    name: j['name'] ?? '',
    sku: j['sku'] ?? '',
    unit: j['unit'] ?? 'pcs',
    sellingPrice: double.tryParse(j['selling_price']?.toString() ?? '0') ?? 0,
    wholesalePrice: double.tryParse(j['wholesale_price']?.toString() ?? '0') ?? 0,
    buyingPrice: double.tryParse(j['buying_price']?.toString() ?? '0') ?? 0,
    qty: double.tryParse(j['qty']?.toString() ?? '0') ?? 0,
    categoryName: j['category_name'] ?? 'General',
  );
}

// ─── Cart Item ────────────────────────────────────────────────────────────────
class CartItem {
  final PosProduct product;
  double quantity;
  double price;

  CartItem({required this.product, this.quantity = 1})
      : price = product.sellingPrice;

  double get total => quantity * price;

  CartItem copyWith({double? quantity, double? price}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity)
        ..price = price ?? this.price;
}

// ─── Chart Data ───────────────────────────────────────────────────────────────
class SalesChartPoint {
  final String label;
  final double value;
  const SalesChartPoint({required this.label, required this.value});
}
