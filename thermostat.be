# berry wrapper around "thermostat" tasmota functionality

import json

class thermostat

    var lsens_name, lsens_key
    var use_cron
    var _trigger
    var _override
    var _samp
    var _sampc
    var _sum

    def init()
        self.use_cron = false
        self._trigger = f"Power{self.get_output_relay()}"
        self._override = false
        self._samp = 1
        self._sampc = 0
        self._sum = 0.0
        tasmota.add_rule(self._trigger, / val -> self._pwr_event(val), self)
    end

    def set_output_relay(relay_num)
        tasmota.remove_rule(self._trigger, self)
        tasmota.cmd(f"OutputRelaySet {relay_num}")
        self._trigger = f"Power{self.get_output_relay()}"
        tasmota.add_rule(self._trigger, / val -> self._pwr_event(val), self)
    end

    def use_average(samples)
        self._samp = samples
    end

    def _pwr_event(val)
        print(f"{val=}")
        val = self._is_on(val)
        print(f" {val=}")
        tasmota.publish_rule(format('{"Thermostat":{"relay_state":%d}}', val))
    end

    def _is_on(val)
        import string
        return (val == 1 || val == '1' || string.toupper(str(val)) == 'ON') ? 1 : 0
    end

    def get_output_relay()
        return tasmota.cmd("OutputRelaySet")["OutputRelaySet1"]
    end

    def set_enable_output(enable)
        var val = enable ? 1 : 0
        tasmota.cmd(f"EnableOutputSet {val}")
    end

    def override_on(secs)
        tasmota.remove_timer("thermovrr")
        self.set_enable_output(false)
        self._override = true
        tasmota.cmd(f"Power{self.get_output_relay()} On")
        tasmota.set_timer(int(secs) * 1000, / -> self._override_done(), "thermovrr")
    end

    def override_off(secs)
        tasmota.remove_timer("thermovrr")
        self.set_enable_output(false)
        self._override = true
        tasmota.cmd(f"Power{self.get_output_relay()} Off")
        tasmota.set_timer(int(secs) * 1000, / -> self._override_done(), "thermovrr")
    end

    def override_abort()
        tasmota.remove_timer("thermovrr")
        if self._override
            self._override_done()
        end
    end

    def _override_done()
        self._override = false
        tasmota.publish_rule('{"Thermostat":{"override":0}}')
        self.set_enable_output(true)
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
            tasmota.log(f"Hysteresis must be at least 0.1 °C (given: {hyst})", 1)
        else
            tasmota.cmd(f"TempHystSet {hyst}")
        end
    end

    def set_ramp_up_delta(delta)
        if delta < 0.1
            tasmota.log(f"Ramp-Up delta must be at least 0.1 °C (given: {delta})", 1)
        else
            tasmota.cmd(f"TempRupDeltInSet {delta}")
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
        self._sum += temp
        self._sampc += 1
        if self._sampc == self._samp
            temp = self._sum / self._samp
            tasmota.log(f"THS: Measured temperature {temp}", 4)
            tasmota.cmd(f"TempMeasuredSet {temp}")
            self._sampc = 0
            self._sum = 0.0
        end
    end

    def _update_measured_temp()
        self.set_measured_temp(json.load(tasmota.read_sensors())[self.lsens_name][self.lsens_key])
    end

    def enable()
        tasmota.cmd("ThermostatModeSet 1")
    end

    def disable()
        tasmota.cmd("ThermostatModeSet 0")
    end

    def set_target_temp(temp)
        tasmota.cmd(f"TempTargetSet {temp}")
    end

end

return thermostat
