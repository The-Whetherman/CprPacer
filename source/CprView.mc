import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;

class CprView extends WatchUi.View {

    var session as CprSession;

    function initialize(s as CprSession) {
        View.initialize();
        session = s;
        session.setView(self);
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (session.state == STATE_IDLE) {
            drawIdle(dc, cx, h);
        } else if (session.state == STATE_RUNNING) {
            drawRunning(dc, cx, h);
        } else if (session.state == STATE_SUMMARY) {
            drawSummary(dc, cx, h);
        } else if (session.state == STATE_HISTORY) {
            drawHistory(dc, cx, h);
        }
    }

    function drawIdle(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.drawText(cx, h * 0.20, Graphics.FONT_MEDIUM, "CPR Pacer", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(cx, h * 0.33, Graphics.FONT_XTINY, "TRAINING AID", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        dc.drawText(cx, h * 0.46, Graphics.FONT_SMALL, "100 / min", Graphics.TEXT_JUSTIFY_CENTER);

        if (session.lastCompressions > 0) {
            var recap = "Last: " + formatTime(session.lastDurationSec * 1000) +
                "  " + session.lastCompressions.toString() + " comp";
            dc.drawText(cx, h * 0.58, Graphics.FONT_XTINY, recap, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.drawText(cx, h * 0.74, Graphics.FONT_SMALL, "SELECT: Start", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY, "DOWN: History", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawRunning(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.drawText(cx, h * 0.34, Graphics.FONT_NUMBER_MEDIUM, formatTime(session.elapsedMs), Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(cx, h * 0.54, Graphics.FONT_SMALL,
            "Compressions: " + session.beatCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.64, Graphics.FONT_SMALL,
            "Cycles: " + session.lastCycleIndex.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        var beepLabel = (session.motionActive || !session.sensorActive) ? "BEEP+VIBE" : "VIBE ONLY";
        dc.setColor((session.motionActive || !session.sensorActive) ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(cx, h * 0.76, Graphics.FONT_XTINY, beepLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        dc.drawText(cx, h * 0.88, Graphics.FONT_XTINY, "SELECT: Stop", Graphics.TEXT_JUSTIFY_CENTER);

        if (session.isCycleBannerActive()) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_YELLOW);
            dc.fillRectangle(0, h * 0.42, dc.getWidth(), h * 0.14);
            dc.drawText(cx, h * 0.45, Graphics.FONT_TINY, "SWITCH / PULSE CHECK", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        }
    }

    function drawSummary(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.drawText(cx, h * 0.24, Graphics.FONT_MEDIUM, "Session Ended", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.42, Graphics.FONT_NUMBER_MEDIUM, formatTime(session.lastDurationSec * 1000), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.60, Graphics.FONT_SMALL,
            "Compressions: " + session.lastCompressions.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.70, Graphics.FONT_SMALL,
            "Cycles: " + session.lastCycles.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY, "SELECT: Continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawHistory(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.drawText(cx, h * 0.12, Graphics.FONT_SMALL, "History", Graphics.TEXT_JUSTIFY_CENTER);

        var history = session.loadHistory();
        if (history.size() == 0) {
            dc.drawText(cx, h * 0.5, Graphics.FONT_XTINY, "No sessions yet", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var startIdx = history.size() - 1;
            var count = 0;
            var y = h * 0.24;
            var i = startIdx;
            while (i >= 0 && count < 5) {
                var entry = history[i] as Dictionary<String, Storage.ValueType>;
                var epoch = entry["epoch"] as Number;
                var durSec = entry["durSec"] as Number;
                var comp = entry["comp"] as Number;
                var line = dateLabel(epoch) + "  " +
                    formatTime(durSec * 1000) + "  " +
                    comp.toString() + "c";
                dc.drawText(cx, y, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
                y += h * 0.11;
                i -= 1;
                count += 1;
            }
        }

        dc.drawText(cx, h * 0.90, Graphics.FONT_XTINY, "SELECT/BACK: Close", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function dateLabel(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return info.month.toString() + "/" + info.day.toString() + " " +
            info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    function formatTime(ms as Number) as String {
        var totalSec = ms / 1000;
        var mm = totalSec / 60;
        var ss = totalSec % 60;
        return mm.toString() + ":" + ss.format("%02d");
    }
}
