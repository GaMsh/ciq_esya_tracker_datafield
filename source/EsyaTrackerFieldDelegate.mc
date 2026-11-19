import Toybox.Lang;
import Toybox.WatchUi;

class EsyaTrackerFieldDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view as EsyaTrackerView;

    function initialize(view as EsyaTrackerView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onTap(evt as ClickEvent) as Boolean {
        _view.toggleDisplayUnits();
        return true;
    }

    function onSelect() as Boolean {
        _view.toggleDisplayUnits();
        return true;
    }
}
