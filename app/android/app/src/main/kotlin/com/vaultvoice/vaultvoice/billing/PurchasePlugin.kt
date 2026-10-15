package com.vaultvoice.vaultvoice.billing

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.android.billingclient.api.*
import com.vaultvoice.vaultvoice.BuildConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.security.KeyFactory
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.security.spec.X509EncodedKeySpec
import android.util.Base64

// Play Billing 9.1.0 API, verified against official integration guide 2026-10-14.
class PurchasePlugin : FlutterPlugin, ActivityAware, PurchaseHostApi, PurchasesUpdatedListener {
    private lateinit var context: Context
    private lateinit var billing: BillingClient
    private var activity: Activity? = null
    private var updates: PurchaseFlutterApi? = null
    private var pending: ((Result<StorePurchaseOutcome>) -> Unit)? = null
    private val waiters = mutableListOf<(Boolean) -> Unit>()
    private var connecting = false
    private val ids = mapOf("vv_pro_annual" to BillingClient.ProductType.SUBS,
        "vv_pro_lifetime" to BillingClient.ProductType.INAPP)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        updates = PurchaseFlutterApi(binding.binaryMessenger)
        PurchaseHostApi.setUp(binding.binaryMessenger, this)
        billing = BillingClient.newBuilder(context).setListener(this)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection().build()
        // Commercial Dart startup queries immediately; personal builds never
        // connect unless the user explicitly opens the store paywall.
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PurchaseHostApi.setUp(binding.binaryMessenger, null)
        billing.endConnection()
        updates = null
        finishPurchase(Result.failure(error("unavailable")))
        val callbacks = waiters.toList(); waiters.clear(); connecting = false
        callbacks.forEach { it(false) }
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onDetachedFromActivity() { activity = null }

    private fun error(code: String) = FlutterError(code, "Store operation failed", null)
    private fun ok(result: BillingResult) = result.responseCode == BillingClient.BillingResponseCode.OK
    private fun connected(work: (Boolean) -> Unit) {
        if (billing.isReady) { work(true); return }
        waiters.add(work)
        if (connecting) return
        connecting = true
        billing.startConnection(object : BillingClientStateListener {
            override fun onBillingServiceDisconnected() {
                connecting = false
                val callbacks = waiters.toList(); waiters.clear()
                callbacks.forEach { it(false) }
            }
            override fun onBillingSetupFinished(result: BillingResult) {
                connecting = false
                val callbacks = waiters.toList(); waiters.clear()
                callbacks.forEach { it(ok(result)) }
            }
        })
    }
    private fun key(): RSAPublicKey? = try {
        val encoded = BuildConfig.PLAY_LICENSE_KEY_REVERSED.reversed()
        val result = KeyFactory.getInstance("RSA").generatePublic(
            X509EncodedKeySpec(Base64.decode(encoded, Base64.DEFAULT))) as RSAPublicKey
        result.takeIf { it.modulus.bitLength() >= 2048 }
    } catch (_: Exception) { null }

    private fun verified(purchase: Purchase): Boolean = try {
        val publicKey = key()
        // Play's existing wire protocol uses SHA1withRSA; verification only.
        publicKey != null && org.json.JSONObject(purchase.originalJson)
            .optString("packageName") == context.packageName &&
            Signature.getInstance("SHA1withRSA").run {
                initVerify(publicKey)
                update(purchase.originalJson.toByteArray(Charsets.UTF_8))
                verify(Base64.decode(purchase.signature, Base64.DEFAULT))
            }
    } catch (_: Exception) { false }

    private fun online(): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = manager.getNetworkCapabilities(manager.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun details(callback: (Result<List<ProductDetails>>) -> Unit) {
        if (key() == null) { callback(Result.failure(error("verification_failed"))); return }
        connected { ready ->
            if (!ready) { callback(Result.failure(error("unavailable"))); return@connected }
            // Mixed product types must be queried separately (Play contract).
            val found = mutableListOf<ProductDetails>()
            fun query(type: String) {
                val typed = QueryProductDetailsParams.newBuilder().setProductList(ids.filterValues { it == type }.map { (id, _) ->
                    QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(type).build()
                }).build()
                billing.queryProductDetailsAsync(typed) { result, response ->
                    if (!ok(result)) { callback(Result.failure(error("unavailable"))); return@queryProductDetailsAsync }
                    found.addAll(response.productDetailsList)
                    if (type == BillingClient.ProductType.SUBS) query(BillingClient.ProductType.INAPP)
                    else callback(Result.success(found))
                }
            }
            query(BillingClient.ProductType.SUBS)
        }
    }
    // PRODUCT-DECISION: offer the regular annual base plan only, no introductory
    // trials or offers whose first-phase price could misrepresent renewal cost.
    private fun annualOffer(p: ProductDetails) = p.subscriptionOfferDetails?.firstOrNull {
        it.offerId == null && it.pricingPhases.pricingPhaseList.size == 1 &&
            it.pricingPhases.pricingPhaseList.first().billingPeriod == "P1Y" &&
            it.pricingPhases.pricingPhaseList.first().recurrenceMode == ProductDetails.RecurrenceMode.INFINITE_RECURRING
    }

    override fun products(callback: (Result<List<StoreProductMessage>>) -> Unit) {
        details { result -> callback(result.map { products -> products.mapNotNull { p ->
            val price = if (p.productId == "vv_pro_annual")
                annualOffer(p)?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice
                else p.oneTimePurchaseOfferDetails?.formattedPrice
            price?.let { StoreProductMessage(p.productId, it) }
        } }) }
    }

    override fun currentEntitlements(callback: (Result<List<StoreEntitlementMessage>>) -> Unit) {
        if (!online()) { callback(Result.failure(error("unavailable"))); return }
        if (key() == null) { callback(Result.failure(error("verification_failed"))); return }
        connected { ready ->
            if (!ready) { callback(Result.failure(error("unavailable"))); return@connected }
            val purchases = mutableListOf<Purchase>()
            fun query(type: String) {
                billing.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(type).build()) { result, found ->
                    if (!ok(result)) { callback(Result.failure(error("unavailable"))); return@queryPurchasesAsync }
                    purchases.addAll(found)
                    if (type == BillingClient.ProductType.SUBS) query(BillingClient.ProductType.INAPP)
                    else deliver(purchases, callback)
                }
            }
            query(BillingClient.ProductType.SUBS)
        }
    }
    private fun deliver(purchases: List<Purchase>, callback: (Result<List<StoreEntitlementMessage>>) -> Unit) {
        val active = purchases.filter { p -> p.products.any { ids.containsKey(it) } &&
            p.purchaseState == Purchase.PurchaseState.PURCHASED && !p.isSuspended }
        if (active.any { !verified(it) }) { callback(Result.failure(error("verification_failed"))); return }
        val owned = mutableListOf<StoreEntitlementMessage>()
        fun next(index: Int) {
            if (index == active.size) { callback(Result.success(owned)); return }
            val purchase = active[index]
            fun append() {
                purchase.products.filter { ids.containsKey(it) }.forEach { id ->
                    // BillingClient has no signed expiry. Bounded one-day lease:
                    // ADR-LIC-02; NEVER derive annual expiry from purchaseTime.
                    owned.add(StoreEntitlementMessage(id,
                        if (id == "vv_pro_annual") System.currentTimeMillis() + 86_400_000L else null))
                }
                next(index + 1)
            }
            if (purchase.isAcknowledged) append()
            else billing.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken).build()) { result ->
                if (ok(result)) append() else callback(Result.failure(error("unavailable")))
            }
        }
        next(0)
    }
    override fun purchase(productId: String, callback: (Result<StorePurchaseOutcome>) -> Unit) {
        if (!ids.containsKey(productId) || pending != null || activity == null) {
            callback(Result.failure(error("unavailable"))); return
        }
        details { result ->
            val product = result.getOrNull()?.firstOrNull { it.productId == productId }
            val host = activity
            if (product == null || host == null) { callback(Result.failure(error("unavailable"))); return@details }
            val item = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product)
            if (productId == "vv_pro_annual") {
                val offer = annualOffer(product)
                if (offer == null) { callback(Result.failure(error("unavailable"))); return@details }
                item.setOfferToken(offer.offerToken)
            }
            pending = callback
            val launched = billing.launchBillingFlow(host,
                BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(item.build())).build())
            if (!ok(launched)) finishPurchase(Result.failure(error("unavailable")))
        }
    }
    private fun finishPurchase(result: Result<StorePurchaseOutcome>) {
        val callback = pending; pending = null; callback?.invoke(result)
    }
    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            finishPurchase(Result.success(StorePurchaseOutcome.CANCELLED)); return
        }
        if (!ok(result)) { finishPurchase(Result.failure(error("unavailable"))); return }
        val outcome = if (purchases.orEmpty().any { it.purchaseState == Purchase.PurchaseState.PURCHASED })
            StorePurchaseOutcome.PURCHASED else StorePurchaseOutcome.PENDING
        finishPurchase(Result.success(outcome))
        updates?.changed { }
    }
    override fun restore(callback: (Result<Unit>) -> Unit) {
        currentEntitlements { result -> callback(result.map { }) }
    }
}
