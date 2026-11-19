import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

module EsyaTrackerAuth {
    const DEVICE_NAME_KEY = "esya_tracker_device_name";
    const TOKEN_STORAGE_KEY = "esya_tracker_bearer";
    const BIND_CODE_KEY = "esya_tracker_bind_code";
    const BOUND_KEY = "esya_tracker_bound";

    const REGISTER_URL = "https://esya.ru/api/device/register";
    const ME_URL = "https://esya.ru/api/device/me";

    var registerBusy as Boolean = false;
    var meBusy as Boolean = false;
    var reregisterNeeded as Boolean = false;
    var lastEnsureAt as Number = 0;
    var lastMeAt as Number = 0;
    var client as EsyaTrackerOnlineClient?;

    function isOnlineMode() as Boolean {
        try {
            var value = Properties.getValue("onlineMode");
            if (value instanceof Boolean) {
                return value as Boolean;
            }
            if (value instanceof Number) {
                return (value as Number) != 0;
            }
            if (value instanceof String) {
                var s = value as String;
                return s.equals("true") || s.equals("1");
            }
        } catch (ex) {
        }
        return false;
    }

    function hasToken() as Boolean {
        return readToken().length() > 0;
    }

    function readToken() as String {
        try {
            var value = Properties.getValue("bearerToken");
            if (value instanceof String) {
                var token = normalizeToken(value as String);
                if (token.length() > 0) {
                    return token;
                }
            }
        } catch (ex) {
        }
        try {
            var stored = Storage.getValue(TOKEN_STORAGE_KEY);
            if (stored instanceof String) {
                return normalizeToken(stored as String);
            }
        } catch (ex2) {
        }
        return "";
    }

    function readDeviceName() as String {
        try {
            var value = Storage.getValue(DEVICE_NAME_KEY);
            if (value instanceof String) {
                return value as String;
            }
        } catch (ex) {
        }
        return "";
    }

    function readBindCode() as String {
        try {
            var value = Storage.getValue(BIND_CODE_KEY);
            if (value instanceof String) {
                return value as String;
            }
        } catch (ex) {
        }
        return "";
    }

    function isBound() as Boolean {
        try {
            var value = Storage.getValue(BOUND_KEY);
            if (value instanceof Boolean) {
                return value as Boolean;
            }
            if (value instanceof Number) {
                return (value as Number) != 0;
            }
        } catch (ex) {
        }
        return false;
    }

    function saveSession(token as String, deviceName as String, bindCode as String, bound as Boolean) as Void {
        try {
            Properties.setValue("bearerToken", token);
        } catch (ex) {
        }
        try {
            Storage.setValue(TOKEN_STORAGE_KEY, token);
        } catch (ex2) {
        }
        try {
            Storage.setValue(DEVICE_NAME_KEY, deviceName);
        } catch (ex3) {
        }
        try {
            if (bindCode.length() > 0) {
                Storage.setValue(BIND_CODE_KEY, bindCode);
            } else {
                Storage.deleteValue(BIND_CODE_KEY);
            }
        } catch (ex4) {
        }
        try {
            Storage.setValue(BOUND_KEY, bound);
        } catch (ex5) {
        }
        reregisterNeeded = false;
        syncPairCodeProperty();
    }

    function clearSession() as Void {
        try {
            Properties.setValue("bearerToken", "unset");
        } catch (ex) {
        }
        try {
            Storage.deleteValue(TOKEN_STORAGE_KEY);
        } catch (ex2) {
        }
        try {
            Storage.deleteValue(DEVICE_NAME_KEY);
        } catch (ex3) {
        }
        try {
            Storage.deleteValue(BIND_CODE_KEY);
        } catch (ex4) {
        }
        try {
            Storage.deleteValue(BOUND_KEY);
        } catch (ex5) {
        }
        syncPairCodeProperty();
    }

    // Visible in Connect IQ mobile settings (XML), not only on-device getSettingsView.
    function syncPairCodeProperty() as Void {
        var text = "";
        try {
            if (!isOnlineMode()) {
                text = WatchUi.loadResource(Rez.Strings.PairCodeOffline) as String;
            } else if (isBound()) {
                text = WatchUi.loadResource(Rez.Strings.PairCodeBound) as String;
            } else {
                var code = readBindCode();
                if (code.length() > 0) {
                    text = code + (WatchUi.loadResource(Rez.Strings.PairCodeHintSuffix) as String);
                } else {
                    text = WatchUi.loadResource(Rez.Strings.PairCodeWait) as String;
                }
            }
        } catch (ex) {
            text = readBindCode();
            if (text.length() == 0) {
                text = "—";
            }
        }
        try {
            Properties.setValue("pairCode", text);
        } catch (ex2) {
        }
    }

    function markReregisterNeeded() as Void {
        reregisterNeeded = true;
        clearSession();
    }

    function isSessionBusy() as Boolean {
        return registerBusy || meBusy;
    }

    function ensureClient() as EsyaTrackerOnlineClient {
        if (client == null) {
            client = new EsyaTrackerOnlineClient();
        }
        return client as EsyaTrackerOnlineClient;
    }

    // From activity compute: only obtain a token when missing.
    function ensureOnlineSession() as Void {
        if (!isOnlineMode()) {
            return;
        }
        if (registerBusy || meBusy) {
            return;
        }
        var now = System.getTimer();
        if ((now - lastEnsureAt) < 5000 && !reregisterNeeded) {
            return;
        }
        lastEnsureAt = now;

        if (!hasToken() || reregisterNeeded) {
            registerGuest();
        }
    }

    // From settings UI: validate token + refresh bind/bound meta.
    function refreshOnlineStatus() as Void {
        if (!isOnlineMode()) {
            return;
        }
        if (registerBusy || meBusy) {
            return;
        }
        if (!hasToken() || reregisterNeeded) {
            registerGuest();
            return;
        }
        var now = System.getTimer();
        if ((now - lastMeAt) < 2000) {
            return;
        }
        lastMeAt = now;
        refreshMe();
    }

    function registerGuest() as Void {
        ensureClient().registerGuest();
    }

    function refreshMe() as Void {
        ensureClient().refreshMe();
    }

    function deviceLabel() as String {
        try {
            var model = System.getDeviceSettings().partNumber;
            if (model instanceof String && (model as String).length() > 0) {
                return "Garmin " + (model as String);
            }
        } catch (ex) {
        }
        return "Garmin IQ";
    }

    function deviceMeta() as Dictionary {
        var meta = {} as Dictionary;
        try {
            var settings = System.getDeviceSettings();
            if (settings.partNumber instanceof String) {
                meta.put("part_number", settings.partNumber as String);
            }
            try {
                var fw = settings.firmwareVersion;
                if (fw != null && fw.size() >= 2) {
                    meta.put("firmware", (fw[0] as Number).toString() + "." + (fw[1] as Number).toString());
                }
            } catch (exFw) {
            }
            try {
                var mv = settings.monkeyVersion;
                if (mv != null && mv.size() >= 3) {
                    meta.put(
                        "ciq_version",
                        (mv[0] as Number).toString() + "." + (mv[1] as Number).toString() + "." + (mv[2] as Number).toString()
                    );
                }
            } catch (exMv) {
            }
            try {
                if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
                    meta.put("device_uid", settings.uniqueIdentifier as String);
                }
            } catch (exUid) {
            }
        } catch (ex) {
        }
        try {
            meta.put("app_version", WatchUi.loadResource(Rez.Strings.Version) as String);
        } catch (exVer) {
        }
        return meta;
    }

    function normalizeToken(token as String) as String {
        if (
            token.length() > 0
            && !token.equals("unset")
            && !token.equals("stale")
            && !token.equals("fallback")
        ) {
            return token;
        }
        return "";
    }

    function asText(value as Object?) as String {
        if (value instanceof String) {
            return value as String;
        }
        if (value instanceof Number) {
            return (value as Number).toString();
        }
        return "";
    }
}
