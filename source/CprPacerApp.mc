import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class CprPacerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var session = new CprSession();
        var view = new CprView(session);
        var delegate = new CprDelegate(session, view);
        return [view, delegate];
    }
}
