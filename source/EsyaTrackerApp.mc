import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class EsyaTrackerApp extends Application.AppBase {

    const TEMP_STORAGE_KEY = "esya_temp_c";

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        registerTempBackground();
        return [new EsyaTrackerView()];
    }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new EsyaTrackerTempDelegate()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        try {
            if (data instanceof Float || data instanceof Number || data instanceof Double) {
                Application.Storage.setValue(TEMP_STORAGE_KEY, data);
            }
        } catch (ex) {
        }
        registerTempBackground();
    }

    hidden function registerTempBackground() as Void {
        try {
            if (!(Background has :registerForTemporalEvent)) {
                return;
            }
            if (Background.getTemporalEventRegisteredTime() != null) {
                return;
            }
            var last = null as Time.Moment?;
            if (Background has :getLastTemporalEventTime) {
                last = Background.getLastTemporalEventTime();
            }
            if (last == null) {
                Background.registerForTemporalEvent(Time.now());
            } else {
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            }
        } catch (ex) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            } catch (ex2) {
            }
        }
    }
}
