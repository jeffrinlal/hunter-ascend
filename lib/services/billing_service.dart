import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Centralized product IDs for Hunter Ascend subscriptions.
/// These must match the product IDs configured in Google Play Console.
class BillingProducts {
  BillingProducts._();

  static const String proMonthly = 'com.hunterascend.pro_monthly';
  static const String maxMonthly = 'com.hunterascend.max_monthly';

  /// All subscription product IDs the app supports.
  static const Set<String> all = {proMonthly, maxMonthly};
}

/// The result of a billing operation (purchase, restore, etc.).
enum BillingStatus {
  /// Operation completed successfully.
  success,

  /// Purchase is pending (e.g., slow payment method).
  pending,

  /// User cancelled the purchase flow.
  userCanceled,

  /// An error occurred (see [BillingResult.error] for details).
  error,

  /// The store/billing is unavailable on this device.
  storeUnavailable,

  /// The requested product was not found.
  productNotFound,

  /// A purchase for this product already exists.
  duplicatePurchase,
}

/// Structured result of a billing operation.
class BillingResult {
  final BillingStatus status;
  final String? error;
  final PurchaseDetails? purchase;

  const BillingResult({
    required this.status,
    this.error,
    this.purchase,
  });

  bool get isSuccess => status == BillingStatus.success;
  bool get isPending => status == BillingStatus.pending;
}

/// Singleton service that encapsulates all Google Play Billing communication.
///
/// UI code (e.g., the membership screen) communicates ONLY with this service —
/// never directly with [InAppPurchase] APIs.
///
/// This service does NOT:
/// - Write to Firestore.
/// - Grant membership.
/// - Call MembershipService.
///
/// It only manages the billing connection, product loading, purchase flow,
/// and exposes verified purchase data for the next layer to handle.
class BillingService {
  BillingService._();

  /// The single shared instance.
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Whether the billing store is available on this device.
  bool _storeAvailable = false;

  /// Whether products are currently being loaded.
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  /// The last error message (null if no error).
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// Whether the store is available and ready.
  bool get isAvailable => _storeAvailable && _initialized;

  /// Loaded product details (populated after [initialize]).
  ProductDetails? proProduct;
  ProductDetails? maxProduct;

  /// Stream controller for purchase events that the UI/membership layer
  /// can listen to. Emits [BillingResult] for each purchase update.
  final StreamController<BillingResult> _purchaseResultController =
      StreamController<BillingResult>.broadcast();

  /// Stream of purchase results. Subscribe to this to handle completed,
  /// pending, or failed purchases.
  Stream<BillingResult> get purchaseResults => _purchaseResultController.stream;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Initializes the billing connection, loads products, and starts listening
  /// to the purchase stream.
  ///
  /// Idempotent — safe to call multiple times. Returns immediately on
  /// subsequent calls if already initialized.
  Future<void> initialize() async {
    if (_initialized) return;

    _storeAvailable = await _iap.isAvailable();

    if (!_storeAvailable) {
      debugPrint('BillingService: Store not available on this device.');
      _initialized = true; // Mark as initialized even if unavailable.
      return;
    }

    // Start listening to the purchase stream BEFORE loading products,
    // so we don't miss any pending purchase updates from previous sessions.
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription = null,
      onError: (error) {
        debugPrint('BillingService: Purchase stream error — $error');
        lastError.value = error.toString();
      },
    );

    // Load available products.
    await loadProducts();

    _initialized = true;
    debugPrint('BillingService: Initialized successfully.');
  }

  // ── Product Loading ──────────────────────────────────────────────────────

  /// Fetches product details from Google Play for all configured product IDs.
  ///
  /// Populates [proProduct] and [maxProduct] on success. Can be called again
  /// to refresh prices (e.g., after a locale change).
  Future<void> loadProducts() async {
    if (!_storeAvailable) return;

    isLoading.value = true;
    lastError.value = null;

    try {
      final response = await _iap.queryProductDetails(BillingProducts.all);

      if (response.error != null) {
        debugPrint('BillingService: Product query error — ${response.error!.message}');
        lastError.value = response.error!.message;
        isLoading.value = false;
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('BillingService: Products not found — ${response.notFoundIDs}');
      }

      // Map loaded products to named fields.
      proProduct = null;
      maxProduct = null;

      for (final product in response.productDetails) {
        if (product.id == BillingProducts.proMonthly) {
          proProduct = product;
        } else if (product.id == BillingProducts.maxMonthly) {
          maxProduct = product;
        }
      }

      debugPrint('BillingService: Products loaded — '
          'Pro: ${proProduct != null ? proProduct!.price : "not found"}, '
          'Max: ${maxProduct != null ? maxProduct!.price : "not found"}');
    } catch (e) {
      debugPrint('BillingService: loadProducts exception — $e');
      lastError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Purchase Flow ────────────────────────────────────────────────────────

  /// Initiates a subscription purchase for the given product.
  ///
  /// Returns a [BillingResult] indicating the immediate result of launching
  /// the purchase flow. The actual purchase completion arrives asynchronously
  /// via [purchaseResults] stream.
  Future<BillingResult> purchase(ProductDetails product) async {
    if (!_storeAvailable) {
      return const BillingResult(
        status: BillingStatus.storeUnavailable,
        error: 'Billing is not available on this device.',
      );
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        return const BillingResult(
          status: BillingStatus.error,
          error: 'Failed to initiate purchase.',
        );
      }

      // Purchase flow launched successfully. The result will arrive via
      // the purchase stream and be emitted on [purchaseResults].
      return const BillingResult(status: BillingStatus.pending);
    } catch (e) {
      debugPrint('BillingService: purchase exception — $e');
      return BillingResult(
        status: BillingStatus.error,
        error: e.toString(),
      );
    }
  }

  // ── Restore Purchases ────────────────────────────────────────────────────

  /// Restores previous purchases (for users who reinstall or switch devices).
  ///
  /// Restored purchases arrive via [purchaseResults] stream with
  /// [PurchaseStatus.restored].
  Future<BillingResult> restorePurchases() async {
    if (!_storeAvailable) {
      return const BillingResult(
        status: BillingStatus.storeUnavailable,
        error: 'Billing is not available on this device.',
      );
    }

    try {
      await _iap.restorePurchases();
      // Restored purchases arrive asynchronously via the purchase stream.
      return const BillingResult(status: BillingStatus.success);
    } catch (e) {
      debugPrint('BillingService: restorePurchases exception — $e');
      return BillingResult(
        status: BillingStatus.error,
        error: e.toString(),
      );
    }
  }

  // ── Purchase Stream Handling ─────────────────────────────────────────────

  /// Processes purchase updates from the [InAppPurchase.purchaseStream].
  ///
  /// Emits structured [BillingResult] events on [purchaseResults] for each
  /// update. Does NOT grant membership or write to Firestore — that is the
  /// responsibility of the consumer (Phase 7).
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // A successful purchase or restore. The consumer must:
          // 1. Send the purchase token to the verifyPurchase Cloud Function.
          // 2. On success, call completePurchase() to acknowledge.
          // 3. Call MembershipService.instance.reload().
          _purchaseResultController.add(BillingResult(
            status: BillingStatus.success,
            purchase: purchase,
          ));
          break;

        case PurchaseStatus.pending:
          // Purchase is pending (e.g., awaiting payment processing).
          _purchaseResultController.add(BillingResult(
            status: BillingStatus.pending,
            purchase: purchase,
          ));
          break;

        case PurchaseStatus.error:
          // Purchase failed.
          final errorMessage = purchase.error?.message ?? 'Unknown error';
          debugPrint('BillingService: Purchase error — $errorMessage');
          _purchaseResultController.add(BillingResult(
            status: BillingStatus.error,
            error: errorMessage,
            purchase: purchase,
          ));
          // Still need to complete the purchase to remove it from the queue.
          _iap.completePurchase(purchase);
          break;

        case PurchaseStatus.canceled:
          // User cancelled the purchase.
          _purchaseResultController.add(const BillingResult(
            status: BillingStatus.userCanceled,
          ));
          break;
      }
    }
  }

  // ── Acknowledgement ──────────────────────────────────────────────────────

  /// Acknowledges a purchase with Google Play.
  ///
  /// Must be called after successful backend verification. If not called
  /// within 3 days, Google automatically refunds the purchase.
  ///
  /// This is exposed so the consumer (Phase 7) can call it after verifyPurchase
  /// Cloud Function succeeds.
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
      debugPrint('BillingService: Purchase acknowledged.');
    }
  }

  // ── Disposal ─────────────────────────────────────────────────────────────

  /// Cancels the purchase stream subscription and cleans up resources.
  ///
  /// Call this only on app shutdown. The singleton typically lives for the
  /// entire app lifecycle.
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _purchaseResultController.close();
    debugPrint('BillingService: Disposed.');
  }
}
