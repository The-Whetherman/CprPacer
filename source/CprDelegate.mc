import Toybox.WatchUi;
import Toybox.Lang;

class CprDelegate extends WatchUi.BehaviorDelegate {

    var session as CprSession;
    var view as CprView;

    function initialize(s as CprSession, v as CprView) {
        BehaviorDelegate.initialize();
        session = s;
        view = v;
    }

    function onSelect() as Boolean {
        if (session.state == STATE_IDLE) {
            session.start();
        } else if (session.state == STATE_RUNNING) {
            session.stop();
        } else if (session.state == STATE_SUMMARY) {
            session.acknowledgeSummary();
        } else if (session.state == STATE_HISTORY) {
            session.hideHistory();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        if (session.state == STATE_RUNNING) {
            session.stop();
            WatchUi.requestUpdate();
            return true;
        } else if (session.state == STATE_HISTORY) {
            session.hideHistory();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        if (session.state == STATE_IDLE) {
            session.showHistory();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onPreviousPage() as Boolean {
        if (session.state == STATE_HISTORY) {
            session.hideHistory();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
