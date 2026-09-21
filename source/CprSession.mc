import Toybox.Lang;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Math;
import Toybox.Sensor;

// App states
enum {
    STATE_IDLE,
    STATE_RUNNING,
    STATE_SUMMARY,
    STATE_HISTORY
}

const BEAT_INTERVAL_MS = 600;     // 100 compressions / minute
const CYCLE_MS = 120000;          // 2-minute rescuer-switch / pulse-check mark
const MOTION_THRESHOLD_MG = 300;  // milli-G peak-to-peak considered "compressing"
const MOTION_QUIET_LIMIT = 2;     // seconds of no motion before muting the beep
const HISTORY_MAX = 10;

class CprSession {

    var state as Number = STATE_IDLE;

    var beatCount as Number = 0;
    var lastCycleIndex as Number = 0;
    var elapsedMs as Number = 0;
    var startMark as Number = 0;

    var motionActive as Boolean = true;
    var quietSeconds as Number = 0;
    var sensorActive as Boolean = false;

    var cycleBannerUntil as Number = 0;

    // last completed session, for display
    var lastDurationSec as Number = 0;
    var lastCompressions as Number = 0;
    var lastCycles as Number = 0;

    var timer as Timer.Timer?;
    var view as CprView?;

    function initialize() {
        timer = new Timer.Timer();
    }

    function setView(v as CprView) as Void {
        view = v;
    }

    function start() as Void {
        beatCount = 0;
        lastCycleIndex = 0;
        elapsedMs = 0;
        motionActive = true;
        quietSeconds = 0;
        cycleBannerUntil = 0;
        startMark = System.getTimer();

        registerSensor();

        (timer as Timer.Timer).start(method(:onBeat), BEAT_INTERVAL_MS, true);
        state = STATE_RUNNING;
    }

    function stop() as Void {
        (timer as Timer.Timer).stop();
        unregisterSensor();

        elapsedMs = System.getTimer() - startMark;
        lastDurationSec = elapsedMs / 1000;
        lastCompressions = beatCount;
        lastCycles = lastCycleIndex;
        saveHistory(lastDurationSec, lastCompressions, lastCycles);

        state = STATE_SUMMARY;
    }

    function acknowledgeSummary() as Void {
        state = STATE_IDLE;
    }

    function showHistory() as Void {
        state = STATE_HISTORY;
    }

    function hideHistory() as Void {
        state = STATE_IDLE;
    }

    function onBeat() as Void {
        beatCount += 1;
        elapsedMs = System.getTimer() - startMark;

        // Haptic pulse is unconditional -- this is the safety-critical cue.
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, 130)]);
        }

        // Audio beep is the only part that adapts to detected motion.
        if ((motionActive || !sensorActive) && (Attention has :playTone)) {
            Attention.playTone(Attention.TONE_KEY);
        }

        var cycleIndex = elapsedMs / CYCLE_MS;
        if (cycleIndex > lastCycleIndex) {
            lastCycleIndex = cycleIndex;
            onCycleMark();
        }

        if (view != null) {
            WatchUi.requestUpdate();
        }
    }

    function onCycleMark() as Void {
        cycleBannerUntil = System.getTimer() + 4000;
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 250)
            ]);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    function isCycleBannerActive() as Boolean {
        return cycleBannerUntil > 0 && System.getTimer() < cycleBannerUntil;
    }

    function registerSensor() as Void {
        sensorActive = false;
        motionActive = true;
        quietSeconds = 0;
        if (Toybox has :Sensor) {
            if (Sensor has :registerSensorDataListener) {
                try {
                    Sensor.registerSensorDataListener(method(:onSensorData), {
                        :period => 1,
                        :accelerometer => { :enabled => true, :sampleRate => 25 }
                    });
                    sensorActive = true;
                } catch (ex) {
                    sensorActive = false;
                }
            }
        }
    }

    function unregisterSensor() as Void {
        if (sensorActive) {
            if (Toybox has :Sensor) {
                if (Sensor has :unregisterSensorDataListener) {
                    try {
                        Sensor.unregisterSensorDataListener();
                    } catch (ex) {
                    }
                }
            }
            sensorActive = false;
        }
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel == null) {
            return;
        }
        var xs = accel.x;
        var ys = accel.y;
        var zs = accel.z;
        if (xs == null || ys == null || zs == null || xs.size() == 0) {
            return;
        }

        var minMag = 999999.0;
        var maxMag = -999999.0;
        for (var i = 0; i < xs.size(); i += 1) {
            var x = xs[i].toFloat();
            var y = ys[i].toFloat();
            var z = zs[i].toFloat();
            var mag = Math.sqrt(x * x + y * y + z * z);
            if (mag < minMag) { minMag = mag; }
            if (mag > maxMag) { maxMag = mag; }
        }

        var range = maxMag - minMag;
        if (range > MOTION_THRESHOLD_MG) {
            motionActive = true;
            quietSeconds = 0;
        } else {
            quietSeconds += 1;
            if (quietSeconds >= MOTION_QUIET_LIMIT) {
                motionActive = false;
            }
        }
    }

    function saveHistory(durSec as Number, compressions as Number, cycles as Number) as Void {
        if (!(Storage has :getValue)) {
            return;
        }
        try {
            var raw = Storage.getValue("cprHistory");
            var history = (raw instanceof Array) ?
                (raw as Array<Storage.ValueType>) : ([] as Array<Storage.ValueType>);
            var entry = ({
                "epoch" => Time.now().value(),
                "durSec" => durSec,
                "comp" => compressions,
                "cycles" => cycles
            }) as Storage.ValueType;
            history.add(entry);
            while (history.size() > HISTORY_MAX) {
                history.remove(history[0]);
            }
            Storage.setValue("cprHistory", history as Storage.ValueType);
        } catch (ex) {
        }
    }

    function loadHistory() as Array<Storage.ValueType> {
        if (!(Storage has :getValue)) {
            return [];
        }
        try {
            var raw = Storage.getValue("cprHistory");
            if (raw instanceof Array) {
                return raw as Array<Storage.ValueType>;
            }
            return [];
        } catch (ex) {
            return [];
        }
    }
}
