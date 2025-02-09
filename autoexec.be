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
# import lv_tasmota_log
#import lv_tasmota_info
# import lv_wifi_graph
import lv_thermostat_card
# import power_switch
import thermostat
#import screensaver

import ch422g

import haspmota


class full_thermostat: lv_thermostat_card

	var _t
	var _got

	def init(parent)
		super(self).init(parent)
		var t = thermostat()
		#t.set_pwm(30, 20, 4)
		t.set_measure_interval(20)   # 2 s interval
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

global.platform_driver = waveshare_lcd_43_driver()
global.platform_driver.set_AD_usage(global.platform_driver.DIG_OUT, 0)
var relay_power_index = global.platform_driver.get_AD_power_index()
# TODO: Propagate the relay index to the haspmota instance of full_thermostat

#var ex_io = ch422g()
# set default output according to measurements and the schematic:
#   EXIO0 .. NC, low
#   EXIO1 .. CTP_RST, high
#   EXIO2 .. DISP, high
#   EXIO3 .. LCD_RST, pull-up
#   EXIO4 .. SDCS, pull-up
#   EXIO5 .. USB_SEL, low
#   EXIO6+7 .. NC
#ex_io.set_to_output(0x1e)
#global.ex_io = ex_io
# BIG NOTE:
# There seems to be something wrong with re-enabling the display via the DISP pin!
# Observations with the following screensaver configuration:
#     "berry_on":"global.ex_io.set_output_pin(2,true)","berry_off":"global.ex_io.set_output_pin(2,false)"
#     => Turning the display back on leads to a restart of the CPU after ~0.5 s after the display has turned on.
#        Also the USB serial connection (to a PC) is lost! Maybe there the sudden load of the LCD backlight
#        driver + LCD controller cause a VCC breakdown or ground bounce???
# Workaround:
# Turning on has to be done by flipping the pins to the input direction, i.e.
#     "berry_on":"global.ex_io.set_to_input()","berry_off":"global.ex_io.set_to_output(0x1a)"

haspmota.start(false) # default: tasmota.wd + "pages.jsonl"

#global.scrsvr = screensaver()    # prevent garbage collection of screensaver
#global.scrsvr.set_delay(30)

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
