import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hunter_ascend/services/membership_service.dart';

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

/// Singleton service that encapsulates all Google Play Billing communication
/// and backend purchase verification.
///
/// UI code (e.g., the membership screen) communicates ONLY with this service —
/// never directly with [InAppPurchase] APIs or Cloud Functions.
///
/// This service does NOT:
/// - Write to Firestore directly.
/// - Grant membership locally.
///
/// It delegates membership activation to the verifyPurchase Cloud Function,
/// which is the only authority that writes membership fields to Firestore.
class BillingService {
  BillingService._();

  /// The single shared instance.
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Whether the billing store is available on this device.
  bool _storeAvailable = false;

  /// Whether a purchase is currently being verified with the backend.
  final ValueNotifier<bool> isVerifying = ValueNotifier<bool>(false);

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

  /// Stream of purchase results. Subscribe to this to handle UI updates
  /// (success messages, error dialogs, loading states).
  Stream<BillingResult> get purchaseResults => _purchaseResultController.stream;

  /// Guards against duplicate verification for the same purchase token.
  final Set<String> _verifyingTokens = {};

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
  /// For successful purchases, automatically triggers backend verification.
  /// The consumer listens to [purchaseResults] for the final outcome.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // A successful purchase or restore — verify with the backend.
          _verifyWithBackend(purchase);
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
          // Complete the purchase to remove it from the pending queue.
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

  // ── Backend Verification ─────────────────────────────────────────────────

  /// Sends a successful purchase to the verifyPurchase Cloud Function for
  /// server-side validation. On success, reloads MembershipService and
  /// acknowledges the purchase. On failure, emits an error result.
  ///
  /// This method is idempotent per purchase token — duplicate calls for the
  /// same token are ignored.
  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    // Extract the purchase token (platform-specific).
    final String? purchaseToken = purchase.verificationData.serverVerificationData;
    final String productId = purchase.productID;

    if (purchaseToken == null || purchaseToken.isEmpty) {
      debugPrint('BillingService: No purchase token available for verification.');
      _purchaseResultController.add(const BillingResult(
        status: BillingStatus.error,
        error: 'Purchase token not available.',
      ));
      return;
    }

    // Deduplicate — don't verify the same token twice concurrently.
    if (_verifyingTokens.contains(purchaseToken)) {
      debugPrint('BillingService: Verification already in progress for this token.');
      return;
    }
    _verifyingTokens.add(purchaseToken);
    isVerifying.value = true;
    lastError.value = null;

    try {
      // Call the verifyPurchase Cloud Function.
      final callable = _functions.httpsCallable('verifyPurchase');
      final response = await callable.call<Map<String, dynamic>>({
        'purchaseToken': purchaseToken,
        'productId': productId,
      });

      final data = response.data;
      final success = data['success'] == true;

      if (success) {
        // Backend verified and updated Firestore.
        // Acknowledge the purchase with Google Play.
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
          debugPrint('BillingService: Purchase acknowledged with Google Play.');
        }

        // Reload MembershipService to pick up the new tier from Firestore.
        await MembershipService.instance.reload();

        debugPrint('BillingService: Verification successful — '
            'plan: ${data['plan']}, expires: ${data['expiryDate']}');

        _purchaseResultController.add(BillingResult(
          status: BillingStatus.success,
          purchase: purchase,
        ));
      } else {
        // Backend rejected the purchase.
        final error = data['error']?.toString() ?? 'Verification failed';
        debugPrint('BillingService: Backend rejected purchase — $error');

        _purchaseResultController.add(BillingResult(
          status: BillingStatus.error,
          error: _userFriendlyError(error),
          purchase: purchase,
        ));
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('BillingService: Cloud Function error — ${e.code}: ${e.message}');
      _purchaseResultController.add(BillingResult(
        status: BillingStatus.error,
        error: _userFriendlyError(e.code),
        purchase: purchase,
      ));
    } catch (e) {
      debugPrint('BillingService: Verification exception — $e');
      _purchaseResultController.add(BillingResult(
        status: BillingStatus.error,
        error: 'Could not verify purchase. Please check your connection and try again.',
        purchase: purchase,
      ));
    } finally {
      _verifyingTokens.remove(purchaseToken);
      isVerifying.value = _verifyingTokens.isNotEmpty;
    }
  }

  /// Maps backend error codes to user-friendly messages.
  String _userFriendlyError(String code) {
    switch (code) {
      case 'invalid_token':
        return 'The purchase could not be verified. Please try again.';
      case 'expired':
        return 'This subscription has expired.';
      case 'payment_pending':
        return 'Payment is still processing. Please wait.';
      case 'billing_issue':
        return 'There is a billing issue with your subscription.';
      case 'unknown_product':
        return 'This product is not recognized.';
      case 'unauthenticated':
        return 'Please sign in to verify your purchase.';
      case 'internal':
        return 'Server error. Please try again later.';
      default:
        return 'Purchase verification failed. Please try again.';
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
