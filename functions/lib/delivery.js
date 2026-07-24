"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackDelivery = exports.cancelDelivery = exports.bookInstantDelivery = exports.getShippingRates = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const v2_1 = require("firebase-functions/v2");
const params_1 = require("firebase-functions/params");
const axios_1 = __importDefault(require("axios"));
const db = (0, firestore_1.getFirestore)();
// ─────────────────────────────────────────────────────────────────
// Setup:
//   firebase functions:secrets:set GOSEND_CLIENT_ID
//   firebase functions:secrets:set GOSEND_CLIENT_SECRET
//   firebase functions:secrets:set GOSEND_MERCHANT_ID
//   firebase functions:secrets:set GRAB_CLIENT_ID
//   firebase functions:secrets:set GRAB_CLIENT_SECRET
//   firebase functions:secrets:set GRAB_MERCHANT_ID
// ─────────────────────────────────────────────────────────────────
const GOSEND_CLIENT_ID = (0, params_1.defineString)("GOSEND_CLIENT_ID");
const GOSEND_CLIENT_SECRET = (0, params_1.defineString)("GOSEND_CLIENT_SECRET");
const GOSEND_MERCHANT_ID = (0, params_1.defineString)("GOSEND_MERCHANT_ID");
const GOSEND_IS_PRODUCTION = (0, params_1.defineString)("GOSEND_IS_PRODUCTION", { default: "false" });
const GRAB_CLIENT_ID = (0, params_1.defineString)("GRAB_CLIENT_ID");
const GRAB_CLIENT_SECRET = (0, params_1.defineString)("GRAB_CLIENT_SECRET");
const GRAB_MERCHANT_ID = (0, params_1.defineString)("GRAB_MERCHANT_ID");
const GRAB_IS_PRODUCTION = (0, params_1.defineString)("GRAB_IS_PRODUCTION", { default: "false" });
// ─── Config helpers ───────────────────────────────────────────────
const goSendBase = () => GOSEND_IS_PRODUCTION.value() === "true"
    ? "https://api.gojek.com"
    : "https://api-sandbox.gojek.com";
const grabBase = () => GRAB_IS_PRODUCTION.value() === "true"
    ? "https://api.grab.com"
    : "https://partner-api.grab.com";
// ─── Token helpers ────────────────────────────────────────────────
async function getGoSendToken() {
    const r = await axios_1.default.post(`${goSendBase()}/auth/oauth2/token`, new URLSearchParams({
        grant_type: "client_credentials",
        client_id: GOSEND_CLIENT_ID.value(),
        client_secret: GOSEND_CLIENT_SECRET.value(),
        scope: "gojek.driver.order.create",
    }), { headers: { "Content-Type": "application/x-www-form-urlencoded" } });
    return r.data.access_token;
}
async function getGrabToken() {
    const r = await axios_1.default.post(`${grabBase()}/grabid/v1/oauth2/token`, {
        client_id: GRAB_CLIENT_ID.value(),
        client_secret: GRAB_CLIENT_SECRET.value(),
        grant_type: "client_credentials",
        scope: "grab_express.partner_deliveries",
    }, { headers: { "Content-Type": "application/json" } });
    return r.data.access_token;
}
// ─────────────────────────────────────────────────────────────────
// FUNCTION 1: Hitung ongkir GoSend + Grab
// ─────────────────────────────────────────────────────────────────
exports.getShippingRates = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    }
    const { origin, destination, weightKg = 1 } = request.data;
    if (!origin?.latitude || !destination?.latitude) {
        throw new https_1.HttpsError("invalid-argument", "origin dan destination wajib diisi.");
    }
    const [goResult, grabResult] = await Promise.allSettled([
        fetchGoSendRates(origin, destination, weightKg),
        fetchGrabRates(origin, destination, weightKg),
    ]);
    const rates = [];
    if (goResult.status === "fulfilled") {
        rates.push(...goResult.value);
    }
    else {
        v2_1.logger.warn("GoSend rate gagal:", goResult.reason);
        rates.push({ provider: "gosend", serviceType: "instant", serviceName: "GoSend Instant", price: 0, currency: "IDR", estimatedDelivery: "-", available: false, errorMessage: "Layanan GoSend tidak tersedia." });
    }
    if (grabResult.status === "fulfilled") {
        rates.push(...grabResult.value);
    }
    else {
        v2_1.logger.warn("Grab rate gagal:", grabResult.reason);
        rates.push({ provider: "grab", serviceType: "instant", serviceName: "GrabExpress", price: 0, currency: "IDR", estimatedDelivery: "-", available: false, errorMessage: "Layanan GrabExpress tidak tersedia." });
    }
    return { rates };
});
async function fetchGoSendRates(origin, destination, weightKg) {
    const token = await getGoSendToken();
    const merchantId = GOSEND_MERCHANT_ID.value();
    const r = await axios_1.default.post(`${goSendBase()}/v1/merchant/orders/calculate-price`, { merchant_id: merchantId, origin: { lat: origin.latitude, lng: origin.longitude, address: origin.address }, destination: { lat: destination.latitude, lng: destination.longitude, address: destination.address }, item: { weight: weightKg, quantity: 1 } }, { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": merchantId } });
    return (r.data.services ?? []).map((s) => ({
        provider: "gosend", serviceType: s.service_type ?? "instant", serviceName: s.service_name ?? "GoSend",
        price: Math.round(s.price ?? 0), currency: "IDR", estimatedDelivery: s.estimated_delivery_time ?? "< 1 jam", available: s.is_available ?? true,
    }));
}
async function fetchGrabRates(origin, destination, weightKg) {
    const token = await getGrabToken();
    const merchantId = GRAB_MERCHANT_ID.value();
    const r = await axios_1.default.post(`${grabBase()}/v1/deliveries/quotes`, { merchantID: merchantId, serviceType: "INSTANT", packages: [{ name: "Paket", description: "Paket Gogama", quantity: 1, price: 0, dimensions: { height: 10, width: 10, depth: 10, weight: weightKg * 1000 } }], origin: { address: origin.address, coordinates: { latitude: origin.latitude, longitude: origin.longitude } }, destination: { address: destination.address, coordinates: { latitude: destination.latitude, longitude: destination.longitude } } }, { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } });
    return (r.data.quotes ?? []).map((q) => ({
        provider: "grab", serviceType: q.serviceType ?? "INSTANT", serviceName: `GrabExpress ${q.serviceType ?? ""}`,
        price: Math.round(q.amount ?? 0), currency: "IDR", estimatedDelivery: "< 1 jam", available: true,
    }));
}
// ─────────────────────────────────────────────────────────────────
// FUNCTION 2: Booking driver instan
// ─────────────────────────────────────────────────────────────────
exports.bookInstantDelivery = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { orderId, provider, serviceType, origin, destination, packageInfo } = request.data;
    if (!orderId || !provider)
        throw new https_1.HttpsError("invalid-argument", "Data tidak lengkap.");
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists)
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    const order = orderDoc.data();
    if (order.deliveryBookingId) {
        return { success: true, bookingId: order.deliveryBookingId, provider: order.deliveryProvider, message: "Sudah dibooking." };
    }
    try {
        let result;
        if (provider === "gosend") {
            result = await bookGoSend(orderId, origin, destination, packageInfo, serviceType);
        }
        else {
            result = await bookGrab(orderId, origin, destination, packageInfo, serviceType);
        }
        await db.collection("orders").doc(orderId).update({
            deliveryBookingId: result.bookingId,
            deliveryProvider: provider,
            deliveryTrackingUrl: result.trackingUrl ?? "",
            deliveryDriverInfo: result.driverInfo ?? {},
            status: "Dikirim",
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return { success: true, bookingId: result.bookingId, provider, trackingUrl: result.trackingUrl };
    }
    catch (err) {
        v2_1.logger.error(`Booking ${provider} gagal:`, err);
        throw new https_1.HttpsError("internal", `Gagal booking: ${err.message}`);
    }
});
async function bookGoSend(orderId, origin, destination, pkg, serviceType) {
    const token = await getGoSendToken();
    const merchantId = GOSEND_MERCHANT_ID.value();
    const r = await axios_1.default.post(`${goSendBase()}/v1/merchant/orders`, { merchant_id: merchantId, merchant_order_id: orderId, service_type: serviceType, origin: { lat: origin.latitude, lng: origin.longitude, address: origin.address, name: origin.contactName, phone: origin.contactPhone }, destination: { lat: destination.latitude, lng: destination.longitude, address: destination.address, name: destination.contactName, phone: destination.contactPhone }, item: { name: "Paket Gogama", description: pkg.description, value: pkg.value, weight: pkg.weightKg, quantity: 1 } }, { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": merchantId } });
    return { bookingId: r.data.order_id ?? r.data.id, trackingUrl: r.data.live_tracking_url, driverInfo: r.data.driver };
}
async function bookGrab(orderId, origin, destination, pkg, serviceType) {
    const token = await getGrabToken();
    const r = await axios_1.default.post(`${grabBase()}/v1/deliveries`, { merchantOrderID: orderId, serviceType, packages: [{ name: "Paket Gogama", description: pkg.description, quantity: 1, price: pkg.value, dimensions: { weight: pkg.weightKg * 1000, height: 10, width: 10, depth: 10 } }], origin: { address: origin.address, coordinates: { latitude: origin.latitude, longitude: origin.longitude }, contact: { firstName: origin.contactName, phone: origin.contactPhone } }, destination: { address: destination.address, coordinates: { latitude: destination.latitude, longitude: destination.longitude }, contact: { firstName: destination.contactName, phone: destination.contactPhone } } }, { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": GRAB_MERCHANT_ID.value() } });
    return { bookingId: r.data.deliveryID ?? r.data.id, trackingUrl: r.data.trackingURL, driverInfo: r.data.driver };
}
// ─────────────────────────────────────────────────────────────────
// FUNCTION 3: Batalkan booking
// ─────────────────────────────────────────────────────────────────
exports.cancelDelivery = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { orderId } = request.data;
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists)
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    const order = orderDoc.data();
    const provider = order.deliveryProvider;
    const bookingId = order.deliveryBookingId;
    if (!provider || !bookingId)
        throw new https_1.HttpsError("failed-precondition", "Tidak ada booking aktif.");
    if (provider === "gosend") {
        const token = await getGoSendToken();
        await axios_1.default.post(`${goSendBase()}/v1/merchant/orders/${bookingId}/cancel`, {}, { headers: { Authorization: `Bearer ${token}`, "X-Merchant-ID": GOSEND_MERCHANT_ID.value() } });
    }
    else {
        const token = await getGrabToken();
        await axios_1.default.delete(`${grabBase()}/v1/deliveries/${bookingId}`, { headers: { Authorization: `Bearer ${token}` } });
    }
    await db.collection("orders").doc(orderId).update({
        deliveryBookingId: firestore_1.FieldValue.delete(),
        deliveryCancelled: true,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { success: true };
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 4: Track delivery
// ─────────────────────────────────────────────────────────────────
exports.trackDelivery = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { orderId } = request.data;
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists)
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    const order = orderDoc.data();
    const provider = order.deliveryProvider;
    const bookingId = order.deliveryBookingId;
    if (!provider || !bookingId)
        return { hasDelivery: false };
    try {
        if (provider === "gosend") {
            const token = await getGoSendToken();
            const r = await axios_1.default.get(`${goSendBase()}/v1/merchant/orders/${bookingId}`, { headers: { Authorization: `Bearer ${token}`, "X-Merchant-ID": GOSEND_MERCHANT_ID.value() } });
            return { hasDelivery: true, status: r.data.status, driverName: r.data.driver?.name, driverPhone: r.data.driver?.phone, driverPlate: r.data.driver?.vehicle_plate, trackingUrl: r.data.live_tracking_url };
        }
        else {
            const token = await getGrabToken();
            const r = await axios_1.default.get(`${grabBase()}/v1/deliveries/${bookingId}`, { headers: { Authorization: `Bearer ${token}` } });
            return { hasDelivery: true, status: r.data.status, driverName: r.data.driver?.name, driverPhone: r.data.driver?.phone, trackingUrl: r.data.trackingURL };
        }
    }
    catch {
        return { hasDelivery: true, provider, status: "unknown", trackingUrl: order.deliveryTrackingUrl ?? "" };
    }
});
//# sourceMappingURL=delivery.js.map