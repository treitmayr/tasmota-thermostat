# simple two-point thermostat
#class tasmota end class lv end
import json
import avg_interval

class simple_thermostat

    var lsens_name, lsens_key
    var use_cron
    var _trigger
    var _override
    var _avg
    var _orelay
    var _o_en
    var _max_on
    var _min_on
    var _min_off
    var _hyst
    var _setpoint
    var _measured
    var _enabled
    var _heat
    var _trg_heat
    var _max_on_tmr
    var _min_on_tmr
    var _min_off_tmr

    def init()
        self.use_cron = false
        self._override = false
        self._o_en = false
        self._max_on = 20 * 60000
        self._min_on = 4 * 60000
        self._min_off = 4 * 60000
        self._hyst = 0.2
        self._enabled = false
        self._heat = false
        self._trg_heat = false
        self._avg = avg_interval()
    end

    def set_output_relay(relay_num)
        if self._trigger != nil
            tasmota.remove_rule(self._trigger, self)
        end
        self._orelay = int(relay_num)
        #print(f"{self._orelay=}")
        self._trigger = f"Power{self._orelay}"
        tasmota.add_rule(self._trigger, / val -> self._pwr_event(val), self)
    end

    def get_output_relay()
        return self._orelay
    end

    def set_measure_interval(secs)
        self._avg.set_interval(secs)
    end

    def _pwr_event(val)
        val = self._is_on(val)
        tasmota.publish_rule(format('{"Thermostat":{"relay_state":%d}}', val))
    end

    def _is_on(val)
        import string
        return (val == 1 || val == '1' || string.toupper(str(val)) == 'ON') ? 1 : 0
    end

    def set_enable_output(enable)
        self._o_en = bool(enable)
        self._recompute()
    end

    def override_on(secs)
        self._do_override(secs, true)
    end

    def override_off(secs)
        self._do_override(secs, false)
    end

    def _do_override(secs, state)
        tasmota.remove_timer("thermovrr")
        self._override = true
        tasmota.publish_rule('{"Thermostat":{"override":1}}')
        self._recompute(state)
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
        self._recompute()
    end

    def set_pwm(max_on, min_on, min_off)
        # all parameters in minutes
        self._max_on = max_on * 60000
        self._min_on = min_on * 60000
        self._min_off = min_off * 60000
    end

    def set_hysteresis(hyst)
        if hyst < 0.1
            tasmota.log(f"Hysteresis must be at least 0.1 °C (given: {hyst})", 1)
        else
            self._hyst = hyst
            self._recompute()
        end
    end

    # def set_ramp_up_delta(delta)
    #     if delta < 0.1
    #         tasmota.log(f"Ramp-Up delta must be at least 0.1 °C (given: {delta})", 1)
    #     else
    #         tasmota.cmd(f"TempRupDeltInSet {delta}")
    #     end
    # end

    # def use_local_sensor(name, key)
    #     var res, ress
    #     if name
    #         self.lsens_name = name
    #         if key
    #             self.lsens_key = key
    #         else
    #             self.lsens_key = "Temperature"
    #         end
    #         ress = tasmota.read_sensors()
    #         res = json.load(ress)
    #         if !res.contains(self.lsens_name)
    #             tasmota.log(f"THS: Cannot find sensor '{self.lsens_name}' in '{ress}'", 1)
    #         elif !res[self.lsens_name].contains(self.lsens_key)
    #             tasmota.log(f"THS: Cannot find key '{self.lsens_key}' in '{res[name]}'", 1)
    #         else
    #             tasmota.log(f"THS: Using local sensor {self.lsens_name}.{self.lsens_key}", 2)
    #             tasmota.cmd("SensorInputSet 0")
    #             self.set_measured_temp(res[self.lsens_name][self.lsens_key])
    #             if self.use_cron
    #                 tasmota.remove_cron("termostat_update_measured")
    #             end
    #             tasmota.add_cron("*/2 * * * * *", def () self._update_measured_temp() end, "termostat_update_measured")
    #             self.use_cron = true
    #         end
    #     else
    #         if self.use_cron
    #             tasmota.remove_cron("termostat_update_measured")
    #             self.use_cron = false
    #         end
    #         tasmota.log(f"THS: Using default local sensor", 2)
    #         tasmota.cmd("SensorInputSet 1")
    #     end
    # end

    # def _update_measured_temp()
    #     self.set_measured_temp(json.load(tasmota.read_sensors())[self.lsens_name][self.lsens_key])
    # end

    def set_measured_temp(temp)
        var avg_temp = self._avg.add_value(temp)
        if avg_temp == nil && self._measured == nil
            # use the initial value immediately
            avg_temp = temp
        end
        if avg_temp != nil
            tasmota.log(f"THS: Measured temperature {avg_temp}", 4)
            self._measured = avg_temp
            self._recompute()
        end
    end

    def enable()
        self._timers_expired()
        self._enabled = true
        self._recompute()
    end

    def disable()
        self._recompute(false)
        self._enabled = false
    end

    def set_target_temp(temp)
        tasmota.remove_timer("thermstt")
        # defer actually setting the setpoint to allow for corrections
        tasmota.set_timer(5000, def ()
            self._setpoint = temp
            self._recompute()
        end, "thermstt")
    end

    def _recompute(heat_overridden)
        if !self._enabled
            return
        end
        #print(f"_recompute: {self._heat=}, {self._trg_heat=}, {self._override}")
        if !self._o_en
            self._trg_heat = false
        elif self._override
            self._timers_expired()
            if heat_overridden != nil
                tasmota.publish_rule(format('{"Thermostat":{"desired_state":%d}}', int(heat_overridden)))
                self._trg_heat = heat_overridden
            end
        else
            if self._setpoint == nil || self._measured == nil
                return
            end
            var new_heat = self._trg_heat
            if self._trg_heat
                if self._measured > (self._setpoint + self._hyst/2)
                    new_heat = false
                end
            elif !self._trg_heat
                if self._measured < (self._setpoint - self._hyst/2)
                    new_heat = true
                end
            end
            #print(f"    {new_heat=}")
            if new_heat != self._trg_heat
                tasmota.publish_rule(format('{"Thermostat":{"desired_state":%d}}', int(new_heat)))
                if new_heat
                    if tasmota.time_reached(self._min_off_tmr)
                        self._min_on_tmr = tasmota.millis(self._min_on)
                        self._max_on_tmr = tasmota.millis(self._max_on)
                        self._trg_heat = new_heat
                    end
                elif tasmota.time_reached(self._min_on_tmr)
                    self._min_off_tmr = tasmota.millis(self._min_off)
                    self._trg_heat = new_heat
                end
            elif self._trg_heat && tasmota.time_reached(self._max_on_tmr)
                self._trg_heat = false
            end
            #print(f"    {self._trg_heat=}")
        end
        if self._trg_heat != self._heat
            self._heat = self._trg_heat
            tasmota.cmd(f"Power{self._orelay} " + (self._heat ? "On" : "Off"))
        end
    end

    def _timers_expired()
        # treat timers as already expired
        var now = tasmota.millis()
        self._max_on_tmr = now
        self._min_on_tmr = now
        self._min_off_tmr = now
    end

end

return simple_thermostat
