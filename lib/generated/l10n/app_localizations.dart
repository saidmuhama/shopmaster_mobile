import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MDSPro'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Business Management'**
  String get appTagline;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your MDSPro account'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get checkConnection;

  /// No description provided for @pinLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App Locked'**
  String get pinLockTitle;

  /// No description provided for @pinLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to continue'**
  String get pinLockSubtitle;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN to secure your app'**
  String get pinSetupSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your PIN to confirm'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Try again.'**
  String get pinMismatch;

  /// No description provided for @pinWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinWrong;

  /// No description provided for @pinUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// No description provided for @pinSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get pinSkip;

  /// No description provided for @pinCreate.
  ///
  /// In en, this message translates to:
  /// **'Create PIN'**
  String get pinCreate;

  /// No description provided for @pinChange.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get pinChange;

  /// No description provided for @pinRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get pinRemove;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @pos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get pos;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sales'**
  String get todaySales;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get totalExpenses;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfit;

  /// No description provided for @totalProducts.
  ///
  /// In en, this message translates to:
  /// **'Total Products'**
  String get totalProducts;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @totalCustomers.
  ///
  /// In en, this message translates to:
  /// **'Total Customers'**
  String get totalCustomers;

  /// No description provided for @outstandingDebts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Debts'**
  String get outstandingDebts;

  /// No description provided for @recentSales.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get recentSales;

  /// No description provided for @topProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get topProducts;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSale;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get emptyCart;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @processPayment.
  ///
  /// In en, this message translates to:
  /// **'Process Payment'**
  String get processPayment;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @mpesa.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa'**
  String get mpesa;

  /// No description provided for @tigoPesa.
  ///
  /// In en, this message translates to:
  /// **'Tigo Pesa'**
  String get tigoPesa;

  /// No description provided for @airtelMoney.
  ///
  /// In en, this message translates to:
  /// **'Airtel Money'**
  String get airtelMoney;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @amountReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount Received'**
  String get amountReceived;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @completeSale.
  ///
  /// In en, this message translates to:
  /// **'Complete Sale'**
  String get completeSale;

  /// No description provided for @saleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sale Completed'**
  String get saleCompleted;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @shareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share Receipt'**
  String get shareReceipt;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New Transaction'**
  String get newTransaction;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistory;

  /// No description provided for @invoiceNo.
  ///
  /// In en, this message translates to:
  /// **'Invoice No'**
  String get invoiceNo;

  /// No description provided for @invoiceDate.
  ///
  /// In en, this message translates to:
  /// **'Invoice Date'**
  String get invoiceDate;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-in Customer'**
  String get walkInCustomer;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @deleteInvoice.
  ///
  /// In en, this message translates to:
  /// **'Delete Invoice'**
  String get deleteInvoice;

  /// No description provided for @deleteInvoiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this invoice? Stock will be reversed and this cannot be undone.'**
  String get deleteInvoiceConfirm;

  /// No description provided for @amendInvoice.
  ///
  /// In en, this message translates to:
  /// **'Amend Invoice'**
  String get amendInvoice;

  /// No description provided for @invoiceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Invoice deleted successfully'**
  String get invoiceDeleted;

  /// No description provided for @deletingInvoice.
  ///
  /// In en, this message translates to:
  /// **'Deleting invoice...'**
  String get deletingInvoice;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @deleteProductConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this product from inventory? This cannot be undone.'**
  String get deleteProductConfirm;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @buyingPrice.
  ///
  /// In en, this message translates to:
  /// **'Buying Price'**
  String get buyingPrice;

  /// No description provided for @sellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get sellingPrice;

  /// No description provided for @wholesalePrice.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Price'**
  String get wholesalePrice;

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'CURRENT STOCK'**
  String get currentStock;

  /// No description provided for @reorderLevel.
  ///
  /// In en, this message translates to:
  /// **'Reorder Level'**
  String get reorderLevel;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @taxable.
  ///
  /// In en, this message translates to:
  /// **'Taxable'**
  String get taxable;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @lowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert'**
  String get lowStockAlert;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// No description provided for @stockValue.
  ///
  /// In en, this message translates to:
  /// **'Stock Value'**
  String get stockValue;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stock'**
  String get adjustStock;

  /// No description provided for @stockAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Stock adjusted successfully'**
  String get stockAdjusted;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @loyaltyPoints.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Points'**
  String get loyaltyPoints;

  /// No description provided for @creditBalance.
  ///
  /// In en, this message translates to:
  /// **'Credit Balance'**
  String get creditBalance;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @totalPurchases.
  ///
  /// In en, this message translates to:
  /// **'Total Purchases'**
  String get totalPurchases;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense Category'**
  String get expenseCategory;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @expenseNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get expenseNote;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expenseDate;

  /// No description provided for @profitLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get profitLoss;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @grossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross Profit'**
  String get grossProfit;

  /// No description provided for @netProfitReport.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfitReport;

  /// No description provided for @costOfGoods.
  ///
  /// In en, this message translates to:
  /// **'Cost of Goods'**
  String get costOfGoods;

  /// No description provided for @operatingExpenses.
  ///
  /// In en, this message translates to:
  /// **'Operating Expenses'**
  String get operatingExpenses;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @swahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get swahili;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageChanged;

  /// No description provided for @pinLock.
  ///
  /// In en, this message translates to:
  /// **'PIN Lock'**
  String get pinLock;

  /// No description provided for @appPinLock.
  ///
  /// In en, this message translates to:
  /// **'App PIN Lock'**
  String get appPinLock;

  /// No description provided for @pinLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Locks after 10 min idle'**
  String get pinLockDesc;

  /// No description provided for @pinNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set — tap to create a PIN'**
  String get pinNotSet;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @logoutConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to access your account.'**
  String get logoutConfirmDesc;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get networkError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpired;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get permissionDenied;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Please try again.'**
  String get deleteFailed;

  /// No description provided for @saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get saveSuccess;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Please try again.'**
  String get saveFailed;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @switchBranch.
  ///
  /// In en, this message translates to:
  /// **'Switch Branch'**
  String get switchBranch;

  /// No description provided for @allBranches.
  ///
  /// In en, this message translates to:
  /// **'All Branches'**
  String get allBranches;

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Subscription Expired'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionExpiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired. Please renew to continue.'**
  String get subscriptionExpiredDesc;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @copyInvoiceNo.
  ///
  /// In en, this message translates to:
  /// **'Copy Invoice Number'**
  String get copyInvoiceNo;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @amend.
  ///
  /// In en, this message translates to:
  /// **'Amend'**
  String get amend;

  /// No description provided for @collect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get collect;

  /// No description provided for @collectPayment.
  ///
  /// In en, this message translates to:
  /// **'Collect Payment'**
  String get collectPayment;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get balanceDue;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @noSales.
  ///
  /// In en, this message translates to:
  /// **'No sales found'**
  String get noSales;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProducts;

  /// No description provided for @noCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomers;

  /// No description provided for @noExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses found'**
  String get noExpenses;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @accountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get accountant;

  /// No description provided for @stockManager.
  ///
  /// In en, this message translates to:
  /// **'Stock Manager'**
  String get stockManager;

  /// No description provided for @productProfit.
  ///
  /// In en, this message translates to:
  /// **'Product Profit'**
  String get productProfit;

  /// No description provided for @margin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get margin;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @loss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get loss;

  /// No description provided for @breakEven.
  ///
  /// In en, this message translates to:
  /// **'Break Even'**
  String get breakEven;

  /// No description provided for @pointOfSale.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get pointOfSale;

  /// No description provided for @tapProductToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap a product to add'**
  String get tapProductToAdd;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmpty;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or category'**
  String get tryDifferentSearch;

  /// No description provided for @setQuantity.
  ///
  /// In en, this message translates to:
  /// **'Set Quantity'**
  String get setQuantity;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @outOfStockShort.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get outOfStockShort;

  /// No description provided for @wholesale.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get wholesale;

  /// No description provided for @splitPayment.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get splitPayment;

  /// No description provided for @changeToGive.
  ///
  /// In en, this message translates to:
  /// **'Change to Give'**
  String get changeToGive;

  /// No description provided for @addPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get addPaymentMethod;

  /// No description provided for @confirmSale.
  ///
  /// In en, this message translates to:
  /// **'Confirm Sale'**
  String get confirmSale;

  /// No description provided for @minimumQtyNotMet.
  ///
  /// In en, this message translates to:
  /// **'Minimum Qty Not Met'**
  String get minimumQtyNotMet;

  /// No description provided for @willChargeRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'These items will be charged at retail price:'**
  String get willChargeRetailPrice;

  /// No description provided for @continueAtRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'Continue at retail price?'**
  String get continueAtRetailPrice;

  /// No description provided for @continue_btn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_btn;

  /// No description provided for @addAtLeastOnePayment.
  ///
  /// In en, this message translates to:
  /// **'Add at least one payment amount'**
  String get addAtLeastOnePayment;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please try again.'**
  String get connectionError;

  /// No description provided for @quantityToAdd.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Add'**
  String get quantityToAdd;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'Add Stock'**
  String get addStock;

  /// No description provided for @noAdjustmentHistory.
  ///
  /// In en, this message translates to:
  /// **'No adjustment history'**
  String get noAdjustmentHistory;

  /// No description provided for @editPrice.
  ///
  /// In en, this message translates to:
  /// **'Edit Price'**
  String get editPrice;

  /// No description provided for @resetPrice.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetPrice;

  /// No description provided for @applyPrice.
  ///
  /// In en, this message translates to:
  /// **'Apply Price'**
  String get applyPrice;

  /// No description provided for @standardPrice.
  ///
  /// In en, this message translates to:
  /// **'Standard price'**
  String get standardPrice;

  /// No description provided for @enterValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get enterValidPrice;

  /// No description provided for @salesHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistoryTitle;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'records'**
  String get records;

  /// No description provided for @paid_count.
  ///
  /// In en, this message translates to:
  /// **'paid'**
  String get paid_count;

  /// No description provided for @connectionErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionErrorTitle;

  /// No description provided for @tryDifferentFilter.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter or time range'**
  String get tryDifferentFilter;

  /// No description provided for @deletingInvoiceMsg.
  ///
  /// In en, this message translates to:
  /// **'Deleting invoice...'**
  String get deletingInvoiceMsg;

  /// No description provided for @collectAmount.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get collectAmount;

  /// No description provided for @invoiceNumberCopied.
  ///
  /// In en, this message translates to:
  /// **'Invoice number copied'**
  String get invoiceNumberCopied;

  /// No description provided for @invoiceAmended.
  ///
  /// In en, this message translates to:
  /// **'Invoice amended successfully'**
  String get invoiceAmended;

  /// No description provided for @items_section.
  ///
  /// In en, this message translates to:
  /// **'ITEMS'**
  String get items_section;

  /// No description provided for @paymentMethod_section.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT METHOD'**
  String get paymentMethod_section;

  /// No description provided for @notes_section.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get notes_section;

  /// No description provided for @collectPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect Payment'**
  String get collectPaymentTitle;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @amountTzs.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT (TZS)'**
  String get amountTzs;

  /// No description provided for @txRef.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION REFERENCE (OPTIONAL)'**
  String get txRef;

  /// No description provided for @confirmCollection.
  ///
  /// In en, this message translates to:
  /// **'Confirm Collection'**
  String get confirmCollection;

  /// No description provided for @paymentCollected.
  ///
  /// In en, this message translates to:
  /// **'Payment collected successfully'**
  String get paymentCollected;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose export format. CSV opens in Excel/Sheets. HTML can be saved as PDF from your browser.'**
  String get exportFormat;

  /// No description provided for @couldNotOpenExport.
  ///
  /// In en, this message translates to:
  /// **'Could not open export. Try again.'**
  String get couldNotOpenExport;

  /// No description provided for @manageInventory.
  ///
  /// In en, this message translates to:
  /// **'Manage inventory & stock levels'**
  String get manageInventory;

  /// No description provided for @productAdded.
  ///
  /// In en, this message translates to:
  /// **'Product added!'**
  String get productAdded;

  /// No description provided for @productUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated!'**
  String get productUpdated;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductSuccess.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get deleteProductSuccess;

  /// No description provided for @deleteFail.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Try again.'**
  String get deleteFail;

  /// No description provided for @reorderAt.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorderAt;

  /// No description provided for @adjustStockBtn.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stock'**
  String get adjustStockBtn;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetails;

  /// No description provided for @addProductImage.
  ///
  /// In en, this message translates to:
  /// **'Add Product Image'**
  String get addProductImage;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @addProducts.
  ///
  /// In en, this message translates to:
  /// **'Add Products'**
  String get addProducts;

  /// No description provided for @fillDetails.
  ///
  /// In en, this message translates to:
  /// **'Fill details · tap + to add more'**
  String get fillDetails;

  /// No description provided for @addAnotherProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Another Product'**
  String get addAnotherProduct;

  /// No description provided for @wholesaleHint.
  ///
  /// In en, this message translates to:
  /// **'Wholesale activates when qty ≥ min (leave blank to skip)'**
  String get wholesaleHint;

  /// No description provided for @alertLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Alert level triggers Low Stock warning'**
  String get alertLevelHint;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @submittedForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submitted for manager approval'**
  String get submittedForApproval;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select Reason'**
  String get selectReason;

  /// No description provided for @correctEntry.
  ///
  /// In en, this message translates to:
  /// **'Correct entry'**
  String get correctEntry;

  /// No description provided for @setToExactQty.
  ///
  /// In en, this message translates to:
  /// **'Set to exact quantity — use this to correct a wrong entry'**
  String get setToExactQty;

  /// No description provided for @newQty.
  ///
  /// In en, this message translates to:
  /// **'New qty'**
  String get newQty;

  /// No description provided for @confirmAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Adjustment'**
  String get confirmAdjustment;

  /// No description provided for @noAdjustmentHistoryMsg.
  ///
  /// In en, this message translates to:
  /// **'No adjustment history'**
  String get noAdjustmentHistoryMsg;

  /// No description provided for @confirmWithPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm with PIN'**
  String get confirmWithPin;

  /// No description provided for @enterPinToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to confirm this adjustment'**
  String get enterPinToConfirm;

  /// No description provided for @editProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Products'**
  String get editProductsTitle;

  /// No description provided for @updateProductDetails.
  ///
  /// In en, this message translates to:
  /// **'Update product details & prices'**
  String get updateProductDetails;

  /// No description provided for @youAreEditingFor.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE EDITING FOR'**
  String get youAreEditingFor;

  /// No description provided for @activeBranch.
  ///
  /// In en, this message translates to:
  /// **'Active Branch'**
  String get activeBranch;

  /// No description provided for @editAnotherProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Another Product'**
  String get editAnotherProduct;

  /// No description provided for @pickProductToEdit.
  ///
  /// In en, this message translates to:
  /// **'Pick a product to edit'**
  String get pickProductToEdit;

  /// No description provided for @noProductsFoundMsg.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFoundMsg;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @addExpenseBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpenseBtn;

  /// No description provided for @noExpensesMsg.
  ///
  /// In en, this message translates to:
  /// **'No expenses found'**
  String get noExpensesMsg;

  /// No description provided for @tapToRecordExpense.
  ///
  /// In en, this message translates to:
  /// **'Tap + Add Expense to record one'**
  String get tapToRecordExpense;

  /// No description provided for @recordExpense.
  ///
  /// In en, this message translates to:
  /// **'Record Expense'**
  String get recordExpense;

  /// No description provided for @trackSpending.
  ///
  /// In en, this message translates to:
  /// **'Track your business spending'**
  String get trackSpending;

  /// No description provided for @addNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Add new category'**
  String get addNewCategory;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @profitByProduct.
  ///
  /// In en, this message translates to:
  /// **'Profit by Product'**
  String get profitByProduct;

  /// No description provided for @seeProductProfit.
  ///
  /// In en, this message translates to:
  /// **'See which products make the most profit'**
  String get seeProductProfit;

  /// No description provided for @thisMonthBtn.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonthBtn;

  /// No description provided for @netProfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfitTitle;

  /// No description provided for @dailyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Daily Revenue'**
  String get dailyRevenue;

  /// No description provided for @thisWeekBtn.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeekBtn;

  /// No description provided for @revenueVsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Revenue vs Expenses'**
  String get revenueVsExpenses;

  /// No description provided for @usersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users & Permissions'**
  String get usersTitle;

  /// No description provided for @manageStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage staff access'**
  String get manageStaff;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User?'**
  String get deleteUser;

  /// No description provided for @allBranchesOpt.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get allBranchesOpt;

  /// No description provided for @userCanChangePassword.
  ///
  /// In en, this message translates to:
  /// **'User can change password after logging in'**
  String get userCanChangePassword;

  /// No description provided for @createUser.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// No description provided for @savePermissions.
  ///
  /// In en, this message translates to:
  /// **'Save Permissions'**
  String get savePermissions;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get editUser;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @addNewUser.
  ///
  /// In en, this message translates to:
  /// **'Add New User'**
  String get addNewUser;

  /// No description provided for @createStaffAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a staff account'**
  String get createStaffAccount;

  /// No description provided for @branchManagement.
  ///
  /// In en, this message translates to:
  /// **'Branch Management'**
  String get branchManagement;

  /// No description provided for @manageLocations.
  ///
  /// In en, this message translates to:
  /// **'Manage locations & outlets'**
  String get manageLocations;

  /// No description provided for @addBranch.
  ///
  /// In en, this message translates to:
  /// **'Add Branch'**
  String get addBranch;

  /// No description provided for @deleteBranch.
  ///
  /// In en, this message translates to:
  /// **'Delete Branch?'**
  String get deleteBranch;

  /// No description provided for @mainBranch.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get mainBranch;

  /// No description provided for @profitByProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit by Product'**
  String get profitByProductTitle;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProducts;

  /// No description provided for @netProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT'**
  String get netProfitLabel;

  /// No description provided for @unitsSold.
  ///
  /// In en, this message translates to:
  /// **'units sold'**
  String get unitsSold;

  /// No description provided for @topPerformers.
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get topPerformers;

  /// No description provided for @byProfit.
  ///
  /// In en, this message translates to:
  /// **'by profit'**
  String get byProfit;

  /// No description provided for @noSalesData.
  ///
  /// In en, this message translates to:
  /// **'No sales data'**
  String get noSalesData;

  /// No description provided for @tryDifferentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Try a different period to see profit distribution.'**
  String get tryDifferentPeriod;

  /// No description provided for @changePeriod.
  ///
  /// In en, this message translates to:
  /// **'Change period'**
  String get changePeriod;

  /// No description provided for @couldntLoadData.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load data'**
  String get couldntLoadData;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @todaysExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Expenses'**
  String get todaysExpensesLabel;

  /// No description provided for @thisWeeksExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Expenses'**
  String get thisWeeksExpensesLabel;

  /// No description provided for @thisMonthsExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'This Month\'s Expenses'**
  String get thisMonthsExpensesLabel;

  /// No description provided for @allExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'All Expenses'**
  String get allExpensesLabel;

  /// No description provided for @expensesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'expenses'**
  String get expensesCountLabel;

  /// No description provided for @averageLabel.
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get averageLabel;

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'period'**
  String get periodLabel;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get greetingEvening;

  /// No description provided for @todaysRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S REVENUE'**
  String get todaysRevenueLabel;

  /// No description provided for @myRecentSales.
  ///
  /// In en, this message translates to:
  /// **'My Recent Sales'**
  String get myRecentSales;

  /// No description provided for @switchBranchBtn.
  ///
  /// In en, this message translates to:
  /// **'Switch Branch'**
  String get switchBranchBtn;

  /// No description provided for @pendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get pendingApprovals;

  /// No description provided for @stockAdjustmentsNeedReview.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustments from branches need your review'**
  String get stockAdjustmentsNeedReview;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @branchLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Branch Leaderboard'**
  String get branchLeaderboard;

  /// No description provided for @todayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todayRevenue;

  /// No description provided for @weeklyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Weekly Revenue'**
  String get weeklyRevenue;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACTIONS'**
  String get quickActions;

  /// No description provided for @newSaleBtn.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSaleBtn;

  /// No description provided for @liveLabel.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveLabel;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayLabel;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'MONTH'**
  String get monthLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get statusLabel;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @txns.
  ///
  /// In en, this message translates to:
  /// **'txns'**
  String get txns;

  /// No description provided for @avgSale.
  ///
  /// In en, this message translates to:
  /// **'AVG SALE'**
  String get avgSale;

  /// No description provided for @myShift.
  ///
  /// In en, this message translates to:
  /// **'MY SHIFT'**
  String get myShift;

  /// No description provided for @mySalesToday.
  ///
  /// In en, this message translates to:
  /// **'MY SALES TODAY'**
  String get mySalesToday;

  /// No description provided for @branchToday.
  ///
  /// In en, this message translates to:
  /// **'BRANCH TODAY'**
  String get branchToday;

  /// No description provided for @topByCapital.
  ///
  /// In en, this message translates to:
  /// **'Top by Capital'**
  String get topByCapital;

  /// No description provided for @byProductArrow.
  ///
  /// In en, this message translates to:
  /// **'by product →'**
  String get byProductArrow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
