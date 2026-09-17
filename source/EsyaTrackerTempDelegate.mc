import Toybox.Background;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;

(:background)
class EsyaTrackerTempDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var temp = null as Float?;
        try {
            var info = Sensor.getInfo();
            if (info != null && info has :temperature && info.temperature != null) {
                temp = info.temperature as Float;
            }
        } catch (ex) {
        }
        Background.exit(temp);
    }
}
