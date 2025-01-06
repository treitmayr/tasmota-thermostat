# OpenHASP demo
# rm haspmota_demo.tapp ; zip -j -0 haspmota_demo.tapp ../haspmota_src/haspmota_demo/*

#- if !tasmota.memory().contains("psram")
	print("HSP: Error: OpenHASP demo requires PSRAM")
	return
end -#

# disable spash screen in order to speed up boot sequence
tasmota.cmd("SetOption135 1")

# import lv_tasmota_log
import lv_tasmota_info
import lv_wifi_graph

import haspmota

class my_haspmota: HASPmota
	def _load(templ_name)
		import string
		import json

		var f = open(templ_name,"r")
		var fsize = f.size()

		# parse each line
		while f.tell() < fsize
			var jsonl = f.readline()
			var jline = json.load(jsonl)
			if type(jline) == 'instance'
				if tasmota.loglevel(4)
					tasmota.log(f"HSP: parsing line '{jsonl}'", 4)
				end
				self.parse_page(jline)    # parse page first to create any page related objects, may change self.lvh_page_cur_idx_parsing
				# objects are created in the current page
				if (self.lvh_pages == nil)
					raise "value_error", "no page 'id' defined"
				end
				self.parse_obj(jline, self.lvh_pages[self.lvh_page_cur_idx_parsing])    # then parse object within this page
			else
				# check if it's invalid json
				if size(string.tr(jsonl, " \t", "")) > 0
					tasmota.log(f"HSP: invalid JSON line '{jsonl}'", 2)
				end
			end
			jline = nil
			jsonl = nil
		end
		f.close()

		# current page is always 1 when we start
		var pages_sorted = self.pages_list_sorted(nil)            # nil for full list
		if (size(pages_sorted) == 0)
			raise "value_error", "no page object defined"
		end
		self.lvh_page_cur_idx = pages_sorted[0]
		self.lvh_pages[self.lvh_page_cur_idx].show(0, 0)          # show first page
	end
end

haspmota.start(false, tasmota.wd + "pages.jsonl")

def p5_in()
	import global
	global.p0b101.bg_opa = 0
	global.p0b102.bg_opa = 0
	global.p0b103.bg_opa = 0
	global.p0b11.bg_opa = 0
end

def p5_out()
	import global
	global.p0b101.bg_opa = 255
	global.p0b102.bg_opa = 255
	global.p0b103.bg_opa = 255
	global.p0b11.bg_opa = 255
end

tasmota.add_rule("hasp#p5=in", p5_in)
tasmota.add_rule("hasp#p5=out", p5_out)

import global

global.p4b51._lv_obj.clear_flag(lv.OBJ_FLAG_SCROLLABLE)


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
