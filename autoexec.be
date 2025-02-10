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

import global

import waveshare_lcd_43_driver

import lv_thermostat_card
import simple_thermostat
import haspmota


class full_thermostat: lv_thermostat_card

	var _t

	def init(parent)
		super(self).init(parent)
		var t = simple_thermostat()
		#t.set_pwm(30, 20, 4)
		t.set_measure_interval(20)
		#print(f"{global.relay_power_index=}")
		t.set_output_relay(global.relay_power_index)
		t.set_enable_output(true)
		self._t = t
		tasmota.defer(/-> self._t.enable())
	end

	def setpoint_cb(t)
		#print(f"setpoint_cb({t=})")
		self._t.set_target_temp(t)
	end

	def measured_temp_cb(t)
		#print(f"measured_temp_cb({t=})")
		self._t.set_measured_temp(t)
	end
end

global.platform_driver = waveshare_lcd_43_driver()
global.platform_driver.set_AD_usage(global.platform_driver.DIG_OUT, 0)
global.relay_power_index = global.platform_driver.get_AD_power_index()

haspmota.start(false) # default: tasmota.wd + "pages.jsonl"

global.p1b10._lv_obj.get_content().clear_flag(lv.OBJ_FLAG_SCROLLABLE)
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
