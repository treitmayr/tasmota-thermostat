# OpenHASP demo
# rm haspmota_demo.tapp ; zip -j -0 haspmota_demo.tapp ../haspmota_src/haspmota_demo/*

#- if !tasmota.memory().contains("psram")
	print("HSP: Error: OpenHASP demo requires PSRAM")
	return
end -#

# needed:
# - disable spash screen in order to speed up boot sequence
#   SetOption135 1
# - use PWM instead of simple on/off for buzzer
#   BuzzerPwm 1
# - set temperature resolution to two decimals (not just one)
#   TempRes 2

# import lv_tasmota_log
import lv_tasmota_info
# import lv_wifi_graph
import lv_thermostat_card
import power_switch_tasmota
import thermostat
import screensaver

import haspmota


class full_thermostat: lv_thermostat_card

	var _t
	var _got

	def init(parent)
		super(self).init(parent)
		var t = thermostat()
		#t.set_pwm(30, 20, 4)
		t.use_average(20)
		self._t = t

		self._got = ''
	end

	def set_output_relay(relay_num)
		self._t.set_output_relay(int(relay_num))
	end

	def set_time_manual_to_auto(mins)
        self._t.set_time_manual_to_auto(mins)
    end

	def setpoint_cb(t)
		self._t.set_target_temp(t)
		if self._got == 'm'
			print("enabling thermostat")
			self._t.enable()
			self._got = '*'
		elif self._got != '*'
			self._got = 's'
		end
	end

	def measured_temp_cb(t)
		self._t.set_measured_temp(t)
		if self._got == 's'
			print("enabling thermostat")
			self._t.enable()
			self._got = '*'
		elif self._got != '*'
			self._got = 'm'
		end
	end
end


haspmota.start(false, tasmota.wd + "pages.jsonl")

var scrsvr = screensaver(30)
global.setmember("scrsvr", scrsvr)     # prevent garbage collection of screensaver

import global

global.p1b20._lv_obj.clear_flag(lv.OBJ_FLAG_SCROLLABLE)

# load custom fonts
#var fstitle = lv.load_font("A:title_symbols.bin")



# var tab_view = lv.tabview(global.p4.get_scr())
# var tab_bar = tab_view.get_tab_bar()
# tab_bar.set_style_pad_gap(0, lv.PART_MAIN)
# tab_bar.set_style_text_font(fstitle, lv.PART_ITEMS)

# var tab
# tab = tab_view.add_tab("\ue9e4")
# tab = tab_view.add_tab("\ue4e9")
# tab = tab_view.add_tab("A")

# var button
# button = tab_bar.get_child_by_type(0, lv.obj_class(lv.button._class))
# # geht nicht:
# # button.set_style_text_font(fstitle, lv.PART_MAIN)
