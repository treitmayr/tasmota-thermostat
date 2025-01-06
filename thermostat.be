# berry wrapper around "thermostat" tasmota functionality

import json

class thermostat

    var lsens_name, lsens_key
    var use_cron

    def init()
        self.use_cron = false
    end

    def set_pwm(cycle_time, max_on, min_on)
        # all parameters in minutes
        if max_on > cycle_time
            tasmota.log(f"max_on ({max_on} min) must be lower or equal cycle_time ({cycle_time} min)", 1)
        elif min_on > cycle_time
            tasmota.log(f"min_on ({min_on} min) must be lower or equal cycle_time ({cycle_time} min)", 1)
        elif min_on > max_on
            tasmota.log(f"min_on ({min_on} min) must be lower or equal max_on ({max_on} min)", 1)
        else
            tasmota.cmd(f"TimePICycleSet {cycle_time}")
            tasmota.cmd(f"TimeMaxActionSet {max_on}")
            tasmota.cmd(f"TimeMinActionSet {min_on}")
        end
    end

    def set_hysteresis(hyst)
        if hyst < 0.1
            tasmota.log(f"Hysteresis must be at least 0.1 °C (is: {hyst})", 1)
        else
            tasmota.cmd(f"TempHystSet {hyst}")
        end
    end

    def set_ramp_up_delta(delta)
        if delta < 0.1
            tasmota.log(f"Ramp-Up delta must be at least 0.1 °C (is: {delta})", 1)
        else
            tasmota.cmd(f"TEMPRUPDELTINSET {delta}")
        end
    end

    def use_local_sensor(name, key)
        var res, ress
        if name
            self.lsens_name = name
            if key
                self.lsens_key = key
            else
                self.lsens_key = "Temperature"
            end
            ress = tasmota.read_sensors()
            res = json.load(ress)
            if !res.contains(self.lsens_name)
                tasmota.log(f"THS: Cannot find sensor '{self.lsens_name}' in '{ress}'", 1)
            elif !res[self.lsens_name].contains(self.lsens_key)
                tasmota.log(f"THS: Cannot find key '{self.lsens_key}' in '{res[name]}'", 1)
            else
                tasmota.log(f"THS: Using local sensor {self.lsens_name}.{self.lsens_key}", 2)
                tasmota.cmd("SensorInputSet 0")
                self.set_measured_temp(res[self.lsens_name][self.lsens_key])
                if self.use_cron
                    tasmota.remove_cron("termostat_update_measured")
                end
                tasmota.add_cron("*/2 * * * * *", def () self._update_measured_temp() end, "termostat_update_measured")
                self.use_cron = true
            end
        else
            if self.use_cron
                tasmota.remove_cron("termostat_update_measured")
                self.use_cron = false
            end
            tasmota.log(f"THS: Using default local sensor", 2)
            tasmota.cmd("SensorInputSet 1")
        end
    end

    def set_measured_temp(temp)
        tasmota.log(f"THS: Measured temperature {temp}", 4)
        tasmota.cmd(f"TempMeasuredSet {temp}")
    end

    def _update_measured_temp()
        self.set_measured_temp(json.load(tasmota.read_sensors())[self.lsens_name][self.lsens_key])
    end

    def enable()
        tasmota.cmd("ThermostatModeSet 1")
    end

    def set_target_temp(temp)
        tasmota.cmd(f"TempTargetSet {temp}")
    end

end

return thermostat
