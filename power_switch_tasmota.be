import lv
import mqtt

class power_switch_tasmota: lv.switch

    var _remote_name
    var _prepare_enable
    var _text_checked
    var _text_unchecked
    var _lv_label
    var _confirm_power
    var _confirm_text_on
    var _confirm_text_off
    var _msgbox

    def init(parent)
        super(self).init(parent)

        # start disabled
        self.add_state(lv.STATE_DISABLED)

        # get informed about user actions
        self.add_event_cb( / obj, event -> self._switch_changed(obj, event), lv.EVENT_VALUE_CHANGED, 0)

        # track connected state to enable/disable the switch
        tasmota.add_rule("Mqtt#Connected", / -> self._mqtt_connect())
        tasmota.add_rule("Mqtt#Disconnected", / -> self._mqtt_disconnect())
    end

    def get_remote(name)
        return self._remote_name
    end

    def set_remote(name)
        if self._remote_name
            mqtt.unsubscribe(self._get_topic("stat", "RESULT"))
            self._mqtt_disconnect()
        end
        self._remote_name = name
        if self._remote_name
            mqtt.subscribe(self._get_topic("stat", "RESULT"),
                           / topic,idx,payload_s -> self._mqtt_result(topic,idx,payload_s))
            self._mqtt_connect()
        end
    end

    # similar to lvh_obj.check_label()
    def _check_label()
        if self._lv_label == nil
            # create a sub-label object
            self._lv_label = lv.label(self)
            self._lv_label.set_align(lv.ALIGN_CENTER)
        end
    end

    def set_text_checked(text)
        self._check_label()
        self._text_checked = str(text)
        self._update_text()
    end

    def set_text_unchecked(text)
        self._text_unchecked = str(text)
        self._update_text()
    end

    def set_confirm_power(power)
        self._confirm_power = power
    end

    def set_confirm_text_on(text)
        self._confirm_text_on = text
    end

    def set_confirm_text_off(text)
        self._confirm_text_off = text
    end

    def _update_text(state)
        if self._lv_label == nil
            return
        end
        if state == nil
            state = self.has_state(lv.STATE_CHECKED)
        end
        if state && self._text_checked != nil
            self._lv_label.set_text(self._text_checked)
        elif !state && self._text_unchecked != nil
            self._lv_label.set_text(self._text_unchecked)
        end
    end

    def _switch_changed(obj, event)
        var state = self.has_state(lv.STATE_CHECKED)
        var change_now = false
        # turn on
        if state && self._confirm_text_on
            self._confirm(self._confirm_text_on)
        elif !state && self._confirm_text_off
            if self._confirm_power != nil
                self._start_power_reading()
            else
                self._confirm(self._confirm_text_off)
            end
        else
            # change right now
            self._update_text(state)
            mqtt.publish(self._get_topic("cmnd", "Power"), state ? "ON" : "OFF")
        end
    end

    def _confirm(text)
        # create modal dialog box
        var mbox = lv.msgbox(0)
        self._msgbox = mbox
        mbox.set_style_bg_opa(100, 0)
        mbox.set_style_pad_all(10, lv.PART_MAIN | lv.STATE_DEFAULT)
        var txt = mbox.add_text(text)
        txt.set_style_pad_bottom(10, lv.PART_MAIN | lv.STATE_DEFAULT)

        var btn = mbox.add_footer_button(lv.SYMBOL_OK)
        var height = lv.font_get_line_height(btn.get_style_text_font(lv.PART_MAIN))
        btn.set_width(height * 3)         # set width based on height
        btn.add_event_cb( / -> self._confirm_cb_ok(), lv.EVENT_CLICKED, 0)

        btn = mbox.add_footer_button(lv.SYMBOL_CLOSE)
        btn.set_width(height * 3)
        btn.add_event_cb( / -> self._confirm_cb_cancel(), lv.EVENT_CLICKED, 0)
    end

    def _confirm_cb_ok()
        self._msgbox.close()
        self._msgbox = nil
        # turn on/off power
        var state = self.has_state(lv.STATE_CHECKED)
        self._update_text(state)
        mqtt.publish(self._get_topic("cmnd", "Power"), state ? "ON" : "OFF")
    end

    def _confirm_cb_cancel()
        self._msgbox.close()
        self._msgbox = nil
        # revert state
        var state = self.has_state(lv.STATE_CHECKED)
        if state
            self.clear_state(lv.STATE_CHECKED)
        else
            self.add_state(lv.STATE_CHECKED)
        end
    end

    def _start_power_reading()
        mqtt.subscribe(self._get_topic("stat", "STATUS10"),
                       / topic,idx,payload_s -> self._mqtt_result(topic,idx,payload_s))
        mqtt.publish(self._get_topic("cmnd", "Status"), "10")
        # TODO: start some timeout (1s) as fallback!
    end

    def _mqtt_result(topic, idx, payload_s)
        import json
        var obj = json.load(payload_s)
        var res
        def traverse(keys)
            res = self._traverse(obj, keys)
            return res != nil
        end
        #print(f"topic={topic}, idx={idx}, payload_s={payload_s}")
        if traverse(["POWER"])
            if res == "ON"
                self.add_state(lv.STATE_CHECKED)
                self._update_text(true)
            else
                self.clear_state(lv.STATE_CHECKED)
                self._update_text(false)
            end
            if self._prepare_enable
                # enable the switch
                self.clear_state(lv.STATE_DISABLED)
                self._prepare_enable = false
            end
        elif topic == self._get_topic("stat", "STATUS10")
            mqtt.unsubscribe(self._get_topic("stat", "STATUS10"))
            if traverse(["StatusSNS", "ENERGY", "Power"])
                if res >= self._confirm_power
                    self._confirm(self._confirm_text_off)
                else
                    self._update_text(false)
                    mqtt.publish(self._get_topic("cmnd", "Power"), "OFF")
                end
            end
        end
    end

    def _traverse(obj, keys)
        var res = obj
        for k: keys
            if !res.contains(k)
                return nil
            end
            res = res[k]
        end
        return res
    end

    def _mqtt_connect()
        if self._remote_name
            # query the current power state
            mqtt.publish(self._get_topic("cmnd", "Power"), "")
            self._prepare_enable = true
        end
    end

    def _mqtt_disconnect()
        # disable the switch
        self.add_state(lv.STATE_DISABLED)
        self._prepare_enable = false
    end

    def _get_topic(kind, name)
        return f"{kind}/{self._remote_name}/{name}"
    end

end

return power_switch_tasmota
