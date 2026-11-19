import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class EsyaTrackerOnlineClient {

    function initialize() {
    }

    function registerGuest() as Void {
        if (EsyaTrackerAuth.registerBusy) {
            return;
        }
        EsyaTrackerAuth.registerBusy = true;
        EsyaTrackerAuth.reregisterNeeded = false;
        var params = EsyaTrackerAuth.deviceMeta();
        params.put("app_id", "EsyaTracker");
        params.put("device_label", EsyaTrackerAuth.deviceLabel());
        try {
            Communications.makeWebRequest(
                EsyaTrackerAuth.REGISTER_URL,
                params,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onRegisterReceive)
            );
        } catch (ex) {
            EsyaTrackerAuth.registerBusy = false;
        }
    }

    function onRegisterReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        EsyaTrackerAuth.registerBusy = false;
        try {
            if (responseCode != 200 || !(data instanceof Dictionary)) {
                return;
            }
            var dict = data as Dictionary;
            var token = EsyaTrackerAuth.asText(dict.get("token"));
            if (token.length() == 0) {
                return;
            }
            var name = EsyaTrackerAuth.asText(dict.get("device_name"));
            if (name.length() == 0) {
                name = EsyaTrackerAuth.deviceLabel();
            }
            var bindCode = EsyaTrackerAuth.asText(dict.get("bind_code"));
            EsyaTrackerAuth.saveSession(token, name, bindCode, false);
            try {
                WatchUi.requestUpdate();
            } catch (ex) {
            }
        } catch (ex2) {
        }
    }

    function refreshMe() as Void {
        if (EsyaTrackerAuth.meBusy || !EsyaTrackerAuth.hasToken()) {
            return;
        }
        EsyaTrackerAuth.meBusy = true;
        var token = EsyaTrackerAuth.readToken();
        var params = EsyaTrackerAuth.deviceMeta();
        params.put("device_label", EsyaTrackerAuth.deviceLabel());
        try {
            Communications.makeWebRequest(
                EsyaTrackerAuth.ME_URL,
                params,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onMeReceive)
            );
        } catch (ex) {
            EsyaTrackerAuth.meBusy = false;
        }
    }

    function onMeReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        EsyaTrackerAuth.meBusy = false;
        try {
            if (responseCode == 401 || responseCode == 403) {
                EsyaTrackerAuth.markReregisterNeeded();
                registerGuest();
                return;
            }
            if (responseCode != 200 || !(data instanceof Dictionary)) {
                return;
            }
            var dict = data as Dictionary;
            var name = EsyaTrackerAuth.asText(dict.get("device_name"));
            var bindCode = EsyaTrackerAuth.asText(dict.get("bind_code"));
            var bound = false;
            var boundVal = dict.get("bound");
            if (boundVal instanceof Boolean) {
                bound = boundVal as Boolean;
            }
            if (name.length() > 0) {
                try {
                    Storage.setValue(EsyaTrackerAuth.DEVICE_NAME_KEY, name);
                } catch (ex) {
                }
            }
            try {
                if (bindCode.length() > 0) {
                    Storage.setValue(EsyaTrackerAuth.BIND_CODE_KEY, bindCode);
                } else if (bound) {
                    Storage.deleteValue(EsyaTrackerAuth.BIND_CODE_KEY);
                }
            } catch (ex2) {
            }
            try {
                Storage.setValue(EsyaTrackerAuth.BOUND_KEY, bound);
            } catch (ex3) {
            }
            EsyaTrackerAuth.syncPairCodeProperty();
            try {
                WatchUi.requestUpdate();
            } catch (ex4) {
            }
        } catch (ex5) {
        }
    }
}
