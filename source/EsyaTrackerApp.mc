import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class EsyaTrackerApp extends Application.AppBase {

    const TEMP_STORAGE_KEY = "esya_temp_c";

    hidden var pendingVersionOnStart as Boolean = true;
    hidden var settingsDisplaySynced as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    // Runs in the 32 KB background process too — keep this empty.
    // WatchUi/Auth here OOMs the temp poll; do that work in getInitialView.
    function onStart(state as Dictionary?) as Void {
    }

    // Drop frozen esya_temp_c from older builds once per version.
    hidden function maybeClearStaleTempOnUpgrade() as Void {
        try {
            var ver = WatchUi.loadResource(Rez.Strings.Version) as String;
            var last = Application.Storage.getValue("esya_temp_cleared_ver");
            if (last instanceof String && (last as String).equals(ver)) {
                return;
            }
            Application.Storage.deleteValue(TEMP_STORAGE_KEY);
            Application.Storage.deleteValue("esya_temp_dbg");
            Application.Storage.deleteValue("esya_temp_dbg_s");
            Application.Storage.deleteValue("esya_temp_bg");
            Application.Storage.deleteValue("esya_temp_reg");
            Application.Storage.deleteValue("esya_temp_at");
            Application.Storage.setValue("esya_temp_cleared_ver", ver);
        } catch (ex) {
        }
    }

    function onSettingsChanged() as Void {
        syncSettingsDisplay();
        // Online toggled from Connect mobile — fetch guest token + bind code on device.
        if (EsyaTrackerAuth.isOnlineMode()) {
            EsyaTrackerAuth.refreshOnlineStatus();
        } else {
            EsyaTrackerAuth.syncPairCodeProperty();
        }
    }

    function consumeVersionOnStart() as Boolean {
        if (pendingVersionOnStart) {
            pendingVersionOnStart = false;
            return true;
        }
        return false;
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        maybeClearStaleTempOnUpgrade();
        syncSettingsDisplay();
        registerTempBackground();
        var view = new EsyaTrackerView();
        return [view, new EsyaTrackerFieldDelegate(view)];
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        syncSettingsDisplay();
        if (EsyaTrackerAuth.isOnlineMode()) {
            EsyaTrackerAuth.refreshOnlineStatus();
        }
        var online = new EsyaTrackerPairView();
        return [online, new EsyaTrackerPairDelegate(online, false)];
    }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new EsyaTrackerTempDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        try {
            if (data instanceof Float || data instanceof Number || data instanceof Double) {
                var value = (data as Number).toFloat();
                if (value >= -40.0 && value <= 80.0) {
                    Application.Storage.setValue(TEMP_STORAGE_KEY, value);
                }
            }
        } catch (ex) {
        }
        registerTempBackground();
        try {
            WatchUi.requestUpdate();
        } catch (ex) {
        }
    }

    // Properties defaults stick after first install — rewrite copyright + pair code for Connect UI.
    function syncSettingsDisplay() as Void {
        syncAboutNotice();
        EsyaTrackerAuth.syncPairCodeProperty();
        settingsDisplaySynced = true;
    }

    // compute() calls this so a hung/missed background still re-arms the next poll.
    function ensureTempBackground() as Void {
        registerTempBackground();
    }

    // Once per process from compute — catches upgrades when Connect still shows stale About.
    function syncSettingsDisplayOnce() as Void {
        if (settingsDisplaySynced) {
            return;
        }
        syncSettingsDisplay();
    }

    // New property keys (appVersion / aboutCopy) so Connect drops stuck aboutNotice values.
    function syncAboutNotice() as Void {
        try {
            var ver = WatchUi.loadResource(Rez.Strings.Version) as String;
            var body = WatchUi.loadResource(Rez.Strings.AboutNoticeBody) as String;
            var notice = "OsMo Tracker " + ver + ". " + body;
            Properties.setValue("appVersion", ver);
            Properties.setValue("aboutCopy", notice);
            Properties.setValue("aboutUrl", "https://esya.ru/osmo");
        } catch (ex) {
        }
    }

    hidden function registerTempBackground() as Void {
        try {
            if (!(Background has :registerForTemporalEvent)) {
                return;
            }
            var registered = Background.getTemporalEventRegisteredTime();
            if (registered instanceof Time.Moment) {
                if ((registered as Time.Moment).greaterThan(Time.now())) {
                    return;
                }
            }
            var last = null as Time.Moment?;
            if (Background has :getLastTemporalEventTime) {
                last = Background.getLastTemporalEventTime();
            }
            if (last == null) {
                Background.registerForTemporalEvent(Time.now());
            } else {
                Background.registerForTemporalEvent(last.add(new Time.Duration(5 * 60)));
            }
        } catch (ex) {
            try {
                Background.registerForTemporalEvent(Time.now().add(new Time.Duration(5 * 60)));
            } catch (ex2) {
            }
        }
    }
}
