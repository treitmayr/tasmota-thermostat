# OpenHASP demo
# rm haspmota_demo.tapp ; zip -j -0 haspmota_demo.tapp ../haspmota_src/haspmota_demo/*

#- if !tasmota.memory().contains("psram")
	print("HSP: Error: OpenHASP demo requires PSRAM")
	return
end -#

# disable spash screen in order to speed up boot sequence
tasmota.cmd("SetOption135 1")

# use PWM instead of simple on/off for buzzer
tasmota.cmd("BuzzerPwm 1")

# set temperature resolution to two decimals (not just one)
tasmota.cmd("TempRes 2")

# import lv_tasmota_log
import lv_tasmota_info
# import lv_wifi_graph
import lv_thermostat_card
import lv_switch_mqtt

import haspmota

haspmota.start(false, tasmota.wd + "pages.jsonl")

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
